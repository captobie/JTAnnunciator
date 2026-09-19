import SwiftUI

@main
struct JTAnnunciatorApp: App {
    @StateObject private var viewModel = AnnunciatorViewModel()

    var body: some Scene {
        WindowGroup {
            AnnunciatorView(viewModel: viewModel)
                .frame(minWidth: 720, minHeight: 480)
                .onAppear { viewModel.start() }
                .onDisappear { viewModel.stop() }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(viewModel: viewModel)
                .frame(width: 480, height: 360)
        }
    }
}
