import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: AnnunciatorViewModel

    // Edits are held in drafts and only written to AppSettings/the view model on Save.
    @State private var ctyDatPath: String = ""
    @State private var udpPortText: String = ""
    @State private var multicastText: String = ""
    @State private var alertSoundEnabled: Bool = true
    @State private var myCallsign: String = ""
    @State private var myGrid: String = ""
    @State private var clearsOnNewCycle: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(UInt16(udpPortText) == nil)
            }
            .padding(12)
        }
        .onAppear(perform: loadDrafts)
    }

    private var form: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            networkTab
                .tabItem { Label("Network", systemImage: "network") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            lookupTab
                .tabItem { Label("Lookup", systemImage: "magnifyingglass") }
            filtersTab
                .tabItem { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
        }
        .padding(12)
    }

    private var generalTab: some View {
        Form {
            Section("Station") {
                HStack {
                    Text("My Callsign")
                    TextField("", text: $myCallsign)
                        .frame(width: 180)
                        .autocorrectionDisabled()
                        .onChange(of: myCallsign) { newValue in
                            let upper = newValue.uppercased()
                            if upper != newValue { myCallsign = upper }
                        }
                }
                HStack {
                    Text("My Grid")
                    TextField("", text: $myGrid)
                        .frame(width: 180)
                        .autocorrectionDisabled()
                        .onChange(of: myGrid) { newValue in
                            let formatted = Self.formatGrid(newValue)
                            if formatted != newValue { myGrid = formatted }
                        }
                }
            }

            Section("Display") {
                Toggle("Clear decodes when a new cycle starts", isOn: $clearsOnNewCycle)
            }
        }
        .padding(8)
    }

    private var networkTab: some View {
        Form {
            Section("WSJT-X Connection") {
                HStack {
                    Text("UDP Port")
                    TextField("2237", text: $udpPortText)
                        .frame(width: 80)
                }
                HStack {
                    Text("Multicast Group")
                    TextField("224.0.0.1 (blank = unicast)", text: $multicastText)
                        .frame(width: 180)
                }
                Text("Set WSJT-X's UDP Server address to this same multicast group so other apps can share the feed. Must match WSJT-X's Settings → Reporting → UDP Server port. Changing this requires restarting the listener (Cmd+Q and relaunch, or toggle via the main window).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }

    private var notificationsTab: some View {
        Form {
            Section("Alerts") {
                Toggle("Play sound on alert", isOn: $alertSoundEnabled)
            }
        }
        .padding(8)
    }

    private var lookupTab: some View {
        Form {
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

            Section("Log Connections") {
                Text("Log program connections will be added here.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }

    private var filtersTab: some View {
        Form {
            Section("Display Filters") {
                Text("Filters for narrowing the decode display will be added here.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }

    /// Maidenhead convention: field and square uppercase/digits (FN42), subsquare lowercase (ab).
    /// Capped at 8 characters (extended-square precision).
    private static func formatGrid(_ text: String) -> String {
        let trimmed = text.filter { !$0.isWhitespace }.prefix(8)
        return String(trimmed.enumerated().map { index, char in
            index < 4 ? Character(char.uppercased()) : Character(char.lowercased())
        })
    }

    private func loadDrafts() {
        ctyDatPath = AppSettings.ctyDatPath ?? ""
        udpPortText = String(AppSettings.udpPort)
        multicastText = AppSettings.multicastAddress
        alertSoundEnabled = AppSettings.alertSoundEnabled
        myCallsign = viewModel.myCallsign
        myGrid = viewModel.myGrid
        clearsOnNewCycle = viewModel.clearsOnNewCycle
    }

    private func save() {
        guard let port = UInt16(udpPortText) else { return }
        AppSettings.udpPort = port
        AppSettings.multicastAddress = multicastText
        AppSettings.alertSoundEnabled = alertSoundEnabled
        viewModel.myCallsign = myCallsign
        viewModel.myGrid = myGrid
        viewModel.clearsOnNewCycle = clearsOnNewCycle
        if ctyDatPath != (AppSettings.ctyDatPath ?? "") {
            AppSettings.ctyDatPath = ctyDatPath
            viewModel.reloadDXCCDatabase()
        }
        closeWindow()
    }

    private func cancel() {
        loadDrafts()
        closeWindow()
    }

    private func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
    }

    private func chooseCTYDatFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a cty.dat DXCC country file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ctyDatPath = url.path
    }
}
