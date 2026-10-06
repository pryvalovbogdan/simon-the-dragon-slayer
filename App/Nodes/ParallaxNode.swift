import SpriteKit

/// A horizontally repeating strip that scrolls at a fraction of the level's speed.
final class ParallaxNode: SKNode {
    private let tileWidth: CGFloat
    private let factor: CGFloat

    init(texture: SKTexture, size: CGSize, viewWidth: CGFloat, factor: CGFloat) {
        tileWidth = size.width
        self.factor = factor
        super.init()
        let count = Int(ceil(viewWidth / size.width)) + 1
        for index in 0..<count {
            let tile = SKSpriteNode(texture: texture, size: size)
            tile.anchorPoint = .zero
            tile.position = CGPoint(x: CGFloat(index) * size.width, y: 0)
            addChild(tile)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func scroll(to distance: CGFloat) {
        // Whole pixels only, otherwise neighbouring tiles shimmer.
        position.x = -floor((distance * factor).truncatingRemainder(dividingBy: tileWidth))
    }
}
