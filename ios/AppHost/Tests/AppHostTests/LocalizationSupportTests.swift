import XCTest
@testable import Xemu

final class LocalizationSupportTests: XCTestCase {
    private let requiredLocales = ["en", "zh-Hans", "zh-Hant", "ja", "es"]

    func testSupportedLanguageMatchesChineseScriptVariants() {
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "zh-Hant-HK"), .zhHant)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "zh_TW"), .zhHant)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "zh-Hans-SG"), .zhHans)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "zh-CN"), .zhHans)
    }

    func testSupportedLanguageMatchesJapaneseAndSpanish() {
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "ja-JP"), .ja)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "es-MX"), .es)
        XCTAssertEqual(SupportedLanguage.bestMatch(for: "fr-FR"), .en)
    }

    func testLocalizedContentResolverFallsBackToScriptAndEnglish() {
        let values = [
            "en": "Continue Playing",
            "zh-Hant": "繼續遊玩",
            "ja": "続きから遊ぶ"
        ]

        XCTAssertEqual(
            LocalizedContentResolver.resolve(values: values, locale: Locale(identifier: "zh-Hant-HK")),
            "繼續遊玩"
        )
        XCTAssertEqual(
            LocalizedContentResolver.resolve(values: values, locale: Locale(identifier: "es-MX")),
            "Continue Playing"
        )
    }

    @MainActor
    func testLanguageManagerPersistsExplicitSelection() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let manager = LanguageManager(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["ja-JP"] }
        )

        XCTAssertEqual(manager.currentLanguage, .system)
        XCTAssertEqual(manager.resolvedLanguage, .ja)

        manager.setLanguage(.es)

        XCTAssertEqual(manager.currentLanguage, .es)
        XCTAssertEqual(manager.resolvedLanguage, .es)
        XCTAssertEqual(defaults.string(forKey: "app.language"), SupportedLanguage.es.rawValue)
    }

    func testStringCatalogsContainAllLaunchLocales() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourcesURL = packageRoot.appendingPathComponent("Sources/Localization/Resources", isDirectory: true)
        let catalogURLs = try FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "xcstrings" }

        XCTAssertFalse(catalogURLs.isEmpty)

        for catalogURL in catalogURLs {
            let data = try Data(contentsOf: catalogURL)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let strings = try XCTUnwrap(object["strings"] as? [String: Any], "Missing strings in \(catalogURL.lastPathComponent)")

            for (key, entryValue) in strings {
                guard let entry = entryValue as? [String: Any],
                      let localizations = entry["localizations"] as? [String: Any] else {
                    XCTFail("Missing localizations block for key \(key) in \(catalogURL.lastPathComponent)")
                    continue
                }

                for locale in requiredLocales {
                    XCTAssertNotNil(
                        localizations[locale],
                        "Missing locale \(locale) for key \(key) in \(catalogURL.lastPathComponent)"
                    )
                }
            }
        }
    }
}
