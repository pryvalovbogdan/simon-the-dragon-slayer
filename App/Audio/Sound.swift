import AVFoundation

enum Sound: String, CaseIterable {
    case jump, doubleJump = "double_jump", fire, charged, impact, stomp, coin, hurt, block
    case bossHit = "boss_hit", levelUp = "level_up", win, lose, bossRoar = "boss_roar"
}

/// Plays the sound effects. Every file is read and prepared when the level is built: SpriteKit's
/// `playSoundFileNamed` loads the file and starts the audio system on first use, which stalled the
/// frame of the first jump.
final class SoundPlayer {
    /// A few copies of each sound so quick repeats (coins, fireballs) can overlap.
    private static let voices = 3
    /// Effects play a little under full volume.
    private static let volume: Float = 0.7
    private var players: [Sound: [AVAudioPlayer]] = [:]

    init(bundle: Bundle = .main) {
        for sound in Sound.allCases {
            guard let url = bundle.url(forResource: sound.rawValue, withExtension: "wav") else { continue }
            players[sound] = (0..<Self.voices).compactMap { _ in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.volume = Self.volume
                player.prepareToPlay()
                return player
            }
        }
    }

    func play(_ sound: Sound) {
        guard let voices = players[sound], !voices.isEmpty else { return }
        // A free copy if there is one, otherwise restart the first.
        let player = voices.first { !$0.isPlaying } ?? voices[0]
        player.currentTime = 0
        player.play()
    }
}

/// The theme on the start and end screens: loops, fades in when a menu screen appears and fades out
/// (keeping its place) when a level starts.
final class MusicPlayer {
    private let player: AVAudioPlayer?
    private static let volume: Float = 0.2
    private static let fade: TimeInterval = 0.5
    /// Bumped on every change so a fade-out that finishes late cannot pause music started since.
    private var generation = 0

    init(bundle: Bundle = .main) {
        player = bundle.url(forResource: "menu_theme", withExtension: "m4a").flatMap { try? AVAudioPlayer(contentsOf: $0) }
        player?.numberOfLoops = -1
        player?.prepareToPlay()
    }

    func play() {
        guard let player else { return }
        generation += 1
        if !player.isPlaying {
            player.volume = 0
            player.play()
        }
        player.setVolume(Self.volume, fadeDuration: Self.fade)
    }

    /// Silences the music at once, for when the app leaves the screen.
    func pauseNow() {
        guard let player else { return }
        generation += 1
        player.pause()
    }

    func stop() {
        guard let player, player.isPlaying else { return }
        generation += 1
        let fadingOut = generation
        player.setVolume(0, fadeDuration: Self.fade)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fade) { [weak self] in
            guard let self, self.generation == fadingOut else { return }
            player.pause()
        }
    }
}
