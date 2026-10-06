import Foundation
import Testing
@testable import GameCore

@Suite struct EndlessTests {
    @Test func levelsComeInOrderAndThenLoop() {
        var run = EndlessRun(levelCount: 4)
        var order: [Int] = []
        var loops: [Int] = []
        for _ in 0..<9 {
            order.append(run.levelIndex)
            loops.append(run.loop)
            run.clear(stats: HeroStats(), score: 0)
        }
        #expect(order == [0, 1, 2, 3, 0, 1, 2, 3, 0])
        #expect(loops == [1, 1, 1, 1, 2, 2, 2, 2, 3])
        #expect(run.cleared == 9)
    }

    @Test func eachLoopIsFasterUpToTheCap() {
        #expect(EndlessRun.speed(forLoop: 1) == 1)
        #expect(abs(EndlessRun.speed(forLoop: 2) - 1.15) < 1e-9)
        #expect(abs(EndlessRun.speed(forLoop: 3) - 1.3) < 1e-9)
        #expect(EndlessRun.speed(forLoop: 7) < EndlessRun.maxSpeed)
        #expect(EndlessRun.speed(forLoop: 8) == EndlessRun.maxSpeed)
        #expect(EndlessRun.speed(forLoop: 500) == EndlessRun.maxSpeed)

        var run = EndlessRun(levelCount: 2)
        #expect(run.speed == 1)
        #expect(!run.startsNewLoop)
        run.clear(stats: HeroStats(), score: 0)
        #expect(run.speed == 1)
        #expect(!run.startsNewLoop)
        run.clear(stats: HeroStats(), score: 0)
        #expect(abs(run.speed - 1.15) < 1e-9)
        #expect(run.startsNewLoop)
    }

    @Test func heartsCarryOverAndABossGivesOneBack() {
        var run = EndlessRun(levelCount: 4)
        #expect(run.stats.hearts == 3)
        var hurt = HeroStats(xp: 320)
        hurt.hearts = 1
        run.clear(stats: hurt, score: 400)
        #expect(run.stats.hearts == 2)
        #expect(run.stats.xp == 320)
        // Never above the maximum.
        run.clear(stats: HeroStats(xp: 600), score: 100)
        #expect(run.stats.hearts == 3)
        #expect(run.score == 500)
    }

    @Test func theRunEndsWithTheLastLevelsScore() {
        var run = EndlessRun(levelCount: 4)
        run.clear(stats: HeroStats(), score: 300)
        run.end(score: 45)
        #expect(run.isOver)
        #expect(run.score == 345)
        #expect(run.cleared == 1)
        run.clear(stats: HeroStats(), score: 999)
        run.end(score: 999)
        #expect(run.score == 345)
        #expect(run.cleared == 1)
    }

    @Test func medalsFollowHowFarARunGot() {
        #expect(Medal.forEndless(cleared: 0, levelCount: 4) == nil)
        #expect(Medal.forEndless(cleared: 1, levelCount: 4) == .bronze)
        #expect(Medal.forEndless(cleared: 3, levelCount: 4) == .bronze)
        #expect(Medal.forEndless(cleared: 4, levelCount: 4) == .silver)
        #expect(Medal.forEndless(cleared: 7, levelCount: 4) == .silver)
        #expect(Medal.forEndless(cleared: 8, levelCount: 4) == .gold)
        #expect(Medal.forEndless(cleared: 40, levelCount: 4) == .gold)
    }

    @Test func aLevelsMedalFollowsTheHeartsLeft() {
        #expect(Medal.forLevel(won: false, hearts: 3, maxHearts: 3) == nil)
        #expect(Medal.forLevel(won: true, hearts: 3, maxHearts: 3) == .gold)
        #expect(Medal.forLevel(won: true, hearts: 2, maxHearts: 3) == .silver)
        #expect(Medal.forLevel(won: true, hearts: 1, maxHearts: 3) == .bronze)
    }

    @Test func theHeroEntersALevelWithAtLeastWhatItAssumes() {
        let run = EndlessRun(levelCount: 4)
        #expect(run.startingStats(for: flatLevel(entry: 1)).level == 1)
        #expect(run.startingStats(for: flatLevel(entry: 3)).level == 3)
    }

    @Test func endlessProgressOpensLevelsAndKeepsBests() {
        var game = SaveGame()
        #expect(game.unlockedLevels == 0)
        game.recordEndless(score: 500, cleared: 1, total: 4)
        #expect(game.unlockedLevels == 1)
        game.recordEndless(score: 2400, cleared: 6, total: 4)
        #expect(game.unlockedLevels == 4)
        game.recordEndless(score: 90, cleared: 0, total: 4)
        #expect(game.unlockedLevels == 4)
        #expect(game.bestEndlessScore == 2400)
        #expect(game.bestEndlessCleared == 6)
    }

    @Test func savesFromBeforeEndlessStillLoad() throws {
        let old = #"{"xp":300,"unlockedLevels":2,"bestScores":{"level_01":120},"soundOn":false}"#
        let game = try JSONDecoder().decode(SaveGame.self, from: Data(old.utf8))
        #expect(game.xp == 300)
        #expect(game.unlockedLevels == 2)
        #expect(game.bestScores["level_01"] == 120)
        #expect(!game.soundOn)
        #expect(game.bestEndlessScore == 0)
    }

    /// The bot plays the shipped levels back to back the way the mode chains them.
    @Test func aFullLoopCarriesTheHeroIntoTheNext() throws {
        let levels = try Content.levelIDs.map(Content.level)
        let bosses = try Content.bosses()
        var run = EndlessRun(levelCount: levels.count)
        for _ in 0...levels.count {
            let level = levels[run.levelIndex]
            var world = RunnerWorld(level: level, boss: bosses[level.boss], stats: run.startingStats(for: level))
            var bot = Bot()
            while !world.isOver, world.time < 400 { _ = world.step(bot.input(for: world, dt: dt), dt: dt) }
            try #require(world.phase == .won)
            run.clear(stats: world.stats, score: world.score)
        }
        #expect(run.loop == 2)
        #expect(run.levelIndex == 1)
        #expect(run.stats.level == Progression.maxLevel)
        #expect(run.stats.hearts == 3)
        #expect(run.score > 0)
    }
}
