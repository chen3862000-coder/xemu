import Foundation

struct PlayerHistorySession: Codable, Identifiable, Equatable {
    let id: UUID
    let gameID: String
    let gameTitle: String
    let system: String
    let startTime: Date
    let endTime: Date
    let durationSeconds: Int
}

struct PlayerAchievementDefinition: Identifiable, Equatable {
    enum Metric: Equatable {
        case sessionCount
        case totalPlaySeconds
        case uniqueGamesPlayed
    }

    let id: String
    let title: String
    let detail: String
    let icon: String
    let metric: Metric
    let target: Int
}

struct PlayerAchievementUnlock: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let unlockedAt: Date
}

struct PlayerProgressSnapshot: Codable, Equatable {
    var sessions: [PlayerHistorySession] = []
    var unlockedAchievementDates: [String: Date] = [:]
}

final class PlayerProgressStore {
    static let shared = PlayerProgressStore()

    static let achievementDefinitions: [PlayerAchievementDefinition] = [
        PlayerAchievementDefinition(
            id: "power-on",
            title: "Power On",
            detail: "Start your first retro game",
            icon: "power",
            metric: .sessionCount,
            target: 1
        ),
        PlayerAchievementDefinition(
            id: "first-hour",
            title: "First Steps",
            detail: "Play for 1 hour total",
            icon: "clock.badge.checkmark",
            metric: .totalPlaySeconds,
            target: 3_600
        ),
        PlayerAchievementDefinition(
            id: "retro-fan",
            title: "Retro Fan",
            detail: "Play for 5 hours total",
            icon: "medal.fill",
            metric: .totalPlaySeconds,
            target: 18_000
        ),
        PlayerAchievementDefinition(
            id: "dedicated-player",
            title: "Dedicated Player",
            detail: "Finish 10 play sessions",
            icon: "bolt.fill",
            metric: .sessionCount,
            target: 10
        ),
        PlayerAchievementDefinition(
            id: "game-sampler",
            title: "Game Sampler",
            detail: "Play 3 different games",
            icon: "square.grid.2x2.fill",
            metric: .uniqueGamesPlayed,
            target: 3
        )
    ]

    private let queue = DispatchQueue(label: "PlayerProgressStore.queue")
    private let fileURL: URL
    private var snapshot: PlayerProgressSnapshot

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.snapshot = Self.loadSnapshot(from: self.fileURL)
    }

    func currentSnapshot() -> PlayerProgressSnapshot {
        queue.sync { snapshot }
    }

    func recentSessions(limit: Int) -> [PlayerHistorySession] {
        queue.sync {
            let sorted = snapshot.sessions.sorted { $0.endTime > $1.endTime }
            if limit > 0 {
                return Array(sorted.prefix(limit))
            }
            return sorted
        }
    }

    func recordSession(
        gameID: String,
        gameTitle: String,
        system: String,
        startTime: Date,
        endTime: Date,
        durationSeconds: Int
    ) -> [PlayerAchievementUnlock] {
        guard durationSeconds > 0 else { return [] }
        let normalizedGameID = gameID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedGameID.isEmpty else { return [] }

        return queue.sync {
            let safeStart = min(startTime, endTime)
            let safeEnd = max(startTime, endTime)
            let session = PlayerHistorySession(
                id: UUID(),
                gameID: normalizedGameID,
                gameTitle: gameTitle.isEmpty ? "Unknown Game" : gameTitle,
                system: system.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                startTime: safeStart,
                endTime: safeEnd,
                durationSeconds: durationSeconds
            )
            snapshot.sessions.append(session)

            // Keep file growth bounded while preserving a long history.
            if snapshot.sessions.count > 2_000 {
                snapshot.sessions.removeFirst(snapshot.sessions.count - 2_000)
            }

            let unlocked = evaluateUnlocks(now: safeEnd)
            persistSnapshot(snapshot, to: fileURL)
            return unlocked
        }
    }

    func unlockedDate(for achievementID: String) -> Date? {
        queue.sync { snapshot.unlockedAchievementDates[achievementID] }
    }

    #if DEBUG
    func resetForTesting() {
        queue.sync {
            snapshot = PlayerProgressSnapshot()
            persistSnapshot(snapshot, to: fileURL)
        }
    }
    #endif

    private func evaluateUnlocks(now: Date) -> [PlayerAchievementUnlock] {
        var newUnlocks: [PlayerAchievementUnlock] = []
        let sessionCount = snapshot.sessions.count
        let totalPlaySeconds = snapshot.sessions.reduce(0) { $0 + $1.durationSeconds }
        let uniqueGamesPlayed = Set(snapshot.sessions.map(\.gameID)).count

        for definition in Self.achievementDefinitions {
            if snapshot.unlockedAchievementDates[definition.id] != nil {
                continue
            }

            let metricValue: Int
            switch definition.metric {
            case .sessionCount:
                metricValue = sessionCount
            case .totalPlaySeconds:
                metricValue = totalPlaySeconds
            case .uniqueGamesPlayed:
                metricValue = uniqueGamesPlayed
            }

            guard metricValue >= definition.target else { continue }
            snapshot.unlockedAchievementDates[definition.id] = now
            newUnlocks.append(
                PlayerAchievementUnlock(
                    id: definition.id,
                    title: definition.title,
                    detail: definition.detail,
                    unlockedAt: now
                )
            )
        }

        return newUnlocks
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = appSupport.appendingPathComponent("AppHost", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("player_progress_v1.json", isDirectory: false)
    }

    private static func loadSnapshot(from url: URL) -> PlayerProgressSnapshot {
        guard let data = try? Data(contentsOf: url) else {
            return PlayerProgressSnapshot()
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(PlayerProgressSnapshot.self, from: data) {
            return decoded
        }

        return PlayerProgressSnapshot()
    }

    private func persistSnapshot(_ snapshot: PlayerProgressSnapshot, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
