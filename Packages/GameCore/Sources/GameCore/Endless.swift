import Foundation

/// One run of the endless mode: the levels in order, over and over, faster each time round. It
/// carries the hero and the score from level to level; each level is still played as its own world.
public struct EndlessRun: Sendable, Equatable {
    /// How much faster the game clock runs for each loop completed.
    public static let speedStep = 0.15
    public static let maxSpeed = 2.0

    public let levelCount: Int
    /// Levels beaten so far in this run.
    public private(set) var cleared = 0
    public private(set) var score = 0
    /// The hero as they leave the last level beaten.
    public private(set) var stats = HeroStats()
    public private(set) var isOver = false

    public init(levelCount: Int) {
        self.levelCount = max(levelCount, 1)
    }

    /// The level to play now.
    public var levelIndex: Int { cleared % levelCount }
    /// 1 on the first pass through the levels.
    public var loop: Int { cleared / levelCount + 1 }
    /// True when the level to play now opens a loop after the first.
    public var startsNewLoop: Bool { cleared > 0 && levelIndex == 0 }

    /// Factor on the game clock. The simulation itself is untouched and only runs faster, so a level
    /// that can be beaten without a hit stays that way on every loop.
    public var speed: Double { Self.speed(forLoop: loop) }

    public static func speed(forLoop loop: Int) -> Double {
        min(maxSpeed, 1 + speedStep * Double(max(loop, 1) - 1))
    }

    /// The hero for the level to play now, never below what that level assumes.
    public func startingStats(for level: LevelDefinition) -> HeroStats {
        var hero = stats
        hero.raise(toLevel: level.entryHeroLevel)
        return hero
    }

    /// A level and its boss were beaten: bank the score, keep the hero and give one heart back.
    public mutating func clear(stats hero: HeroStats, score levelScore: Int) {
        guard !isOver else { return }
        cleared += 1
        score += levelScore
        stats = hero
        stats.hearts = min(hero.maxHearts, hero.hearts + 1)
    }

    /// The hero died: the run ends with whatever the last level earned.
    public mutating func end(score levelScore: Int) {
        guard !isOver else { return }
        score += levelScore
        isOver = true
    }
}
