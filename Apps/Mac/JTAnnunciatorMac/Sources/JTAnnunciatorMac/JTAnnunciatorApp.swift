import SwiftUI
import AppKit

@main
struct JTAnnunciatorApp: App {
    @StateObject private var viewModel = AnnunciatorViewModel()

    init() {
        // Launched via `swift run` there is no .app bundle, so macOS defaults to a background
        // (no Dock icon / no window focus) activation policy. Force a regular foreground app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            AnnunciatorView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 560)
                .onAppear { viewModel.start() }
                .onDisappear { viewModel.stop() }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                ColorKeyCommand()
            }
        }

        Window("Color Key", id: ColorKeyView.windowID) {
            ColorKeyView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(minWidth: 480, idealWidth: 520, maxWidth: .infinity, minHeight: 420, idealHeight: 560, maxHeight: .infinity)
        }
        // `.contentMinSize` (rather than the `.automatic` default) is what actually puts a drag
        // handle on a `Settings` window: it lets the window grow past its ideal size instead of
        // pinning to it, and shrink down to `minWidth`/`minHeight` above with each tab's own
        // ScrollView (see SettingsView) taking over once it's smaller than the tab's content.
        .windowResizability(.contentMinSize)
    }
}
