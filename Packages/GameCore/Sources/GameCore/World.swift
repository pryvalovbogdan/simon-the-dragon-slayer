import Foundation

public struct Tuning: Sendable, Equatable {
    public var gravity = 900.0
    public var jumpVelocity = 300.0
    /// Upward speed is multiplied by this when the jump button is released early.
    public var jumpCut = 0.45
    public var doubleJumpScale = 0.9
    /// A jump pressed this long before landing still triggers.
    public var jumpBuffer = 0.1
    public var heroWidth = 14.0
    public var heroHeight = 32.0
    /// Fireball speed relative to the hero.
    public var fireballSpeed = 260.0
    public var fireCooldown = 0.35
    /// Hold time that turns a fireball into a charged one.
    public var chargeTime = 0.45
    public var invulnerability = 1.2
    public var stompBounce = 220.0
    public var spawnAhead = 420.0
    public var despawnBehind = 140.0
    public var projectileRange = 330.0
    /// Boss position ahead of the hero. The app uses `wideBossOffset` on a wide (landscape) screen
    /// and `narrowBossOffset` on a narrow (portrait) one, where less of the level fits on screen.
    public var bossOffset = Tuning.wideBossOffset
    public static let wideBossOffset = 210.0
    public static let narrowBossOffset = 170.0
    public var bossIntro = 1.5
    public var victoryDelay = 2.0
    public var archerInterval = 1.8
    public var archerRange = 300.0
    public var arrowSpeed = 90.0

    public init() {}
}

public struct Entity: Sendable, Equatable, Identifiable {
    public let id: Int
    public let kind: ItemKind
    public var x: Double
    public var y: Double
    public var hp: Int
    /// Walking away from the hero, after turning back at a ravine.
    public var reversed = false
    var timer = 0.6

    public var box: AABB {
        let spec = kind.spec
        return AABB(centerX: x, bottom: y, width: spec.width, height: spec.height)
    }
}

public struct Projectile: Sendable, Equatable, Identifiable {
    public let id: Int
    public var x: Double
    public var y: Double
    public var vx: Double
    public let charged: Bool

    public var size: Double { charged ? 14 : 8 }
    public var damage: Int { charged ? 3 : 1 }
    public var box: AABB { AABB(centerX: x, bottom: y, width: size, height: size) }
}

public struct Hazard: Sendable, Equatable, Identifiable {
    public let id: Int
    public let kind: String
    public var x: Double
    public var y: Double
    public let width: Double
    public let height: Double
    public var vx: Double
    /// Seconds left as a harmless warning.
    public var arm: Double

    public var isArmed: Bool { arm <= 0 }
    public var box: AABB { AABB(centerX: x, bottom: y, width: width, height: height) }
}

public struct Input: Sendable, Equatable {
    /// True only on the frame the jump touch began.
    public var jumpPressed = false
    public var jumpHeld = false
    public var fireHeld = false

    public init(jumpPressed: Bool = false, jumpHeld: Bool = false, fireHeld: Bool = false) {
        self.jumpPressed = jumpPressed
        self.jumpHeld = jumpHeld
        self.fireHeld = fireHeld
    }
}

public enum Phase: Sendable, Equatable {
    case running, boss, victory, won, dead
}

public enum GameEvent: Sendable, Equatable {
    case jumped(double: Bool)
    case landed
    case heroHit(heartsLeft: Int)
    case heroDied
    /// The hero dropped into a ravine; `heroDied` follows.
    case heroFell
    case stomped(id: Int)
    case enemyHit(id: Int)
    case enemyDefeated(id: Int, kind: ItemKind)
    case coin(id: Int)
    case shrine
    case leveledUp(level: Int, ability: Ability?)
    case fired(id: Int, charged: Bool)
    case fireballGone(id: Int, hit: Bool)
    case bossAppeared(id: String)
    case bossTelegraph(attack: String)
    case bossAttack(attack: String)
    case bossHit(hp: Int)
    case bossBlocked
    case bossDefeated
    case levelComplete
}

