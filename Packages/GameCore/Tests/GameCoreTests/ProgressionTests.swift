import Testing
@testable import GameCore

@Suite struct ProgressionTests {
    @Test func levelsFollowThresholds() {
        #expect(Progression.level(forXP: 0) == 1)
        #expect(Progression.level(forXP: 99) == 1)
        #expect(Progression.level(forXP: 100) == 2)
        #expect(Progression.level(forXP: 299) == 2)
        #expect(Progression.level(forXP: 300) == 3)
        #expect(Progression.level(forXP: 600) == 4)
        #expect(Progression.level(forXP: 99_999) == 4)
    }

    @Test func abilitiesUnlockInOrder() {
        #expect(Progression.abilities(forLevel: 1).isEmpty)
        #expect(Progression.abilities(forLevel: 2) == [.fireball])
        #expect(Progression.abilities(forLevel: 3) == [.fireball, .doubleJump])
        #expect(Progression.abilities(forLevel: 4) == Set(Ability.allCases))
    }

    @Test func gainReportsEveryLevelCrossed() {
        var stats = HeroStats()
        #expect(stats.gain(xp: 50).isEmpty)
        #expect(stats.gain(xp: 50) == [2])
        #expect(stats.gain(xp: 600) == [3, 4])
        #expect(stats.gain(xp: 1000).isEmpty)
    }

    @Test func raiseNeverLowersXP() {
        var stats = HeroStats(xp: 450)
        #expect(stats.raise(toLevel: 2).isEmpty)
        #expect(stats.xp == 450)
        #expect(stats.raise(toLevel: 4) == [4])
        #expect(stats.xp == 600)
    }

    @Test func xpToNextIsNilAtMax() {
        #expect(Progression.xpToNext(fromXP: 40) == 60)
        #expect(Progression.xpToNext(fromXP: 600) == nil)
    }

    @Test func saveRoundTripsAndKeepsBest() throws {
        let suite = "gamecore.tests.\(UInt64.random(in: 0...UInt64.max))"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DefaultsSaveStore(defaults: defaults)
        #expect(store.load() == SaveGame())

        var game = SaveGame()
        game.complete(levelID: "level_01", score: 120, xp: 300)
        game.complete(levelID: "level_01", score: 80, xp: 100)
        game.recordEndless(score: 900, cleared: 2, total: 4)
        store.save(game)

        let loaded = store.load()
        #expect(loaded.unlockedLevels == 2)
        #expect(loaded.bestScores["level_01"] == 120)
        #expect(loaded.xp == 300)
        #expect(loaded.bestEndlessScore == 900)
    }
}

import Foundation
