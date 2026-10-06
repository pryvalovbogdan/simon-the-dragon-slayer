import Testing
@testable import GameCore

@Suite struct WorldTests {
    @Test func holdingJumpGoesHigherThanTapping() {
        func apex(held: Bool) -> Double {
            var world = RunnerWorld(level: flatLevel(), boss: nil)
            var top = 0.0
            var input = Input(jumpPressed: true, jumpHeld: held)
            for _ in 0..<90 {
                _ = world.step(input, dt: dt)
                input.jumpPressed = false
                top = max(top, world.heroY)
            }
            #expect(world.onGround)
            return top
        }
        let tap = apex(held: false)
        let hold = apex(held: true)
        #expect(tap > 5)
        #expect(hold > tap * 2)
        #expect(hold > ItemKind.tree.spec.height)
    }

    @Test func doubleJumpNeedsTheAbility() {
        func jumps(level: Int) -> Int {
            var world = RunnerWorld(level: flatLevel(), boss: nil, stats: HeroStats(xp: Progression.xp(forLevel: level)))
            var events = world.run(0.3, Input(jumpPressed: true, jumpHeld: true))
            events += world.run(0.2, Input(jumpPressed: true, jumpHeld: true))
            return events.filter { if case .jumped = $0 { true } else { false } }.count
        }
        #expect(jumps(level: 2) == 1)
        #expect(jumps(level: 3) == 2)
    }

    @Test func runningIntoATreeCostsAHeartThenGrantsImmunity() {
        var world = RunnerWorld(level: flatLevel(items: [.init(at: 200, kind: .tree), .init(at: 230, kind: .tree)]), boss: nil)
        let events = world.run(2.6)
        #expect(events.filter { $0 == .heroHit(heartsLeft: 2) }.count == 1)
        #expect(world.stats.hearts == 2)
    }

    @Test func threeHitsKill() {
        let trees = [200.0, 400, 600].map { PlacedItem(at: $0, kind: .tree) }
        var world = RunnerWorld(level: flatLevel(items: trees), boss: nil)
        let events = world.run(10)
        #expect(events.contains(.heroDied))
        #expect(world.phase == .dead)
        #expect(world.isOver)
    }

    /// Jumps at whichever take-off gap brings the hero down on top of the enemy.
    private func stomp(_ kind: ItemKind) -> (world: RunnerWorld, events: [GameEvent])? {
        for takeOff in stride(from: 20.0, to: 140, by: 4) {
            var world = RunnerWorld(level: flatLevel(items: [.init(at: 300, kind: kind)]), boss: nil)
            var events: [GameEvent] = []
            var jumped = false
            while world.time < 3.5 {
                let gap = (world.entities.first?.x ?? 1000) - world.distance
                let jump = !jumped && gap < takeOff
                jumped = jumped || jump
                events += world.step(Input(jumpPressed: jump, jumpHeld: true), dt: dt)
            }
            if events.contains(where: { if case .stomped = $0 { true } else { false } }) { return (world, events) }
        }
        return nil
    }

    @Test(arguments: [ItemKind.goblin, .wolf, .skeleton])
    func landingOnItKillsItForItsXP(kind: ItemKind) throws {
        let (world, events) = try #require(stomp(kind))
        #expect(events.contains(.enemyDefeated(id: 1, kind: kind)))
        // One landing is enough, however much health it had.
        #expect(!events.contains { if case .enemyHit = $0 { true } else { false } })
        #expect(world.stats.xp == kind.spec.xp)
        #expect(world.score == kind.spec.xp)
        #expect(world.stats.hearts == 3)
    }

    @Test func theHeroBouncesOffAStompedEnemy() {
        var world = RunnerWorld(level: flatLevel(items: [.init(at: 200, kind: .goblin)]), boss: nil)
        var bouncedUp = false
        // Jump late enough to come down on its head: goblin closes at 120 u/s, jump lasts 0.67 s.
        while world.time < 3 {
            let gap = (world.entities.first?.x ?? 1000) - world.distance
            let jump = world.onGround && gap < 62 && gap > 50
            let step = world.step(Input(jumpPressed: jump, jumpHeld: true), dt: dt)
            if step.contains(where: { if case .stomped = $0 { true } else { false } }) { bouncedUp = world.heroVY > 0 }
        }
        #expect(bouncedUp)
    }

