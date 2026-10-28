import GameCore
import SpriteKit
import SwiftUI

struct GameView: View {
    @Environment(AppModel.self) private var model
    let levelIndex: Int
    @State private var hud = GameHUD()
    @State private var scene: GameScene?

    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase

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
            HUDView(hud: hud,
                    jump: { scene?.setJump(held: $0) },
                    fire: { scene?.setFire(held: $0) },
                    quit: { model.quit() })
        }
        // The buttons sit near the screen's edges: iOS must not hold their touches back (or take
        // them) for its own edge swipes, nor show the home indicator over them, during play.
        .defersSystemGestures(on: .all)
        .persistentSystemOverlays(.hidden)
        // Leaving the app mid-level pauses it, so the player comes back to the resume screen, not a
        // run that carried on (or a hit taken) while they were away.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { hud.isPaused = true }
        }
        .onAppear {
            // A level can open while the app is away: the next-level screen starts it after a countdown.
            // A bot run opens its level at launch, before the app is active, and must not wait on a tap.
            if scenePhase != .active, !model.autoplay { hud.isPaused = true }
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
            // Bot and other debug runs stay silent.
            soundOn: model.soundOn,
            autoplay: model.autoplay,
            timeScale: model.endless?.speed ?? 1,
            openingBanner: openingBanner(for: level),
            text: { model.text($0) },
            onFinish: { model.finish(level: levelIndex, result: $0) }
        )
    }
}

extension GameView {
    /// In an endless run each level announces itself, and a new loop its number and speed.
    private func openingBanner(for level: LevelDefinition) -> String? {
        guard let run = model.endless else { return nil }
        guard run.startsNewLoop else { return model.text(level.nameKey).uppercased() }
        return NextLevelView.loopTitle(run)
    }
}

private struct HUDView: View {
    let hud: GameHUD
    let jump: (Bool) -> Void
    let fire: (Bool) -> Void
    let quit: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Upright, the buttons sit a little in from the corners and up off the bottom edge, nearer the thumbs.
    private var upright: Bool { verticalSizeClass != .compact }

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
                if let ability = hud.award {
                    AwardCard(ability: ability)
                        .padding(.top, 8)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: hud.award)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Only these two buttons take game input: fire on the left, jump on the right.
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if hud.canFire {
                        HoldButton(onChange: fire) {
                            ZStack {
                                Circle().fill(.black.opacity(0.15))
                                Circle().trim(from: 0, to: hud.canCharge ? hud.chargeFraction : 0)
                                    .stroke(Color.orange, lineWidth: 5)
                                    .rotationEffect(.degrees(-90))
                                Image(systemName: "flame.fill").font(.largeTitle).foregroundStyle(.orange)
                            }
                        }
                        .accessibilityLabel("Fireball")
                    }
                    Spacer()
                    HoldButton(onChange: jump) {
                        ZStack {
                            Circle().fill(.black.opacity(0.15))
                            if hud.canDoubleJump { FlameRing() }
                            SpriteImage(sprite: "ability_\(Ability.doubleJump.rawValue)", animation: "still")
                                .frame(width: 48, height: 48)
                        }
                    }
                    .accessibilityLabel("Jump")
                }
                // On its side the safe area already keeps the buttons clear of the notch, so they can
                // reach a little past it towards the edges.
                .padding(.horizontal, upright ? 26 : -14)
                .padding(.bottom, upright ? 20 : 0)
            }
            .disabled(hud.isPaused)

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

/// A round on-screen button that reports when a finger goes down on it and when it lifts. The
/// touch area reaches a little past the drawn circle so a thumb that lands just off it still counts.
private struct HoldButton<Label: View>: View {
    let onChange: (Bool) -> Void
    @ViewBuilder let label: () -> Label
    @State private var isPressed = false

