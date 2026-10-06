import Foundation

/// One damaging shape spawned by a boss attack.
public struct HazardSpec: Codable, Sendable, Equatable {
    /// Visual id, also the sprite name (`hazard_<kind>`).
    public var kind: String
    /// Seconds after the attack starts.
    public var delay: Double
    /// Bottom of the hazard above the ground. Low hazards are jumped, high ones are run under.
    public var y: Double
    public var width: Double
    public var height: Double
    /// Speed at which it approaches the hero on screen.
    public var closingSpeed: Double
    /// If set, spawns this far ahead of the hero instead of at the boss.
    public var ahead: Double?
    /// Seconds it is visible as a warning before it can hurt.
    public var arm: Double?
}

public struct SummonSpec: Codable, Sendable, Equatable {
    public var kind: ItemKind
    public var delay: Double
}

public struct BossAttack: Codable, Sendable, Equatable {
    public var name: String
    /// Wind-up before anything spawns.
    public var telegraph: Double
    /// Length of the attack itself; hazards and summons are timed inside it.
    public var duration: Double
    /// Pause afterwards, when `recover`-vulnerable bosses can be damaged.
    public var recover: Double
    public var hazards: [HazardSpec]
    public var summons: [SummonSpec]?
}

public struct BossPhase: Codable, Sendable, Equatable {
    /// Phase is active once HP fraction is at or below this (first phase uses 1).
    public var startsBelow: Double
    /// Attack names, cycled in order.
    public var attacks: [String]
}

public enum BossVulnerability: String, Codable, Sendable {
    case always, recover
}

public struct BossDefinition: Codable, Sendable, Equatable {
    public var id: String
    public var hp: Int
    public var width: Double
    public var height: Double
    /// Bottom of the hitbox above the ground.
    public var baseY: Double
    public var vulnerable: BossVulnerability
    /// Only charged fireballs damage it.
    public var requiresCharged: Bool
    public var attacks: [BossAttack]
    public var phases: [BossPhase]
}

public enum BossAction: String, Sendable, Equatable {
    case intro, telegraph, attack, recover, dead
}

public struct BossState: Sendable, Equatable {
    public var id: String
    public var hp: Int
    public var maxHP: Int
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var action: BossAction = .intro
    public var attackName: String = ""
    public var phaseIndex = 0
    /// Seconds spent in the current action.
    public var actionTime: Double = 0
    var attackCursor = 0
    var spawnedHazards = 0
    var spawnedSummons = 0

    public var hpFraction: Double { maxHP > 0 ? Double(hp) / Double(maxHP) : 0 }
    public var box: AABB { AABB(centerX: x, bottom: y, width: width, height: height) }
}
