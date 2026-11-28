import CoreGraphics

/// Resolution-independent frame geometry shared by the preview and the export.
///
/// `imageRect` is the rectangle occupied by the orientation-corrected photograph: the
/// aspect-fit display rectangle in the preview, or `(0, 0, W, H)` at full resolution.
/// All values keep fractional precision; nothing is rounded before rasterization.
struct FrameGeometry: Equatable, Sendable {
    let imageRect: CGRect
    /// `S = min(W, H)`.
    let shortestSide: CGFloat
    /// `S * widthPercent / 100`.
    let frameWidth: CGFloat
    /// `S * offsetPercent / 100`, measured from the image edge to the frame's outer edge.
    let frameOffset: CGFloat

    init(imageRect: CGRect, widthPercent: Double, offsetPercent: Double) {
        let rect = imageRect.standardized
        let shortest = max(0, min(rect.width, rect.height))
        self.imageRect = rect
        self.shortestSide = shortest
        self.frameWidth = shortest * CGFloat(max(0, widthPercent)) / 100
        self.frameOffset = shortest * CGFloat(max(0, offsetPercent)) / 100
    }

    init(imageRect: CGRect, settings: FrameSettings) {
        self.init(imageRect: imageRect, widthPercent: settings.widthPercent, offsetPercent: settings.offsetPercent)
    }

    /// Outer edge of the frame.
    var outerRect: CGRect { imageRect.insetBy(dx: frameOffset, dy: frameOffset) }

    /// Inner edge of the frame.
    var innerRect: CGRect {
        imageRect.insetBy(dx: frameOffset + frameWidth, dy: frameOffset + frameWidth)
    }

    /// Centerline of the frame, equivalent to a centered stroke of `frameWidth`.
    var strokeCenterRect: CGRect {
        imageRect.insetBy(dx: frameOffset + frameWidth / 2, dy: frameOffset + frameWidth / 2)
    }

    /// Whether the frame has a positive width and leaves a positive interior.
    var isDrawable: Bool {
        frameWidth > 0 && 2 * (frameOffset + frameWidth) < shortestSide
    }

    /// The frame as a ring: outer rectangle minus inner rectangle, to be filled with the even-odd rule.
    func ringPath() -> CGPath {
        let path = CGMutablePath()
        path.addRect(outerRect)
        path.addRect(innerRect)
        return path
    }
}
