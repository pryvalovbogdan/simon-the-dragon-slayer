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

    /// Rows of the grassless earth tile from `top` down past the bottom of the scene, for screens
    /// where the earth runs deeper than the ground tile is tall.
    static func earth(below top: CGFloat, tile: SKTexture, tileSize: CGSize, viewWidth: CGFloat) -> [ParallaxNode] {
        var rows: [ParallaxNode] = []
        var top = top
        while top > 0 {
            top -= tileSize.height
            let row = ParallaxNode(texture: tile, size: tileSize, viewWidth: viewWidth, factor: 1)
            row.position.y = top
            rows.append(row)
        }
        return rows
    }

    func scroll(to distance: CGFloat) {
        // Whole pixels only, otherwise neighbouring tiles shimmer.
        position.x = -floor((distance * factor).truncatingRemainder(dividingBy: tileWidth))
    }
}
