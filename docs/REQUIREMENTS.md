# iOS Inset Frame App

## Product Vision

Design and develop a native iOS application for iPhone and iPad with one purpose: adding beautiful, customizable inset frames to photographs.

The application should do one thing and do it exceptionally well. It should not be a jack of all trades, a Swiss Army knife, or a general-purpose photo editor.

The guiding principles are simplicity, precision, responsiveness, minimalism, and ease of use. Every design and implementation decision should reinforce these principles.

## Definition of an Inset Frame

An inset frame is a rectangular outline superimposed directly onto a photograph, positioned a configurable distance inward from the photograph's edges.

Unlike a traditional photo border, an inset frame:

- Does not expand the image canvas.
- Does not crop or resize the photograph.
- Does not change the photograph's aspect ratio.
- Allows the original photograph to remain visible on both sides of the frame when the offset is positive.
- Is rendered directly over the photograph.

The frame must follow the photograph's rectangular boundaries, with consistent spacing from all four edges.

## Core Functionality

### 1. Photo Selection

- Allow users to select a photograph from their Apple Photos library using the native photo picker.
- Support portrait, landscape, square, and nonstandard aspect ratios.
- Correctly handle image orientation.
- Preserve the original photograph.
- Do not require unnecessary photo library permissions.

### 2. Frame Customization

Provide three primary sliders and a color picker.

**Frame Width**

- Control the thickness of the frame line.
- Support extremely thin, subtle lines as well as thicker, more pronounced frames.
- Display the current value alongside the slider in pixels at the photograph's full resolution (for example, "15 px" for 0.5% of a 3000-pixel shortest dimension), rounded to the nearest whole pixel. The value is stored and applied as a percentage of the shortest dimension (see Resolution-Independent Frame Geometry); pixels are a display unit only.
- Range: 0% to 5% of the shortest dimension. Default: 0.5%.
- Use a nonlinear (for example, quadratic) slider mapping so that very thin widths can be set precisely. Store the percentage with two decimal places.
- A width of 0% renders no frame.
- Update the preview continuously as the slider is adjusted.

**Frame Offset**

- Control the distance between the photograph's edges and the outer edge of the inset frame.
- Apply the same offset to all four sides.
- Allow the frame to be positioned close to the photograph's edges or significantly farther inward.
- Adjust the offset independently of the frame width.
- Display the current value in pixels at the photograph's full resolution, rounded to the nearest whole pixel. Store it as a percentage of the shortest dimension, with one decimal place.
- Range: 0% to 20% of the shortest dimension. Default: 5%.
- Prevent invalid combinations of frame width and offset. The width and offset ranges are chosen so that every combination is valid: at their maximums, `2 * (20% + 5%) = 50%` of the shortest dimension, leaving a positive interior. The sliders therefore never constrain each other.

**Frame Transparency**

- Control the transparency of the frame.
- Support a range from completely opaque (0% transparency) to completely transparent (100% transparency).
- Display the current transparency as a percentage.
- Default to a fully opaque frame.

**Frame Color**

- Default to black.
- Provide a compact row of preset color swatches: black, white, gray, tan, brown, and slate.
- Provide a native iOS color picker (SwiftUI `ColorPicker`) in the same row for choosing an arbitrary custom color.
- Clearly indicate the selected color, whether it is a preset or a custom color.
- Store and render colors in a defined color space (Display P3 or extended sRGB) so that the preview, export, and saved preferences match.
- Keep the color selection interface compact and unobtrusive.

All frame properties must be independently adjustable within valid geometric limits.

### 3. Real-Time Preview

The photograph should be the focal point of the application.

- Render frame adjustments immediately and continuously.
- Ensure slider interactions are smooth and responsive.
- Display the entire photograph without cropping.
- Ensure the preview accurately represents the exported image.
- Provide a simple before-and-after comparison, such as pressing and holding the preview to temporarily hide the frame. Expose an equivalent accessibility action so VoiceOver users can also compare.
- Ensure the preview works equally well with portrait and landscape photographs.
- Display the photograph with square corners. Do not round, clip, or otherwise alter the preview in ways that would not appear in the export.
- Render the preview from a downsampled copy of the photograph sized to the display; decode the full-resolution image only for export.
- Known limitation: frame widths thinner than one display pixel in the preview are drawn anti-aliased and may look softer than in the full-resolution export. Geometry remains identical; do not inflate preview widths to compensate.

### 4. Export and Sharing

