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

    /// Rows repeating the lower, grassless part of a ground tile from `top` down past the bottom of
    /// the scene, for screens where the earth runs deeper than the tile is tall.
    static func earth(below top: CGFloat, tile: SKTexture, tileSize: CGSize, viewWidth: CGFloat) -> [ParallaxNode] {
        let height = (tileSize.height * 0.75).rounded()
        let texture = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: height / tileSize.height), in: tile)
        texture.filteringMode = .nearest
        var rows: [ParallaxNode] = []
        var top = top
        while top > 0 {
            top -= height
            let row = ParallaxNode(texture: texture, size: CGSize(width: tileSize.width, height: height),
                                   viewWidth: viewWidth, factor: 1)
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
