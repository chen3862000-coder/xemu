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

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let previewCornerRadius: CGFloat = 18

    private var canReset: Bool {
        !((entry.customCoverURL ?? "").isEmpty) || CoverArtService.shared.customCoverExists(for: entry.id)
    }

    private var hasTransformation: Bool {
        scale != 1.0 || offset != .zero
    }

    private var previewSide: CGFloat {
        let horizontalPadding: CGFloat = 32
        return min(UIScreen.main.bounds.width - horizontalPadding, 520)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                previewCard

                if candidateData != nil && hasTransformation {
                    HStack {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1.0
                                offset = .zero
                            }
                        } label: {
                            Label("Reset Transform", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("Pinch to resize, drag to move")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

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
                TransformableImage(image: image, scale: $scale, offset: $offset, minScale: minScale, maxScale: maxScale)
            } else if let resolved = CoverArtService.shared.resolve(for: entry),
                      let image = UIImage(data: resolved.data) {
                TransformableImage(image: image, scale: $scale, offset: $offset, minScale: minScale, maxScale: maxScale)
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
            withAnimation(.spring(response: 0.3)) {
                scale = 1.0
                offset = .zero
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDataFromPhoto(item: PhotosPickerItem) async {
        do {
            candidateData = try await item.loadTransferable(type: Data.self)
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    scale = 1.0
                    offset = .zero
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveCandidate() {
        guard let candidateData else { return }
        isSaving = true

        do {
            let transformedData = applyTransformation(to: candidateData)
            let url = try CoverArtService.shared.saveCustomCoverData(transformedData, for: entry.id)
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

    private func applyTransformation(to data: Data) -> Data {
        guard let inputImage = UIImage(data: data),
              let cgImage = inputImage.cgImage else {
            return data
        }

        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        let transformedImage = renderer.image { context in
            context.cgContext.translateBy(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
            context.cgContext.scaleBy(x: scale, y: scale)
            context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)

            if let cropped = cgImage.cropping(to: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)) {
                let aspectRatio = CGFloat(cropped.width) / CGFloat(cropped.height)
                var drawRect: CGRect

                if aspectRatio > 1 {
                    let height = size.width / aspectRatio
                    drawRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
                } else {
                    let width = size.height * aspectRatio
                    drawRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
                }

                context.cgContext.draw(cropped, in: drawRect)
            }
        }

        return transformedImage.jpegData(compressionQuality: 0.9) ?? data
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

struct TransformableImage: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let minScale: CGFloat
    let maxScale: CGFloat

    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, minScale), maxScale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .clipped()
        }
    }
}
#endif
