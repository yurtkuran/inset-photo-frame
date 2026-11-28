import Foundation
import Photos

enum PhotoLibrarySaver {
    enum SaveError: Error {
        case notAuthorized
    }

    /// Adds the file to the photo library as a new asset, using add-only access.
    static func save(fileAt url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: url, options: nil)
        }
    }
}