/// The whole game simulation for one level. A value type with no randomness, so a copy can be
/// stepped forward to look into the future — the validator bot relies on that.
public struct RunnerWorld: Sendable {
    public let level: LevelDefinition
    public let boss: BossDefinition?
    /// The level's ravines in order. Like items, any that reach the boss arena are left out.
    public let ravines: [Ravine]
    public private(set) var tuning: Tuning

    public private(set) var time = 0.0
    /// Hero's world x; the level scrolls by increasing this.
    public private(set) var distance = 0.0
    public private(set) var heroY = 0.0
    public private(set) var heroVY = 0.0
    public private(set) var onGround = true
    public private(set) var stats: HeroStats
    public private(set) var phase = Phase.running
    public private(set) var entities: [Entity] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var hazards: [Hazard] = []
    public private(set) var bossState: BossState?
    /// Seconds of hit immunity left.
    public private(set) var invulnerable = 0.0
    /// Seconds the fire button has been held.
    public private(set) var charge = 0.0
    public private(set) var score = 0

    private var nextItem = 0
    private var nextID = 1
    private var jumpsUsed = 0
    private var jumpCutDone = false
    private var jumpBuffer = 0.0
    private var fireCooldown = 0.0
    private var wasFireHeld = false
    private var phaseTimer = 0.0
    private let attacks: [String: BossAttack]

    public init(level: LevelDefinition, boss: BossDefinition?, stats: HeroStats = HeroStats(),
                tuning: Tuning = Tuning()) {
        var sorted = level
        sorted.items.sort { $0.at < $1.at }
        self.level = sorted
        ravines = (level.ravines ?? []).filter { $0.end < level.length }.sorted { $0.at < $1.at }
        self.boss = boss
        self.stats = stats
        self.tuning = tuning
        var table: [String: BossAttack] = [:]
        for var attack in boss?.attacks ?? [] {
            attack.hazards.sort { $0.delay < $1.delay }
            attack.summons?.sort { $0.delay < $1.delay }
            table[attack.name] = attack
        }
        attacks = table
    }

    public var heroBox: AABB {
        AABB(centerX: distance, bottom: heroY, width: tuning.heroWidth, height: tuning.heroHeight)
    }

    /// Moves the boss nearer or farther to suit the screen. Safe at any time: the boss is re-placed
    /// from this value on every step.
    public mutating func setBossOffset(_ offset: Double) {
        tuning.bossOffset = offset
    }

    public var isCharged: Bool { stats.has(.chargedFireball) && charge >= tuning.chargeTime }
    public var isOver: Bool { phase == .won || phase == .dead }

    // MARK: - Step

    public mutating func step(_ input: Input, dt: Double) -> [GameEvent] {
        var events: [GameEvent] = []
        guard !isOver else { return events }

        time += dt
        distance += level.speed * dt
        invulnerable = max(0, invulnerable - dt)
        fireCooldown = max(0, fireCooldown - dt)

        let previousBottom = heroY
        moveHero(input, dt: dt, events: &events)
        fire(input, dt: dt, events: &events)
        spawnItems()
        moveEntities(dt: dt)
        updateBoss(dt: dt, events: &events)
        moveHazards(dt: dt)
        moveProjectiles(dt: dt, events: &events)
        if phase == .running || phase == .boss {
            collideHero(previousBottom: previousBottom, events: &events)
        }
        cleanUp()

        if phase == .victory {
            phaseTimer -= dt
            if phaseTimer <= 0 {
                phase = .won
                events.append(.levelComplete)
            }
        }
        return events
    }

    // MARK: - Hero

