import Foundation
import OSLog

struct GameplayAnalysisLogger {
    private static let logger = Logger(subsystem: "com.xemu.Xemu", category: "GameplayAnalysis")
    private static let enabledKey = "settings.dev.gameplayEventLogging"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func session(_ message: String) {
        guard isEnabled else { return }
        logger.info("\(message, privacy: .public)")
        NSLog("[GameplayAnalysis] %@", message)
    }

    static func event(_ message: String) {
        guard isEnabled else { return }
        logger.debug("\(message, privacy: .public)")
        NSLog("[GameplayAnalysis] %@", message)
    }
}
