import Foundation

enum AppRoute: Equatable {
    case boot
    case home
    case importFlow
    case importSummary
    case systemBrowser
    case settings
    case search
    case prepareSession
    case resumeEngine
    case gameplay
    case sessionError
    case errorRecovery
}

enum PauseSheetMode: Equatable {
    case quick
    case advanced
}

enum ResumeLaunchPolicy: String, CaseIterable, Codable, Identifiable {
    case autoResumeLatest
    case askEveryTime
    case startFresh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoResumeLatest: return "Auto Resume"
        case .askEveryTime: return "Ask Every Time"
        case .startFresh: return "Start Fresh"
        }
    }

    var subtitle: String {
        switch self {
        case .autoResumeLatest: return "Resume latest save automatically"
        case .askEveryTime: return "Choose resume or fresh start"
        case .startFresh: return "Always start without loading a save"
        }
    }
}

struct AppUXState: Equatable {
    var route: AppRoute = .boot
    var pauseMode: PauseSheetMode = .quick
    var resumePolicy: ResumeLaunchPolicy = .autoResumeLatest
    var hasLibrary = false
    var hasRecentGame = false
}
