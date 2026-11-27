import Foundation
import Observation
import PhotosUI
import SwiftUI

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
@Observable
final class EditorModel {
    var settings: FrameSettings {
        didSet {
            if settings != oldValue { settings.save(to: defaults) }
        }
    }

    private(set) var photo: SourcePhoto?
    private(set) var isLoadingPhoto = false
    private(set) var isExporting = false
    private(set) var confirmationMessage: String?
    var alertMessage: String?
    var shareItem: ShareItem?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var confirmationTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = FrameSettings.load(from: defaults)
    }

    // MARK: - Photo selection

    func loadPhoto(from item: PhotosPickerItem) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoadingPhoto = true
        defer {
            if generation == loadGeneration { isLoadingPhoto = false }
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoError.unreadableImage
            }
            let loaded = try await Task.detached(priority: .userInitiated) {
                try PhotoLoader.load(data: data)
            }.value
            guard generation == loadGeneration else { return }
            photo = loaded
        } catch {
            guard generation == loadGeneration else { return }
            alertMessage = String(localized: "This photo couldn’t be opened.")
        }
    }

    #if DEBUG
    /// Debug builds only: loads the image at `INSET_FRAME_DEBUG_PHOTO` so layouts can be checked in the simulator.
    func loadDebugPhotoIfRequested() {
        guard photo == nil,
              let path = ProcessInfo.processInfo.environment["INSET_FRAME_DEBUG_PHOTO"],
              let data = FileManager.default.contents(atPath: path)
        else { return }
        photo = try? PhotoLoader.load(data: data)
    }
    #endif

    // MARK: - Settings

    func resetSettings() {
        settings = .defaults
    }

    // MARK: - Export

    func saveToPhotos() async {
        guard let photo, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let exported = try await export(photo)
            try await PhotoLibrarySaver.save(fileAt: exported.url)
            showConfirmation(String(localized: "Saved to Photos"))
        } catch PhotoLibrarySaver.SaveError.notAuthorized {
            alertMessage = String(localized: "Inset Frame doesn’t have permission to add photos. You can allow access in Settings.")
        } catch {
            alertMessage = String(localized: "The photo couldn’t be saved.")
        }
    }

    func share() async {
        guard let photo, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            shareItem = ShareItem(url: try await export(photo).url)
        } catch {
            alertMessage = String(localized: "The photo couldn’t be prepared for sharing.")
        }
    }

    private func export(_ photo: SourcePhoto) async throws -> ExportedPhoto {
        let data = photo.data
        let settings = settings
        return try await Task.detached(priority: .userInitiated) {
            try PhotoExporter.export(data: data, settings: settings)
        }.value
    }

    private func showConfirmation(_ message: String) {
        confirmationTask?.cancel()
        confirmationMessage = message
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.confirmationMessage = nil
        }
    }
}
