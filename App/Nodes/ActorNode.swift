import SpriteKit

/// A sprite that plays named animations from the sprite manifest.
final class ActorNode: SKSpriteNode {
    let spriteName: String
    private let library: SpriteLibrary
    private(set) var current = ""
    /// True while a non-looping animation is still running.
    private(set) var isBusy = false

    init(sprite: String, library: SpriteLibrary) {
        spriteName = sprite
        self.library = library
        let sheet = library.sheet(sprite)
        let size = CGSize(width: sheet?.width ?? 16, height: sheet?.height ?? 16)
        // An unknown sprite shows as a magenta block instead of crashing, so a missing asset is obvious.
        super.init(texture: nil, color: sheet == nil ? .magenta : .clear, size: size)
        anchorPoint = CGPoint(x: sheet?.anchorX ?? 0.5, y: sheet?.anchorY ?? 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func has(_ name: String) -> Bool {
        library.animation(spriteName, name) != nil
    }

    /// Starts `name` unless it is already playing. Looping animations repeat; others stop on the last frame.
    func play(_ name: String, restart: Bool = false, completion: (() -> Void)? = nil) {
        guard restart || name != current else { return }
        guard let animation = library.animation(spriteName, name) else {
            completion?()
            return
        }
        let textures = library.textures(spriteName, name)
        guard !textures.isEmpty else {
            completion?()
            return
        }
        current = name
        removeAction(forKey: "animation")
        texture = textures[0]
        let animate = SKAction.animate(with: textures, timePerFrame: 1 / max(animation.fps, 1))
        if animation.loop {
            isBusy = false
            if textures.count > 1 { run(.repeatForever(animate), withKey: "animation") }
        } else {
            isBusy = true
            run(.sequence([animate, .run { [weak self] in
                self?.isBusy = false
                completion?()
            }]), withKey: "animation")
        }
    }

    func flash(_ color: SKColor = .white, duration: TimeInterval = 0.12) {
        removeAction(forKey: "flash")
        run(.sequence([.colorize(with: color, colorBlendFactor: 0.9, duration: 0),
                       .wait(forDuration: duration),
                       .colorize(withColorBlendFactor: 0, duration: 0.05)]), withKey: "flash")
    }
}
