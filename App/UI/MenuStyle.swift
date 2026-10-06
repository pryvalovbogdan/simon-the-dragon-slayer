import GameCore
import SpriteKit
import SwiftUI

extension Color {
    static let menuInk = Color(red: 0.11, green: 0.08, blue: 0.13)
    static let menuPaper = Color(red: 0.96, green: 0.96, blue: 0.94)
}

/// The scene behind the menu and the end screen, rebuilt whenever the screen changes shape.
struct MenuBackground: View {
    var pose = MenuScene.Pose.running

    @Environment(AppModel.self) private var model
    @Environment(\.displayScale) private var displayScale
    @State private var scene: MenuScene?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.44, green: 0.71, blue: 0.88)
                if let scene {
                    // Only the running scene scrolls; at rest half the frame rate is plenty.
                    SpriteView(scene: scene, preferredFramesPerSecond: pose == .running ? 60 : 30)
                }
            }
            .onAppear { scene = makeScene(proxy.size) }
            .onChange(of: proxy.size) { _, newSize in scene = makeScene(newSize) }
        }
        .ignoresSafeArea()
    }

    private func makeScene(_ size: CGSize) -> MenuScene {
        MenuScene(viewSize: size, displayScale: displayScale, library: model.sprites, pose: pose)
    }
}

/// The game's name as a chunky two-line logo with a dark outline.
struct PixelTitle: View {
    let text: String
    let size: CGFloat
    var alignment = HorizontalAlignment.leading
    /// One flat colour instead of the two-tone logo fill; used for numerals.
    var tint: Color?

    private static let outline: [CGSize] = [-1, 0, 1].flatMap { x in [-1, 0, 1].map { CGSize(width: x, height: $0) } }
        + [CGSize(width: 0, height: 2)]

    private var lines: [String] {
        let words = text.uppercased().split(separator: " ")
        guard words.count > 2 else { return [text.uppercased()] }
        let first = words.count / 2
        return [words.prefix(first).joined(separator: " "), words.dropFirst(first).joined(separator: " ")]
    }

    /// Outline thickness, in step with the lettering so small text is not swamped by it.
    private var weight: CGFloat { max(1.5, size * 0.075) }

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            ForEach(lines, id: \.self) { line in
                ZStack {
                    ForEach(Self.outline.indices, id: \.self) { index in
                        Text(line)
                            .foregroundStyle(Color.menuInk)
                            .offset(x: Self.outline[index].width * weight, y: Self.outline[index].height * weight)
                    }
                    Text(line).foregroundStyle(LinearGradient(
                        stops: [.init(color: tint ?? .menuPaper, location: 0.52), .init(color: tint ?? .orange, location: 0.52)],
                        startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .font(.pixel(size))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// One frame of a generated sprite as a SwiftUI image, kept crisp at any size.
struct SpriteImage: View {
    @Environment(AppModel.self) private var model
    let sprite: String
    let animation: String

    var body: some View {
        if let image = model.sprites.textures(sprite, animation).first?.cgImage() {
            Image(decorative: image, scale: 1).interpolation(.none).resizable()
        }
    }
}

/// Frame shared by the menu's buttons: a dark edge with a light line inside it.
struct MenuPanel: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .background(fill, in: Rectangle())
            .overlay(Rectangle().inset(by: 4.5).stroke(Color.menuPaper, lineWidth: 3))
            .overlay(Rectangle().stroke(Color.menuInk, lineWidth: 3))
    }
}
