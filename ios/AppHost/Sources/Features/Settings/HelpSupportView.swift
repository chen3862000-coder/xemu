import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct HelpSupportView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.openURL) private var openURL

    @AppStorage("showCartridgeLaunchIntro") private var showCartridgeLaunchIntro = false

    @State private var searchText = ""
    @State private var showReplayGuideAlert = false

    private let catalog = LocalizedContentStore.loadHelpSupportCatalog()
    private let quickActionArticleIDs = [
        "start_playing",
        "add_games",
        "save_progress",
        "what_enhanced_games",
        "bluetooth_audio_lag"
    ]

    private var locale: Locale {
        languageManager.formattingLocale
    }

    private var searchResults: [HelpSupportSearchResult] {
        catalog.searchResults(matching: searchText, locale: locale)
    }

    private var quickActionResults: [HelpSupportSearchResult] {
        quickActionArticleIDs.compactMap { id in
            guard let match = catalog.article(id: id) else { return nil }
            return HelpSupportSearchResult(category: match.category, item: match.item, score: 0)
        }
    }

    var body: some View {
        List {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                homeContent
            } else {
                searchContent
            }
        }
        .helpSupportListStyle()
        .navigationTitle(catalog.ui.text(\.screenTitle, locale: locale))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: Text(catalog.ui.text(\.searchPlaceholder, locale: locale)))
        .alert(catalog.ui.text(\.replayGuideTitle, locale: locale), isPresented: $showReplayGuideAlert) {
            Button(L10n.string("common.done", languageManager: languageManager)) {}
        } message: {
            Text(catalog.ui.text(\.replayGuideMessage, locale: locale))
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        Section(header: HelpSupportSectionHeader(catalog.ui.text(\.popularHelpTitle, locale: locale))) {
            ForEach(quickActionResults) { result in
                NavigationLink {
                    HelpSupportCategoryView(
                        category: result.category,
                        ui: catalog.ui,
                        initiallyExpandedID: result.item.id
                    )
                    .environmentObject(languageManager)
                } label: {
                    HelpSupportListRow(
                        icon: result.item.icon ?? result.category.icon,
                        title: result.item.title(for: locale),
                        subtitle: result.item.summary(for: locale)
                    )
                }
            }

            if let contactAction = catalog.action(id: "contact_support") {
                actionButtonRow(contactAction)
            }
        }

        Section(header: HelpSupportSectionHeader(catalog.ui.text(\.browseByTopicTitle, locale: locale))) {
            ForEach(catalog.categories) { category in
                NavigationLink {
                    HelpSupportCategoryView(category: category, ui: catalog.ui)
                        .environmentObject(languageManager)
                } label: {
                    HelpSupportListRow(icon: category.icon, title: category.title(for: locale))
                }
            }
        }

        Section(header: HelpSupportSectionHeader(catalog.ui.text(\.getInTouchTitle, locale: locale))) {
            ForEach(catalog.supportActions.filter { $0.id != "contact_support" }) { action in
                actionButtonRow(action)
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if searchResults.isEmpty {
            ContentUnavailableView {
                Label(catalog.ui.text(\.noResultsTitle, locale: locale), systemImage: "magnifyingglass")
            } description: {
                Text(catalog.ui.text(\.noResultsBody, locale: locale))
            }
            .listRowBackground(Color.clear)
        } else {
            ForEach(searchResults) { result in
                NavigationLink {
                    HelpSupportCategoryView(
                        category: result.category,
                        ui: catalog.ui,
                        initiallyExpandedID: result.item.id
                    )
                    .environmentObject(languageManager)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.item.title(for: locale))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(result.category.title(for: locale))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)

                        if let summary = result.item.summary(for: locale) {
                            Text(summary)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
            }
        }
    }

    private func actionButtonRow(_ action: HelpSupportAction) -> some View {
        Button {
            perform(action)
        } label: {
            HelpSupportListRow(
                icon: action.icon,
                title: action.title(for: locale),
                subtitle: action.subtitle(for: locale)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func perform(_ action: HelpSupportAction) {
        switch action.destination {
        case .contactSupport, .sendFeedback:
            guard let subject = action.emailSubject(for: locale),
                  let body = action.emailBody(for: locale),
                  let url = mailURL(subject: subject, body: body) else { return }
            openURL(url)
        case .replayGuide:
            showCartridgeLaunchIntro = true
            showReplayGuideAlert = true
        }
    }

    private func mailURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@retromind.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: supportBody(body))
        ]
        return components.url
    }

    private func supportBody(_ baseBody: String) -> String {
        #if canImport(UIKit)
        let deviceDetails = [
            "Device: \(UIDevice.current.model)",
            "iOS: \(UIDevice.current.systemVersion)"
        ].joined(separator: "\n")
        return "\(baseBody)\n\n\(deviceDetails)"
        #else
        return baseBody
        #endif
    }
}

private struct HelpSupportCategoryView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let category: HelpSupportCategory
    let ui: HelpSupportUIStrings

    @State private var expandedID: String?

    init(category: HelpSupportCategory, ui: HelpSupportUIStrings, initiallyExpandedID: String? = nil) {
        self.category = category
        self.ui = ui
        _expandedID = State(initialValue: initiallyExpandedID)
    }

    private var locale: Locale {
        languageManager.formattingLocale
    }

    var body: some View {
        List {
            if category.items.isEmpty {
                ContentUnavailableView(
                    ui.text(\.moreHelpComingTitle, locale: locale),
                    systemImage: category.icon,
                    description: Text(ui.text(\.moreHelpComingBody, locale: locale))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(category.items) { item in
                    ExpandableFAQRow(
                        item: item,
                        locale: locale,
                        expandedStateText: ui.text(\.expandedState, locale: locale),
                        collapsedStateText: ui.text(\.collapsedState, locale: locale),
                        isExpanded: expandedID == item.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            expandedID = expandedID == item.id ? nil : item.id
                        }
                    }
                }
            }
        }
        .helpSupportListStyle()
        .navigationTitle(category.title(for: locale))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .id("help-support-category-\(category.id)-\(languageManager.refreshID)")
    }
}

private struct ExpandableFAQRow: View {
    let item: HelpSupportItem
    let locale: Locale
    let expandedStateText: String
    let collapsedStateText: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(item.title(for: locale))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title(for: locale))
            .accessibilityValue(isExpanded ? expandedStateText : collapsedStateText)

            if isExpanded {
                FAQAnswerView(item: item, locale: locale)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, isExpanded ? 4 : 0)
    }
}

private struct FAQAnswerView: View {
    let item: HelpSupportItem
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = item.summary(for: locale) {
                Text(summary)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
            }

            let steps = item.steps(for: locale)
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(step)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            if let tip = item.tip(for: locale) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.secondary)
                    Text(tip)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundShape)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        #if canImport(UIKit)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
        #else
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
        #endif
    }
}

private struct HelpSupportSectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.tertiary)
    }
}

private struct HelpSupportListRow: View {
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }
}

private extension View {
    @ViewBuilder
    func helpSupportListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}
