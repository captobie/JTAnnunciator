import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: AnnunciatorViewModel

    @State private var ctyDatPath: String = AppSettings.ctyDatPath ?? ""
    @State private var udpPortText: String = String(AppSettings.udpPort)
    @State private var alertSoundEnabled: Bool = AppSettings.alertSoundEnabled

    var body: some View {
        Form {
            Section("WSJT-X Connection") {
                HStack {
                    Text("UDP Port")
                    TextField("2237", text: $udpPortText)
                        .frame(width: 80)
                        .onSubmit(applyUDPPort)
                }
                Text("Must match WSJT-X's Settings → Reporting → UDP Server port. Changing this requires restarting the listener (Cmd+Q and relaunch, or toggle via the main window).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("DXCC Data") {
                HStack {
                    Text(ctyDatPath.isEmpty ? "No cty.dat file selected" : ctyDatPath)
                        .font(.callout)
                        .foregroundStyle(ctyDatPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose…", action: chooseCTYDatFile)
                }
                Text("A cty.dat file (as used by N1MM, Log4OM, and most other logging programs) drives wanted-DXCC alerts. Get one from your logging program's install, or from country-files.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Alerts") {
                Toggle("Play sound on alert", isOn: $alertSoundEnabled)
                    .onChange(of: alertSoundEnabled) { newValue in
                        AppSettings.alertSoundEnabled = newValue
                    }
            }
        }
        .padding(20)
    }

    private func applyUDPPort() {
        guard let value = UInt16(udpPortText) else { return }
        AppSettings.udpPort = value
    }

    private func chooseCTYDatFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a cty.dat DXCC country file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        AppSettings.ctyDatPath = url.path
        ctyDatPath = url.path
        viewModel.reloadDXCCDatabase()
    }
}
