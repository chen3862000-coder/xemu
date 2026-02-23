import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Foundation

struct ContentView: View {
    @EnvironmentObject private var themeController: ThemeController

    var body: some View {
        HomeView()
            .id("root-home-\(themeController.mode.rawValue)")
    }
}
