import Foundation

/// Normalized, resolution-independent frame parameters.
///
/// Width and offset are percentages of the photograph's shortest dimension, so the same
/// settings produce proportionally identical frames at every resolution. Every value is
/// clamped to its valid range on assignment. The ranges are chosen so that every in-range
/// combination satisfies `2 * (offset + width) < 100`.
struct FrameSettings: Equatable, Sendable {
    static let widthRange: ClosedRange<Double> = 0...5
    static let offsetRange: ClosedRange<Double> = 0...20
    static let transparencyRange: ClosedRange<Double> = 0...100

    static let defaults = FrameSettings(
        widthPercent: 0.5,
        offsetPercent: 5,
        transparencyPercent: 0,
        color: .black
    )

    var widthPercent: Double {
        didSet { widthPercent = Self.clamp(widthPercent, to: Self.widthRange) }
    }

    var offsetPercent: Double {
        didSet { offsetPercent = Self.clamp(offsetPercent, to: Self.offsetRange) }
    }

    var transparencyPercent: Double {
        didSet { transparencyPercent = Self.clamp(transparencyPercent, to: Self.transparencyRange) }
    }

    var color: FrameColor

    init(widthPercent: Double, offsetPercent: Double, transparencyPercent: Double, color: FrameColor) {
        self.widthPercent = Self.clamp(widthPercent, to: Self.widthRange)
        self.offsetPercent = Self.clamp(offsetPercent, to: Self.offsetRange)
        self.transparencyPercent = Self.clamp(transparencyPercent, to: Self.transparencyRange)
        self.color = color
    }

    /// Fill opacity derived from transparency: 0% transparency is fully opaque.
    var opacity: Double { 1 - transparencyPercent / 100 }

    /// Whether the settings describe a geometrically valid frame with a positive interior.
    var isValid: Bool {
        widthPercent >= 0
            && offsetPercent >= 0
            && Self.transparencyRange.contains(transparencyPercent)
            && 2 * (offsetPercent + widthPercent) < 100
    }

    /// Whether rendering would produce any visible change.
    var drawsFrame: Bool { widthPercent > 0 && opacity > 0 }

    static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        guard !value.isNaN else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Persistence

extension FrameSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case widthPercent, offsetPercent, transparencyPercent, color
    }

    /// Decodes through the clamping initializer so stored out-of-range values are corrected.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            widthPercent: try container.decode(Double.self, forKey: .widthPercent),
            offsetPercent: try container.decode(Double.self, forKey: .offsetPercent),
            transparencyPercent: try container.decode(Double.self, forKey: .transparencyPercent),
            color: try container.decode(FrameColor.self, forKey: .color)
        )
    }
}

extension FrameSettings {
    static let storageKey = "frameSettings.v1"

    /// Returns the stored settings, or the defaults if none are stored or they cannot be read.
    static func load(from defaults: UserDefaults) -> FrameSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(FrameSettings.self, from: data)
        else { return .defaults }
        return settings
    }

    func save(to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
