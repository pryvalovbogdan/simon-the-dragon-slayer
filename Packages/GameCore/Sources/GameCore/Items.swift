import Foundation

/// Everything a level file can place. Raw values are the ids used in level JSON and asset names.
public enum ItemKind: String, Codable, Sendable, CaseIterable {
    case tree, root, thorns, goblin, wolf, skeleton, ghost, giant, icicle, archer, hound, raven, coin, shrine
}

public struct ItemSpec: Sendable {
    /// Hitbox in world units (1 unit = 1 sprite pixel).
    public var width: Double
    public var height: Double
    /// Bottom of the hitbox above the ground.
    public var baseY: Double = 0
    public var hp: Int = 1
    public var xp: Int = 0
    /// World velocity along x; negative walks toward the hero.
    public var velocity: Double = 0
    public var hurtsOnTouch = true
    /// Landing on it from above is safe: the hero bounces off unhurt.
    public var stompable = false
    /// That landing also defeats it outright, whatever health it has left, and earns its XP.
    public var stompKills = false
    /// Fireballs damage it (otherwise they pass through).
    public var burnable = false
    /// Hero level a player needs to get past it without being hit.
    public var minHeroLevel = 1
}

extension ItemKind {
    /// Moves along the ground, so it cannot cross a ravine.
    public var walks: Bool { spec.velocity != 0 && spec.baseY == 0 }

    public var spec: ItemSpec {
        switch self {
        case .tree: ItemSpec(width: 12, height: 24)
        case .root: ItemSpec(width: 18, height: 7)
        // Wide and low: needs a committed jump. Fire does nothing to it.
        case .thorns: ItemSpec(width: 22, height: 14)
        case .wolf: ItemSpec(width: 20, height: 15, hp: 2, xp: 20, velocity: -50, stompable: true, stompKills: true,
                             burnable: true)
        case .skeleton: ItemSpec(width: 12, height: 26, hp: 2, xp: 25, velocity: -14, stompable: true,
                                 stompKills: true, burnable: true)
        // Fire and boots pass straight through it. It drifts in overhead, then swoops to the ground.
        case .ghost: ItemSpec(width: 14, height: 18, baseY: GhostFlight.high, velocity: -20)
        case .goblin: ItemSpec(width: 14, height: 18, xp: 10, velocity: -20, stompable: true, stompKills: true,
                               burnable: true)
        case .giant: ItemSpec(width: 24, height: 56, hp: 3, xp: 40, velocity: -8, burnable: true, minHeroLevel: 2)
        case .icicle: ItemSpec(width: 10, height: 40, baseY: 42)
        case .archer: ItemSpec(width: 14, height: 24, hp: 2, xp: 25, stompable: true, burnable: true)
        case .hound: ItemSpec(width: 20, height: 14, xp: 15, velocity: -70, stompable: true, burnable: true)
        case .raven: ItemSpec(width: 14, height: 10, baseY: 44, xp: 15, velocity: -40, burnable: true)
        case .coin: ItemSpec(width: 10, height: 10, baseY: 14, xp: 5, hurtsOnTouch: false)
        case .shrine: ItemSpec(width: 16, height: 400, hurtsOnTouch: false)
        }
    }
}

/// How a ghost flies: overhead while far away, down to the ground once it is close to the hero.
public enum GhostFlight {
    public static let high = 44.0
    public static let low = 2.0
    /// Gap to the hero at which the dive starts and ends.
    public static let diveStart = 150.0
    public static let diveEnd = 80.0

    public static func height(gap: Double) -> Double {
        let progress = min(1, max(0, (diveStart - gap) / (diveStart - diveEnd)))
        return high + (low - high) * progress
    }
}

public struct AABB: Sendable, Equatable {
    public var minX, minY, maxX, maxY: Double

    public init(centerX: Double, bottom: Double, width: Double, height: Double) {
        minX = centerX - width / 2
        maxX = centerX + width / 2
        minY = bottom
        maxY = bottom + height
    }

    public func intersects(_ other: AABB) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }
}
