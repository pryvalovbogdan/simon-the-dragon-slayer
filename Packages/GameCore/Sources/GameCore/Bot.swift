import Foundation

/// A jump the bot commits to: hold time for the first jump and, optionally, when to double jump.
struct BotPlan: Sendable, Equatable {
    var hold: Double
    var secondAt: Double?

    func input(elapsed: Double, dt: Double, fireHeld: Bool) -> Input {
        var input = Input(fireHeld: fireHeld)
        input.jumpPressed = elapsed < dt / 2
        input.jumpHeld = elapsed < hold
        if let secondAt, elapsed >= secondAt {
            input.jumpPressed = elapsed < secondAt + dt
            input.jumpHeld = elapsed < secondAt + hold
        }
        return input
    }
}

/// Plays a level by simulating copies of the world a second ahead. Used to prove that a level and
/// its boss can be finished without taking a hit; it is not shipped as gameplay.
public struct Bot: Sendable {
    private var plan: BotPlan?
    private var elapsed = 0.0

    public init() {}

    /// Fire-button pattern as a pure function of world time, so look-ahead copies reproduce it.
    static func fireHeld(_ world: RunnerWorld) -> Bool {
        guard world.stats.has(.fireball) else { return false }
        let charged = world.stats.has(.chargedFireball) && world.phase == .boss && world.boss?.requiresCharged == true
        let hold = charged ? world.tuning.chargeTime + 0.1 : 0.1
        let period = hold + (charged ? 0.15 : 0.3)
        return world.time.truncatingRemainder(dividingBy: period) < hold
    }

    static func survives(_ start: RunnerWorld, plan: BotPlan?, horizon: Double, dt: Double) -> Bool {
        var world = start
        var elapsed = 0.0
        var horizon = horizon
        var landed = false
        while elapsed < horizon {
            let fire = fireHeld(world)
            let input = plan?.input(elapsed: elapsed, dt: dt, fireHeld: fire) ?? Input(fireHeld: fire)
            for event in world.step(input, dt: dt) {
                switch event {
                case .heroHit, .heroDied: return false
                default: break
                }
            }
            if world.phase == .victory || world.isOver { return true }
            elapsed += dt
            // A jump only has to get the hero back on the ground safely; what comes after that is
            // a fresh decision, so stop looking shortly after touchdown.
            if plan != nil, !landed, world.onGround, elapsed > dt * 2 {
                landed = true
                horizon = min(horizon, elapsed + 0.12)
            }
        }
        return true
    }

    public mutating func input(for world: RunnerWorld, dt: Double) -> Input {
        let fire = Self.fireHeld(world)
        if let plan {
            if world.onGround, elapsed > dt {
                self.plan = nil
            } else {
                defer { elapsed += dt }
                return plan.input(elapsed: elapsed, dt: dt, fireHeld: fire)
            }
        }
        guard world.onGround, !Self.survives(world, plan: nil, horizon: 0.45, dt: dt) else {
            return Input(fireHeld: fire)
        }
        var candidates = [BotPlan(hold: 0.4), BotPlan(hold: 0.03)]
        if world.stats.has(.doubleJump) {
            candidates += [BotPlan(hold: 0.4, secondAt: 0.3), BotPlan(hold: 0.4, secondAt: 0.45)]
        }
        guard let chosen = candidates.first(where: { Self.survives(world, plan: $0, horizon: 1.3, dt: dt) }) else {
            return Input(fireHeld: fire)
        }
        plan = chosen
        elapsed = dt
        return chosen.input(elapsed: 0, dt: dt, fireHeld: fire)
    }
}

public struct ValidationReport: Sendable, Equatable {
    public var problems: [String] = []
    /// Seconds of game time the bot needed; nil if it never finished.
    public var clearTime: Double?
    public var isValid: Bool { problems.isEmpty }
}

