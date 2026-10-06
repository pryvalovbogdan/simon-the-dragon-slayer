import Foundation

public enum Ability: String, Codable, Sendable, CaseIterable {
    case fireball, doubleJump, chargedFireball
}

/// XP → hero level → abilities. Hero level is 1-based and capped at `maxLevel`.
public enum Progression {
    /// XP needed to *be* each level; index 0 is level 1.
    public static let thresholds = [0, 100, 300, 600]
    public static var maxLevel: Int { thresholds.count }

    public static func level(forXP xp: Int) -> Int {
        (thresholds.lastIndex { xp >= $0 } ?? 0) + 1
    }

    public static func xp(forLevel level: Int) -> Int {
        thresholds[min(max(level, 1), maxLevel) - 1]
    }

    public static func ability(unlockedAt level: Int) -> Ability? {
        switch level {
        case 2: .fireball
        case 3: .doubleJump
        case 4: .chargedFireball
        default: nil
        }
    }

    public static func abilities(forLevel level: Int) -> Set<Ability> {
        guard level >= 2 else { return [] }
        return Set((2...min(level, maxLevel)).compactMap(ability(unlockedAt:)))
    }

    /// XP still needed for the next level, or nil at max level.
    public static func xpToNext(fromXP xp: Int) -> Int? {
        let level = level(forXP: xp)
        return level >= maxLevel ? nil : thresholds[level] - xp
    }
}

public struct HeroStats: Codable, Sendable, Equatable {
    public var xp: Int
    public var hearts: Int
    public var maxHearts: Int

    public init(xp: Int = 0, maxHearts: Int = 3) {
        self.xp = xp
        self.hearts = maxHearts
        self.maxHearts = maxHearts
    }

    public var level: Int { Progression.level(forXP: xp) }
    public var abilities: Set<Ability> { Progression.abilities(forLevel: level) }
    public func has(_ ability: Ability) -> Bool { abilities.contains(ability) }

    /// Adds XP and returns every level reached by it, lowest first.
    @discardableResult
    public mutating func gain(xp amount: Int) -> [Int] {
        let before = level
        xp += max(amount, 0)
        let after = level
        return after > before ? Array((before + 1)...after) : []
    }

    /// Raises the hero to at least `target` level; never lowers XP.
    @discardableResult
    public mutating func raise(toLevel target: Int) -> [Int] {
        gain(xp: Progression.xp(forLevel: target) - xp)
    }
}
