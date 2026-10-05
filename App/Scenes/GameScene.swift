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
        /// How much taller than wide one world unit is drawn. Above 1 the whole playfield — hero,
        /// obstacles, ground, backdrop — is stretched upward to use a tall screen.
        let verticalStretch: CGFloat
        /// Share of the screen height below the ground line.
        let groundShare: CGFloat?

        static let wide = Framing(minimumUnits: CGSize(width: 330, height: 180), heroScreenX: 70,
                                  bossOffset: Tuning.wideBossOffset, verticalStretch: 1, groundShare: nil)
        /// Portrait trades view distance for size: sprites are drawn larger, so the hero stands
        /// nearer the edge and the boss nearer the hero to keep both on screen.
        static let narrow = Framing(minimumUnits: CGSize(width: 230, height: 180), heroScreenX: 36,
                                    bossOffset: Tuning.narrowBossOffset, verticalStretch: 1.4, groundShare: 0.3)

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

    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    init(viewSize: CGSize, displayScale: CGFloat, level: LevelDefinition, boss: BossDefinition?, stats: HeroStats, library: SpriteLibrary,
         hud: GameHUD, soundOn: Bool, autoplay: Bool = false, text: @escaping (String) -> String,
         onFinish: @escaping (GameResult) -> Void) {
        world = RunnerWorld(level: level, boss: boss, stats: stats)
        self.library = library
        self.hud = hud
        self.soundOn = soundOn
        self.text = text
        self.onFinish = onFinish
        bot = autoplay ? Bot() : nil
        self.displayScale = max(displayScale, 1)
        framing = Framing.for(viewSize)
        world.setBossOffset(framing.bossOffset)
        super.init(size: Self.sceneSize(viewSize: viewSize, displayScale: self.displayScale))
        // `.fill` lets the two axes scale independently, which is what the portrait stretch needs;
        // in landscape both axes use the same scale, so nothing is distorted there.
        scaleMode = .fill
        anchorPoint = .zero
        groundY = Self.groundLine(for: size, framing: framing)
    }

    /// World units shown for a view of `viewSize` points. One unit always covers a whole number of
    /// device pixels on each axis, so every sprite pixel is drawn the same size.
    static func sceneSize(viewSize: CGSize, displayScale: CGFloat) -> CGSize {
        let minimum = Framing.for(viewSize).minimumUnits
        let pixelsPerUnit = max(1, floor(min(viewSize.height * displayScale / minimum.height,
                                             viewSize.width * displayScale / minimum.width)))
        let verticalPixels = (pixelsPerUnit * Framing.for(viewSize).verticalStretch).rounded()
        return CGSize(width: viewSize.width * displayScale / pixelsPerUnit,
                      height: viewSize.height * displayScale / verticalPixels)
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
            if above > 0 {
                let topColour = SKTexture(rect: CGRect(x: 0, y: 0.98, width: 1, height: 0.02), in: sky)
                topColour.filteringMode = .nearest
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
        for (layer, factor, z) in [("far", 0.15, -8.0), ("near", 0.4, -6.0)] {
            let name = "bg_\(theme)_\(layer)"
            guard let texture = library.textures(name, "still").first, let sheet = library.sheet(name) else { continue }
            let node = ParallaxNode(texture: texture, size: CGSize(width: sheet.width, height: sheet.height),
                                    viewWidth: size.width, factor: factor)
            node.position.y = groundY
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
        accumulator += min(currentTime - last, 0.1)
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
                    showBanner("LEVEL \(level) — \(text("ability.\(ability.rawValue)").uppercased())")
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

    private func retire(_ node: ActorNode?) {
        guard let node else { return }
        if node.has("death") {
            node.play("death") { [weak node] in node?.removeFromParent() }
        } else {
            node.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
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
        renderHero()
        renderEntities()
        renderHazards()
        renderShots()
        renderBoss()
    }

    private func renderHero() {
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
        hud.hearts = stats.hearts
        hud.maxHearts = stats.maxHearts
        hud.heroLevel = stats.level
        if let needed = Progression.xpToNext(fromXP: stats.xp) {
            let floor = Progression.xp(forLevel: stats.level)
            hud.xpFraction = Double(stats.xp - floor) / Double(stats.xp - floor + needed)
        } else {
            hud.xpFraction = 1
        }
        hud.canFire = stats.has(.fireball)
        hud.canCharge = stats.has(.chargedFireball)
        hud.chargeFraction = min(1, world.charge / world.tuning.chargeTime)
        if let boss = world.bossState, world.phase == .boss {
            hud.bossName = text("\(boss.id).name")
            hud.bossFraction = boss.hpFraction
        } else {
            hud.bossName = nil
        }
        if hud.banner != nil, world.time > bannerUntil { hud.banner = nil }
    }
}
