import Testing
@testable import GameCore

@Suite struct BossTests {
    func boss(vulnerable: BossVulnerability = .always, requiresCharged: Bool = false, hp: Int = 3) -> BossDefinition {
        let hazard = HazardSpec(kind: "wave", delay: 0, y: 0, width: 16, height: 10, closingSpeed: 150)
        let slam = BossAttack(name: "slam", telegraph: 0.5, duration: 0.5, recover: 1.0, hazards: [hazard])
        let high = HazardSpec(kind: "blade", delay: 0, y: 42, width: 20, height: 10, closingSpeed: 150)
        let slash = BossAttack(name: "slash", telegraph: 0.5, duration: 0.5, recover: 1.0, hazards: [high])
        return BossDefinition(id: "test_boss", hp: hp, width: 40, height: 60, baseY: 0, vulnerable: vulnerable,
                              requiresCharged: requiresCharged, attacks: [slam, slash],
                              phases: [.init(startsBelow: 1, attacks: ["slam"]), .init(startsBelow: 0.5, attacks: ["slash"])])
    }

    func arena(_ boss: BossDefinition, heroLevel: Int) -> RunnerWorld {
        var world = RunnerWorld(level: flatLevel(length: 100), boss: boss,
                                stats: HeroStats(xp: Progression.xp(forLevel: heroLevel)))
        world.run(1.1)
        return world
    }

    @Test func bossAppearsAtLevelLengthAndCyclesItsAttack() {
        var world = RunnerWorld(level: flatLevel(length: 100), boss: boss(), stats: HeroStats())
        var events = world.run(1.1)
        #expect(events.contains(.bossAppeared(id: "test_boss")))
        #expect(world.phase == .boss)
        events = world.run(2.2, Input())
        #expect(events.contains(.bossTelegraph(attack: "slam")))
        #expect(events.contains(.bossAttack(attack: "slam")))
        #expect(world.hazards.count == 1)
    }

    @Test func lowHazardHurtsUnlessJumped() {
        var standing = arena(boss(), heroLevel: 1)
        #expect(standing.run(5).contains(.heroHit(heartsLeft: 2)))

        var world = arena(boss(), heroLevel: 1)
        var bot = Bot()
        var hit = false
        while world.time < 12 {
            for event in world.step(bot.input(for: world, dt: dt), dt: dt) {
                if case .heroHit = event { hit = true }
            }
        }
        #expect(!hit)
    }

    @Test func fireballsDefeatBossAndGrantReward() {
        var world = arena(boss(hp: 3), heroLevel: 2)
        var bot = Bot()
        var events: [GameEvent] = []
        while !world.isOver, world.time < 30 { events += world.step(bot.input(for: world, dt: dt), dt: dt) }
        #expect(events.contains(.bossDefeated))
        #expect(events.contains(.levelComplete))
        #expect(world.phase == .won)
    }

    @Test func secondPhaseSwitchesAttack() {
        var world = arena(boss(hp: 6), heroLevel: 2)
        var bot = Bot()
        var telegraphs: [String] = []
        while !world.isOver, world.time < 40 {
            for case let .bossTelegraph(attack) in world.step(bot.input(for: world, dt: dt), dt: dt) { telegraphs.append(attack) }
        }
        #expect(telegraphs.first == "slam")
        #expect(telegraphs.contains("slash"))
    }

    @Test func recoverOnlyBossBlocksShotsOutsideTheWindow() {
        var world = arena(boss(vulnerable: .recover, hp: 50), heroLevel: 2)
        var bot = Bot()
        var blocked = 0, hits = 0
        var hitActions: Set<BossAction> = []
        while world.time < 15 {
            for event in world.step(bot.input(for: world, dt: dt), dt: dt) {
                if event == .bossBlocked { blocked += 1 }
                if case .bossHit = event {
                    hits += 1
                    if let action = world.bossState?.action { hitActions.insert(action) }
                }
            }
        }
        #expect(blocked > 0)
        #expect(hits > 0)
        #expect(hitActions == [.recover])
    }

    @Test func chargedOnlyBossIgnoresNormalShots() {
        var world = arena(boss(requiresCharged: true, hp: 50), heroLevel: 2)
        var events: [GameEvent] = []
        for _ in 0..<8 {
            events += world.run(0.05, Input(jumpHeld: false, fireHeld: true))
            events += world.run(0.5)
        }
        #expect(events.contains(.bossBlocked))
        #expect(!events.contains { if case .bossHit = $0 { true } else { false } })
    }
}
