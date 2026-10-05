import Foundation

public struct SaveGame: Codable, Sendable, Equatable {
    public var xp = 0
    /// Number of levels the player may start (1 = only the first).
    public var unlockedLevels = 1
    public var bestScores: [String: Int] = [:]
    public var soundOn = true

    public init() {}

    /// Records a finished level; `index` is 0-based, `total` the number of levels in the game.
    public mutating func complete(levelID: String, index: Int, total: Int, score: Int, xp newXP: Int) {
        xp = max(xp, newXP)
        unlockedLevels = min(total, max(unlockedLevels, index + 2))
        bestScores[levelID] = max(bestScores[levelID] ?? 0, score)
    }
}

public protocol SaveStore {
    func load() -> SaveGame
    func save(_ game: SaveGame)
}

public struct DefaultsSaveStore: SaveStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "savegame.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> SaveGame {
        guard let data = defaults.data(forKey: key),
              let game = try? JSONDecoder().decode(SaveGame.self, from: data) else { return SaveGame() }
        return game
    }

    public func save(_ game: SaveGame) {
        guard let data = try? JSONEncoder().encode(game) else { return }
        defaults.set(data, forKey: key)
    }
}
