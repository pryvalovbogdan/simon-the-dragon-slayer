import Foundation
import Testing
@testable import GameCore

@Suite struct ContentTests {
    /// Every level, at both boss distances the app uses (landscape and portrait).
    @Test(arguments: Content.levelIDs, [Tuning.wideBossOffset, Tuning.narrowBossOffset])
    func shippedLevelIsBeatableWithoutAHit(id: String, bossOffset: Double) throws {
        var tuning = Tuning()
        tuning.bossOffset = bossOffset
        let report = LevelValidator.validate(try Content.level(id), bosses: try Content.bosses(), tuning: tuning)
        #expect(report.problems == [])
        #expect(report.clearTime != nil)
    }

    @Test func levelFilesAreFound() {
        #expect(Content.levelIDs.count >= 4)
        #expect(Content.levelIDs.first == "level_01")
    }

    @Test func entryLevelsMatchEarlierBossRewards() throws {
        var guaranteed = 1
        for id in Content.levelIDs {
            let level = try Content.level(id)
            #expect(level.entryHeroLevel <= guaranteed, "\(id) assumes more than earlier levels grant")
            guaranteed = max(guaranteed, level.bossRewardLevel)
        }
    }

    @Test func everyBossDefinitionIsConsistent() throws {
        for boss in try Content.bosses().values {
            #expect(LevelValidator.problems(in: boss) == [])
        }
    }

    @Test func wallOfTreesIsRejected() throws {
        let wall = stride(from: 400.0, to: 700, by: 14).map { PlacedItem(at: $0, kind: .tree) }
        var level = try Content.level("level_01")
        level.items = wall
        let report = LevelValidator.validate(level, bosses: try Content.bosses())
        #expect(!report.isValid)
        #expect(report.problems.contains { $0.contains("no-hit bot failed") })
    }

    @Test func giantBeforeFireballIsRejected() throws {
        var level = try Content.level("level_01")
        level.items = [PlacedItem(at: 600, kind: .giant), PlacedItem(at: 900, kind: .shrine)]
        let report = LevelValidator.validate(level, bosses: try Content.bosses())
        #expect(report.problems.contains { $0.contains("needs hero level 2") })
    }

    @Test func staticProblemsAreReported() throws {
        var level = try Content.level("level_01")
        level.boss = "boss_missing"
        level.items = [PlacedItem(at: 20, kind: .root), PlacedItem(at: level.length - 10, kind: .root)]
        let problems = LevelValidator.validate(level, bosses: try Content.bosses()).problems
        #expect(problems.contains { $0.contains("start runway") })
        #expect(problems.contains { $0.contains("too close to the boss") })
        #expect(problems.contains { $0.contains("not defined") })
    }

    @Test func everyNameTheGameShowsIsInTheLoreFile() throws {
        let lore = try Content.lore()
        var keys = ["game.title", "hero.name"] + Ability.allCases.map { "ability.\($0.rawValue)" }
        for id in Content.levelIDs {
            let level = try Content.level(id)
            keys += [level.nameKey, "\(level.boss).name"]
        }
        for key in keys {
            #expect(lore.strings[key]?.isEmpty == false, "Lore.json has no text for \(key)")
        }
        #expect(lore.text("no.such.key") == "no.such.key")
    }
}
