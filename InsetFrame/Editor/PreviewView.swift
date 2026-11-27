import SwiftUI

/// Draws the photograph and its frame in one coordinate space.
///
/// The frame geometry is computed from the aspect-fit rectangle of the photograph (not the
/// view bounds), using the same `FrameGeometry` as the full-resolution export.
struct PreviewView: View {
    let photo: SourcePhoto
    let settings: FrameSettings

    @GestureState private var isPressing = false
    @State private var accessibilityShowsOriginal = false

    var body: some View {
        let showsOriginal = isPressing || accessibilityShowsOriginal

        Canvas { context, size in
            let imageRect = AspectFit.rect(for: photo.pixelSize, in: CGRect(origin: .zero, size: size))
            context.draw(Image(decorative: photo.previewImage, scale: 1).interpolation(.high), in: imageRect)

            guard !showsOriginal, settings.drawsFrame else { return }
            let geometry = FrameGeometry(imageRect: imageRect, settings: settings)
            guard geometry.isDrawable else { return }
            context.fill(
                Path(geometry.ringPath()),
                with: .color(settings.color.color.opacity(settings.opacity)),
                style: FillStyle(eoFill: true)
            )
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { _, state, _ in state = true }
        )
        .accessibilityElement()
        .accessibilityLabel("Photo preview")
        .accessibilityValue(showsOriginal ? Text("Showing original") : Text("Showing frame"))
        .accessibilityHint("Touch and hold to compare with the original.")
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: accessibilityShowsOriginal ? Text("Show Frame") : Text("Show Original")) {
            accessibilityShowsOriginal.toggle()
        }
    }
}
