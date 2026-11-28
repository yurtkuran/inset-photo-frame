import Foundation
import Testing
@testable import InsetFrame

@MainActor
struct EditorModelTests {
    @Test func remembersSettingsAcrossLaunchesAndResets() throws {
        let suite = "InsetFrameTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = EditorModel(defaults: defaults)
        #expect(first.settings == .defaults)
        first.settings.widthPercent = 2.25
        first.settings.color = .white

        let second = EditorModel(defaults: defaults)
        #expect(second.settings.widthPercent == 2.25)
        #expect(second.settings.color == .white)

        second.resetSettings()
        #expect(second.settings == .defaults)
        #expect(EditorModel(defaults: defaults).settings == .defaults)
    }

    @Test func exportActionsDoNothingWithoutAPhoto() async throws {
        let suite = "InsetFrameTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let model = EditorModel(defaults: defaults)
        await model.share()
        await model.saveToPhotos()
        #expect(model.shareItem == nil)
        #expect(model.alertMessage == nil)
        #expect(!model.isExporting)
    }
}
