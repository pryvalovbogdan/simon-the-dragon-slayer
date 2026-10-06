import Foundation

public struct SaveGame: Codable, Sendable, Equatable {
    public var xp = 0
    /// Number of levels the player may start on their own, counted from the first. Levels are
    /// opened by beating them in an endless run.
    public var unlockedLevels = 0
    public var bestScores: [String: Int] = [:]
    public var soundOn = true
    public var bestEndlessScore = 0
    /// Most levels beaten in one endless run.
    public var bestEndlessCleared = 0

    public init() {}

    /// Fields added after the first release are optional in the data, so older saves still load.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        xp = try values.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        unlockedLevels = try values.decodeIfPresent(Int.self, forKey: .unlockedLevels) ?? 0
        bestScores = try values.decodeIfPresent([String: Int].self, forKey: .bestScores) ?? [:]
        soundOn = try values.decodeIfPresent(Bool.self, forKey: .soundOn) ?? true
        bestEndlessScore = try values.decodeIfPresent(Int.self, forKey: .bestEndlessScore) ?? 0
        bestEndlessCleared = try values.decodeIfPresent(Int.self, forKey: .bestEndlessCleared) ?? 0
    }

    /// Records a level finished on its own.
    public mutating func complete(levelID: String, score: Int, xp newXP: Int) {
        xp = max(xp, newXP)
        bestScores[levelID] = max(bestScores[levelID] ?? 0, score)
    }

    /// Records where an endless run stands: `cleared` levels beaten out of a game of `total`. Each
    /// level beaten there becomes playable on its own.
    public mutating func recordEndless(score: Int, cleared: Int, total: Int) {
        unlockedLevels = min(total, max(unlockedLevels, cleared))
        bestEndlessScore = max(bestEndlessScore, score)
        bestEndlessCleared = max(bestEndlessCleared, cleared)
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
