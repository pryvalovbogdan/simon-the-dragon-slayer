import GameCore
import SwiftUI

struct ResultView: View {
    @Environment(AppModel.self) private var model
    let levelIndex: Int
    let result: GameResult

    var body: some View {
        ZStack {
            (result.won ? Color(red: 0.1, green: 0.25, blue: 0.18) : Color(red: 0.25, green: 0.08, blue: 0.1))
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(result.won ? "LEVEL CLEARED" : "YOU FELL").font(.pixel(32))
                    .foregroundStyle(result.won ? .yellow : .red)
                Text(model.text(model.levels[levelIndex].nameKey).uppercased()).font(.pixel(14))
                Text("SCORE \(result.score)   ·   HERO LV \(result.heroLevel)").font(.pixel(14))
                ForEach(result.won ? result.unlocked : [], id: \.self) { ability in
                    Text("NEW: \(model.text("ability.\(ability.rawValue)").uppercased())")
                        .font(.pixel(14)).foregroundStyle(.orange)
                }
                // Side by side when there is room (landscape), stacked when there is not (portrait).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { buttons }
                    VStack(spacing: 12) { buttons }
                }
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder private var buttons: some View {
        if result.won, levelIndex + 1 < model.levels.count {
            Button("NEXT LEVEL") { model.start(level: levelIndex + 1) }.buttonStyle(PixelButton())
        }
        Button("RETRY") { model.start(level: levelIndex) }.buttonStyle(PixelButton(tint: .white))
        Button("MENU") { model.screen = .menu }.buttonStyle(PixelButton(tint: .gray))
    }
}
