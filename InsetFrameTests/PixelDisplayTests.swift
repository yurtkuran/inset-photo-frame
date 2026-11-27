import CoreGraphics
import Testing
@testable import InsetFrame

struct PixelDisplayTests {
    private func displayed(_ settings: FrameSettings, imageSize: CGSize) -> (width: String, offset: String) {
        let geometry = FrameGeometry(imageRect: CGRect(origin: .zero, size: imageSize), settings: settings)
        return (ControlsPanel.pixelText(geometry.frameWidth), ControlsPanel.pixelText(geometry.frameOffset))
    }

    @Test func showsFullResolutionPixelsForDefaults() {
        let values = displayed(.defaults, imageSize: CGSize(width: 3000, height: 4000))
        #expect(values.width == "15 px")
        #expect(values.offset == "150 px")
    }

    @Test func pixelValuesFollowTheShortestSideOfEachPhoto() {
        // Same stored percentages, different photos: same proportions, different pixel counts.
        let large = displayed(.defaults, imageSize: CGSize(width: 8064, height: 6048))
        #expect(large.width == "30 px")    // 6048 * 0.5% = 30.24
        #expect(large.offset == "302 px")  // 6048 * 5% = 302.4
    }

    @Test func roundsToWholePixels() {
        #expect(ControlsPanel.pixelText(0.4) == "0 px")
        #expect(ControlsPanel.pixelText(1.5) == "2 px")
        #expect(ControlsPanel.pixelAccessibilityText(14.6) == "15 pixels")
    }
}
