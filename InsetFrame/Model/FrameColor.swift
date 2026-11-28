import CoreGraphics
import SwiftUI

/// An opaque frame color stored as Display P3 components in 0...1.
///
/// Opacity is controlled separately by `FrameSettings.transparencyPercent`.
struct FrameColor: Codable, Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    static var colorSpace: CGColorSpace { CGColorSpace(name: CGColorSpace.displayP3)! }

    init(displayP3Red red: Double, green: Double, blue: Double) {
        self.red = FrameSettings.clamp(red, to: 0...1)
        self.green = FrameSettings.clamp(green, to: 0...1)
        self.blue = FrameSettings.clamp(blue, to: 0...1)
    }

    /// Converts any CGColor (for example, from the system color picker) to Display P3.
    init?(cgColor: CGColor) {
        guard let converted = cgColor.converted(to: Self.colorSpace, intent: .relativeColorimetric, options: nil),
              let components = converted.components,
              components.count >= 3
        else { return nil }
        self.init(
            displayP3Red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2])
        )
    }

    init(sRGBRed red: Double, green: Double, blue: Double) {
        let sRGB = CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        self = FrameColor(cgColor: sRGB) ?? FrameColor(displayP3Red: red, green: green, blue: blue)
    }

    var cgColor: CGColor {
        CGColor(colorSpace: Self.colorSpace, components: [red, green, blue, 1])!
    }

    var color: Color {
        Color(.displayP3, red: red, green: green, blue: blue)
    }

    func isApproximatelyEqual(to other: FrameColor, tolerance: Double = 0.002) -> Bool {
        abs(red - other.red) <= tolerance
            && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
    }

    static let black = FrameColor(displayP3Red: 0, green: 0, blue: 0)
    static let white = FrameColor(displayP3Red: 1, green: 1, blue: 1)
}

struct ColorPreset: Identifiable, Sendable {
    let name: String
    let color: FrameColor
    var id: String { name }
}

extension FrameColor {
    static let presets: [ColorPreset] = [
        ColorPreset(name: String(localized: "Black"), color: .black),
        ColorPreset(name: String(localized: "White"), color: .white),
        ColorPreset(name: String(localized: "Gray"), color: FrameColor(sRGBRed: 0.53, green: 0.53, blue: 0.53)),
        ColorPreset(name: String(localized: "Tan"), color: FrameColor(sRGBRed: 0.82, green: 0.71, blue: 0.56)),
        ColorPreset(name: String(localized: "Brown"), color: FrameColor(sRGBRed: 0.45, green: 0.27, blue: 0.23)),
        ColorPreset(name: String(localized: "Slate"), color: FrameColor(sRGBRed: 0.24, green: 0.30, blue: 0.36)),
    ]

    /// The preset matching this color, if any.
    var preset: ColorPreset? {
        Self.presets.first { $0.color.isApproximatelyEqual(to: self) }
    }
}
