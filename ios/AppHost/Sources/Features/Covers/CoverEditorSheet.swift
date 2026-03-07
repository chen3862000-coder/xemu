#if os(iOS)
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct CoverEditorSheet: View {
    let entry: ROMLibraryEntry
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isFileImporterPresented = false
    @State private var candidateData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?
    private let previewCornerRadius: CGFloat = 18

    private var canReset: Bool {
        !((entry.customCoverURL ?? "").isEmpty) || CoverArtService.shared.customCoverExists(for: entry.id)
    }

    private var previewSide: CGFloat {
        let horizontalPadding: CGFloat = 32
        return min(UIScreen.main.bounds.width - horizontalPadding, 520)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                previewCard

                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Photos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Files", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if candidateData != nil {
                    Text("Square preview (2:2). Saved output is JPEG (600x600).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Edit Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveCandidate()
                    }
                    .disabled(candidateData == nil || isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        resetCover()
                    } label: {
                        Label("Reset Cover", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!canReset || isSaving)
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadDataFromFile(url: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadDataFromPhoto(item: newValue)
            }
        }
        .alert("Cover Update Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var previewCard: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: previewCornerRadius)
                .fill(Color.secondary.opacity(0.12))

            if let candidateData,
               let image = UIImage(data: candidateData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let resolved = CoverArtService.shared.resolve(for: entry),
                      let image = UIImage(data: resolved.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text((entry.system ?? "UNK").uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary.opacity(0.92))
                .clipShape(Capsule())
                .padding(10)

            RoundedRectangle(cornerRadius: previewCornerRadius)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        }
        .frame(width: previewSide, height: previewSide)
        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity)
    }

    private func loadDataFromFile(url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            candidateData = try Data(contentsOf: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDataFromPhoto(item: PhotosPickerItem) async {
        do {
            candidateData = try await item.loadTransferable(type: Data.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveCandidate() {
        guard let candidateData else { return }
        isSaving = true

        do {
            let url = try CoverArtService.shared.saveCustomCoverData(candidateData, for: entry.id)
            entry.customCoverURL = url.path
            try viewContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func resetCover() {
        isSaving = true
        CoverArtService.shared.removeCustomCover(for: entry.id)
        entry.customCoverURL = nil
        CoverArtService.shared.assignDeterministicPlaceholderIfNeeded(to: entry)

        do {
            try viewContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
#endif