    private mutating func moveHero(_ input: Input, dt: Double, events: inout [GameEvent]) {
        jumpBuffer = input.jumpPressed ? tuning.jumpBuffer : max(0, jumpBuffer - dt)

        let overRavine = ravines.contains { $0.isOpen(at: distance) }
        if onGround, overRavine {
            // Ran off the rim: nothing to push off from, so no jump can save this.
            onGround = false
            jumpsUsed = 2
        }

        if jumpBuffer > 0 {
            if onGround {
                heroVY = tuning.jumpVelocity
                onGround = false
                jumpsUsed = 1
                jumpCutDone = false
                jumpBuffer = 0
                events.append(.jumped(double: false))
            } else if input.jumpPressed, jumpsUsed < 2, stats.has(.doubleJump) {
                heroVY = tuning.jumpVelocity * tuning.doubleJumpScale
                jumpsUsed = 2
                jumpCutDone = false
                jumpBuffer = 0
                events.append(.jumped(double: true))
            }
        }

        guard !onGround else { return }
        if !input.jumpHeld, heroVY > 0, !jumpCutDone {
            heroVY *= tuning.jumpCut
            jumpCutDone = true
        }
        heroVY -= tuning.gravity * dt
        heroY += heroVY * dt
        guard heroY <= 0 else { return }
        if !overRavine {
            heroY = 0
            heroVY = 0
            onGround = true
            jumpsUsed = 0
            events.append(.landed)
        } else if heroY < 0, phase != .dead {
            // Below the rim there is no way back, whatever hearts are left.
            stats.hearts = 0
            phase = .dead
            events += [.heroFell, .heroDied]
        }
    }

    private mutating func fire(_ input: Input, dt: Double, events: inout [GameEvent]) {
        defer { wasFireHeld = input.fireHeld }
        guard stats.has(.fireball), phase == .running || phase == .boss else {
            charge = 0
            return
        }
        let canCharge = stats.has(.chargedFireball)
        if input.fireHeld {
            // Without the charge ability a tap fires at once; with it the shot waits for release.
            if !wasFireHeld, !canCharge { launch(charged: false, events: &events) }
            charge += dt
        } else {
            if wasFireHeld, canCharge { launch(charged: charge >= tuning.chargeTime, events: &events) }
            charge = 0
        }
    }

    private mutating func launch(charged: Bool, events: inout [GameEvent]) {
        guard fireCooldown <= 0 else { return }
        fireCooldown = tuning.fireCooldown
        let shot = Projectile(id: takeID(), x: distance + 20, y: heroY + (charged ? 9 : 12),
                              vx: level.speed + tuning.fireballSpeed, charged: charged)
        projectiles.append(shot)
        events.append(.fired(id: shot.id, charged: charged))
    }

    // MARK: - World

    private mutating func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private mutating func spawnItems() {
        guard phase == .running else { return }
        while nextItem < level.items.count {
            let item = level.items[nextItem]
            guard item.at < level.length else {
                nextItem = level.items.count
                break
            }
            guard item.at <= distance + tuning.spawnAhead else { break }
            let spec = item.kind.spec
            entities.append(Entity(id: takeID(), kind: item.kind, x: item.at, y: item.y ?? spec.baseY, hp: spec.hp))
            nextItem += 1
        }
    }

    private mutating func moveEntities(dt: Double) {
        for index in entities.indices {
            let spec = entities[index].kind.spec
            let velocity = entities[index].reversed ? -spec.velocity : spec.velocity
            entities[index].x += velocity * dt
            if entities[index].kind.walks {
                // Stop at the rim and head back the other way.
                let front = entities[index].x + (velocity < 0 ? -spec.width : spec.width) / 2
                if let ravine = ravines.first(where: { $0.isOpen(at: front) }) {
                    entities[index].x = velocity < 0 ? ravine.end + spec.width / 2 : ravine.at - spec.width / 2
                    entities[index].reversed.toggle()
                }
            }
            if entities[index].kind == .ghost {
                entities[index].y = GhostFlight.height(gap: entities[index].x - distance)
            }
            guard entities[index].kind == .archer else { continue }
            let gap = entities[index].x - distance
            guard gap > 30, gap < tuning.archerRange else { continue }
            entities[index].timer -= dt
            if entities[index].timer <= 0 {
                entities[index].timer = tuning.archerInterval
                hazards.append(Hazard(id: takeID(), kind: "arrow", x: entities[index].x - 10, y: 8,
                                      width: 10, height: 3, vx: -tuning.arrowSpeed, arm: 0))
            }
        }
    }

