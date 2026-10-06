import GameCore
import SwiftUI

struct MenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // An iPhone on its side has a compact height: title and hero on the left, buttons on the
        // right. Upright, the title is at the top and the buttons sit on the earth under the hero.
        let sideBySide = verticalSizeClass == .compact
        ZStack {
            MenuBackground()
            GeometryReader { proxy in
                if sideBySide {
                    HStack(alignment: .top, spacing: 24) {
                        PixelTitle(text: model.text("game.title"), size: 34)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        actions.frame(width: min(330, proxy.size.width * 0.44)).frame(maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        PixelTitle(text: model.text("game.title"), size: 40, alignment: .center)
                            .padding(.top, 64)
                        Spacer(minLength: 0)
                        actions.frame(height: proxy.size.height * (MenuScene.narrowGroundShare - 0.05), alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            SoundButton()
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: sideBySide ? .bottomLeading : .topTrailing)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            StartButton()
            // A level shows up here once it has been beaten in an endless run.
            ForEach(model.levels.indices.filter(model.isUnlocked), id: \.self) { index in
                LevelRow(index: index)
            }
        }
    }
}

/// Starts an endless run: every level in order, round and round.
private struct StartButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.startEndless()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("START").font(.pixel(24))
                    Text(model.text("mode.endless.name")).font(.pixel(10))
                }
                Spacer()
                if model.save.bestEndlessScore > 0 {
                    Text("BEST \(model.save.bestEndlessScore)").font(.pixel(11))
                }
                Image(systemName: "play.fill")
            }
            .foregroundStyle(Color.menuPaper)
            .shadow(color: .menuInk.opacity(0.6), radius: 0, x: 0, y: 2)
            .padding(.vertical, 13)
            .modifier(MenuPanel(fill: .orange))
        }
        .accessibilityLabel("Start, \(model.text("mode.endless.name"))")
    }
}

private struct LevelRow: View {
    @Environment(AppModel.self) private var model
    let index: Int

    var body: some View {
        let level = model.levels[index]
        Button {
            model.start(level: index)
        } label: {
            HStack {
                Text("\(index + 1)").font(.pixel(18)).frame(width: 24)
                Text(model.text(level.nameKey).uppercased()).font(.pixel(13)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                if let best = model.save.bestScores[level.id] {
                    Text("BEST \(best)").font(.pixel(10))
                }
                Image(systemName: "play.fill").font(.caption)
            }
            .foregroundStyle(Color.menuInk)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(Color.menuPaper, in: Rectangle())
            .overlay(Rectangle().stroke(Color.menuInk, lineWidth: 3))
        }
        .accessibilityLabel("Level \(index + 1), \(model.text(level.nameKey))")
    }
}

private struct SoundButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let on = model.save.soundOn
        Button {
            model.setSound(on: !on)
        } label: {
            Image(systemName: on ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.body.weight(.bold))
                .foregroundStyle(Color.menuInk)
                .frame(width: 42, height: 42)
                .background(Color.menuPaper, in: Rectangle())
                .overlay(Rectangle().stroke(Color.menuInk, lineWidth: 3))
        }
        .accessibilityLabel(on ? "Sound on" : "Sound off")
    }
}
