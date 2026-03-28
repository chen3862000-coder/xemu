import SwiftUI

@main
struct iOSApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeController = ThemeController.shared
    @StateObject private var shellThemeManager = ShellThemeManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeController)
                .environmentObject(shellThemeManager)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.formattingLocale)
                .environment(\.colorScheme, themeController.colorScheme)
                .preferredColorScheme(themeController.colorScheme)
                .id("app-theme-\(themeController.mode.rawValue)-lang-\(languageManager.refreshID)")
        }
    }
}
