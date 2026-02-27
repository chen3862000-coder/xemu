import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct RecentlyPlayedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var games: [ROMLibraryEntry] = []
    @State private var searchText = ""
    @State private var selectedGame: Game?
    @State private var activeAlert: RecentAlertState?

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: 14) {
                        if filteredGames.isEmpty {
                            emptyState
                        } else {
                            gamesGrid
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedGame) { game in
            GamePlayView(game: game, onExit: {
                selectedGame = nil
            })
        }
        #endif
        .alert(item: $activeAlert) { state in
            switch state {
            case .launchError(let message):
                return Alert(
                    title: Text("Unable to Open Game"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            case .confirmDelete(let candidate):
                return Alert(
                    title: Text(candidate.mode.displayName),
                    message: Text(candidate.mode.firstConfirmation),
                    primaryButton: .default(Text("Continue")) {
                        activeAlert = .confirmFinalDelete(candidate)
                    },
                    secondaryButton: .cancel()
                )
            case .confirmFinalDelete(let candidate):
                return Alert(
                    title: Text("Final Confirmation"),
                    message: Text(candidate.mode.secondConfirmation),
                    primaryButton: .destructive(Text("Delete")) {
                        performDeletion(candidate)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear(perform: loadGames)
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            loadGames()
        }
    }

    private var filteredGames: [ROMLibraryEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return games
        }
        return games.filter { entry in
            (entry.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (entry.system ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.16), AppColors.accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 150, y: -230)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.10), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 430, height: 430)
                .offset(x: -190, y: 320)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.surfaceLight.opacity(0.5))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Recently Played")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(games.count) games")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }

                Spacer()

                Menu {
                    Button("Recent") {}
                    Button("A–Z") {}
                    Button("Most Played") {}
                } label: {
                    HStack(spacing: 6) {
                        Text("Recent")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(AppColors.surfaceLight.opacity(0.45))
                    .overlay(
                        Capsule().stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)

                TextField("Search recently played...", text: $searchText)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 12)
                .frame(height: 36)
            .background(AppColors.surfaceLight.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 19)
                    .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 19))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.background.opacity(0.85))
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceLight.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var gamesGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(filteredGames) { entry in
                RecentlyPlayedCard(entry: entry) {
                    launchGame(entry)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        activeAlert = .confirmDelete(RecentDeleteCandidate(entry: entry, mode: .removeROMOnly))
                    } label: {
                        Label("Remove ROM Only", systemImage: "eject")
                    }
                    Button(role: .destructive) {
                        activeAlert = .confirmDelete(RecentDeleteCandidate(entry: entry, mode: .removeAll))
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppColors.textMuted)

            Text(searchText.isEmpty ? "No Recently Played Games" : "No Matching Games")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(searchText.isEmpty ? "Start playing games to see them here." : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadGames() {
        let request = NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "lastPlayedAt", ascending: false)]
        request.predicate = NSPredicate(format: "lastPlayedAt != nil")

        do {
            games = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch recent games: \(error)")
            games = []
        }
    }

    private func launchGame(_ entry: ROMLibraryEntry) {
        let compatibility = ROMCompatibilityService.shared.compatibility(for: entry)
        if let issue = compatibility.issue {
            activeAlert = .launchError(issue.message)
            return
        }
        guard let game = entry.toGame() else { return }
        selectedGame = game
    }

    private func performDeletion(_ candidate: RecentDeleteCandidate) {
        do {
            try GameDeletionService.shared.delete(entry: candidate.entry, mode: candidate.mode, in: viewContext)
            loadGames()
        } catch {
            activeAlert = .launchError("Could not delete game: \(error.localizedDescription)")
        }
    }
}

struct RecentlyPlayedCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    coverArt
                        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132)

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text((entry.system ?? "UNK").uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.84))
                        .clipShape(Capsule())
                        .padding(8)

                    if let issue = ROMCompatibilityService.shared.compatibility(for: entry).issue {
                        VStack {
                            HStack {
                                Image(systemName: issue.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(6)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(Circle())
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title ?? "Unknown Game")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    if ROMCompatibilityService.shared.compatibility(for: entry).issue != nil {
                        Label("Unsupported Mapper", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(playedDateLabel)
                            .font(.system(size: 12, weight: .semibold))
                        if Int(entry.playtimeTotal) > 0 {
                            Text("•")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.55)
                            Text(totalHoursLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.08), radius: 10, x: 0, y: 5)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var coverArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
#if os(iOS)
            if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
               let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let imageData = entry.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.textMuted)
            }
#else
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textMuted)
#endif
        }
        .frame(maxWidth: .infinity, minHeight: 132, maxHeight: 132)
        .overlay(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var playedDateLabel: String {
        guard let date = entry.lastPlayedAt else { return "Never" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var totalHoursLabel: String {
        let hours = max(0, Int(entry.playtimeTotal) / 3600)
        return "\(hours)h"
    }
}

private struct RecentDeleteCandidate: Identifiable {
    let id = UUID()
    let entry: ROMLibraryEntry
    let mode: GameDeletionMode
}

private enum RecentAlertState: Identifiable {
    case launchError(String)
    case confirmDelete(RecentDeleteCandidate)
    case confirmFinalDelete(RecentDeleteCandidate)

    var id: String {
        switch self {
        case .launchError(let message):
            return "error-\(message)"
        case .confirmDelete(let candidate):
            return "confirm-delete-\(candidate.id.uuidString)"
        case .confirmFinalDelete(let candidate):
            return "confirm-final-delete-\(candidate.id.uuidString)"
        }
    }
}

#if DEBUG
struct RecentlyPlayedView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyPlayedView()
    }
}
#endif
