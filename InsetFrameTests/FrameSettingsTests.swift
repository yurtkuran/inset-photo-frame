import CoreGraphics
import Foundation
import Testing
@testable import InsetFrame

struct FrameSettingsTests {
    @Test func defaultsMatchRequirements() {
        let defaults = FrameSettings.defaults
        #expect(defaults.widthPercent == 0.5)
        #expect(defaults.offsetPercent == 5)
        #expect(defaults.transparencyPercent == 0)
        #expect(defaults.color == .black)
        #expect(defaults.opacity == 1)
        #expect(defaults.isValid)
    }

    @Test func clampsOnInitialization() {
        let settings = FrameSettings(widthPercent: -1, offsetPercent: 99, transparencyPercent: 150, color: .white)
        #expect(settings.widthPercent == 0)
        #expect(settings.offsetPercent == 20)
        #expect(settings.transparencyPercent == 100)
    }

    @Test func clampsOnAssignment() {
        var settings = FrameSettings.defaults
        settings.widthPercent = 7
        settings.offsetPercent = -3
        settings.transparencyPercent = .nan
        #expect(settings.widthPercent == 5)
        #expect(settings.offsetPercent == 0)
        #expect(settings.transparencyPercent == 0)
    }

    @Test func everyCombinationWithinRangesIsValid() {
        for width in stride(from: 0.0, through: 5.0, by: 0.25) {
            for offset in stride(from: 0.0, through: 20.0, by: 0.5) {
                for transparency in [0.0, 50.0, 100.0] {
                    let settings = FrameSettings(widthPercent: width, offsetPercent: offset, transparencyPercent: transparency, color: .black)
                    #expect(settings.isValid)
                }
            }
        }
    }

    @Test func transparencyMapsToOpacity() {
        var settings = FrameSettings.defaults
        settings.transparencyPercent = 25
        #expect(settings.opacity == 0.75)
        settings.transparencyPercent = 100
        #expect(settings.opacity == 0)
        #expect(!settings.drawsFrame)
    }

    @Test func zeroWidthDrawsNoFrame() {
        var settings = FrameSettings.defaults
        settings.widthPercent = 0
        #expect(!settings.drawsFrame)
    }

    @Test func roundTripsThroughCodable() throws {
        let settings = FrameSettings(widthPercent: 1.23, offsetPercent: 4.5, transparencyPercent: 30, color: FrameColor(displayP3Red: 0.1, green: 0.2, blue: 0.3))
        let decoded = try JSONDecoder().decode(FrameSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func decodingClampsOutOfRangeValues() throws {
        let json = #"{"widthPercent":12,"offsetPercent":-4,"transparencyPercent":300,"color":{"red":0,"green":0,"blue":0}}"#
        let decoded = try JSONDecoder().decode(FrameSettings.self, from: Data(json.utf8))
        #expect(decoded.widthPercent == 5)
        #expect(decoded.offsetPercent == 0)
        #expect(decoded.transparencyPercent == 100)
    }

    @Test func persistsAndFallsBackToDefaults() throws {
        let suite = "InsetFrameTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(FrameSettings.load(from: defaults) == .defaults)

        let settings = FrameSettings(widthPercent: 2, offsetPercent: 10, transparencyPercent: 40, color: .white)
        settings.save(to: defaults)
        #expect(FrameSettings.load(from: defaults) == settings)

        defaults.set(Data("corrupt".utf8), forKey: FrameSettings.storageKey)
        #expect(FrameSettings.load(from: defaults) == .defaults)
    }
}

struct WidthSliderMappingTests {
    @Test func mapsEndpoints() {
        #expect(WidthSliderMapping.percent(forPosition: 0) == 0)
        #expect(WidthSliderMapping.percent(forPosition: 1) == 5)
        #expect(WidthSliderMapping.position(forPercent: 0) == 0)
        #expect(WidthSliderMapping.position(forPercent: 5) == 1)
    }

    @Test func givesThinWidthsMostOfTheTravel() {
        #expect(WidthSliderMapping.percent(forPosition: 0.5) == 1.25)
    }

    @Test func roundsToTwoDecimals() {
        let percent = WidthSliderMapping.percent(forPosition: 0.123)
        #expect(percent == (percent * 100).rounded() / 100)
    }

    @Test func roundTripsAndIsMonotonic() {
        var previous = -1.0
        for step in 0...1000 {
            let position = Double(step) / 1000
            let percent = WidthSliderMapping.percent(forPosition: position)
            #expect(percent >= previous)
            previous = percent
        }
        for percent in stride(from: 0.0, through: 5.0, by: 0.01) {
            let rounded = (percent * 100).rounded() / 100
            let roundTrip = WidthSliderMapping.percent(forPosition: WidthSliderMapping.position(forPercent: rounded))
            #expect(abs(roundTrip - rounded) < 0.0001)
        }
    }

    @Test func clampsOutOfRangeInput() {
        #expect(WidthSliderMapping.percent(forPosition: 2) == 5)
        #expect(WidthSliderMapping.position(forPercent: -1) == 0)
    }
}

struct FrameColorTests {
    @Test func roundTripsThroughCGColor() throws {
        let color = FrameColor(displayP3Red: 0.2, green: 0.4, blue: 0.6)
        let converted = try #require(FrameColor(cgColor: color.cgColor))
        #expect(converted.isApproximatelyEqual(to: color, tolerance: 1e-6))
    }

    @Test func convertsSRGBToDisplayP3() throws {
        let sRGBRed = try #require(FrameColor(cgColor: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)))
        // sRGB red lies inside the P3 gamut, so its P3 red component is below 1.
        #expect(sRGBRed.red < 1)
        #expect(sRGBRed.green > 0)
    }

    @Test func presetsIncludeBlackAndWhiteFirst() {
        #expect(FrameColor.presets.count == 6)
        #expect(FrameColor.presets[0].color == .black)
        #expect(FrameColor.presets[1].color == .white)
        #expect(Set(FrameColor.presets.map(\.id)).count == 6)
    }

    @Test func identifiesPresetsAndCustomColors() {
        #expect(FrameColor.black.preset?.color == .black)
        #expect(FrameColor(displayP3Red: 0.9, green: 0.1, blue: 0.5).preset == nil)
    }
}
