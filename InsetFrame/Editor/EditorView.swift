import PhotosUI
import SwiftUI

struct EditorView: View {
    @State private var model = EditorModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var controlsHeight: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let sidePanelWidth: CGFloat = 340

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Inset Frame")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        #if DEBUG
        .task { model.loadDebugPhotoIfRequested() }
        #endif
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task { await model.loadPhoto(from: item) }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .sheet(item: $model.shareItem) { item in
            ActivityView(items: [item.url]) { model.shareItem = nil }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let photo = model.photo {
            GeometryReader { geometry in
                if horizontalSizeClass == .regular || geometry.size.width > geometry.size.height {
                    sideBySideLayout(photo: photo)
                } else {
                    stackedLayout(photo: photo, availableHeight: geometry.size.height)
                }
            }
        } else {
            EmptyStateView(pickerItem: $pickerItem, isLoading: model.isLoadingPhoto)
        }
    }

    /// iPhone portrait and narrow iPad windows: preview above the controls.
    private func stackedLayout(photo: SourcePhoto, availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            preview(photo: photo)
                .padding([.horizontal, .top])
            ScrollView {
                controls(photo: photo)
                    .padding()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(controlsHeight, availableHeight * 0.6))
        }
    }

    /// iPad and landscape iPhone: large preview with the controls panel alongside.
    private func sideBySideLayout(photo: SourcePhoto) -> some View {
        HStack(spacing: 0) {
            preview(photo: photo)
                .padding()
            Divider()
                .ignoresSafeArea(edges: .bottom)
            ScrollView {
                controls(photo: photo).padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: sidePanelWidth)
        }
    }

    private func preview(photo: SourcePhoto) -> some View {
        PreviewView(photo: photo, settings: model.settings)
            .overlay {
                if model.isLoadingPhoto {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .overlay(alignment: .bottom) {
                if let message = model.confirmationMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
    }

    private func controls(photo: SourcePhoto) -> some View {
        ControlsPanel(
            settings: $model.settings,
            imageSize: photo.pixelSize,
            isExporting: model.isExporting,
            onReset: model.resetSettings,
            onSave: { Task { await model.saveToPhotos() } }
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            PhotosPicker(selection: $pickerItem, matching: .images, preferredItemEncoding: .current) {
                Label("Choose Photo", systemImage: "photo.badge.plus")
            }
            .disabled(model.isLoadingPhoto)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await model.share() }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(model.photo == nil || model.isExporting)
        }
    }
}

#Preview {
    EditorView()
}
