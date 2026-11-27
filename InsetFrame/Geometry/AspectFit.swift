import CoreGraphics

enum AspectFit {
    /// The rectangle an image of `size` occupies when scaled to fit, centered, within `bounds`.
    static func rect(for size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }
}
