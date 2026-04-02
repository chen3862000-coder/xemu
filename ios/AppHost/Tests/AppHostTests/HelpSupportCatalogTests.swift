import XCTest
@testable import Xemu

final class HelpSupportCatalogTests: XCTestCase {
    private let requiredLocales = ["en", "zh-Hans", "zh-Hant", "ja", "es"]

    func testHelpSupportCatalogLoadsExpectedCategories() {
        let catalog = LocalizedContentStore.loadHelpSupportCatalog()

        XCTAssertEqual(catalog.categories.count, 6)
        XCTAssertEqual(catalog.supportActions.count, 3)
        XCTAssertEqual(catalog.category(id: "quick_start")?.items.count, 3)
        XCTAssertEqual(catalog.category(id: "enhanced_games")?.items.count, 6)
    }

    func testHelpSupportSearchMatchesLocalizedTerms() {
        let catalog = LocalizedContentStore.loadHelpSupportCatalog()

        let spanishResults = catalog.searchResults(matching: "importar", locale: Locale(identifier: "es"))
        XCTAssertEqual(spanishResults.first?.item.id, "add_games")

        let chineseResults = catalog.searchResults(matching: "蓝牙", locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(chineseResults.first?.item.id, "bluetooth_audio_lag")
    }

    func testHelpSupportContentIncludesLaunchLocales() {
        let catalog = LocalizedContentStore.loadHelpSupportCatalog()

        assertLocalizedMap(catalog.ui.screenTitle, name: "ui.screenTitle")
        assertLocalizedMap(catalog.ui.searchPlaceholder, name: "ui.searchPlaceholder")

        for category in catalog.categories {
            assertLocalizedMap(category.title, name: "category.\(category.id).title")

            for item in category.items {
                assertLocalizedMap(item.title, name: "item.\(item.id).title")
                if let summary = item.summary {
                    assertLocalizedMap(summary, name: "item.\(item.id).summary")
                }
                if let tip = item.tip {
                    assertLocalizedMap(tip, name: "item.\(item.id).tip")
                }
                assertLocalizedArrayMap(item.steps, name: "item.\(item.id).steps")
            }
        }

        for action in catalog.supportActions {
            assertLocalizedMap(action.title, name: "action.\(action.id).title")
            assertLocalizedMap(action.subtitle, name: "action.\(action.id).subtitle")
        }
    }

    private func assertLocalizedMap(_ values: [String: String], name: String) {
        for locale in requiredLocales {
            XCTAssertNotNil(values[locale], "Missing locale \(locale) for \(name)")
        }
    }

    private func assertLocalizedArrayMap(_ values: [String: [String]], name: String) {
        for locale in requiredLocales {
            XCTAssertNotNil(values[locale], "Missing locale \(locale) for \(name)")
            XCTAssertFalse(values[locale]?.isEmpty ?? true, "Expected content for \(name) in \(locale)")
        }
    }
}
