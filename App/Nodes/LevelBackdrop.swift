import SpriteKit

/// The layered scenery of a level theme: sky, clouds, hills and the ground strip. Shared by the game
/// and the screen that announces the next level, so both show the same place.
enum LevelBackdrop {
    /// Adds the layers for `theme` to `parent` and returns the strips that scroll, back to front.
    static func build(theme: String, size: CGSize, groundY: CGFloat, library: SpriteLibrary,
                      into parent: SKNode) -> [ParallaxNode] {
        var parallax: [ParallaxNode] = []
        if let sky = library.textures("bg_\(theme)_sky", "still").first {
            // The banded sky keeps its drawn height and sits on the ground line, so the horizon looks the
            // same in both orientations; anything above it is filled with the sky's top colour.
            let bandHeight: CGFloat = 200
            let node = SKSpriteNode(texture: sky, size: CGSize(width: size.width, height: bandHeight))
            node.anchorPoint = .zero
            node.position.y = groundY
            node.zPosition = -10
            parent.addChild(node)
            let above = size.height - groundY - bandHeight
            if above > 0, let topColour = library.textures("bg_\(theme)_sky_top", "still").first {
                let fill = SKSpriteNode(texture: topColour, size: CGSize(width: size.width, height: above + 1))
                fill.anchorPoint = .zero
                fill.position.y = groundY + bandHeight - 1
                fill.zPosition = -10
                parent.addChild(fill)
            }
        }
        if let fill = library.textures("ground_\(theme)_fill", "still").first {
            let node = SKSpriteNode(texture: fill, size: CGSize(width: size.width, height: groundY))
            node.anchorPoint = .zero
            node.zPosition = -5
            parent.addChild(node)
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
            parent.addChild(node)
            parallax.append(node)
        }
        let name = "ground_\(theme)"
        if let texture = library.textures(name, "still").first, let sheet = library.sheet(name) {
            let node = ParallaxNode(texture: texture, size: CGSize(width: sheet.width, height: sheet.height),
                                    viewWidth: size.width, factor: 1)
            node.position.y = groundY - sheet.height
            node.zPosition = -4
            parent.addChild(node)
            parallax.append(node)
            // Upright the earth runs deeper than the tile; keep it textured and scrolling as one piece.
            if let earth = library.textures("\(name)_earth", "still").first, let earthSheet = library.sheet("\(name)_earth") {
                for row in ParallaxNode.earth(below: node.position.y, tile: earth,
                                              tileSize: CGSize(width: earthSheet.width, height: earthSheet.height),
                                              viewWidth: size.width) {
                    row.zPosition = -4
                    parent.addChild(row)
                    parallax.append(row)
                }
            }
        }
        return parallax
    }
}
