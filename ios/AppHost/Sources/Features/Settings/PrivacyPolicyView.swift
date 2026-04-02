import SwiftUI

#if os(iOS)
import WebKit
#endif

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            titleKey: "settings.privacy_policy.nav",
            url: URL(string: "https://sites.google.com/view/retromind/privacy-policy")!
        )
    }
}

struct UserAgreementView: View {
    var body: some View {
        LegalDocumentView(
            titleKey: "settings.user_agreement.nav",
            url: URL(string: "https://sites.google.com/view/retromind/user-agreement")!
        )
    }
}

private struct LegalDocumentView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var state: LegalDocumentState = .loading

    let titleKey: String
    let url: URL

    var body: some View {
        Group {
            #if os(iOS)
            content
            #else
            Link(url.absoluteString, destination: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            #endif
        }
        .navigationTitle(L10n.string(titleKey, languageManager: languageManager))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: url) {
            await loadDocument()
        }
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let html):
            LegalDocumentWebView(html: html, baseURL: url)
        case .failed:
            VStack(spacing: 16) {
                Text(L10n.string(titleKey, languageManager: languageManager))
                    .font(.headline)

                Text(url.absoluteString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 24)

                Link(destination: url) {
                    Text(url.host ?? url.absoluteString)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    @MainActor
    private func loadDocument() async {
        guard case .loading = state else { return }

        do {
            let html = try await LegalDocumentExtractor.fetchEmbeddedHTML(from: url)
            state = .loaded(html)
        } catch {
            state = .failed
        }
    }
    #endif
}

private enum LegalDocumentState {
    case loading
    case loaded(String)
    case failed
}

#if os(iOS)
private enum LegalDocumentExtractor {
    private static let marker = "data-code=\""

    static func fetchEmbeddedHTML(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let pageHTML = String(data: data, encoding: .utf8) else {
            throw ExtractorError.invalidEncoding
        }

        guard let startRange = pageHTML.range(of: marker) else {
            throw ExtractorError.embedNotFound
        }

        let contentStart = startRange.upperBound
        guard let endIndex = pageHTML[contentStart...].firstIndex(of: "\"") else {
            throw ExtractorError.embedNotFound
        }

        let encodedHTML = String(pageHTML[contentStart..<endIndex])
        let decodedHTML = decodeHTMLEntities(in: encodedHTML)

        guard decodedHTML.contains("<html") else {
            throw ExtractorError.embedNotFound
        }

        return decodedHTML
    }

    private static func decodeHTMLEntities(in string: String) -> String {
        string
            .replacingOccurrences(of: "&#10;", with: "\n")
            .replacingOccurrences(of: "&#13;", with: "\r")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private enum ExtractorError: Error {
        case invalidEncoding
        case embedNotFound
    }
}

private struct LegalDocumentWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let renderedHash = context.coordinator.renderedHash
        let nextHash = html.hashValue
        guard renderedHash != nextHash else { return }

        context.coordinator.renderedHash = nextHash
        webView.loadHTMLString(html, baseURL: baseURL.deletingLastPathComponent())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var renderedHash: Int?
    }
}
#endif
