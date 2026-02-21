#if canImport(UIKit)
import UIKit
#endif
import Combine
import SwiftUI

@MainActor
struct SaveStatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SaveStatesViewModel
    
    init(rom: ROMLibraryEntry) {
        self._viewModel = StateObject(wrappedValue: SaveStatesViewModel(rom: rom))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.saveStates, id: \.id) { saveState in
                            SaveStateRow(saveState: saveState)
                                .onTapGesture {
                                    viewModel.load(saveState: saveState)
                                }
                                .onLongPressGesture {
                                    viewModel.showDeleteConfirmation(for: saveState)
                                }
                        }
                        
                        if viewModel.saveStates.isEmpty {
                            EmptySaveStateView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                
                SaveStateControlsView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .navigationTitle("Save States")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif
            }
            .alert("Delete Save State", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteSelectedSaveState()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete save state \(viewModel.selectedSaveState?.slotIndex ?? 0)?")
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
}

struct SaveStateRow: View {
    let saveState: SaveState
    
    var body: some View {
        HStack(spacing: 12) {
            #if os(iOS)
            if let thumbnail = saveState.screenshotData, let uiImage = UIImage(data: thumbnail) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 48)
                    .cornerRadius(8)
                    .clipped()
            } else {
                emptyThumbnail
            }
            #elseif os(macOS)
            if let thumbnail = saveState.screenshotData, let nsImage = NSImage(data: thumbnail) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 48)
                    .cornerRadius(8)
                    .clipped()
            } else {
                emptyThumbnail
            }
            #endif
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Slot \(saveState.slotIndex + 1)")
                    .font(.headline)
                
                Text(formattedTimestamp(saveState.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let title = saveState.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var emptyThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 64, height: 48)
            .overlay(
                Image(systemName: "camera.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 16, weight: .bold))
            )
    }
}

struct EmptySaveStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "floppydisk.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.blue.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("No Save States")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Save your game progress to return later.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
}

struct SaveStateControlsView: View {
    @ObservedObject var viewModel: SaveStatesViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.captureSaveState()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Quick Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCapturing)
            
            Button {
                viewModel.loadQuickSave()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Quick Load")
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isCapturing || viewModel.quickSaveSlot == nil)
            
            Spacer()
            
            Button {
                viewModel.showAllSlots = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                    Text("All Slots")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(height: 44)
        .disabled(viewModel.isCapturing)
        .opacity(viewModel.isCapturing ? 0.5 : 1.0)
    }
}

#if DEBUG
struct SaveStatesView_Previews: PreviewProvider {
    static var previews: some View {
        SaveStatesView(rom: ROMLibraryEntry())
    }
}
#endif
