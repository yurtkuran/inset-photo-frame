import Foundation

/// Maps the frame width slider position (0...1) to a width percentage.
///
/// The mapping is quadratic so that thin widths, where small differences are most
/// visible, get most of the slider's travel. Percentages are rounded to two decimal
/// places so the displayed value is exactly the value used for rendering.
enum WidthSliderMapping {
    static var maximum: Double { FrameSettings.widthRange.upperBound }

    static func percent(forPosition position: Double) -> Double {
        let t = FrameSettings.clamp(position, to: 0...1)
        return (maximum * t * t * 100).rounded() / 100
    }

    static func position(forPercent percent: Double) -> Double {
        (FrameSettings.clamp(percent, to: FrameSettings.widthRange) / maximum).squareRoot()
    }
}