    var body: some View {
        label()
            .frame(width: 88, height: 88)
            .scaleEffect(isPressed ? 0.92 : 1)
            .opacity(isPressed ? 0.9 : 0.55)
            .padding(14)
            // Touches come straight from UIKit (a SwiftUI gesture lost holds on a real device: every
            // jump came out a tap). The pad covers the whole circle, padding included.
            .overlay {
                TouchPad { pressed in
                    guard pressed != isPressed else { return }
                    isPressed = pressed
                    onChange(pressed)
                }
                .clipShape(Circle())
            }
            .onDisappear {
                if isPressed {
                    isPressed = false
                    onChange(false)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            // VoiceOver's double tap: a short press.
            .accessibilityAction {
                onChange(true)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.15))
                    onChange(false)
                }
            }
    }
}

/// A transparent UIKit view that reports a press: held from the moment a finger lands on it until
/// that same finger lifts or the system cancels it, with nothing in between (moving the finger, other
/// fingers on other buttons) changing that. Hit-tests as a circle filling its bounds.
private struct TouchPad: UIViewRepresentable {
    let onChange: (Bool) -> Void

    func makeUIView(context: Context) -> TouchPadView {
        let view = TouchPadView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: TouchPadView, context: Context) {
        view.onChange = onChange
    }

    static func dismantleUIView(_ view: TouchPadView, coordinator: ()) {
        view.release()
    }
}

final class TouchPadView: UIView {
    var onChange: ((Bool) -> Void)?
    /// The finger that pressed this button; others are ignored until it lifts.
    private var touch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isExclusiveTouch = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Recognizers up the hierarchy (SwiftUI's, the window's) must neither hold a touch back until
        // they give up on it nor cancel it when they recognise something.
        var view: UIView? = superview
        while let current = view {
            for recognizer in current.gestureRecognizers ?? [] {
                recognizer.delaysTouchesBegan = false
                recognizer.delaysTouchesEnded = false
                recognizer.cancelsTouchesInView = false
            }
            view = current.superview
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let radius = min(bounds.width, bounds.height) / 2
        return hypot(point.x - bounds.midX, point.y - bounds.midY) <= radius
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touch == nil, let first = touches.first else { return }
        touch = first
        onChange?(true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lift(touches)
    }

    private func lift(_ touches: Set<UITouch>) {
        guard let touch, touches.contains(touch) else { return }
        release()
    }

    /// Lets go (the finger lifted, or the button is going away).
    func release() {
        guard touch != nil else { return }
        touch = nil
        onChange?(false)
    }
}

/// A ring of fire that spins and flickers around the jump button once the double jump is won.
private struct FlameRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let colors: [Color] = [.red, .orange, .yellow, .orange, .red, .orange, .yellow, .orange, .red]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let flicker = 0.5 + 0.5 * sin(t * 9) * sin(t * 5.3)
            ZStack {
                Circle()
                    .stroke(AngularGradient(colors: colors, center: .center), lineWidth: 5)
                    .rotationEffect(.radians(t * 2.5))
                    .blur(radius: 4 + 3 * flicker)
                Circle()
                    .stroke(AngularGradient(colors: colors, center: .center), lineWidth: 4)
                    .rotationEffect(.radians(-t * 1.7))
            }
            .opacity(0.75 + 0.25 * flicker)
        }
        .allowsHitTesting(false)
    }
}

/// The award for a new ability: its icon and name on a gold card.
private struct AwardCard: View {
    @Environment(AppModel.self) private var model
    let ability: Ability

    var body: some View {
        HStack(spacing: 12) {
            SpriteImage(sprite: "ability_\(ability.rawValue)", animation: "still").frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("NEW ABILITY").font(.pixel(10)).foregroundStyle(Color.menuInk.opacity(0.75))
                PixelTitle(text: model.text("ability.\(ability.rawValue)"), size: 20).fixedSize()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .modifier(MenuPanel(fill: Color(red: 0.95, green: 0.78, blue: 0.27)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New ability: \(model.text("ability.\(ability.rawValue)"))")
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
