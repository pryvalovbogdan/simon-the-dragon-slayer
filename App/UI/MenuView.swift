import GameCore
import SwiftUI

struct MenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // An iPhone on its side has a compact height: two columns there, one stacked column upright.
        let sideBySide = verticalSizeClass == .compact
        let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 28)) : AnyLayout(VStackLayout(spacing: 22))
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.2, blue: 0.36), Color(red: 0.3, green: 0.17, blue: 0.47)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            layout {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.text("game.title").uppercased())
                        .font(.pixel(30))
                        .foregroundStyle(.orange)
                        .minimumScaleFactor(0.6)
                    let level = Progression.level(forXP: model.save.xp)
                    Text("\(model.text("hero.name").uppercased()) · LV \(level)").font(.pixel(14))
                    ForEach(Ability.allCases, id: \.self) { ability in
                        let owned = Progression.abilities(forLevel: level).contains(ability)
                        Label(model.text("ability.\(ability.rawValue)"), systemImage: owned ? "checkmark.square.fill" : "square")
                            .font(.pixel(12))
                            .opacity(owned ? 1 : 0.45)
                    }
                    if sideBySide { Spacer() }
                    Toggle(isOn: Binding(get: { model.save.soundOn }, set: { model.setSound(on: $0) })) {
                        Text("SOUND").font(.pixel(12))
                    }
                    .frame(width: 150)
                    .tint(.orange)
                }
                .frame(maxWidth: sideBySide ? 260 : .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(model.levels.indices, id: \.self) { index in
                        LevelRow(index: index)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
    }
}

private struct LevelRow: View {
    @Environment(AppModel.self) private var model
    let index: Int

    var body: some View {
        let level = model.levels[index]
        let unlocked = model.isUnlocked(index)
        Button {
            model.start(level: index)
        } label: {
            HStack {
                Text("\(index + 1)").font(.pixel(22)).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text(level.nameKey).uppercased()).font(.pixel(15))
                    Text(model.text("\(level.boss).name")).font(.pixel(10)).opacity(0.75)
                }
                Spacer()
                if let best = model.save.bestScores[level.id] {
                    Text("BEST \(best)").font(.pixel(10))
                }
                Image(systemName: unlocked ? "play.fill" : "lock.fill")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.black.opacity(unlocked ? 0.4 : 0.2), in: Rectangle())
            .overlay(Rectangle().stroke(.white.opacity(unlocked ? 0.8 : 0.25), lineWidth: 2))
            .opacity(unlocked ? 1 : 0.5)
        }
        .disabled(!unlocked)
        .accessibilityLabel("Level \(index + 1), \(model.text(level.nameKey))\(unlocked ? "" : ", locked")")
    }
}
