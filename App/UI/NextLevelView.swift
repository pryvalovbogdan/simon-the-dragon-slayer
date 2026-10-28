import GameCore
import SwiftUI

/// Between two levels of an endless run: the next level's name over its own scenery, with the hero
/// running through it, and a card with the score so far. Starts the level by itself after a moment.
struct NextLevelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let levelIndex: Int

    /// How long the screen stays before the level starts on its own.
    static let wait = 4.0
    @State private var countdown = 1.0

    private var level: LevelDefinition { model.levels[levelIndex] }

    var body: some View {
        let sideBySide = verticalSizeClass == .compact
        ZStack {
            MenuBackground(theme: level.background)
            GeometryReader { proxy in
                if sideBySide {
                    // The hero runs on the left, as on the start screen; the card keeps to the right.
                    VStack(spacing: 12) {
                        heading(size: 30)
                        card
                        goButton
                    }
                    .frame(width: min(380, proxy.size.width * 0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                } else {
                    VStack(spacing: 0) {
                        heading(size: 36).padding(.top, 20)
                        card.padding(.top, 18)
                        Spacer(minLength: 0)
                        goButton
                            .frame(height: proxy.size.height * (MenuScene.narrowGroundShare - 0.05), alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .task {
            withAnimation(.linear(duration: Self.wait)) { countdown = 0 }
            try? await Task.sleep(for: .seconds(Self.wait))
            if !Task.isCancelled { model.continueEndless() }
        }
    }

    /// "Next level" (or the new loop and its speed) over the level's name.
    private func heading(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(subtitle)
                .font(.pixel(13))
                .foregroundStyle(Color.menuPaper)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.menuInk.opacity(0.55), in: Capsule())
            // A dark strip keeps the name readable over busy or bright scenery.
            PixelTitle(text: model.text(level.nameKey), size: size, alignment: .center)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.menuInk.opacity(0.45), in: Rectangle())
        }
    }

    private var subtitle: String {
        guard let run = model.endless else { return "NEXT LEVEL" }
        if run.startsNewLoop {
            return Self.loopTitle(run)
        }
        return "LEVEL \(levelIndex + 1) OF \(model.levels.count)"
    }

    /// "LOOP 2 — SPEED ×1.15". Always a dot, whatever the phone's region writes for decimals.
    static func loopTitle(_ run: EndlessRun) -> String {
        let speed = run.speed.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US_POSIX")))
        return "LOOP \(run.loop) — SPEED ×\(speed)"
    }

    private var card: some View {
        let run = model.endless
        let hero = model.startingStats(for: levelIndex)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                label("SCORE")
                PixelTitle(text: "\(run?.score ?? 0)", size: 28, tint: .menuPaper).fixedSize()
                label("LEVELS \(run?.cleared ?? 0)").padding(.top, 4)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                label("HERO LV \(hero.level)")
                HStack(spacing: 4) {
                    ForEach(0..<hero.maxHearts, id: \.self) { index in
                        Image(systemName: index < hero.hearts ? "heart.fill" : "heart")
                            .foregroundStyle(index < hero.hearts ? Color.red : Color.menuInk.opacity(0.4))
                    }
                }
                .font(.title3)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(hero.hearts) of \(hero.maxHearts) hearts")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .modifier(MenuPanel(fill: .cardFill))
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.pixel(12)).foregroundStyle(Color.cardInk)
    }

    /// Starts the level now; the bar running out along its bottom shows when it would start anyway.
    private var goButton: some View {
        ResultButton(title: "GO") { model.continueEndless() }
            .overlay(alignment: .bottomLeading) {
                GeometryReader { proxy in
                    Rectangle().fill(Color.menuPaper.opacity(0.8))
                        .frame(width: proxy.size.width * countdown, height: 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .padding(7)
                .allowsHitTesting(false)
            }
    }
}
