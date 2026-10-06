import GameCore
import SpriteKit
import UIKit

/// Draws a `RunnerWorld` and feeds it touches. All rules live in GameCore; nothing here decides
/// whether the hero is hit or an enemy dies.
final class GameScene: SKScene {
    private static let step = 1.0 / 60
    /// How the playfield is framed for one orientation.
    private struct Framing {
        /// Fewest world units that must fit: height for the tallest boss and a double jump, width to
        /// see a boss standing `bossOffset` ahead of the hero.
        let minimumUnits: CGSize
        let heroScreenX: CGFloat
        let bossOffset: Double
        /// Share of the screen height below the ground line.
        let groundShare: CGFloat?

        static let wide = Framing(minimumUnits: CGSize(width: 330, height: 180), heroScreenX: 70,
                                  bossOffset: Tuning.wideBossOffset, groundShare: nil)
        /// Portrait trades view distance for size: sprites are drawn larger, so the hero stands
        /// nearer the edge and the boss nearer the hero to keep both on screen.
        static let narrow = Framing(minimumUnits: CGSize(width: 190, height: 180), heroScreenX: 30,
                                    bossOffset: Tuning.narrowBossOffset, groundShare: 0.38)

        static func `for`(_ viewSize: CGSize) -> Framing {
            viewSize.height > viewSize.width ? narrow : wide
        }
    }

    private var framing: Framing

    /// Height of the ground line above the bottom of the scene; set by `layout(viewSize:)`.
    private var groundY: CGFloat = 40
    private let displayScale: CGFloat

    private var world: RunnerWorld
    private let library: SpriteLibrary
    private let hud: GameHUD
    private let soundOn: Bool
    /// How fast the game clock runs; above 1 in the later loops of an endless run.
    private let timeScale: Double
    private let openingBanner: String?
    private let text: (String) -> String
    private let onFinish: (GameResult) -> Void
    /// Set by the `-autoplay` debug launch argument: the validator bot plays instead of touches.
    private var bot: Bot?

    private var lastTime: TimeInterval?
    private var accumulator = 0.0
    /// Distance used for scrolling the scenery; stops when the level is won.
    private var scroll = 0.0
    private var jumpTouches = Set<UITouch>()
    private var fireTouches = Set<UITouch>()
    private var jumpPending = false
    private var reported = false
    private var unlocked: [Ability] = []

    private var parallax: [ParallaxNode] = []
    private var ravineNodes: [(ravine: Ravine, node: SKNode)] = []
    /// The hero went down a ravine: the drop is animated here, so `renderHero` leaves them alone.
    private var fell = false
    private let scenery = SKNode()
    private let actors = SKNode()
    private var hero: ActorNode!
    private var bossNode: ActorNode?
    private var entityNodes: [Int: ActorNode] = [:]
    private var hazardNodes: [Int: ActorNode] = [:]
    private var shotNodes: [Int: ActorNode] = [:]
    private var hurtUntil = 0.0
    private var castUntil = 0.0
    private var bannerUntil = 0.0
    private var awardUntil = 0.0

    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    init(viewSize: CGSize, displayScale: CGFloat, level: LevelDefinition, boss: BossDefinition?, stats: HeroStats, library: SpriteLibrary,
         hud: GameHUD, soundOn: Bool, autoplay: Bool = false, timeScale: Double = 1, openingBanner: String? = nil,
         text: @escaping (String) -> String, onFinish: @escaping (GameResult) -> Void) {
        world = RunnerWorld(level: level, boss: boss, stats: stats)
        self.library = library
        self.hud = hud
        self.soundOn = soundOn
        self.timeScale = timeScale
        self.openingBanner = openingBanner
        self.text = text
        self.onFinish = onFinish
        bot = autoplay ? Bot() : nil
        self.displayScale = max(displayScale, 1)
        framing = Framing.for(viewSize)
        world.setBossOffset(framing.bossOffset)
        super.init(size: Self.sceneSize(viewSize: viewSize, displayScale: self.displayScale))
        // The scene has the view's proportions, so `.fill` scales both axes alike.
        scaleMode = .fill
        anchorPoint = .zero
        groundY = Self.groundLine(for: size, framing: framing)
        // Animations keep pace with the faster clock.
        speed = CGFloat(timeScale)
    }