- Save the edited photograph to Apple Photos as a new image.
- Support the native iOS share sheet.
- Preserve the original image resolution and aspect ratio.
- Preserve image quality and color accuracy.
- Preserve relevant image metadata where technically appropriate.
- Never overwrite or modify the original photograph.
- Do not add watermarks, branding, or other unwanted elements.
- Request add-only photo library access (`NSPhotoLibraryAddUsageDescription`) for saving. Never request full library access.

**Export format and image handling (v1)**

- Export HEIC sources as HEIC and JPEG sources as JPEG. Export other formats (PNG, ProRAW/DNG, and others) as HEIC.
- For Live Photos, export the still image only.
- Export in standard dynamic range (SDR). Preserving HDR gain maps is out of scope for v1.
- Preserve the source color space (for example, Display P3) where possible.
- Preserve EXIF, TIFF, and GPS metadata. Because the pixels are written upright, set the orientation tag to "up" (1).
- Share the encoded file with its metadata through the share sheet, not a metadata-less in-memory image.

The exported frame must precisely match the preview, regardless of the original image resolution or device screen size.

### 5. Preferences

- Automatically remember the most recently used frame width, offset, transparency, and color.
- Apply these settings when another photograph is selected.
- Provide a simple Reset control to restore the default frame settings: width 0.5%, offset 5%, transparency 0%, and black.
- Persist custom colors along with their color space.

Do not introduce a dedicated settings screen unless absolutely necessary.

## User Interface and User Experience

The interface should be minimal, polished, intuitive, and distinctly native to iOS.

The primary workflow should be:

1. Select a photograph.
2. Adjust the frame.
3. Save or share the photograph.

The user should be able to complete this workflow within seconds.

### Design Requirements

- Use a single primary editing screen.
- Maximize the space available for the photograph preview.
- Group the three sliders and color picker into a compact, accessible control area.
- Clearly label each control.
- Display current slider values.
- Use native iOS controls wherever appropriate.
- Support light and dark mode.
- Support Dynamic Type and VoiceOver.
- Provide appropriate touch target sizes.
- Avoid unnecessary animations, decorative elements, navigation, and visual clutter.
- Do not include an onboarding tutorial. The interface should be sufficiently intuitive that one is unnecessary.
- Provide a minimal empty state when no photograph is selected, with a single clear action to choose one.
- Use native SwiftUI `Slider` controls rather than custom-styled tracks.

### Reference Mockup

`docs/suggested interface.jpg` shows the intended iPhone portrait layout: a toolbar with photo picker and share actions, the preview, labeled sliders with values, a color swatch row, and Reset and Save Photo actions. Where it conflicts with this document, this document takes precedence. In particular:

- The frame width value must be shown with its unit (pixels), not as "2.0".
- The color row must include the native custom color picker in addition to the presets.
- The preview must not have rounded corners.
- The frame offset must be equal on all four sides.

### iPhone Layout

- Place the photograph preview prominently above the editing controls in portrait orientation.
- Keep the editing controls easily accessible.
- Adapt gracefully to landscape orientation. In landscape, place the controls beside the preview rather than below it, because the controls occupy too much vertical space to stack.

### iPad Layout

- Take advantage of the additional screen space.
- Consider a large photograph preview with a compact editing panel alongside it.
- Support portrait and landscape orientations.
- Support resizable windows and multitasking.
- Do not simply stretch the iPhone interface to fill the iPad screen.

The iPhone and iPad versions should provide the same functionality with layouts appropriate to their respective screen sizes.

## Technical Requirements

- Develop a native Apple application using Swift and SwiftUI.
- Minimum supported versions: iOS 18 and iPadOS 18.
- Use a single codebase supporting both iPhone and iPad.
- Use modern Apple frameworks and APIs.
- Use PhotosUI for photograph selection.
- Use Core Graphics, Core Image, or another appropriate native rendering technology for full-resolution image export.
- Handle high-resolution photographs efficiently without excessive memory consumption. A 48 MP photograph occupies roughly 190 MB when decoded, so use ImageIO downsampling for the preview and keep at most one full-resolution decode alive, only during export.
- Avoid blocking the main thread during expensive image processing or export operations.
- Use local persistence for frame preferences.
- Prefer native Apple frameworks over third-party dependencies.
- Keep the architecture clean, maintainable, testable, and proportionate to the simplicity of the application.
- Avoid unnecessary architectural abstractions and overengineering.

