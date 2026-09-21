import SwiftUI
import AppKit
import JTAnnunciatorCore

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
    @State private var logbooks: [LogbookConnection] = []
    @State private var qrzEnabled: Bool = false
    @State private var qrzUsername: String = ""
    @State private var qrzPassword: String = ""
    @State private var qrzTestResult: (message: String, succeeded: Bool)?
    @State private var qrzTesting = false
    @State private var showingWantedLists = false

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
        .sheet(isPresented: $showingWantedLists) {
            WantedListsView(viewModel: viewModel)
        }
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
            Section("Wanted") {
                Button("Wanted Lists…") { showingWantedLists = true }
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

            Section("Callbook") {
                Toggle("Look up callsigns on QRZ.com", isOn: $qrzEnabled)
                HStack {
                    Text("Username")
                    TextField("", text: $qrzUsername)
                        .frame(width: 180)
                        .autocorrectionDisabled()
                }
                HStack {
                    Text("Password")
                    SecureField("", text: $qrzPassword)
                        .frame(width: 180)
                }
                HStack {
                    Button("Test Login", action: testQRZLogin)
                        .disabled(qrzTesting || qrzUsername.isEmpty || qrzPassword.isEmpty)
                    if let result = qrzTestResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.succeeded ? .green : .red)
                    }
                }
                if let error = viewModel.callbookError {
                    Text("Lookups stopped: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Uses the QRZ XML Data service, which needs a QRZ XML subscription. Name, location and grid for decoded stations appear in the decode hover text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Log Connections") {
                if logbooks.isEmpty {
                    Text("No logs connected. Add your logging program to see stations you've already worked marked in the decode list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach($logbooks) { $logbook in
                    logbookRow($logbook)
                }
                Menu("Add Log…") {
                    ForEach(LogbookKind.allCases, id: \.self) { kind in
                        Button(kind.displayName) { addLogbook(kind) }
                    }
                }
                .fixedSize()
            }
        }
        .padding(8)
    }

    private func logbookRow(_ logbook: Binding<LogbookConnection>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Toggle(logbook.wrappedValue.kind.displayName, isOn: logbook.isEnabled)
                    .fontWeight(.medium)
                Spacer()
                Button("Choose…") { chooseLogbookFile(logbook) }
                Button {
                    logbooks.removeAll { $0.id == logbook.wrappedValue.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove this log connection")
            }
            Text(logbook.wrappedValue.path.isEmpty ? "No file selected" : logbook.wrappedValue.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            if let status = viewModel.logbookStatuses[logbook.wrappedValue.id] {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(status.hasSuffix("loaded") ? .green : .red)
            }
        }
        .padding(.vertical, 2)
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
        logbooks = viewModel.logbookConnections
        qrzEnabled = AppSettings.qrzEnabled
        qrzUsername = AppSettings.qrzUsername
        qrzPassword = AppSettings.qrzPassword
        qrzTestResult = nil
    }

    private func save() {
        guard let port = UInt16(udpPortText) else { return }
        AppSettings.udpPort = port
        AppSettings.multicastAddress = multicastText
        AppSettings.alertSoundEnabled = alertSoundEnabled
        viewModel.myCallsign = myCallsign
        viewModel.myGrid = myGrid
        viewModel.clearsOnNewCycle = clearsOnNewCycle
        viewModel.setLogbookConnections(logbooks)
        if qrzEnabled != AppSettings.qrzEnabled || qrzUsername != AppSettings.qrzUsername
            || qrzPassword != AppSettings.qrzPassword {
            viewModel.setQRZCredentials(enabled: qrzEnabled, username: qrzUsername, password: qrzPassword)
        }
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

    private func testQRZLogin() {
        qrzTesting = true
        qrzTestResult = nil
        let client = QRZClient(username: qrzUsername, password: qrzPassword)
        Task {
            do {
                let expiry = try await client.login()
                if let expiry, expiry.lowercased().contains("non-subscriber") {
                    qrzTestResult = ("Signed in, but this account has no XML subscription — lookups will be limited.", false)
                } else {
                    qrzTestResult = ("Signed in.", true)
                }
            } catch {
                qrzTestResult = (error.localizedDescription, false)
            }
            qrzTesting = false
        }
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

    /// Adds a connection for `kind`, pre-filled with that program's usual log location if it
    /// exists; otherwise asks the user to pick the file.
    private func addLogbook(_ kind: LogbookKind) {
        let defaultPath = kind.defaultRelativePath.map {
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent($0).path
        }
        let exists = defaultPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        var connection = LogbookConnection(kind: kind, path: exists ? defaultPath ?? "" : "")
        if !exists {
            guard let picked = pickLogbookFile(for: kind) else { return }
            connection.path = picked
        }
        logbooks.append(connection)
    }

    private func chooseLogbookFile(_ logbook: Binding<LogbookConnection>) {
        if let picked = pickLogbookFile(for: logbook.wrappedValue.kind) {
            logbook.wrappedValue.path = picked
        }
    }

    private func pickLogbookFile(for kind: LogbookKind) -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose your \(kind.displayName) log file"
        if let relative = kind.defaultRelativePath {
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(relative).deletingLastPathComponent()
        }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}
