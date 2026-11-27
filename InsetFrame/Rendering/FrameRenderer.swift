import CoreGraphics

enum FrameRenderer {
    /// Fills the frame ring for `settings` over a photograph occupying `imageRect` in `context`.
    static func draw(_ settings: FrameSettings, in context: CGContext, imageRect: CGRect) {
        guard settings.drawsFrame else { return }
        let geometry = FrameGeometry(imageRect: imageRect, settings: settings)
        guard geometry.isDrawable,
              let color = settings.color.cgColor.copy(alpha: settings.opacity)
        else { return }

        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(color)
        context.addPath(geometry.ringPath())
        context.fillPath(using: .evenOdd)
    }
}