The application must operate entirely on-device and function without an internet connection. No photograph or user data should be transmitted to an external service by the application.

### Resolution-Independent Frame Geometry

Calculate frame width and frame offset as percentages of the photograph's shortest dimension, rather than fixed pixel values. This ensures consistent visual proportions regardless of image resolution, aspect ratio, orientation, or device screen size. Remembered settings therefore keep the same proportions on the next photograph, and the displayed pixel values change with that photograph's resolution.

Use the same geometry calculations for both the real-time preview and full-resolution export.

For an orientation-corrected photograph with dimensions `W` and `H`:

- `S = min(W, H)`
- `frameWidth = S * widthPercent / 100`
- `frameOffset = S * offsetPercent / 100`
- `opacity = 1 - transparencyPercent / 100`

The offset is measured from the image edge to the outer edge of the frame, not to its centerline. For a centered stroke, inset the rectangular path by `frameOffset + frameWidth / 2` on all four sides.

Render the frame as a filled ring rather than a stroked path: the outer rectangle inset by `frameOffset`, minus the inner rectangle inset by `frameOffset + frameWidth`, filled using the even-odd rule. This is geometrically identical to the centered stroke above, but it produces exact square corners and avoids differences in how lines are joined between renderers.

Validate that width and offset are nonnegative, that transparency is between 0% and 100%, and that `2 * (frameOffset + frameWidth) < S` so the frame retains a positive interior area. A visible frame requires positive width. Prevent invalid combinations through the editing controls and rendering validation.

Calculate preview geometry relative to the actual displayed photograph, not its surrounding view, padding, or letterboxed area. Preserve fractional precision until rasterization. Use the same normalized parameters and geometry logic for export at the original image dimensions.

For example, a width of 0.5% and an offset of 2% produce a 15-pixel frame and 60-pixel offset on a 4000 × 3000 image, and a 30-pixel frame and 120-pixel offset on an 8000 × 6000 image. Both have identical proportional geometry.

## Explicitly Out of Scope

Do not implement any of the following:

- General-purpose photo editing.
- Image cropping or resizing.
- Exposure, contrast, saturation, or other image adjustments.
- Filters or photographic effects.
- Traditional external borders.
- Multiple frames.
- Decorative frame templates.
- Text overlays.
- Stickers.
- Watermarks.
- Collages.
- Drawing tools.
- AI-powered features.
- User accounts or authentication.
- Cloud storage or synchronization.
- Social networking features.
- Analytics or tracking.
- Advertising.
- Subscriptions or in-app purchases.

Do not introduce additional functionality simply because it is easy to implement or commonly found in competing photography applications.

Any proposed feature that expands the scope beyond adding an inset frame must be discussed and approved before implementation.

## Quality and Testing

Give particular attention to the accuracy of frame rendering and the quality of the exported photograph.

Test the application with:

- Portrait, landscape, square, panoramic, and unusually proportioned photographs.
- High-resolution photographs.
- Photographs containing orientation metadata.
- Minimum and maximum frame widths.
- Minimum and maximum frame offsets.
- All transparency levels.
- Custom frame colors.
- Combinations of large frame widths and offsets.
- iPhone and iPad screen sizes.
- Portrait and landscape device orientations.
- Light and dark mode.
- Repeated photograph selection and export.

Include automated tests for frame geometry, parameter validation, and consistency between preview and export. Verify proportional geometry across different image resolutions, equal offsets on all four sides, correct stroke placement, and preview alignment when the image is letterboxed. Verify that exported dimensions remain unchanged.

## Implementation Approach

Before writing code:

1. Review the existing repository, if applicable.
2. Propose a concise technical architecture.
3. Describe the primary user interface and interaction flow.
4. Explain how the specified resolution-independent frame geometry will be shared between the preview and full-resolution export.
5. Recommend the minimum supported iOS and iPadOS versions.
6. Identify any significant technical decisions that require approval.

Keep the planning process focused. Do not turn it into an extensive requirements-gathering exercise. Make reasonable implementation decisions independently where they do not materially affect the product requirements.

Once the implementation plan is approved, build the application, compile it, run the available tests, and resolve any compilation errors or test failures.

## Definition of Success

The finished application should feel like a premium, purpose-built photography utility rather than a simplified general-purpose photo editor.

Its value should come from doing one thing exceptionally well: allowing users to add a precisely positioned, beautifully rendered inset frame to any photograph with minimal effort.

**Do one thing. Do it exceptionally well. Nothing more.**
