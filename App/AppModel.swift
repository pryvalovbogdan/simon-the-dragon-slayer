import Foundation
import GameCore
import Observation

struct GameResult: Equatable {
    var won: Bool
    var score: Int
    var xp: Int
    var heroLevel: Int
    var hearts: Int
    /// Abilities gained during this run, in unlock order.
    var unlocked: [Ability]
}

@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable {
        case menu
        /// `attempt` changes on every start so a retry builds a fresh scene.
        case playing(level: Int, attempt: Int)
        case finished(level: Int, result: GameResult)
    }

    let levels: [LevelDefinition]
    let bosses: [String: BossDefinition]
    let sprites: SpriteLibrary
    private let lore: Lore
    private let store = DefaultsSaveStore()

    var screen = Screen.menu
    private(set) var save: SaveGame
    /// Debug builds only: `-autoplay <level number>` starts that level with the validator bot playing,
    /// and `-autoplay endless` an endless run, so the game can be watched and screenshotted in the
    /// simulator without touch input. Those runs are silent and are not saved.
    private(set) var autoplay = false
    /// The endless run in progress or just ended; nil while a level is played on its own.
    private(set) var endless: EndlessRun?
    private var attempts = 0

    init(bundle: Bundle = .main) {
        do {
            levels = try ContentLoader.levels(in: bundle)
            bosses = try ContentLoader.bosses(in: bundle)
            guard let loreURL = bundle.url(forResource: "Lore", withExtension: "json") else {
                throw ContentError.missing("Lore.json")
            }
            lore = try Lore(data: Data(contentsOf: loreURL))
            sprites = try SpriteLibrary(bundle: bundle)
        } catch {
            // The content ships inside the app; if it cannot be read the build itself is broken.
            fatalError("Game content failed to load: \(error)")
        }
        save = store.load()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-autoplay"), arguments.indices.contains(flag + 1) {
            if arguments[flag + 1] == "endless" {
                autoplay = true
                startEndless()
            } else if let number = Int(arguments[flag + 1]), levels.indices.contains(number - 1) {
                autoplay = true
                save.unlockedLevels = levels.count
                screen = .playing(level: number - 1, attempt: 0)
            }
        }
        #endif
    }

    func text(_ key: String) -> String {
        lore.text(key)
    }

    func isUnlocked(_ index: Int) -> Bool {
        index < save.unlockedLevels
    }

    /// On its own a level starts with saved XP, but never below what earlier bosses guarantee. In an
    /// endless run the hero is whoever left the previous level.
    func startingStats(for index: Int) -> HeroStats {
        if let endless { return endless.startingStats(for: levels[index]) }
        return HeroStats(xp: max(save.xp, Progression.xp(forLevel: levels[index].entryHeroLevel)))
    }

    func start(level index: Int) {
        guard levels.indices.contains(index), isUnlocked(index) else { return }
        endless = nil
        attempts += 1
        screen = .playing(level: index, attempt: attempts)
    }

    /// Starts an endless run from the first level with a fresh hero.
    func startEndless() {
        let run = EndlessRun(levelCount: levels.count)
        endless = run
        attempts += 1
        screen = .playing(level: run.levelIndex, attempt: attempts)
    }

    func finish(level index: Int, result: GameResult) {
        guard var run = endless else {
            if result.won, !autoplay {
                save.complete(levelID: levels[index].id, score: result.score, xp: result.xp)
                store.save(save)
            }
            screen = .finished(level: index, result: result)
            return
        }
        if result.won {
            var hero = HeroStats(xp: result.xp)
            hero.hearts = result.hearts
            run.clear(stats: hero, score: result.score)
        } else {
            run.end(score: result.score)
        }
        endless = run
        record(run)
        if run.isOver {
            screen = .finished(level: index, result: result)
        } else {
            attempts += 1
            screen = .playing(level: run.levelIndex, attempt: attempts)
        }
    }

    /// Back to the menu from anywhere; an endless run left part-way keeps what it had banked.
    func quit() {
        if let endless { record(endless) }
        endless = nil
        screen = .menu
    }

    private func record(_ run: EndlessRun) {
        guard !autoplay else { return }
        save.recordEndless(score: run.score, cleared: run.cleared, total: levels.count)
        store.save(save)
    }

    func setSound(on: Bool) {
        save.soundOn = on
        store.save(save)
    }
}