    @Test(arguments: [ItemKind.hound, .archer])
    func landingOnItOnlyBounces(kind: ItemKind) throws {
        let (world, events) = try #require(stomp(kind))
        #expect(!events.contains { if case .enemyDefeated = $0 { true } else { false } })
        #expect(world.stats.xp == 0)
    }

    @Test func fireballNeedsLevelTwoAndBurnsEnemies() {
        let level = flatLevel(items: [.init(at: 260, kind: .goblin)])
        var novice = RunnerWorld(level: level, boss: nil)
        #expect(novice.run(0.5, Input(fireHeld: true)).isEmpty)

        var mage = RunnerWorld(level: level, boss: nil, stats: HeroStats(xp: 100))
        let events = mage.run(0.1, Input(fireHeld: true)) + mage.run(1.5)
        #expect(events.contains { if case .fired(_, charged: false) = $0 { true } else { false } })
        #expect(events.contains { if case .enemyDefeated(_, kind: .goblin) = $0 { true } else { false } })
    }

    @Test func giantTakesThreeFireballs() {
        var world = RunnerWorld(level: flatLevel(items: [.init(at: 380, kind: .giant)]), boss: nil, stats: HeroStats(xp: 100))
        var events: [GameEvent] = []
        for _ in 0..<3 {
            events += world.run(0.05, Input(fireHeld: true))
            events += world.run(0.45)
        }
        events += world.run(0.6)
        #expect(events.filter { if case .enemyHit = $0 { true } else { false } }.count == 2)
        #expect(events.contains { if case .enemyDefeated(_, kind: .giant) = $0 { true } else { false } })
        #expect(world.stats.hearts == 3)
    }

    @Test func chargedShotOnlyAfterHoldingLongEnough() {
        func shot(hold: Double) -> Bool? {
            var world = RunnerWorld(level: flatLevel(), boss: nil, stats: HeroStats(xp: 600))
            let events = world.run(hold, Input(fireHeld: true)) + world.run(0.05)
            for case let .fired(_, charged) in events { return charged }
            return nil
        }
        #expect(shot(hold: 0.1) == false)
        #expect(shot(hold: 0.6) == true)
    }

    @Test(arguments: [ItemKind.tree, .thorns])
    func fireballsPassThroughPlantsWithoutDestroyingThem(kind: ItemKind) {
        // A goblin stands behind the plant: the shot must leave the plant alone and still reach it.
        let level = flatLevel(items: [.init(at: 300, kind: kind), .init(at: 345, kind: .goblin)])
        var mage = RunnerWorld(level: level, boss: nil, stats: HeroStats(xp: 100))
        let events = mage.run(0.05, Input(fireHeld: true)) + mage.run(0.9)
        #expect(events.contains { if case .enemyDefeated(_, kind: .goblin) = $0 { true } else { false } })
        #expect(!events.contains { if case .enemyDefeated(_, kind: kind) = $0 { true } else { false } })
        #expect(mage.entities.contains { $0.kind == kind })
        // And it still hurts to run into.
        #expect((mage.run(4)).contains(.heroHit(heartsLeft: 2)))
    }

    @Test func skeletonHurtsFromTheSideAndTakesTwoFireballs() {
        var walker = RunnerWorld(level: flatLevel(items: [.init(at: 200, kind: .skeleton)]), boss: nil)
        var events = walker.run(3)
        #expect(events.contains(.heroHit(heartsLeft: 2)))
        #expect(walker.stats.xp == 0)

        var mage = RunnerWorld(level: flatLevel(items: [.init(at: 380, kind: .skeleton)]), boss: nil, stats: HeroStats(xp: 100))
        events = []
        for _ in 0..<2 {
            events += mage.run(0.05, Input(fireHeld: true))
            events += mage.run(0.45)
        }
        events += mage.run(1)
        #expect(events.filter { if case .enemyHit = $0 { true } else { false } }.count == 1)
        #expect(events.contains { if case .enemyDefeated(_, kind: .skeleton) = $0 { true } else { false } })
    }

