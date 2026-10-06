import SpriteKit

/// The picture behind the start and end screens: the hero in a bright morning, running on the start
/// screen and at rest once a run is over. Decoration only; no game rules run here.
final class MenuScene: SKScene {
    enum Pose {
        case running, standing, fallen
    }

    /// Share of the screen height below the ground line when upright; the buttons sit on that earth.
    static let narrowGroundShare: CGFloat = 0.36
    /// World units across an upright screen: few enough that the hero fills a good part of it.
    private static let narrowUnits: CGFloat = 190
    private static let pace: CGFloat = 70

    private let library: SpriteLibrary
    private let upright: Bool
    private let pose: Pose
    private var parallax: [ParallaxNode] = []
    private var lastTime: TimeInterval?
    private var scroll: CGFloat = 0

    init(viewSize: CGSize, displayScale: CGFloat, library: SpriteLibrary, pose: Pose = .running) {
        self.library = library
        self.pose = pose
        upright = viewSize.height > viewSize.width
        super.init(size: Self.sceneSize(viewSize: viewSize, displayScale: max(displayScale, 1)))
        scaleMode = .fill
        anchorPoint = .zero
    }

    /// On its side the menu is framed like the game. Upright the game needs width to show what is
    /// coming; the menu does not, so it zooms in and the hero fills more of the screen.
    private static func sceneSize(viewSize: CGSize, displayScale: CGFloat) -> CGSize {
        guard viewSize.height > viewSize.width else {
            return GameScene.sceneSize(viewSize: viewSize, displayScale: displayScale)
        }
        let pixelsPerUnit = max(1, floor(viewSize.width * displayScale / narrowUnits))
        return CGSize(width: viewSize.width * displayScale / pixelsPerUnit,
                      height: viewSize.height * displayScale / pixelsPerUnit)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        let groundY = upright ? (size.height * Self.narrowGroundShare).rounded() : 40
        if let sky = library.textures("bg_menu_sky", "still").first {
            let node = SKSpriteNode(texture: sky, size: size)
            node.anchorPoint = .zero
            node.zPosition = -10
            addChild(node)
        }
        // Loose clouds fill the open sky an upright screen has above the cloud bank.
        addStrip("bg_menu_puffs", bottom: groundY + (upright ? 120 : 70), factor: 0.04, z: -9.5)
        addStrip("bg_menu_clouds", bottom: groundY, factor: 0.08, z: -9)
        addStrip("bg_menu_horizon", bottom: groundY, factor: 0.2, z: -8)
        addStrip("bg_menu_bushes", bottom: groundY, factor: 0.55, z: -7)
        if let fill = library.textures("ground_forest_fill", "still").first {
            let node = SKSpriteNode(texture: fill, size: CGSize(width: size.width, height: groundY))
            node.anchorPoint = .zero
            node.zPosition = -6
            addChild(node)
        }
        if let sheet = library.sheet("ground_forest"), let earth = library.textures("ground_forest_earth", "still").first,
           let earthSheet = library.sheet("ground_forest_earth") {
            let top = groundY - sheet.height
            addStrip("ground_forest", bottom: top, factor: 1, z: -5)
            for row in ParallaxNode.earth(below: top, tile: earth,
                                          tileSize: CGSize(width: earthSheet.width, height: earthSheet.height),
                                          viewWidth: size.width) {
                row.zPosition = -5
                addChild(row)
                parallax.append(row)
            }
        }

        let hero = ActorNode(sprite: "hero", library: library)
        hero.setScale(2)
        // At rest on a wide screen the hero steps aside to leave the middle to the score card.
        let place: CGFloat = upright ? 0.5 : (pose == .running ? 0.22 : 0.13)
        hero.position = CGPoint(x: (size.width * place).rounded(), y: groundY)
        switch pose {
        case .running: hero.play("run")
        case .standing: hero.play("idle")
        case .fallen:
            // Lying where they fell: a frame from before the death animation fades the hero away.
            let frames = library.textures("hero", "death")
            if !frames.isEmpty { hero.texture = frames[min(3, frames.count - 1)] }
        }
        addChild(hero)
    }

    private func addStrip(_ name: String, bottom: CGFloat, factor: CGFloat, z: CGFloat) {
        guard let texture = library.textures(name, "still").first, let sheet = library.sheet(name) else { return }
        let node = ParallaxNode(texture: texture, size: CGSize(width: sheet.width, height: sheet.height),
                                viewWidth: size.width, factor: factor)
        node.position.y = bottom
        node.zPosition = z
        addChild(node)
        parallax.append(node)
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastTime = currentTime }
        guard let lastTime, pose == .running else { return }
        scroll += CGFloat(min(currentTime - lastTime, 0.1)) * Self.pace
        for layer in parallax { layer.scroll(to: scroll) }
    }
}