public enum LevelValidator {
    /// Static checks plus a no-hit bot run (the bot plays with a single heart).
    public static func validate(_ level: LevelDefinition, bosses: [String: BossDefinition],
                                tuning: Tuning = Tuning()) -> ValidationReport {
        var report = ValidationReport()
        let sorted = level.items.sorted { $0.at < $1.at }

        if level.speed <= 0 { report.problems.append("speed must be positive") }
        if level.length < 400 { report.problems.append("length must be at least 400") }
        if !(1...Progression.maxLevel).contains(level.entryHeroLevel) {
            report.problems.append("entryHeroLevel \(level.entryHeroLevel) is out of range")
        }
        let shrineAt = sorted.first { $0.kind == .shrine }?.at
        if shrineAt != nil, level.shrineLevel == nil {
            report.problems.append("a shrine is placed but shrineLevel is not set")
        }
        for item in sorted {
            if item.at < 150 { report.problems.append("\(item.kind.rawValue) at \(Int(item.at)) is inside the 150-unit start runway") }
            if item.at > level.length - 60 { report.problems.append("\(item.kind.rawValue) at \(Int(item.at)) is too close to the boss (length \(Int(level.length)))") }
            var guaranteed = level.entryHeroLevel
            if let shrineAt, let shrineLevel = level.shrineLevel, item.at > shrineAt { guaranteed = max(guaranteed, shrineLevel) }
            if item.kind.spec.minHeroLevel > guaranteed {
                report.problems.append("\(item.kind.rawValue) at \(Int(item.at)) needs hero level \(item.kind.spec.minHeroLevel), only \(guaranteed) is guaranteed there")
            }
        }

        report.problems += ravineProblems(in: level, items: sorted, tuning: tuning)

        let boss = bosses[level.boss]
        if let boss {
            report.problems += problems(in: boss)
        } else {
            report.problems.append("boss '\(level.boss)' is not defined")
        }
        guard report.problems.isEmpty else { return report }

        let run = botRun(level, boss: boss, tuning: tuning)
        if run.finished {
            report.clearTime = run.time
        } else {
            report.problems.append("no-hit bot failed at distance \(Int(run.distance)) (\(run.phase))")
        }
        return report
    }

    /// Ground left between two ravines: room for the widest walker to turn around on.
    static let minimumLedge = 40.0
    /// Share of a full jump's reach a ravine may span, so clearing it does not need a perfect take-off.
    static let ravineJumpShare = 0.65

    static func ravineProblems(in level: LevelDefinition, items: [PlacedItem], tuning: Tuning) -> [String] {
        var problems: [String] = []
        let ravines = (level.ravines ?? []).sorted { $0.at < $1.at }
        let reach = 2 * tuning.jumpVelocity / tuning.gravity * level.speed
        let widest = (reach * ravineJumpShare).rounded(.down)
        for (index, ravine) in ravines.enumerated() {
            let name = "ravine at \(Int(ravine.at))"
            if ravine.at < 150 { problems.append("\(name) is inside the 150-unit start runway") }
            if ravine.end > level.length - 60 { problems.append("\(name) is too close to the boss (length \(Int(level.length)))") }
            if ravine.width < 16 || ravine.width > widest {
                problems.append("\(name) is \(Int(ravine.width)) wide; it must be between 16 and \(Int(widest)) at speed \(Int(level.speed))")
            }
            if index > 0, ravine.at - ravines[index - 1].end < minimumLedge {
                problems.append("\(name) is too close to the one before it (leave \(Int(minimumLedge)) of ground)")
            }
            for item in items where item.y == nil && item.kind.spec.baseY == 0 {
                let half = item.kind.spec.width / 2
                if item.at + half > ravine.at, item.at - half < ravine.end {
                    problems.append("\(item.kind.rawValue) at \(Int(item.at)) stands in the \(name)")
                }
            }
        }
        return problems
    }

    public static func problems(in boss: BossDefinition) -> [String] {
        var problems: [String] = []
        let names = Set(boss.attacks.map(\.name))
        if boss.hp <= 0 { problems.append("boss \(boss.id): hp must be positive") }
        if boss.phases.isEmpty { problems.append("boss \(boss.id): no phases") }
        if boss.phases.first?.startsBelow != 1 { problems.append("boss \(boss.id): first phase must have startsBelow 1") }
        for (index, phase) in boss.phases.enumerated() {
            if phase.attacks.isEmpty { problems.append("boss \(boss.id): phase \(index) has no attacks") }
            for name in phase.attacks where !names.contains(name) {
                problems.append("boss \(boss.id): phase \(index) uses unknown attack '\(name)'")
            }
        }
        return problems
    }

    static func botRun(_ level: LevelDefinition, boss: BossDefinition?, tuning: Tuning = Tuning(),
                       dt: Double = 1.0 / 60) -> (finished: Bool, time: Double, distance: Double, phase: Phase) {
        let stats = HeroStats(xp: Progression.xp(forLevel: level.entryHeroLevel), maxHearts: 1)
        var world = RunnerWorld(level: level, boss: boss, stats: stats, tuning: tuning)
        var bot = Bot()
        let limit = level.length / max(level.speed, 1) + 240
        while !world.isOver, world.time < limit {
            _ = world.step(bot.input(for: world, dt: dt), dt: dt)
        }
        return (world.phase == .won, world.time, world.distance, world.phase)
    }
}
