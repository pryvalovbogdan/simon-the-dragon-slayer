import SpriteKit

enum Sound: String {
    case jump, doubleJump = "double_jump", fire, charged, impact, stomp, coin, hurt, block
    case bossHit = "boss_hit", levelUp = "level_up", win, lose, bossRoar = "boss_roar"

    var action: SKAction {
        .playSoundFileNamed("\(rawValue).wav", waitForCompletion: false)
    }
}