    @Test func ghostIgnoresFireAndSwoopsDownWhenClose() {
        #expect(GhostFlight.height(gap: 400) == GhostFlight.high)
        #expect(GhostFlight.height(gap: 20) == GhostFlight.low)
        #expect(GhostFlight.height(gap: 115) < GhostFlight.high)
        #expect(GhostFlight.height(gap: 115) > GhostFlight.low)

        var world = RunnerWorld(level: flatLevel(items: [.init(at: 400, kind: .ghost)]), boss: nil, stats: HeroStats(xp: 100))
        #expect(world.run(0.5).isEmpty)
        #expect(world.entities.first?.y == GhostFlight.high)
        // Standing still under it is not safe: by the time it arrives it is on the ground.
        var events: [GameEvent] = []
        for _ in 0..<8 {
            events += world.run(0.05, Input(fireHeld: true))
            events += world.run(0.4)
        }
        #expect(!events.contains { if case .enemyDefeated = $0 { true } else { false } })
        #expect(events.contains(.heroHit(heartsLeft: 2)))
    }

    @Test func wolfIsFasterThanAGoblinAndCanBeStomped() {
        #expect(ItemKind.wolf.spec.velocity < ItemKind.goblin.spec.velocity)
        var world = RunnerWorld(level: flatLevel(items: [.init(at: 200, kind: .wolf)]), boss: nil)
        var events: [GameEvent] = []
        var bot = Bot()
        while world.time < 3 { events += world.step(bot.input(for: world, dt: dt), dt: dt) }
        #expect(world.stats.hearts == 3)
    }

    @Test func coinsAndShrineLevelTheHeroUp() {
        let items = [PlacedItem(at: 200, kind: .coin, y: 0), PlacedItem(at: 300, kind: .shrine)]
        var world = RunnerWorld(level: flatLevel(items: items, shrine: 2), boss: nil)
        let events = world.run(3.5)
        #expect(events.contains { if case .coin = $0 { true } else { false } })
        #expect(events.contains(.shrine))
        #expect(events.contains(.leveledUp(level: 2, ability: .fireball)))
        #expect(world.stats.has(.fireball))
        #expect(world.stats.hearts == 3)
    }

    @Test func levelWithoutBossEndsAtItsLength() {
        var world = RunnerWorld(level: flatLevel(length: 400, reward: 3), boss: nil)
        let events = world.run(10)
        #expect(events.contains(.levelComplete))
        #expect(world.phase == .won)
        #expect(world.stats.level == 3)
    }

    // MARK: - Ravines

    @Test func runningIntoARavineEndsTheRunWhateverHeartsAreLeft() {
        var world = RunnerWorld(level: flatLevel(ravines: [Ravine(at: 200, width: 40)]), boss: nil)
        let events = world.run(3)
        #expect(events.contains(.heroFell))
        #expect(events.contains(.heroDied))
        #expect(world.phase == .dead)
        #expect(world.stats.hearts == 0)
        #expect(world.distance > 200 && world.distance < 240)
        #expect(world.heroY < 0)
    }

    @Test func aJumpClearsARavine() {
        var world = RunnerWorld(level: flatLevel(ravines: [Ravine(at: 200, width: 40)]), boss: nil)
        world.run(1.9)
        let events = world.run(1.5, Input(jumpPressed: true, jumpHeld: true))
        #expect(!events.contains(.heroFell))
        #expect(events.contains(.landed))
        #expect(world.onGround)
        #expect(world.distance > 240)
        #expect(world.stats.hearts == 3)
    }

    @Test func aJumpThatComesDownOverARavineFalls() {
        var world = RunnerWorld(level: flatLevel(ravines: [Ravine(at: 200, width: 40)]), boss: nil)
        // A full jump covers about 67 units at speed 100; from 150 it comes down at 217.
        world.run(1.5)
        let events = world.run(1.5, Input(jumpPressed: true, jumpHeld: true))
        #expect(events.contains(.heroFell))
        #expect(!events.contains(.landed))
    }

