import CoreData
import SwiftUI

struct MyPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var summary = GlobalPlaySummary(
        totalDeaths: 0,
        totalDamageEvents: 0,
        supportedGamesPlayed: 0,
        heroSummaryText: "",
        activeRuns: [],
        hardestGames: [],
        supportedGameCards: [],
        updatedAt: Date()
    )
    @State private var entriesByGameId: [String: ROMLibraryEntry] = [:]
    @State private var detailEntry: ROMLibraryEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if summary.supportedGamesPlayed == 0 {
                            InsightsEmptyStateView(
                                title: screenString("playinsights.my_play.title", "My Play"),
                                bodyText: screenString(
                                    "playinsights.my_play.empty.body",
                                    "Play supported games to unlock tracked deaths, damage, and game-aware progress summaries."
                                )
                            )
                        } else {
                            heroCard
                            totalsSection
                            activeRunsSection
                            hardestGamesSection
                            supportedGamesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    reload()
                }
            }
            .navigationTitle(screenString("playinsights.my_play.title", "My Play"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                #else
                ToolbarItem {
                    Button(screenString("library.detail.close", "Close")) { dismiss() }
                }
                #endif
            }
            .sheet(item: $detailEntry) { entry in
                NavigationStack {
                    RomDetailView(rom: entry) {
                        detailEntry = nil
                    }
                }
            }
            .onAppear(perform: reload)
            .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
                reload()
            }
            .onChange(of: languageManager.refreshID) {
                reload()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(screenString("playinsights.my_play.title", "My Play"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(summary.heroSummaryText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: 10) {
                heroMetric(label: screenString("playinsights.my_play.metric.tracked_deaths", "Tracked Deaths"), value: "\(summary.totalDeaths)")
                heroMetric(label: screenString("playinsights.my_play.metric.damage_events", "Damage Events"), value: "\(summary.totalDamageEvents)")
                heroMetric(label: screenString("playinsights.my_play.metric.supported_games", "Supported Games"), value: "\(summary.supportedGamesPlayed)")
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surface, AppColors.surfaceLight.opacity(0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func heroMetric(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private var totalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            InsightsSectionHeaderView(title: screenString("playinsights.my_play.performance_totals", "Performance Totals"))
            HStack(spacing: 12) {
                SummaryStatCardView(title: screenString("playinsights.my_play.total_deaths", "Total Deaths"), value: "\(summary.totalDeaths)", icon: "xmark.circle.fill")
                SummaryStatCardView(title: screenString("playinsights.my_play.total_damage", "Total Damage"), value: "\(summary.totalDamageEvents)", icon: "shield.slash.fill")
                SummaryStatCardView(title: screenString("playinsights.my_play.games_tracked", "Games Tracked"), value: "\(summary.supportedGamesPlayed)", icon: "gamecontroller.fill")
            }
        }
    }

    private var activeRunsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            InsightsSectionHeaderView(title: screenString("playinsights.my_play.active_runs", "Active Runs"))
            ForEach(summary.activeRuns) { item in
                if let entry = entriesByGameId[item.gameId] {
                    Button {
                        detailEntry = entry
                    } label: {
                        ActiveRunRowView(entry: entry, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hardestGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            InsightsSectionHeaderView(title: screenString("playinsights.my_play.hardest_games", "Hardest Games"))
            ForEach(summary.hardestGames) { item in
                if let entry = entriesByGameId[item.gameId] {
                    Button {
                        detailEntry = entry
                    } label: {
                        HardestGameRowView(entry: entry, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var supportedGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            InsightsSectionHeaderView(title: screenString("playinsights.my_play.supported_games", "Supported Games"))
            ForEach(summary.supportedGameCards) { item in
                if let entry = entriesByGameId[item.gameId] {
                    Button {
                        detailEntry = entry
                    } label: {
                        SupportedGameInsightCardView(entry: entry, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func reload() {
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false),
            NSSortDescriptor(keyPath: \ROMLibraryEntry.dateAdded, ascending: false)
        ]
        let entries = (try? viewContext.fetch(request)) ?? []
        entriesByGameId = Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            guard let checksum = entry.checksum else { return nil }
            return (checksum, entry)
        })
        summary = PlayInsightsStore.shared.globalSummary(for: entries)
    }

    private func screenString(_ key: String, _ fallback: String) -> String {
        L10n.string(key, table: "Screens", fallback: fallback, languageManager: languageManager)
    }
}
