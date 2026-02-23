import SwiftUI

@main
struct iOSApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeController = ThemeController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeController)
                .environment(\.colorScheme, themeController.colorScheme)
                .preferredColorScheme(themeController.colorScheme)
                .id("app-theme-\(themeController.mode.rawValue)")
        }
    }
}
