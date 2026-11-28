# Implementation Plan

This plan implements `docs/REQUIREMENTS.md`. Where the two differ, the requirements take precedence.

## Platform and Tooling

- Swift 6 (strict concurrency), SwiftUI, iOS/iPadOS 18 minimum, a single universal target.
- Frameworks: PhotosUI, ImageIO, Core Graphics, Photos (add-only), UniformTypeIdentifiers. No third-party dependencies.
- The Xcode project uses file-system-synchronized groups (Xcode 16+), which keep `project.pbxproj` small and stable. Targets: `InsetFrame` (app) and `InsetFrameTests` (Swift Testing).

## Architecture

There is one screen, one observable model, and a few pure helpers. There are no coordinators, repositories, or protocol layers beyond what the tests need.

```
InsetFrame/
  App/          InsetFrameApp.swift
  Model/        FrameSettings.swift        settings, ranges, defaults, clamping, Codable
                FrameColor.swift           RGBA + color space, presets, persistence
                SliderMapping.swift        nonlinear width mapping
  Geometry/     FrameGeometry.swift        single source of truth for frame rects
                AspectFit.swift            displayed-image rect inside a view
  Rendering/    FrameRenderer.swift        fills the ring into any CGContext / SwiftUI Path
  Photo/        PhotoLoader.swift          picker data → preview thumbnail + source
                PhotoExporter.swift        full-res render, encode, metadata
                PhotoLibrarySaver.swift    add-only save
  Editor/       EditorModel.swift          @Observable @MainActor state
                EditorView.swift           adaptive layout
                PreviewView.swift          image + frame overlay, press-and-hold compare
                ControlsPanel.swift        sliders, color row, reset/save
                EmptyStateView.swift
```

## Shared Geometry (Preview = Export)

`FrameGeometry` is a pure function:

```swift
struct FrameGeometry {
    let outerRect: CGRect   // image rect inset by frameOffset
    let innerRect: CGRect   // image rect inset by frameOffset + frameWidth
    init(imageRect: CGRect, settings: FrameSettings)
}
```

- `S = min(imageRect.width, imageRect.height)`. Width and offset are `S * percent / 100`. All values are `CGFloat`, with no rounding.
- **Preview:** `imageRect` is the aspect-fit rect of the photograph inside the preview view (computed by `AspectFit`), not the view's bounds. The ring is drawn as a SwiftUI `Path` with even-odd fill, overlaid in the same coordinate space.
- **Export:** `imageRect` is `(0, 0, W, H)` of the orientation-corrected full-resolution image. The ring is filled with the same path construction in a `CGContext`.
- Both paths call the same `FrameGeometry` and the same `FrameRenderer.ringPath(...)`, so the only difference between preview and export is the scale.

## Image Pipeline

- **Selection:** `PhotosPicker` (no permission prompt) → `loadTransferable(type: Data.self)`. The original encoded data and its UTType are kept in memory. The original asset is never modified.
- **Preview image:** ImageIO `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailWithTransform` (orientation applied). The maximum pixel size is the screen's longest side × scale, and the image is decoded off the main thread.
- **Export:** runs off the main thread (`Task.detached` / a nonisolated async function):
  1. Decode the full-resolution, orientation-corrected image with ImageIO.
  2. Create a `CGContext` at the original pixel dimensions in the source color space (falling back to Display P3), as 8-bit SDR.
  3. Draw the photo, then fill the ring with the frame color at `opacity = 1 - transparency`.
  4. Encode with `CGImageDestination`: HEIC→HEIC, JPEG→JPEG, other→HEIC. Copy the source properties (EXIF/TIFF/GPS), set orientation to 1, and use high quality.
  5. Write to a temporary file. Only one full-resolution bitmap exists at a time, and it is released immediately after encoding.
- **Save:** `PHPhotoLibrary.requestAuthorization(for: .addOnly)` → `PHAssetCreationRequest.addResource(with: .photo, fileURL:)`.
- **Share:** export the same encoded file → share sheet (`ShareLink` with a file URL, or `UIActivityViewController`), so metadata is included.

## Settings and Persistence

- `FrameSettings`: `widthPercent` 0–5 (default 0.5), `offsetPercent` 0–20 (default 5), `transparencyPercent` 0–100 (default 0), `color` (default black). Every setter clamps its value. `isValid` enforces `2 * (offset + width) < 100`, which is always true within these ranges.
- The width slider uses a quadratic mapping, `percent = 5 * t²` with `t ∈ [0, 1]`, which gives fine control at thin widths.
- Settings are persisted as JSON in `UserDefaults` whenever they change, restored at launch, and applied to each newly selected photograph. Reset restores the defaults.

## User Interface and Interaction Flow

1. **Empty state:** an app title and a "Choose Photo" button (`PhotosPicker`).
2. **Editing screen:**
   - Toolbar: a photo picker button (leading) and Share (trailing).
   - Preview: the full photograph with square corners and the frame overlay. Press and hold to hide the frame. The same comparison is available as an accessibility action ("Show original").
   - Controls: labeled sliders with values (width and offset in full-resolution pixels, e.g. `15 px`, `150 px`; transparency `0%`). A color row with six preset swatches and a `ColorPicker`. Reset and Save Photo buttons.
   - Saving shows a progress indicator, then a brief, non-modal "Saved" confirmation. Errors are shown in an alert.
3. **Layouts** are selected by available size rather than device type:
   - Compact width, taller than wide (iPhone portrait, narrow iPad split view): preview above the controls.
   - Wider than tall with compact height (iPhone landscape): preview on the leading side, scrollable controls panel (~320 pt) on the trailing side.
   - Regular width (iPad, large windows): a large preview with a fixed-width (~340 pt) controls panel alongside it, in both orientations and while resizing.
- Light/dark mode, Dynamic Type (the controls scroll when text is large), VoiceOver labels and values, and 44 pt minimum touch targets.

## Testing

Swift Testing, in the simulator:

- **Geometry:** expected pixel values (e.g. 4000×3000 at 0.5%/2% → 15 px and 60 px), proportional results across resolutions, equal insets on all four sides, the outer/inner rect relationship, portrait/landscape/square/panoramic images.
- **Validation:** clamping at the range boundaries, transparency limits, and that every in-range combination is valid.
- **Slider mapping:** round trip and monotonic.
- **Aspect fit / letterbox:** the preview frame is aligned to the displayed image rect, not the view bounds.
- **Preview/export consistency:** render small and large versions of the same synthetic image and compare the frame edge positions after normalizing by S.
- **Export:**
  - output dimensions equal the source dimensions
  - EXIF-rotated sources (orientation 6/8) come out upright with orientation 1
  - metadata is copied
  - the format mapping is correct
  - ring pixels have the frame color, and pixels inside and outside the ring are unchanged
- Build and check the layouts on iPhone and iPad simulators, in portrait and landscape.

## Decisions Needing Approval

1. **Bundle identifier:** proposed `com.yurtkuran.InsetFrame`.
2. **App display name:** proposed "Inset Frame".
3. **Xcode project:** hand-written `project.pbxproj` with synchronized folders (no XcodeGen or other tooling).
4. **Language mode:** Swift 6 strict concurrency.
