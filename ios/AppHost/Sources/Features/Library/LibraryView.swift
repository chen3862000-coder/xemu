import SwiftUI
import CoreData

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedFilter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var selectedRom: ROMLibraryEntry?

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading library...")
            } else {
                mainContent
            }
        }
        .searchable(text: $searchText, prompt: "Search ROMs...")
        .onAppear {
            viewModel.loadEntries(in: viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .coverArtDidChange)) { _ in
            viewModel.loadEntries(in: viewContext)
        }
        .sheet(item: $selectedRom) { rom in
            RomDetailView(rom: rom) {
                viewModel.loadEntries(in: viewContext)
            }
        }
    }

    private var mainContent: some View {
        VStack {
            filterSection
            romGrid
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        viewModel.applyFilter(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var romGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredRomEntries) { entry in
                    RomCard(entry: entry) {
                        selectedRom = entry
                    }
                }
            }
            .padding()
        }
    }

    private var filteredRomEntries: [ROMLibraryEntry] {
        var entries = viewModel.filteredEntries

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                (entry.title ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct RomCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let coverData = CoverArtService.shared.resolve(for: entry)?.data,
                   let coverImage = Image(data: coverData) {
                    coverImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    PlatformPlaceholder(platform: entry.system)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(GameCardTitleFormatter.format(entry.title, maxWords: 7))
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(height: 44, alignment: .topLeading)

                if ROMCompatibilityService.shared.compatibility(for: entry).issue != nil {
                    Label("Unsupported Mapper", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.orange)
                }

                HStack {
                    Text(entry.consoleIdentity?.systemCode ?? entry.system ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(entry.consoleIdentity?.accentColor ?? .secondary)

                    Spacer()

                    if let lastPlayed = entry.lastPlayedAt {
                        Text(lastPlayed, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Spacer()

                    if entry.playtimeTotal > 0 {
                        Text("\(formatPlaytime(entry.playtimeTotal))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }

    private func formatPlaytime(_ seconds: Int64) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }
}

struct PlatformPlaceholder: View {
    let platform: String?

    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            if let assetName = platformIconAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .opacity(0.65)
            } else {
                Text(platformIcon)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var platformIconAssetName: String? {
        ConsoleIdentity.resolve(systemRaw: platform)?.assetName
    }

    private var platformIcon: String {
        switch platform?.lowercased() {
        case "nes": return "🕹️"
        case "gba": return "🎮"
        case "gb": return "📱"
        case "genesis": return "🎯"
        case "nds": return "📊"
        case "ps1": return "📀"
        case "ps2": return "💿"
        case "3ds": return "🪧"
        default: return "🎲"
        }
    }
}

private enum RomDetailLayout {
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 22
    static let cardSpacing: CGFloat = 18
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 20
    static let heroCornerRadius: CGFloat = 32
    static let actionCornerRadius: CGFloat = 18
    static let actionHeight: CGFloat = 50
    static let heroTopInset: CGFloat = 60
    static let heroBottomInset: CGFloat = 28
    static let heroCoverSize = CGSize(width: 168, height: 210)
    static let heroMinHeight: CGFloat = 500
    static let titleToBadgesSpacing: CGFloat = 8
    static let closeTopPadding: CGFloat = 10
    static let detailLabelWidth: CGFloat = 120
    static let rowVerticalPadding: CGFloat = 6
}

struct RomDetailView: View {
    let rom: ROMLibraryEntry
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var isLaunching = false
    @State private var adShouldShow = false
    @State private var launchErrorMessage: String?
    @State private var heroCoverSettled = false
    @State private var isShowingSaveStates = false
    @State private var playInsightsSummary: GamePlayInsightsSummary?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: RomDetailLayout.sectionSpacing) {
                heroSection
                statsSection
                if let playInsightsSummary {
                    VStack(alignment: .leading, spacing: 28) {
                        playInsightsSection(summary: playInsightsSummary)
                        currentRunSection(summary: playInsightsSummary)
                    }
                }
                collectorDataSection
                fileDetailsSection
            }
            .padding(.horizontal, RomDetailLayout.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(backgroundLayer.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
                onDismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text(screenString("library.detail.close", "Close"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(.ultraThinMaterial.opacity(0.88))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .padding(.leading, RomDetailLayout.pagePadding)
            .padding(.top, RomDetailLayout.closeTopPadding)
        }
        .sheet(isPresented: $isLaunching) {
            Group {
                if let game = rom.toGame() {
                    GamePlayView(game: game) {
                        isLaunching = false
                    }
                } else {
                    VStack {
                        Text(screenString("library.detail.failed_to_load", "Failed to load game"))
                        Text(screenString("library.detail.verify_metadata", "Please verify ROM import metadata"))
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLaunching = false
                        }
                    }
                }
            }
        }
        .alert(isPresented: $adShouldShow) {
            Alert(
                title: Text(screenString("library.detail.sponsor_title", "Sponsor Message")),
                message: Text(screenString("library.detail.sponsor_message", "Watch this ad to continue playing")),
                dismissButton: .default(Text(screenString("library.detail.ok", "OK")))
            )
        }
        .alert(screenString("library.detail.unable_to_open", "Unable to Open Game"), isPresented: Binding(
            get: { launchErrorMessage != nil },
            set: { if !$0 { launchErrorMessage = nil } }
        )) {
            Button(screenString("library.detail.ok", "OK"), role: .cancel) { launchErrorMessage = nil }
        } message: {
            Text(launchErrorMessage ?? screenString("library.detail.launch_fallback", "This game cannot be launched right now."))
        }
        .sheet(isPresented: $isShowingSaveStates) {
            SaveStatesView(rom: rom)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                heroCoverSettled = true
            }
            reloadPlayInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            reloadPlayInsights()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColors.background

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.22), AppColors.accent.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 80)
                .offset(x: 120, y: -180)

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.14), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 90)
                .offset(x: -140, y: 260)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: RomDetailLayout.heroCornerRadius, style: .continuous)
                .fill(AppColors.surface)
                .overlay(heroBackground)
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: RomDetailLayout.heroCornerRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RomDetailLayout.heroCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: accentColor.opacity(0.16), radius: 24, x: 0, y: 14)

            VStack(alignment: .leading, spacing: 14) {
                heroCover
                    .frame(
                        width: RomDetailLayout.heroCoverSize.width,
                        height: RomDetailLayout.heroCoverSize.height
                    )
                    .scaleEffect(heroCoverSettled ? 1.0 : 0.92)
                    .rotation3DEffect(.degrees(heroCoverSettled ? 0 : -8), axis: (x: 1, y: 0, z: 0))
                    .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 12)
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: RomDetailLayout.titleToBadgesSpacing) {
                    Text(rom.title ?? screenString("library.detail.unknown_title", "Unknown Title"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .tracking(0.3)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 10) {
                        Text(systemBadgeText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(accentColor.opacity(0.20))
                            .clipShape(Capsule())

                        Text(regionBadgeText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    Button(action: launchGame) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(isLaunching ? screenString("library.detail.launching", "Launching…") : screenString("library.detail.play_game", "Play Game"))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Spacer()
                            Text(systemBadgeText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .frame(height: 26)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: RomDetailLayout.actionHeight)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RomDetailLayout.actionCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RomDetailLayout.actionCornerRadius, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.28), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLaunching)

                    deluxeActionRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, RomDetailLayout.heroTopInset)
            .padding(.horizontal, RomDetailLayout.pagePadding)
            .padding(.bottom, RomDetailLayout.heroBottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: RomDetailLayout.heroMinHeight)
    }

    private var heroBackground: some View {
        ZStack {
            if let coverData = CoverArtService.shared.resolve(for: rom)?.data,
               let coverImage = Image(data: coverData) {
                coverImage
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 50)
                    .opacity(0.35)
                    .overlay(accentColor.opacity(0.20))
            } else {
                LinearGradient(
                    colors: [accentColor.opacity(0.9), AppColors.accent.opacity(0.65), AppColors.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    PlatformPlaceholder(platform: rom.system)
                        .opacity(0.18)
                        .padding(28)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: RomDetailLayout.heroCornerRadius, style: .continuous))
    }

    private var heroCover: some View {
        Group {
            if let coverData = CoverArtService.shared.resolve(for: rom)?.data,
               let coverImage = Image(data: coverData) {
                coverImage
                    .resizable()
                    .scaledToFill()
            } else {
                PlatformPlaceholder(platform: rom.system)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var statsSection: some View {
        CollectorInfoCard(title: screenString("library.detail.statistics", "Statistics"), icon: "chart.bar.xaxis") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(screenString("library.detail.play_time", "Play Time"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Text(formatPlaytime(rom.playtimeTotal))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.surfaceLight.opacity(0.85))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * animatedPlaytimeProgress, 18))
                            .animation(.easeInOut(duration: 0.7), value: animatedPlaytimeProgress)
                    }
                }
                .frame(height: 10)

                HStack(spacing: 12) {
                    deluxeStatPill(title: screenString("library.detail.sessions", "Sessions"), value: sessionCountText)
                    deluxeStatPill(title: screenString("library.detail.status", "Status"), value: rom.lastPlayedAt == nil ? screenString("library.detail.fresh_import", "Fresh import") : screenString("library.detail.played", "Played"))
                }

                if let lastPlayedText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(screenString("library.detail.last_session", "Last Session"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        Text(lastPlayedText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
    }

    private var collectorDataSection: some View {
        CollectorInfoCard(title: screenString("library.detail.collector_data", "Collector Data"), icon: "shippingbox.fill") {
            DetailRow(label: screenString("library.detail.region", "Region"), value: regionDetailText)
            DetailRow(label: screenString("library.detail.rom_size", "ROM Size"), value: formatFileSize(rom.fileSize))
            DetailRow(label: screenString("library.detail.save_type", "Save Type"), value: inferredSaveType)
            DetailRow(label: screenString("library.detail.media", "Media"), value: mediaFormat)
            DetailRow(label: screenString("library.detail.catalog_id", "Catalog ID"), value: catalogReferenceText)
        }
    }

    @ViewBuilder
    private func playInsightsSection(summary: GamePlayInsightsSummary) -> some View {
        if summary.playInsightsEnabled {
            VStack(alignment: .leading, spacing: 16) {
                InsightsSectionHeaderView(title: screenString("playinsights.section.title", "Play Insights"))

                HStack(alignment: .top, spacing: 16) {
                    if let value = summary.deathsPrimaryValue {
                        InsightsMetricCardView(
                            icon: "xmark.circle.fill",
                            title: screenString("playinsights.card.deaths", "Deaths"),
                            primaryValue: value,
                            secondaryLine1: summary.deathsSecondaryLine1,
                            secondaryLine2: summary.deathsSecondaryLine2
                        )
                    }

                    if let value = summary.damagePrimaryValue {
                        InsightsMetricCardView(
                            icon: "shield.slash.fill",
                            title: screenString("playinsights.card.damage_taken", "Damage Taken"),
                            primaryValue: value,
                            secondaryLine1: summary.damageSecondaryLine1,
                            secondaryLine2: summary.damageSecondaryLine2
                        )
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    if let progressPrimary = summary.progressPrimaryValue,
                       let progressSecondary = summary.progressSecondaryValue {
                        InsightsNarrativeCardView(
                            title: screenString("playinsights.card.progress", "Progress"),
                            bodyText: "\(progressPrimary)\n\(progressSecondary)",
                            icon: "location.circle.fill",
                            tinted: true
                        )
                    }

                    if let text = summary.performanceInsightText {
                        InsightsNarrativeCardView(
                            title: screenString("playinsights.card.performance_insight", "Performance Insight"),
                            bodyText: text,
                            icon: "sparkles",
                            emphasized: true
                        )
                    }
                }

                if let title = summary.playStyleTitle {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(screenString("playinsights.card.play_style", "Play Style"), systemImage: "figure.run")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        PlayStyleBadgeView(text: title)
                        if let description = summary.playStyleBullet1 {
                            Text(description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .playInsightsCardStyle(padding: 18)
                }
            }
        } else if rom.lastPlayedAt != nil, playInsightsSupported {
            VStack(alignment: .leading, spacing: 16) {
                InsightsSectionHeaderView(title: screenString("playinsights.section.title", "Play Insights"))
                InsightsEmptyStateView(
                    title: screenString("playinsights.section.title", "Play Insights"),
                    bodyText: screenString(
                        "playinsights.empty.body",
                        "Start playing to unlock performance and progress insights for this game."
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func currentRunSection(summary: GamePlayInsightsSummary) -> some View {
        if summary.currentRunEnabled,
           let primary = summary.currentRunPrimary,
           let secondary = summary.currentRunSecondary {
            VStack(alignment: .leading, spacing: 16) {
                InsightsSectionHeaderView(title: screenString("playinsights.current_run.section_title", "Current Run"))
                CurrentRunCardView(primary: primary, secondary: secondary)
            }
            .padding(.top, 8)
        }
    }

    private var fileDetailsSection: some View {
        CollectorInfoCard(title: screenString("library.detail.file_details", "File Details"), icon: "doc.text.magnifyingglass") {
            DetailRow(label: "SHA-1", value: shortSHA1)
            DetailRow(label: screenString("library.detail.checksum", "Checksum"), value: shortChecksum)
            DetailRow(label: screenString("library.detail.added", "Added"), value: addedDateText)
            DetailRow(label: screenString("library.detail.file", "File"), value: rom.fileName ?? screenString("library.detail.unknown", "Unknown"))
            DetailRow(label: screenString("library.detail.path", "Path"), value: rom.romPath ?? screenString("library.detail.unavailable", "Unavailable"))
        }
    }

    private var accentColor: Color {
        SubpageUI.CollectorIdentity.accent(forSystem: rom.system)
    }

    private var systemBadgeText: String {
        (rom.system ?? screenString("library.detail.unknown", "Unknown")).uppercased()
    }

    private var lastPlayedText: String? {
        rom.lastPlayedAt?.formatted(date: .abbreviated, time: .omitted)
    }

    private var addedDateText: String {
        rom.dateAdded?.formatted(date: .abbreviated, time: .omitted) ?? screenString("library.detail.unknown", "Unknown")
    }

    private var regionBadgeText: String {
        inferredRegion.shortCode
    }

    private var regionDetailText: String {
        inferredRegion.displayName
    }

    private var shortChecksum: String {
        guard let checksum = rom.checksum, !checksum.isEmpty else { return screenString("library.detail.unavailable", "Unavailable") }
        return "\(checksum.prefix(8))…\(checksum.suffix(6))"
    }

    private var shortSHA1: String {
        guard let sha1 = rom.romSha1, !sha1.isEmpty else { return screenString("library.detail.unavailable", "Unavailable") }
        return "\(sha1.prefix(8))…\(sha1.suffix(6))"
    }

    private var playtimeProgress: CGFloat {
        let twelveHours: Double = 12 * 60 * 60
        let progress = min(max(Double(rom.playtimeTotal) / twelveHours, 0), 1)
        return CGFloat(progress)
    }

    private var animatedPlaytimeProgress: CGFloat {
        heroCoverSettled ? playtimeProgress : 0.02
    }

    private var inferredRegion: CollectorRegion {
        let haystacks = [rom.title ?? "", rom.fileName ?? "", rom.canonicalTitleID ?? ""]
            .map { $0.lowercased() }
            .joined(separator: " ")

        if haystacks.contains("japan") || haystacks.contains("(jp") || haystacks.contains("(j)") {
            return .japan
        }
        if haystacks.contains("europe") || haystacks.contains("(eu") || haystacks.contains("(e)") {
            return .europe
        }
        if haystacks.contains("usa") || haystacks.contains("us)") || haystacks.contains("(u)") || haystacks.contains("north america") {
            return .usa
        }
        if haystacks.contains("world") || haystacks.contains("intl") || haystacks.contains("international") {
            return .international
        }
        return .unknown
    }

    private var inferredSaveType: String {
        switch SubpageUI.CollectorIdentity.normalizedSystemCode(rom.system) {
        case "gbc":
            return screenString("library.detail.save_type_battery", "Battery-backed")
        case "gba":
            return screenString("library.detail.save_type_sram_flash", "SRAM / Flash")
        case "nds":
            return screenString("library.detail.save_type_eeprom_flash", "EEPROM / Flash")
        default:
            return screenString("library.detail.unknown", "Unknown")
        }
    }

    private var mediaFormat: String {
        let ext = (rom.fileName as NSString?)?.pathExtension.uppercased() ?? ""
        guard !ext.isEmpty else { return screenString("library.detail.rom_image", "ROM image") }
        return L10n.format("library.detail.cartridge_image_format", ext, table: "Screens", fallback: "%@ cartridge image", languageManager: languageManager)
    }

    private var catalogReferenceText: String {
        if let canonicalTitleID = rom.canonicalTitleID, !canonicalTitleID.isEmpty {
            return canonicalTitleID.uppercased()
        }
        return shortChecksum.replacingOccurrences(of: "…", with: "-")
    }

    private var collectorStatusText: String {
        rom.isFavorite ? screenString("library.detail.featured", "Featured") : (rom.lastPlayedAt == nil ? screenString("library.detail.archived", "Archived") : screenString("library.detail.active", "Active"))
    }

    private var sessionCountText: String {
        let minutes = max(Int(rom.playtimeTotal / 60), 0)
        let estimatedSessions = max(rom.lastPlayedAt == nil ? 0 : 1, Int(ceil(Double(minutes) / 35.0)))
        return "\(estimatedSessions)"
    }

    private var playInsightsSupported: Bool {
        guard let game = rom.toGame(),
              let profile = MarioGameProfile.activeProfile(
                  title: game.title ?? "",
                  platform: game.gamePlatform ?? .GBA,
                  romHash: rom.checksum ?? ""
              ) else {
            return false
        }
        return PlayInsightsSupportedGame(profileID: profile.id) != nil
    }

    private func launchGame() {
        let compatibility = ROMCompatibilityService.shared.compatibility(for: rom)
        if let issue = compatibility.issue {
            launchErrorMessage = issue.message
            return
        }
        isLaunching = true
        updateLastPlayed()
    }

    private func updateLastPlayed() {
        rom.lastPlayedAt = Date()

        do {
            try viewContext.save()
        } catch {
            print("Failed to update last played: \(error)")
        }
    }

    private func toggleFavorite() {
        rom.isFavorite.toggle()

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .romLibraryDidChange, object: nil)
        } catch {
            rom.isFavorite.toggle()
            launchErrorMessage = "Could not update favorite status: \(error.localizedDescription)"
        }
    }

    private func formatPlaytime(_ seconds: Int64) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return L10n.format("library.detail.playtime_minutes", minutes, table: "Screens", fallback: "%lld min", languageManager: languageManager)
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return L10n.format("library.detail.playtime_hours", hours, table: "Screens", fallback: "%lld hr", languageManager: languageManager)
        }
        return L10n.format("library.detail.playtime_hours_minutes", hours, remainingMinutes, table: "Screens", fallback: "%1$lld hr %2$lld min", languageManager: languageManager)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    @ViewBuilder
    private var deluxeActionRow: some View {
        HStack(spacing: 10) {
            Button(action: toggleFavorite) {
                deluxeActionButtonLabel(
                    title: rom.isFavorite ? screenString("library.detail.saved", "Saved") : screenString("library.detail.favorite", "Favorite"),
                    subtitle: collectorStatusText,
                    icon: rom.isFavorite ? "heart.fill" : "heart"
                )
            }
            .buttonStyle(.plain)

            Button {
                isShowingSaveStates = true
            } label: {
                deluxeActionButtonLabel(
                    title: screenString("library.detail.save_states", "Save States"),
                    subtitle: screenString("library.detail.quick_save", "Quick save"),
                    icon: "internaldrive.fill"
                )
            }
            .buttonStyle(.plain)

            if let shareURL = rom.romPath.map(URL.init(fileURLWithPath:)) {
                ShareLink(item: shareURL) {
                    deluxeActionButtonLabel(
                        title: screenString("library.detail.share", "Share"),
                        subtitle: screenString("library.detail.rom_file", "ROM file"),
                        icon: "square.and.arrow.up"
                    )
                }
                .buttonStyle(.plain)
            } else {
                deluxeActionButtonLabel(
                    title: screenString("library.detail.share", "Share"),
                    subtitle: screenString("library.detail.unavailable", "Unavailable"),
                    icon: "square.and.arrow.up"
                )
                .opacity(0.55)
            }
        }
    }

    private func screenString(_ key: String, _ fallback: String) -> String {
        L10n.string(key, table: "Screens", fallback: fallback, languageManager: languageManager)
    }

    private func reloadPlayInsights() {
        guard let checksum = rom.checksum else {
            playInsightsSummary = nil
            return
        }
        playInsightsSummary = PlayInsightsStore.shared.summary(for: checksum)
    }

    @ViewBuilder
    private func deluxeActionButtonLabel(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accentColor)

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.82))
        .overlay(
            RoundedRectangle(cornerRadius: RomDetailLayout.actionCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RomDetailLayout.actionCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func deluxeStatPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.surfaceLight.opacity(0.56))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private enum CollectorRegion {
    case usa
    case europe
    case japan
    case international
    case unknown

    var shortCode: String {
        switch self {
        case .usa: return "USA"
        case .europe: return "EUR"
        case .japan: return "JPN"
        case .international: return "INTL"
        case .unknown: return "UNK"
        }
    }

    var displayName: String {
        switch self {
        case .usa: return "USA / North America"
        case .europe: return "Europe"
        case .japan: return "Japan"
        case .international: return "International"
        case .unknown: return "Unknown"
        }
    }
}

private struct CollectorInfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }

            content
        }
        .padding(RomDetailLayout.cardPadding)
        .background(AppColors.surface.opacity(0.92))
        .overlay(.ultraThinMaterial.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: RomDetailLayout.cardCornerRadius, style: .continuous)
                .stroke(AppColors.surfaceLight.opacity(0.78), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RomDetailLayout.cardCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: RomDetailLayout.detailLabelWidth, alignment: .leading)

            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(alignment: .trailing)
        }
        .padding(.vertical, RomDetailLayout.rowVerticalPadding)
    }
}

extension ROMLibraryEntry {
    @MainActor
    var romPath: String? {
        guard let checksum = checksum,
              let fileName = fileName else { return nil }

        let fileExtension = (fileName as NSString).pathExtension
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to access documents directory for ROM path calculation")
            return nil
        }
        return documentsDir.appendingPathComponent("ROMs/\(checksum).\(fileExtension)").path
    }
    
    @MainActor
    func toGame() -> Game? {
        guard let title = title,
              let checksum = checksum else { return nil }
        
        // Use the object's id
        let gameUUID = id
        
        let normalizedSystem = resolvedSystemCode

        // Extract extension from imported filename and normalize case
        let primaryExtension: String
        if let fileName = self.fileName {
            let ext = (fileName as NSString).pathExtension.lowercased()
            primaryExtension = ext.isEmpty ? "rom" : ext
        } else {
            // Fallback to system-based extension if fileName is not available
            switch normalizedSystem {
            case "nes": primaryExtension = "nes"
            case "gb", "gameboy", "game boy": primaryExtension = "gb"
            case "gbc", "gameboycolor", "game boy color", "cgb": primaryExtension = "gbc"
            case "gba", "game boy advance", "gameboyadvance": primaryExtension = "gba"
            case "genesis": primaryExtension = "md"
            case "nds", "nintendo ds": primaryExtension = "nds"
            case "ps1", "playstation 1": primaryExtension = "bin"
            default: primaryExtension = "rom"
            }
        }

        var extensionCandidates: [String] = [primaryExtension]
        if normalizedSystem == "gbc" || normalizedSystem == "cgb" || normalizedSystem.contains("game boy color") {
            extensionCandidates.append(contentsOf: ["gbc", "gb"])
        } else if normalizedSystem == "gb" || normalizedSystem.contains("game boy") {
            extensionCandidates.append(contentsOf: ["gb", "gbc"])
        }
        extensionCandidates = Array(Set(extensionCandidates.map { $0.lowercased() }))
        
        let platformString: String
        switch normalizedSystem {
        case "nes": platformString = "NES"
        case "gb", "gameboy", "game boy": platformString = "Game Boy"
        case "gbc", "gameboycolor", "game boy color", "cgb": platformString = "Game Boy Color"
        case "gba", "gameboyadvance", "game boy advance": platformString = "Game Boy Advance"
        case "genesis": platformString = "Genesis"
        case "nds", "nintendo ds": platformString = "Nintendo DS"
        case "ps1", "playstation 1": platformString = "PlayStation 1"
        default: platformString = system ?? "Unknown"
        }

        var romLocation: ROMStorageLocation?
        for ext in extensionCandidates {
            if let found = ROMStorage.shared.getROMLocation(checksum: checksum, fileExtension: ext) {
                romLocation = found
                break
            }
        }

        if romLocation == nil {
            // Last-resort fallback: scan by checksum prefix regardless of extension/casing.
            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Failed to access documents directory for ROM fallback scan")
                return nil
            }
            let romDir = documentsDir.appendingPathComponent("ROMs")
            if let files = try? FileManager.default.contentsOfDirectory(at: romDir, includingPropertiesForKeys: nil),
               let match = files.first(where: { $0.lastPathComponent.lowercased().hasPrefix("\(checksum.lowercased()).") }) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: match.path)
                let size = attrs?[.size] as? Int64 ?? 0
                romLocation = ROMStorageLocation(url: match, fileSize: size, checksum: checksum)
            }
        }

        guard let romLocation else { return nil }
        
        return Game(
            id: gameUUID,
            title: title,
            platform: platformString,
            coverImage: CoverArtService.shared.resolve(for: self)?.data,
            rating: 0.0,
            lastPlayedDate: lastPlayedAt,
            totalPlayTime: Int(playtimeTotal),
            isFavorite: isFavorite,
            releaseYear: 2000,
            genre: nil,
            fileSize: Int64(fileSize),
            gameDescription: nil,
            romPath: romLocation.url.path
        )
    }
}

@objc(ROMLibraryEntry)
class ROMLibraryEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String?
    @NSManaged var fileName: String?
    @NSManaged var fileSize: Int64
    @NSManaged var coverImageData: Data?
    @NSManaged var customCoverURL: String?
    @NSManaged var system: String?
    @NSManaged var lastPlayedAt: Date?
    @NSManaged var playtimeTotal: Int64
    @NSManaged var isFavorite: Bool
    @NSManaged var dateAdded: Date?
    @NSManaged var checksum: String?
    @NSManaged var romSha1: String?
    @NSManaged var defaultCoverKey: String?
    @NSManaged var canonicalTitleID: String?
}

final class LibraryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var filteredEntries: [ROMLibraryEntry] = []

    private let tierResolver: (String) -> Tier
    private var allEntries: [ROMLibraryEntry] = []
    private var fetchedResultsController: NSFetchedResultsController<ROMLibraryEntry>?
    private weak var viewContext: NSManagedObjectContext?

    init(tierResolver: @escaping (String) -> Tier = LibraryViewModel.defaultTierResolver) {
        self.tierResolver = tierResolver
    }

    func loadEntries(in context: NSManagedObjectContext) {
        isLoading = true
        viewContext = context

        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false)
        ]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        do {
            try fetchedResultsController?.performFetch()
            allEntries = fetchedResultsController?.fetchedObjects ?? []
            filteredEntries = allEntries
        } catch {
            filteredEntries = []
        }

        isLoading = false
    }

    func applyFilter(_ filter: LibraryFilter) {
        switch filter {
        case .all:
            filteredEntries = allEntries
        case .gb:
            filteredEntries = allEntries.filter { $0.resolvedSystemCode == "gb" }
        case .gbc:
            filteredEntries = allEntries.filter { $0.resolvedSystemCode == "gbc" }
        case .recent:
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filteredEntries = allEntries.filter { entry in
                guard let lastPlayed = entry.lastPlayedAt else { return false }
                return lastPlayed >= oneWeekAgo
            }
        case .favorites:
            filteredEntries = allEntries.filter { entry in
                entry.isFavorite
            }
        case .stable:
            let tiersByChecksum = Self.compatibilityTiersByChecksum()
            filteredEntries = allEntries.filter { entry in
                guard let checksum = entry.checksum, !checksum.isEmpty else { return false }
                return tiersByChecksum[checksum] == .stable || tierResolver(checksum) == .stable
            }
        case .experimental:
            let tiersByChecksum = Self.compatibilityTiersByChecksum()
            filteredEntries = allEntries.filter { entry in
                guard let checksum = entry.checksum, !checksum.isEmpty else { return false }
                return tiersByChecksum[checksum] == .experimental || tierResolver(checksum) == .experimental
            }
        }
    }

    private static func compatibilityTiersByChecksum() -> [String: Tier] {
        var tiersByChecksum = Dictionary(
            uniqueKeysWithValues: CompatibilityDataStore.shared.getAllROMs().map { ($0.romHash, $0.tier) }
        )

        if tiersByChecksum.isEmpty,
           let fallbackEntries = try? AzureApiStub.shared.fetchCompatibilityMatrix() {
            for entry in fallbackEntries {
                tiersByChecksum[entry.romHash] = Tier(rawValue: entry.tier.lowercased()) ?? .unknown
            }
        }
        return tiersByChecksum
    }

    private static func defaultTierResolver(for checksum: String) -> Tier {
        let cachedTier = CompatibilityDataStore.shared.getTier(for: checksum)
        if cachedTier != .unknown {
            return cachedTier
        }
        if let fallback = try? AzureApiStub.shared.fetchCompatibilityMatrix().first(where: { $0.romHash == checksum }) {
            return Tier(rawValue: fallback.tier.lowercased()) ?? .unknown
        }
        return .unknown
    }
}

enum LibraryFilter: CaseIterable {
    case all
    case gb
    case gbc
    case recent
    case favorites
    case stable
    case experimental

    var displayName: String {
        switch self {
        case .all: return "All"
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .stable: return "Stable"
        case .experimental: return "Experimental"
        }
    }
}

extension ROMLibraryEntry: Identifiable {
    static func fetchRequest() -> NSFetchRequest<ROMLibraryEntry> {
        return NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
    }
}

extension Image {
    init?(data: Data) {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            self.init(uiImage: uiImage)
        } else {
            return nil
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }
}
