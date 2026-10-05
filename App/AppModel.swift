import Foundation
import GameCore
import Observation

struct GameResult: Equatable {
    var won: Bool
    var score: Int
    var xp: Int
    var heroLevel: Int
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
    /// so the game can be watched and screenshotted in the simulator without touch input.
    private(set) var autoplay = false
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
        if let flag = arguments.firstIndex(of: "-autoplay"), arguments.indices.contains(flag + 1),
           let number = Int(arguments[flag + 1]), levels.indices.contains(number - 1) {
            autoplay = true
            save.unlockedLevels = levels.count
            screen = .playing(level: number - 1, attempt: 0)
        }
        #endif
    }

    func text(_ key: String) -> String {
        lore.text(key)
    }

    func isUnlocked(_ index: Int) -> Bool {
        index < save.unlockedLevels
    }

    /// The hero starts a level with saved XP, but never below what earlier bosses guarantee.
    func startingStats(for index: Int) -> HeroStats {
        HeroStats(xp: max(save.xp, Progression.xp(forLevel: levels[index].entryHeroLevel)))
    }

    func start(level index: Int) {
        guard levels.indices.contains(index), isUnlocked(index) else { return }
        attempts += 1
        screen = .playing(level: index, attempt: attempts)
    }

    func finish(level index: Int, result: GameResult) {
        if result.won, !autoplay {
            save.complete(levelID: levels[index].id, index: index, total: levels.count, score: result.score, xp: result.xp)
            store.save(save)
        }
        screen = .finished(level: index, result: result)
    }

    func setSound(on: Bool) {
        save.soundOn = on
        store.save(save)
    }
}
