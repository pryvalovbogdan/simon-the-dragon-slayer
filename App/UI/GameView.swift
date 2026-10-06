import GameCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    let levelIndex: Int
    @State private var hud = GameHUD()
    @State private var scene: GameScene?

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            // The game fills the whole screen; the HUD below stays inside the safe area so it clears
            // the notch, Dynamic Island and home indicator in either orientation.
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    if let scene {
                        SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    }
                }
                .onAppear { if scene == nil { scene = makeScene(viewSize: proxy.size) } }
                .onChange(of: proxy.size) { _, newSize in scene?.layout(viewSize: newSize) }
            }
            .ignoresSafeArea()
            HUDView(hud: hud, quit: { model.screen = .menu })
        }
    }

    private func makeScene(viewSize: CGSize) -> GameScene {
        let level = model.levels[levelIndex]
        return GameScene(
            viewSize: viewSize,
            displayScale: displayScale,
            level: level,
            boss: model.bosses[level.boss],
            stats: model.startingStats(for: levelIndex),
            library: model.sprites,
            hud: hud,
            // Bot runs are for debugging and stay silent.
            soundOn: model.save.soundOn && !model.autoplay,
            autoplay: model.autoplay,
            text: { model.text($0) },
            onFinish: { model.finish(level: levelIndex, result: $0) }
        )
    }
}

private struct HUDView: View {
    let hud: GameHUD
    let quit: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(0..<hud.maxHearts, id: \.self) { index in
                            Image(systemName: index < hud.hearts ? "heart.fill" : "heart")
                                .foregroundStyle(index < hud.hearts ? Color.red : Color.white.opacity(0.5))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LV \(hud.heroLevel)").font(.pixel(13))
                        Bar(fraction: hud.xpFraction, color: .yellow).frame(width: 90, height: 6)
                    }
                    Spacer()
                    Button {
                        hud.isPaused.toggle()
                    } label: {
                        Image(systemName: hud.isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel(hud.isPaused ? "Resume" : "Pause")
                }
                if let boss = hud.bossName {
                    VStack(spacing: 2) {
                        Text(boss.uppercased()).font(.pixel(11))
                        Bar(fraction: hud.bossFraction, color: .red).frame(maxWidth: 240).frame(height: 8)
                    }
                }
                if let banner = hud.banner {
                    Text(banner)
                        .font(.pixel(18))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.top, 8)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if hud.canFire {
                // Shows where to press; the scene itself reads the touches.
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(.black.opacity(0.3))
                            Circle().trim(from: 0, to: hud.canCharge ? hud.chargeFraction : 0)
                                .stroke(Color.orange, lineWidth: 5)
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "flame.fill").font(.title).foregroundStyle(.orange)
                        }
                        .frame(width: 72, height: 72)
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                    }
                }
                .allowsHitTesting(false)
            }

            if hud.isPaused {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("PAUSED").font(.pixel(28))
                    Button("RESUME") { hud.isPaused = false }.buttonStyle(PixelButton())
                    Button("QUIT TO MENU", action: quit).buttonStyle(PixelButton(tint: .gray))
                }
            }
        }
        .foregroundStyle(.white)
    }
}

struct Bar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.5))
                Rectangle().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
            .overlay(Rectangle().stroke(.white.opacity(0.8), lineWidth: 1))
        }
    }
}

struct PixelButton: ButtonStyle {
    var tint = Color.orange

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(16))
            .foregroundStyle(.black)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(tint.opacity(configuration.isPressed ? 0.6 : 1), in: Rectangle())
            .overlay(Rectangle().stroke(.black, lineWidth: 2))
    }
}

extension Font {
    static func pixel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}