    @Test func theHeroStandsUntilTheirCentreIsPastTheRim() {
        var world = RunnerWorld(level: flatLevel(ravines: [Ravine(at: 200, width: 40)]), boss: nil)
        while world.distance < 199 { _ = world.step(Input(), dt: dt) }
        // The front half of the hitbox already hangs over the gap.
        #expect(world.heroBox.maxX > 200)
        #expect(world.onGround)
        #expect(!world.isOver)
    }

    @Test func noJumpingBackOutOfARavine() {
        var world = RunnerWorld(level: flatLevel(ravines: [Ravine(at: 200, width: 40)], entry: 3), boss: nil,
                                stats: HeroStats(xp: Progression.xp(forLevel: 3)))
        while !world.isOver, world.time < 5 {
            _ = world.step(Input(jumpPressed: world.distance > 201, jumpHeld: true), dt: dt)
        }
        #expect(world.phase == .dead)
    }

    @Test func aWalkerTurnsAroundAtARavine() throws {
        let level = flatLevel(items: [.init(at: 260, kind: .goblin)], ravines: [Ravine(at: 200, width: 40)])
        var world = RunnerWorld(level: level, boss: nil)
        var leftmost = 1000.0
        var turnedAt: Double?
        while world.time < 1.8 {
            _ = world.step(Input(), dt: dt)
            guard let goblin = world.entities.first else { continue }
            leftmost = min(leftmost, goblin.box.minX)
            if goblin.reversed, turnedAt == nil { turnedAt = goblin.x }
        }
        // It never steps over the rim at 240, and after turning it walks away from it.
        #expect(leftmost >= 240)
        #expect(leftmost < 241)
        let goblin = try #require(world.entities.first)
        #expect(goblin.reversed)
        #expect(goblin.x > (turnedAt ?? 1000))
    }

    @Test func aWalkerBetweenTwoRavinesPatrols() {
        let level = flatLevel(items: [.init(at: 560, kind: .hound)],
                              ravines: [Ravine(at: 500, width: 40), Ravine(at: 600, width: 40)])
        var world = RunnerWorld(level: level, boss: nil)
        var turns = 0
        var reversed = false
        while world.time < 3.5 {
            _ = world.step(Input(), dt: dt)
            guard let hound = world.entities.first else { continue }
            #expect(hound.box.minX >= 540 && hound.box.maxX <= 600)
            if hound.reversed != reversed {
                reversed = hound.reversed
                turns += 1
            }
        }
        #expect(turns >= 3)
    }

    @Test func flyersAndStaticThingsIgnoreRavines() {
        let level = flatLevel(items: [.init(at: 300, kind: .raven), .init(at: 310, kind: .ghost)],
                              ravines: [Ravine(at: 200, width: 40)])
        var world = RunnerWorld(level: level, boss: nil)
        world.run(1.2)
        #expect(world.entities.count == 2)
        #expect(world.entities.allSatisfy { !$0.reversed })
        #expect(world.entities.contains { $0.kind == .raven && $0.x < 260 })
    }

    @Test func ravinesInTheBossArenaAreIgnored() {
        let level = flatLevel(ravines: [Ravine(at: 380, width: 40)], length: 400, reward: 3)
        var world = RunnerWorld(level: level, boss: nil)
        #expect(world.ravines.isEmpty)
        world.run(10)
        #expect(world.phase == .won)
    }

    @Test func simulationIsDeterministic() throws {
        let level = try Content.level("level_01")
        let boss = try Content.bosses()[level.boss]
        func play() -> (Double, Int, Int) {
            var world = RunnerWorld(level: level, boss: boss)
            var bot = Bot()
            while !world.isOver, world.time < 120 { _ = world.step(bot.input(for: world, dt: dt), dt: dt) }
            return (world.distance, world.stats.xp, world.stats.hearts)
        }
        #expect(play() == play())
    }
}