    /// World units shown for a view of `viewSize` points. One unit always covers a whole number of
    /// device pixels, the same on both axes, so every sprite pixel is drawn square and the same size.
    static func sceneSize(viewSize: CGSize, displayScale: CGFloat) -> CGSize {
        let minimum = Framing.for(viewSize).minimumUnits
        let pixelsPerUnit = max(1, floor(min(viewSize.height * displayScale / minimum.height,
                                             viewSize.width * displayScale / minimum.width)))
        return CGSize(width: viewSize.width * displayScale / pixelsPerUnit,
                      height: viewSize.height * displayScale / pixelsPerUnit)
    }

    /// In portrait the ground line sits part-way up the screen, leaving earth below for thumbs.
    private static func groundLine(for size: CGSize, framing: Framing) -> CGFloat {
        framing.groundShare.map { (size.height * $0).rounded() } ?? 40
    }

    /// Called when the view changes size (rotation). The simulation is untouched; only the camera
    /// framing and scenery are rebuilt.
    func layout(viewSize: CGSize) {
        let newSize = Self.sceneSize(viewSize: viewSize, displayScale: displayScale)
        guard newSize != size, viewSize.width > 0, viewSize.height > 0 else { return }
        size = newSize
        framing = Framing.for(viewSize)
        world.setBossOffset(framing.bossOffset)
        groundY = Self.groundLine(for: newSize, framing: framing)
        guard hero != nil else { return }
        buildScenery()
        render()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        addChild(scenery)
        buildScenery()
        actors.zPosition = 10
        addChild(actors)
        hero = ActorNode(sprite: "hero", library: library)
        hero.zPosition = 5
        hero.play("run")
        actors.addChild(hero)
        syncHUD()
        if let openingBanner { showBanner(openingBanner) }
        render()
    }

    private func buildScenery() {
        scenery.removeAllChildren()
        parallax.removeAll()
        let theme = world.level.background
        if let sky = library.textures("bg_\(theme)_sky", "still").first {
            // The banded sky keeps its drawn height and sits on the ground line, so the horizon looks the
            // same in both orientations; anything above it is filled with the sky's top colour.
            let bandHeight: CGFloat = 200
            let node = SKSpriteNode(texture: sky, size: CGSize(width: size.width, height: bandHeight))
            node.anchorPoint = .zero
            node.position.y = groundY
            node.zPosition = -10
            scenery.addChild(node)
            let above = size.height - groundY - bandHeight
            if above > 0, let topColour = library.textures("bg_\(theme)_sky_top", "still").first {
                let fill = SKSpriteNode(texture: topColour, size: CGSize(width: size.width, height: above + 1))
                fill.anchorPoint = .zero
                fill.position.y = groundY + bandHeight - 1
                fill.zPosition = -10
                scenery.addChild(fill)
            }
        } else {
            backgroundColor = .darkGray
        }
        if let fill = library.textures("ground_\(theme)_fill", "still").first {
            let node = SKSpriteNode(texture: fill, size: CGSize(width: size.width, height: groundY))
            node.anchorPoint = .zero
            node.zPosition = -5
            scenery.addChild(node)
        }
        // Back to front. The loose clouds float above the tree line, so they mostly show upright,
        // where there is open sky; everything else stands on the ground line.
        for (layer, factor, z, lift) in [("puffs", 0.03, -9.5, 150.0), ("clouds", 0.06, -9.0, 0), ("far", 0.15, -8.0, 0),
                                         ("near", 0.4, -6.0, 0), ("bushes", 0.7, -5.5, 0)] {
            let name = "bg_\(theme)_\(layer)"
            guard let texture = library.textures(name, "still").first, let sheet = library.sheet(name) else { continue }
            let node = ParallaxNode(texture: texture, size: CGSize(width: sheet.width, height: sheet.height),
                                    viewWidth: size.width, factor: factor)
            node.position.y = groundY + lift
            node.zPosition = z
            scenery.addChild(node)
            parallax.append(node)
        }
        let name = "ground_\(theme)"
        if let texture = library.textures(name, "still").first, let sheet = library.sheet(name) {
            let node = ParallaxNode(texture: texture, size: CGSize(width: sheet.width, height: sheet.height),
                                    viewWidth: size.width, factor: 1)
            node.position.y = groundY - sheet.height
            node.zPosition = -4
            scenery.addChild(node)
            parallax.append(node)
            // Upright the earth runs deeper than the tile; keep it textured and scrolling as one piece.
            if let earth = library.textures("\(name)_earth", "still").first, let earthSheet = library.sheet("\(name)_earth") {
                for row in ParallaxNode.earth(below: node.position.y, tile: earth,
                                              tileSize: CGSize(width: earthSheet.width, height: earthSheet.height),
                                              viewWidth: size.width) {
                    row.zPosition = -4
                    scenery.addChild(row)
                    parallax.append(row)
                }
            }
        }
        buildRavines(theme: theme)
    }

