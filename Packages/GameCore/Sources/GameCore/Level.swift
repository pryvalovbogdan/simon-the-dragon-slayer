import Foundation

public struct PlacedItem: Codable, Sendable, Equatable {
    /// Distance from the level start, in world units.
    public var at: Double
    public var kind: ItemKind
    /// Overrides the kind's default height above ground (used for coin arcs).
    public var y: Double?

    public init(at: Double, kind: ItemKind, y: Double? = nil) {
        self.at = at
        self.kind = kind
        self.y = y
    }
}

public struct LevelDefinition: Codable, Sendable, Equatable {
    public var id: String
    /// Key into Lore.json for the display name.
    public var nameKey: String
    public var background: String
    /// Run speed in world units per second.
    public var speed: Double
    /// Distance at which the boss fight starts.
    public var length: Double
    /// Hero level a player is guaranteed to have on entry (set by earlier boss rewards).
    public var entryHeroLevel: Int
    /// Hero level granted by passing a shrine in this level.
    public var shrineLevel: Int?
    public var boss: String
    /// Hero level granted by defeating the boss.
    public var bossRewardLevel: Int
    public var items: [PlacedItem]

    public init(id: String, nameKey: String, background: String, speed: Double, length: Double,
                entryHeroLevel: Int, shrineLevel: Int? = nil, boss: String, bossRewardLevel: Int,
                items: [PlacedItem]) {
        self.id = id
        self.nameKey = nameKey
        self.background = background
        self.speed = speed
        self.length = length
        self.entryHeroLevel = entryHeroLevel
        self.shrineLevel = shrineLevel
        self.boss = boss
        self.bossRewardLevel = bossRewardLevel
        self.items = items
    }
}

public enum ContentError: Error, Equatable {
    case missing(String)
    case invalid(String)
}

public enum ContentLoader {
    public static func level(from data: Data) throws -> LevelDefinition {
        var level = try JSONDecoder().decode(LevelDefinition.self, from: data)
        level.items.sort { $0.at < $1.at }
        return level
    }

    public static func bosses(from data: Data) throws -> [String: BossDefinition] {
        let list = try JSONDecoder().decode([BossDefinition].self, from: data)
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static func level(named id: String, in bundle: Bundle) throws -> LevelDefinition {
        try level(from: data(id, in: bundle))
    }

    /// All `level_*.json` files in the bundle, in play order (file names sort in play order).
    public static func levels(in bundle: Bundle) throws -> [LevelDefinition] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let levels = try urls
            .filter { $0.lastPathComponent.hasPrefix("level_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try level(from: Data(contentsOf: $0)) }
        guard !levels.isEmpty else { throw ContentError.missing("level_*.json") }
        return levels
    }

    public static func bosses(in bundle: Bundle) throws -> [String: BossDefinition] {
        try bosses(from: data("Bosses", in: bundle))
    }

    private static func data(_ name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw ContentError.missing("\(name).json")
        }
        return try Data(contentsOf: url)
    }
}
