import Foundation
import GameCore
import Observation

/// What the SwiftUI overlay shows; the scene writes it once per frame.
@MainActor
@Observable
final class GameHUD {
    var hearts = 3
    var maxHearts = 3
    var heroLevel = 1
    /// Progress toward the next hero level, 0...1 (1 at max level).
    var xpFraction = 0.0
    var canFire = false
    var canCharge = false
    /// How full the charged shot is, 0...1.
    var chargeFraction = 0.0
    var bossName: String?
    var bossFraction = 1.0
    var banner: String?
    /// An ability just won, shown as an award card for a moment.
    var award: Ability?
    var isPaused = false
}