    private mutating func moveHazards(dt: Double) {
        for index in hazards.indices {
            hazards[index].x += hazards[index].vx * dt
            hazards[index].arm = max(0, hazards[index].arm - dt)
        }
    }

    private mutating func moveProjectiles(dt: Double, events: inout [GameEvent]) {
        var kept: [Projectile] = []
        for var shot in projectiles {
            shot.x += shot.vx * dt
            if hit(with: shot, events: &events) {
                events.append(.fireballGone(id: shot.id, hit: true))
            } else if shot.x > distance + tuning.projectileRange {
                events.append(.fireballGone(id: shot.id, hit: false))
            } else {
                kept.append(shot)
            }
        }
        projectiles = kept
    }

    /// Returns true when the shot is used up.
    private mutating func hit(with shot: Projectile, events: inout [GameEvent]) -> Bool {
        let box = shot.box
        if let index = entities.firstIndex(where: { $0.hp > 0 && $0.kind.spec.burnable && $0.box.intersects(box) }) {
            damage(entityAt: index, by: shot.damage, events: &events)
            return true
        }
        guard phase == .boss, var state = bossState, let boss, state.action != .intro, state.action != .dead,
              state.box.intersects(box) else { return false }
        let open = boss.vulnerable == .always || state.action == .recover
        if open, shot.charged || !boss.requiresCharged {
            state.hp = max(0, state.hp - shot.damage)
            bossState = state
            events.append(.bossHit(hp: state.hp))
            if state.hp == 0 { defeatBoss(events: &events) }
        } else {
            events.append(.bossBlocked)
        }
        return true
    }

    private mutating func damage(entityAt index: Int, by amount: Int, events: inout [GameEvent]) {
        entities[index].hp -= amount
        let entity = entities[index]
        if entity.hp > 0 {
            events.append(.enemyHit(id: entity.id))
        } else {
            events.append(.enemyDefeated(id: entity.id, kind: entity.kind))
            award(xp: entity.kind.spec.xp, events: &events)
        }
    }

    private mutating func award(xp: Int, events: inout [GameEvent]) {
        score += xp
        announce(stats.gain(xp: xp), events: &events)
    }

    private func announce(_ levels: [Int], events: inout [GameEvent]) {
        for level in levels {
            events.append(.leveledUp(level: level, ability: Progression.ability(unlockedAt: level)))
        }
    }

    private mutating func collideHero(previousBottom: Double, events: inout [GameEvent]) {
        let hero = heroBox
        for index in entities.indices where entities[index].hp > 0 && entities[index].box.intersects(hero) {
            let entity = entities[index]
            let spec = entity.kind.spec
            switch entity.kind {
            case .coin:
                entities[index].hp = 0
                events.append(.coin(id: entity.id))
                award(xp: spec.xp, events: &events)
            case .shrine:
                entities[index].hp = 0
                events.append(.shrine)
                if let target = level.shrineLevel { announce(stats.raise(toLevel: target), events: &events) }
            default:
                let fromAbove = heroVY < 0 && previousBottom >= entity.box.maxY - 4
                if spec.stompable, fromAbove {
                    events.append(.stomped(id: entity.id))
                    // For most it is only a bounce; the ones it kills pay out like a burn.
                    if spec.stompKills { damage(entityAt: index, by: entity.hp, events: &events) }
                    heroVY = tuning.stompBounce
                    jumpsUsed = 1
                    jumpCutDone = true
                } else if spec.hurtsOnTouch {
                    hurt(events: &events)
                }
            }
        }
        for hazard in hazards where hazard.isArmed && hazard.box.intersects(hero) {
            hurt(events: &events)
        }
    }

    private mutating func hurt(events: inout [GameEvent]) {
        guard invulnerable <= 0, phase == .running || phase == .boss else { return }
        stats.hearts -= 1
        invulnerable = tuning.invulnerability
        if stats.hearts <= 0 {
            stats.hearts = 0
            phase = .dead
            events.append(.heroDied)
        } else {
            events.append(.heroHit(heartsLeft: stats.hearts))
        }
    }

