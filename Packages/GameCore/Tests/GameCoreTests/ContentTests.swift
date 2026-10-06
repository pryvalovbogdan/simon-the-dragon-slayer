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
        level.ravines = nil
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

    @Test func badRavinesAreRejected() throws {
        var level = try Content.level("level_01")
        level.items = [PlacedItem(at: 820, kind: .tree), PlacedItem(at: 820, kind: .coin)]
        level.ravines = [Ravine(at: 100, width: 30), Ravine(at: 800, width: 40), Ravine(at: 850, width: 30),
                         Ravine(at: 1200, width: 90), Ravine(at: level.length - 70, width: 30)]
        let problems = LevelValidator.validate(level, bosses: try Content.bosses()).problems
        #expect(problems.contains { $0.contains("ravine at 100 is inside the 150-unit start runway") })
        #expect(problems.contains { $0.contains("tree at 820 stands in the ravine at 800") })
        #expect(!problems.contains { $0.contains("coin at 820") })
        #expect(problems.contains { $0.contains("ravine at 850 is too close to the one before it") })
        #expect(problems.contains { $0.contains("ravine at 1200 is 90 wide") })
        #expect(problems.contains { $0.contains("too close to the boss") && $0.contains("ravine") })
    }

    @Test func levelsWithoutRavinesStillLoad() throws {
        let json = #"{"id":"l","nameKey":"k","background":"forest","speed":110,"length":900,"entryHeroLevel":1,"boss":"b","bossRewardLevel":2,"items":[]}"#
        #expect(try ContentLoader.level(from: Data(json.utf8)).ravines == nil)
    }

    @Test func everyNameTheGameShowsIsInTheLoreFile() throws {
        let lore = try Content.lore()
        var keys = ["game.title", "hero.name", "mode.endless.name"] + Ability.allCases.map { "ability.\($0.rawValue)" }
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
