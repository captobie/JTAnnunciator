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
                .frame(minWidth: 480, idealWidth: 520, maxWidth: .infinity, minHeight: 420, idealHeight: 480, maxHeight: .infinity)
        }
    }
}
