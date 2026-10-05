import Foundation
@testable import GameCore

enum Content {
    /// App/Resources, located relative to this source file.
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Resources")

    /// Every level file in the app, in play order (file names sort in play order).
    static let levelIDs: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: resources.appendingPathComponent("Levels").path)) ?? []
        return files.filter { $0.hasPrefix("level_") && $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    }()

    static func level(_ id: String) throws -> LevelDefinition {
        try ContentLoader.level(from: Data(contentsOf: resources.appendingPathComponent("Levels/\(id).json")))
    }

    static func bosses() throws -> [String: BossDefinition] {
        try ContentLoader.bosses(from: Data(contentsOf: resources.appendingPathComponent("Bosses.json")))
    }

    static func lore() throws -> Lore {
try Lore(data: Data(contentsOf: resources.appendingPathComponent("Lore.json")))
    }
}

let dt = 1.0 / 60

func flatLevel(items: [PlacedItem] = [], length: Double = 2000, entry: Int = 1, shrine: Int? = nil,
               reward: Int = 2) -> LevelDefinition {
    LevelDefinition(id: "test", nameKey: "test", background: "forest", speed: 100, length: length,
                    entryHeroLevel: entry, shrineLevel: shrine, boss: "none", bossRewardLevel: reward, items: items)
}

extension RunnerWorld {
    /// Steps with a constant input (jump pressed only on the first frame); returns all events.
    @discardableResult
    mutating func run(_ seconds: Double, _ input: Input = Input()) -> [GameEvent] {
        var events: [GameEvent] = []
        var current = input
        var elapsed = 0.0
        while elapsed < seconds, !isOver {
            events += step(current, dt: dt)
            current.jumpPressed = false
            elapsed += dt
        }
        return events
    }
}
