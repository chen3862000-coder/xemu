import Foundation
import SwiftUI

enum EmulatorPlatform: String, CaseIterable, Identifiable {
    case gameBoy = "Game Boy"
    case gameBoyColor = "Game Boy Color"
    case gameBoyAdvance = "Game Boy Advance"
    case nintendoDS = "Nintendo DS"
    case playStation1 = "PlayStation 1"
    case nintendo3DS = "Nintendo 3DS"
    case psp = "PSP"
    
    var id: String { rawValue }
    
    var shortName: String {
        switch self {
        case .gameBoy: return "GB"
        case .gameBoyColor: return "GBC"
        case .gameBoyAdvance: return "GBA"
        case .nintendoDS: return "NDS"
        case .playStation1: return "PS1"
        case .nintendo3DS: return "3DS"
        case .psp: return "PSP"
        }
    }
    
    var iconName: String {
        switch self {
        case .gameBoy: return "gameboy.fill"
        case .gameBoyColor: return "gameboy.fill"
        case .gameBoyAdvance: return "gamecontroller.fill"
        case .nintendoDS: return "laptopcomputer"
        case .playStation1: return "tv.fill"
        case .nintendo3DS: return "cube.fill"
        case .psp: return "gamecontroller.fill"
        }
    }
    
    var displayName: String {
        rawValue
    }
    
    var gradient: LinearGradient {
        switch self {
        case .gameBoy: return LinearGradient(colors: [Color(hex: "8B8B8B"), Color(hex: "5A5A5A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gameBoyColor: return LinearGradient(colors: [Color(hex: "9B59B6"), Color(hex: "8E44AD")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gameBoyAdvance: return LinearGradient(colors: [Color(hex: "3498DB"), Color(hex: "2980B9")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .nintendoDS: return LinearGradient(colors: [Color(hex: "E74C3C"), Color(hex: "C0392B")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .playStation1: return LinearGradient(colors: [Color(hex: "2C3E50"), Color(hex: "1A252F")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .nintendo3DS: return LinearGradient(colors: [Color(hex: "E67E22"), Color(hex: "D35400")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .psp: return LinearGradient(colors: [Color(hex: "1ABC9C"), Color(hex: "16A085")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct Game: Identifiable {
    let id: UUID
    var title: String?
    var platform: String
    var coverImage: Data?
    var rating: Double
    var lastPlayedDate: Date?
    var totalPlayTime: Int
    var isFavorite: Bool
    var releaseYear: Int
    var genre: String?
    var fileSize: Int64
    var gameDescription: String?
    
    var emulatorPlatform: EmulatorPlatform {
        EmulatorPlatform(rawValue: platform) ?? .gameBoyAdvance
    }
    
    init(
        id: UUID = UUID(),
        title: String? = nil,
        platform: String = "",
        coverImage: Data? = nil,
        rating: Double = 0.0,
        lastPlayedDate: Date? = nil,
        totalPlayTime: Int = 0,
        isFavorite: Bool = false,
        releaseYear: Int = 2000,
        genre: String? = nil,
        fileSize: Int64 = 0,
        gameDescription: String? = nil
    ) {
        self.id = id
        self.title = title
        self.platform = platform
        self.coverImage = coverImage
        self.rating = rating
        self.lastPlayedDate = lastPlayedDate
        self.totalPlayTime = totalPlayTime
        self.isFavorite = isFavorite
        self.releaseYear = releaseYear
        self.genre = genre
        self.fileSize = fileSize
        self.gameDescription = gameDescription
    }
}