    private mutating func cleanUp() {
        let left = distance - tuning.despawnBehind
        entities.removeAll { $0.hp <= 0 || $0.x < left }
        hazards.removeAll { $0.x < left }
    }

    // MARK: - Boss

    private mutating func updateBoss(dt: Double, events: inout [GameEvent]) {
        if phase == .running, distance >= level.length {
            guard let boss else {
                win(events: &events)
                return
            }
            phase = .boss
            bossState = BossState(id: boss.id, hp: boss.hp, maxHP: boss.hp, x: distance + tuning.bossOffset,
                                  y: boss.baseY, width: boss.width, height: boss.height)
            events.append(.bossAppeared(id: boss.id))
        }
        guard var state = bossState, let boss else { return }
        state.x = distance + tuning.bossOffset
        defer { if bossState != nil, bossState?.action != .dead { bossState = state } }
        guard phase == .boss else {
            bossState = state
            return
        }
        state.actionTime += dt

        switch state.action {
        case .intro:
            if state.actionTime >= tuning.bossIntro { startAttack(&state, boss: boss, events: &events) }
        case .telegraph:
            if state.actionTime >= (attacks[state.attackName]?.telegraph ?? 0) {
                state.action = .attack
                state.actionTime = 0
                events.append(.bossAttack(attack: state.attackName))
            }
        case .attack:
            guard let attack = attacks[state.attackName] else {
                state.action = .recover
                state.actionTime = 0
                break
            }
            while state.spawnedHazards < attack.hazards.count,
                  attack.hazards[state.spawnedHazards].delay <= state.actionTime {
                let spec = attack.hazards[state.spawnedHazards]
                let x = spec.ahead.map { distance + $0 } ?? state.x - state.width / 2
                hazards.append(Hazard(id: takeID(), kind: spec.kind, x: x, y: spec.y, width: spec.width,
                                      height: spec.height, vx: level.speed - spec.closingSpeed, arm: spec.arm ?? 0))
                state.spawnedHazards += 1
            }
            let summons = attack.summons ?? []
            while state.spawnedSummons < summons.count, summons[state.spawnedSummons].delay <= state.actionTime {
                let kind = summons[state.spawnedSummons].kind
                entities.append(Entity(id: takeID(), kind: kind, x: state.x - state.width / 2 - 10,
                                       y: kind.spec.baseY, hp: kind.spec.hp))
                state.spawnedSummons += 1
            }
            if state.actionTime >= attack.duration {
                state.action = .recover
                state.actionTime = 0
            }
        case .recover:
            if state.actionTime >= (attacks[state.attackName]?.recover ?? 0.5) {
                startAttack(&state, boss: boss, events: &events)
            }
        case .dead:
            break
        }
    }

    private func startAttack(_ state: inout BossState, boss: BossDefinition, events: inout [GameEvent]) {
        let fraction = state.hpFraction
        let phaseIndex = boss.phases.lastIndex { fraction <= $0.startsBelow } ?? 0
        if phaseIndex != state.phaseIndex {
            state.phaseIndex = phaseIndex
            state.attackCursor = 0
        }
        let names = boss.phases.indices.contains(phaseIndex) ? boss.phases[phaseIndex].attacks : []
        state.attackName = names.isEmpty ? "" : names[state.attackCursor % names.count]
        state.attackCursor += 1
        state.action = .telegraph
        state.actionTime = 0
        state.spawnedHazards = 0
        state.spawnedSummons = 0
        events.append(.bossTelegraph(attack: state.attackName))
    }

    private mutating func defeatBoss(events: inout [GameEvent]) {
        bossState?.action = .dead
        bossState?.actionTime = 0
        hazards.removeAll()
        events.append(.bossDefeated)
        win(events: &events)
    }

    private mutating func win(events: inout [GameEvent]) {
        phase = .victory
        phaseTimer = tuning.victoryDelay
        score += stats.hearts * 50
        announce(stats.raise(toLevel: level.bossRewardLevel), events: &events)
    }
}
