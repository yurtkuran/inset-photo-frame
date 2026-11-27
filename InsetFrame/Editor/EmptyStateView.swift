import PhotosUI
import SwiftUI

struct EmptyStateView: View {
    @Binding var pickerItem: PhotosPickerItem?
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ProgressView()
                .controlSize(.large)
        } else {
            ContentUnavailableView {
                Label("No Photo", systemImage: "photo")
            } description: {
                Text("Choose a photo to add an inset frame.")
            } actions: {
                PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                    Text("Choose Photo")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