    /// Pits drawn over the ground strip, one per ravine; `render()` moves them with the level.
    private func buildRavines(theme: String) {
        ravineNodes.removeAll()
        let name = "ravine_\(theme)"
        guard let wall = library.textures(name, "still").first, let sheet = library.sheet(name),
              let dark = library.textures("\(name)_fill", "still").first else { return }
        let wallSize = CGSize(width: sheet.width, height: sheet.height)
        for ravine in world.ravines {
            let node = SKNode()
            node.zPosition = -3
            let width = CGFloat(ravine.width)
            let fill = SKSpriteNode(texture: dark, size: CGSize(width: width, height: wallSize.height))
            fill.anchorPoint = .zero
            fill.position.y = groundY - wallSize.height
            node.addChild(fill)
            // Where the earth is deeper than the drawn pit, carry its bottom colour on down.
            if groundY > wallSize.height, let bottomColour = library.textures("\(name)_deep", "still").first {
                let rest = SKSpriteNode(texture: bottomColour, size: CGSize(width: width, height: fill.position.y + 1))
                rest.anchorPoint = .zero
                node.addChild(rest)
            }
            for (x, facing) in [(0, 1.0), (width, -1.0)] {
                let side = SKSpriteNode(texture: wall, size: wallSize)
                side.anchorPoint = .zero
                side.position = CGPoint(x: x, y: fill.position.y)
                side.xScale = facing
                side.zPosition = 0.5
                node.addChild(side)
            }
            scenery.addChild(node)
            ravineNodes.append((ravine, node))
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // Right-hand side is the fire button once the fireball is unlocked; everywhere else jumps.
            if world.stats.has(.fireball), touch.location(in: self).x > size.width * 0.62 {
                fireTouches.insert(touch)
            } else {
                jumpTouches.insert(touch)
                jumpPending = true
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        jumpTouches.subtract(touches)
        fireTouches.subtract(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard !hud.isPaused, let last = lastTime else {
            // Dropping the timestamp while paused stops the pause from being replayed as one big step.
            lastTime = hud.isPaused ? nil : currentTime
            return
        }
        lastTime = currentTime
        accumulator += min(currentTime - last, 0.1) * timeScale
        while accumulator >= Self.step {
            accumulator -= Self.step
            guard !world.isOver else { break }
            let input = bot?.input(for: world, dt: Self.step)
                ?? Input(jumpPressed: jumpPending, jumpHeld: !jumpTouches.isEmpty, fireHeld: !fireTouches.isEmpty)
            jumpPending = false
            let moving = world.phase == .running || world.phase == .boss
            handle(world.step(input, dt: Self.step))
            if moving { scroll += world.level.speed * Self.step }
        }
        render()
        syncHUD()
        if world.isOver, !reported { report() }
    }

    private func report() {
        reported = true
        let won = world.phase == .won
        play(won ? .win : .lose)
        let result = GameResult(won: won, score: world.score, xp: world.stats.xp, heroLevel: world.stats.level,
                                hearts: world.stats.hearts,
                                unlocked: unlocked)
        run(.sequence([.wait(forDuration: won ? 0.6 : 1.4), .run { [onFinish] in onFinish(result) }]))
    }

    // MARK: - Events

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .jumped(let double):
                play(double ? .doubleJump : .jump)
            case .landed:
                break
            case .heroHit:
                hurtUntil = world.time + 0.3
                play(.hurt)
                haptics.impactOccurred()
            case .heroDied:
                play(.hurt)
                haptics.impactOccurred()
            case .heroFell:
                dropHeroIntoRavine()
            case .stomped:
                play(.stomp)
            case .enemyHit(let id):
                entityNodes[id]?.flash()
            case .enemyDefeated(let id, _):
                retire(entityNodes.removeValue(forKey: id))
            case .coin(let id):
                play(.coin)
                if let node = entityNodes.removeValue(forKey: id) {
                    node.run(.sequence([.group([.moveBy(x: 0, y: 14, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                                        .removeFromParent()]))
                }
            case .shrine:
                break
            case .leveledUp(let level, let ability):
                play(.levelUp)
                if let ability {
                    unlocked.append(ability)
                    award(ability)
                } else {
                    showBanner("LEVEL \(level)")
                }
            case .fired(_, let charged):
                castUntil = world.time + 0.3
                play(charged ? .charged : .fire)
            case .fireballGone(let id, let hit):
                guard let node = shotNodes.removeValue(forKey: id) else { break }
                if hit {
                    play(.impact)
                    node.play("impact") { [weak node] in node?.removeFromParent() }
                } else {
                    node.removeFromParent()
                }
            case .bossAppeared(let id):
                play(.bossRoar)
                showBanner(text("\(id).name").uppercased())
            case .bossTelegraph, .bossAttack:
                break
            case .bossHit:
                play(.bossHit)
                bossNode?.flash()
            case .bossBlocked:
                play(.block)
                bossNode?.flash(.gray, duration: 0.06)
            case .bossDefeated:
                bossNode?.play("death")
            case .levelComplete:
                break
            }
        }
    }

    /// Drops the hero out of sight. The crop keeps them behind the ground on either side of the pit.
    private func dropHeroIntoRavine() {
        fell = true
        hero.play("fall")
        guard let ravine = world.ravines.first(where: { $0.isOpen(at: world.distance) }) else { return }
        let sky = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: size.height - groundY))
        sky.anchorPoint = .zero
        sky.position.y = groundY
        let pit = SKSpriteNode(color: .white, size: CGSize(width: CGFloat(ravine.width), height: groundY))
        pit.anchorPoint = .zero
        pit.position.x = screenX(ravine.at)
        let mask = SKNode()
        mask.addChild(sky)
        mask.addChild(pit)
        let crop = SKCropNode()
        crop.maskNode = mask
        crop.zPosition = hero.zPosition
        hero.removeFromParent()
        crop.addChild(hero)
        actors.addChild(crop)
        let drop = SKAction.moveBy(x: 0, y: -(groundY + hero.size.height), duration: 0.5)
        drop.timingMode = .easeIn
        hero.run(drop)
    }

    private func retire(_ node: ActorNode?) {
        guard let node else { return }
        if node.has("death") {
            node.play("death") { [weak node] in node?.removeFromParent() }
        } else {
            node.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
    }

    /// A new ability is the big moment of a run: an award card on the HUD and a burst around the hero.
    private func award(_ ability: Ability) {
        hud.award = ability
        awardUntil = world.time + 2.6
        hero.flash(.yellow, duration: 0.25)
        let origin = CGPoint(x: hero.position.x, y: hero.position.y + 18)

        if let star = library.textures("spark_star", "still").first {
            let count = 10
            for index in 0..<count {
                let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
                let node = SKSpriteNode(texture: star)
                node.position = origin
                node.zPosition = 7
                actors.addChild(node)
                let fly = SKAction.moveBy(x: cos(angle) * 48, y: sin(angle) * 48, duration: 0.6)
                fly.timingMode = .easeOut
                node.run(.sequence([.group([fly, .rotate(byAngle: .pi, duration: 0.6),
                                            .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.25)])]),
                                    .removeFromParent()]))
            }
        }
        // Fire for the fireballs, feathers for the jump.
        let rising = ability == .doubleJump ? "spark_feather" : "spark_ember"
        if let texture = library.textures(rising, "still").first {
            for (index, offset) in [-16, 9, -5, 15, -11, 3, 12, -8].enumerated() {
                let node = SKSpriteNode(texture: texture)
                node.position = CGPoint(x: origin.x + CGFloat(offset), y: hero.position.y + CGFloat(index % 3) * 6)
                node.zPosition = 7
                node.alpha = 0
                actors.addChild(node)
                let rise = SKAction.moveBy(x: CGFloat(offset) * 0.3, y: 46, duration: 0.8)
                rise.timingMode = .easeOut
                node.run(.sequence([.wait(forDuration: Double(index) * 0.07), .fadeIn(withDuration: 0.05),
                                    .group([rise, .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.35)])]),
                                    .removeFromParent()]))
            }
        }
    }

    private func showBanner(_ message: String) {
        hud.banner = message
        bannerUntil = world.time + 2.2
    }

    private func play(_ sound: Sound) {
        guard soundOn else { return }
        run(sound.action)
    }

    // MARK: - Drawing

    private func screenX(_ worldX: Double) -> CGFloat {
        CGFloat(worldX - world.distance) + framing.heroScreenX
    }

    private func screenY(_ worldY: Double) -> CGFloat {
        CGFloat(worldY) + groundY
    }

    private func render() {
        for layer in parallax { layer.scroll(to: CGFloat(scroll)) }
        for (ravine, node) in ravineNodes {
            node.position.x = screenX(ravine.at).rounded()
            node.isHidden = node.position.x > size.width || node.position.x + CGFloat(ravine.width) < 0
        }
        renderHero()
        renderEntities()
        renderHazards()
        renderShots()
        renderBoss()
    }

    private func renderHero() {
        guard !fell else { return }
        hero.position = CGPoint(x: framing.heroScreenX, y: screenY(world.heroY))
        // Blink while hit-immune so the player can see the grace period.
        let blinking = world.invulnerable > 0 && world.phase != .dead && world.phase != .victory
        hero.alpha = blinking && Int(world.time * 16) % 2 == 0 ? 0.35 : 1

        switch world.phase {
        case .dead:
            hero.play("death")
        case .victory, .won:
            if hero.current != "stop", hero.current != "idle" {
                hero.play("stop") { [weak hero] in hero?.play("idle") }
            }
        case .running, .boss:
            if world.time < hurtUntil {
                hero.play("hurt")
            } else if world.time < castUntil {
                hero.play("cast")
            } else if !world.onGround {
                hero.play(world.heroVY > 0 ? "jump" : "fall")
            } else {
                hero.play("run")
            }
        }
    }

    private static let defaultAnimation: [ItemKind: String] = [
        .tree: "still", .root: "still", .icicle: "still", .goblin: "walk", .giant: "walk", .archer: "idle",
        .hound: "run", .raven: "fly", .coin: "spin", .shrine: "glow",
        .thorns: "still", .wolf: "run", .skeleton: "walk", .ghost: "float",
    ]

    private func renderEntities() {
        var seen = Set<Int>()
        for entity in world.entities {
            seen.insert(entity.id)
            let node = entityNodes[entity.id] ?? makeEntityNode(entity)
            node.position = CGPoint(x: screenX(entity.x), y: screenY(entity.y))
            node.xScale = entity.reversed ? -1 : 1
            let gap = entity.x - world.distance
            switch entity.kind {
            case .giant:
                node.play(gap < 80 && gap > 0 ? "swing" : "walk")
            case .archer:
                node.play(gap < world.tuning.archerRange && gap > 30 ? "shoot" : "idle")
            default:
                break
            }
        }
        for (id, node) in entityNodes where !seen.contains(id) {
            node.removeFromParent()
            entityNodes[id] = nil
        }
    }

    private func makeEntityNode(_ entity: Entity) -> ActorNode {
        let node = ActorNode(sprite: entity.kind.rawValue, library: library)
        node.zPosition = entity.kind == .shrine ? 1 : 3
        node.play(Self.defaultAnimation[entity.kind] ?? "still")
        actors.addChild(node)
        entityNodes[entity.id] = node
        return node
    }

    private func renderHazards() {
        var seen = Set<Int>()
        for hazard in world.hazards {
            seen.insert(hazard.id)
            let node: ActorNode
            if let existing = hazardNodes[hazard.id] {
                node = existing
            } else {
                node = ActorNode(sprite: "hazard_\(hazard.kind)", library: library)
                node.zPosition = 4
                node.play("fly")
                actors.addChild(node)
                hazardNodes[hazard.id] = node
            }
            node.position = CGPoint(x: screenX(hazard.x), y: screenY(hazard.y))
            // A hazard that is still arming is only a warning: faint and blinking.
            node.alpha = hazard.isArmed ? 1 : (Int(world.time * 12) % 2 == 0 ? 0.25 : 0.55)
        }
        for (id, node) in hazardNodes where !seen.contains(id) {
            node.removeFromParent()
            hazardNodes[id] = nil
        }
    }

    private func renderShots() {
        for shot in world.projectiles {
            let node: ActorNode
            if let existing = shotNodes[shot.id] {
                node = existing
            } else {
                node = ActorNode(sprite: shot.charged ? "fireball_charged" : "fireball", library: library)
                node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                node.zPosition = 6
                node.play("fly")
                actors.addChild(node)
                shotNodes[shot.id] = node
            }
            node.position = CGPoint(x: screenX(shot.x), y: screenY(shot.y + shot.size / 2))
        }
    }

    /// Animation a boss plays for an attack; "*" is the fallback for that boss.
    private static let attackAnimation: [String: [String: String]] = [
        "boss_giant": ["*": "slam"],
        "boss_dragon": ["tail_sweep": "tail", "*": "breath"],
        "boss_queen": ["mirror_orbs": "cast", "*": "summon"],
        "boss_stormking": ["*": "lightning"],
    ]

    private func renderBoss() {
        guard let state = world.bossState else { return }
        let node: ActorNode
        if let bossNode {
            node = bossNode
        } else {
            node = ActorNode(sprite: state.id, library: library)
            node.zPosition = 2
            node.play("idle")
            actors.addChild(node)
            bossNode = node
        }
        // Slides in from off-screen during the intro.
        let entering = state.action == .intro ? max(0, 1 - state.actionTime / world.tuning.bossIntro) : 0
        node.position = CGPoint(x: screenX(state.x) + CGFloat(entering) * 180, y: groundY)

        switch state.action {
        case .dead:
            break
        case .intro:
            node.play("idle")
        case .telegraph:
            // The wind-up is the first frames of the attack animation, so it reads as a warning.
            let table = Self.attackAnimation[state.id] ?? [:]
            let name = table[state.attackName] ?? table["*"] ?? "idle"
            if node.current != name { node.play(name) }
        case .attack:
            break
        case .recover:
            if !node.isBusy { node.play(node.has("stunned") ? "stunned" : "idle") }
        }
    }

    private func syncHUD() {
        let stats = world.stats
        show(\.hearts, stats.hearts)
        show(\.maxHearts, stats.maxHearts)
        show(\.heroLevel, stats.level)
        if let needed = Progression.xpToNext(fromXP: stats.xp) {
            let floor = Progression.xp(forLevel: stats.level)
            show(\.xpFraction, Double(stats.xp - floor) / Double(stats.xp - floor + needed))
        } else {
            show(\.xpFraction, 1)
        }
        show(\.canFire, stats.has(.fireball))
        show(\.canCharge, stats.has(.chargedFireball))
        show(\.chargeFraction, min(1, world.charge / world.tuning.chargeTime))
        if let boss = world.bossState, world.phase == .boss {
            show(\.bossName, text("\(boss.id).name"))
            show(\.bossFraction, boss.hpFraction)
        } else {
            show(\.bossName, nil)
        }
        if hud.banner != nil, world.time > bannerUntil { hud.banner = nil }
        if hud.award != nil, world.time > awardUntil { hud.award = nil }
    }

    /// Writes a HUD value only when it differs. Every write redraws the SwiftUI overlay, even one
    /// that changes nothing, and this runs each frame.
    private func show<Value: Equatable>(_ field: ReferenceWritableKeyPath<GameHUD, Value>, _ value: Value) {
        if hud[keyPath: field] != value { hud[keyPath: field] = value }
    }
}
