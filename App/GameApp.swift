import SwiftUI

@main
struct GameApp: App {
    @State private var model = AppModel()

    #if DEBUG
    /// `-orientation landscape|portrait` rotates the app at launch. The simulator cannot be rotated
    /// from the command line, so Tools/run-sim.sh uses this to screenshot both orientations.
    private static func applyDebugOrientation() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-orientation"), arguments.indices.contains(flag + 1),
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let mask: UIInterfaceOrientationMask = arguments[flag + 1] == "landscape" ? .landscapeRight : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                #if DEBUG
                .onAppear(perform: Self.applyDebugOrientation)
                #endif
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.screen {
        case .menu:
            MenuView()
        case .playing(let index, let attempt):
            GameView(levelIndex: index).id(attempt)
        case .finished(let index, let result):
            ResultView(levelIndex: index, result: result)
        }
    }
}
