import GameCore
import SwiftUI

/// The end of a run: a title, a card with the medal, the score and the best score, then the buttons,
/// over the same backdrop as the start screen.
struct ResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let levelIndex: Int
    let result: GameResult

    private var level: LevelDefinition { model.levels[levelIndex] }
    /// The score this screen is about: the whole run in endless, the level otherwise.
    private var score: Int { model.endless?.score ?? result.score }
    private var savedBest: Int { model.endless != nil ? model.save.bestEndlessScore : model.save.bestScores[level.id] ?? 0 }
    /// Only a finished level counts toward its best; an endless run always counts.
    private var counts: Bool { model.endless != nil || result.won }
    private var best: Int { counts ? max(savedBest, score) : savedBest }

    private var medal: Medal? {
        if let run = model.endless { return Medal.forEndless(cleared: run.cleared, levelCount: model.levels.count) }
        return Medal.forLevel(won: result.won, hearts: result.hearts, maxHearts: HeroStats().maxHearts)
    }

    var body: some View {
        let sideBySide = verticalSizeClass == .compact
        ZStack {
            MenuBackground(pose: result.won ? .standing : .fallen)
            GeometryReader { proxy in
                if sideBySide {
                    // The hero stands at the left edge here, so everything keeps to a centre column.
                    VStack(spacing: 12) {
                        title(size: 32)
                        card(notesBeside: true)
                        HStack(spacing: 10) { buttons }
                    }
                    .frame(width: min(420, proxy.size.width * 0.52))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        title(size: 40).padding(.top, 20)
                        card(notesBeside: false).padding(.top, 18)
                        Spacer(minLength: 0)
                        VStack(spacing: 8) { buttons }
                            .frame(height: proxy.size.height * (MenuScene.narrowGroundShare - 0.05), alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func title(size: CGFloat) -> some View {
        PixelTitle(text: result.won ? "Level cleared" : "Game over", size: size, alignment: .center)
    }

    /// On a wide, short screen the small print goes between the medal and the numbers to save height.
    private func card(notesBeside: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    label("MEDAL")
                    MedalView(medal: medal)
                }
                if notesBeside {
                    noteLines.padding(.top, 24).padding(.leading, 10)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    label("SCORE")
                    PixelTitle(text: "\(score)", size: 28, tint: .menuPaper).fixedSize()
                    HStack(spacing: 6) {
                        if counts, score > 0, score >= savedBest {
                            Text("NEW").font(.pixel(9)).foregroundStyle(Color.menuPaper)
                                .padding(.horizontal, 4).padding(.vertical, 2)
                                .background(Color.red, in: Rectangle())
                        }
                        label("BEST")
                    }
                    .padding(.top, 4)
                    PixelTitle(text: "\(best)", size: 28, tint: .menuPaper).fixedSize()
                }
            }
            if !notesBeside {
                noteLines.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .modifier(MenuPanel(fill: Self.cardFill))
    }

    private var noteLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(notes, id: \.self) { note in
                Text(note).font(.pixel(11)).foregroundStyle(Color.menuInk.opacity(0.8))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private static let cardFill = Color(red: 0.85, green: 0.75, blue: 0.54)
    private static let cardInk = Color(red: 0.62, green: 0.42, blue: 0.1)

    private func label(_ text: String) -> some View {
        Text(text).font(.pixel(12)).foregroundStyle(Self.cardInk)
    }

    /// The small print under the numbers: how far the run got, and anything it unlocked.
    private var notes: [String] {
        if let run = model.endless { return ["LEVELS \(run.cleared)"] }
        let abilities = result.won ? result.unlocked.map { "NEW: \(model.text("ability.\($0.rawValue)").uppercased())" } : []
        return [model.text(level.nameKey).uppercased()] + abilities
    }

    @ViewBuilder private var buttons: some View {
        if model.endless != nil {
            ResultButton(title: "RETRY") { model.startEndless() }
        } else {
            if result.won, model.isUnlocked(levelIndex + 1) {
                ResultButton(title: "NEXT LEVEL") { model.start(level: levelIndex + 1) }
            }
            ResultButton(title: "RETRY") { model.start(level: levelIndex) }
        }
        ResultButton(title: "MENU") { model.quit() }
    }
}

/// The medal earned, drawn from the sprite atlas, or an empty slot when there is none.
private struct MedalView: View {
    let medal: Medal?

    var body: some View {
        Group {
            if let medal {
                SpriteImage(sprite: "medal", animation: medal.rawValue)
            } else {
                Circle().stroke(Color.menuInk.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [6, 5])).padding(8)
            }
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel(medal.map { "\($0.rawValue) medal" } ?? "No medal")
    }
}

private struct ResultButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(18))
                .foregroundStyle(Color.menuPaper)
                .shadow(color: .menuInk.opacity(0.6), radius: 0, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .modifier(MenuPanel(fill: .orange))
        }
    }
}
