import Foundation
import os
import JTAnnunciatorCore

/// One decode as shown on screen, paired with the alert (if any) it triggered.
struct DecodeEntry: Identifiable {
    let id = UUID()
    let decode: WSJTXDecode
    var alert: AlertEvent?
    /// The transmitting station's callsign, and its DXCC country when a cty.dat is loaded.
    var callsign: String?
    var country: String?
    /// Set when the sending station appears in a connected logbook (or was logged this session).
    var worked: WorkedInfo?
}

@MainActor
final class AnnunciatorViewModel: ObservableObject {
    /// Decodes on display, in arrival order. By default holds only the current cycle.
    @Published private(set) var entries: [DecodeEntry] = []
    /// Timestamp (ms since midnight UTC) of the cycle currently on display.
    /// Band and mode WSJT-X is currently on (from its Status messages); worked-before matching
    /// only counts contacts on this band and mode. `nil` until the first Status arrives.
    private var currentBand: String?
    private var currentMode: String?
    @Published private(set) var cycleTimeMillis: UInt32?
    @Published private(set) var alerts: [AlertEvent] = []
    @Published private(set) var latestAlert: AlertEvent?
    @Published private(set) var isListening = false
    @Published private(set) var lastErrorDescription: String?
    /// Confirmation of the last reply sent to WSJT-X, shown in the status bar.
    @Published private(set) var replyStatus: String?
    private static let log = Logger(subsystem: "com.jtannunciator", category: "reply")
    @Published private(set) var stationsHeard = 0
    @Published private(set) var dxccDatabaseEntityCount = 0
    @Published private(set) var logbookConnections: [LogbookConnection] = AppSettings.logbookConnections
    /// One human-readable line per connection ("1,481 QSOs" or the error), shown in Settings.
    @Published private(set) var logbookStatuses: [UUID: String] = [:]
    /// Distinct callsigns across all enabled logbooks.
    @Published private(set) var logbookCallsignCount = 0
    /// Callbook results by callsign, shown in decode hover details.
    @Published private(set) var callbookRecords: [String: CallbookRecord] = [:]
    /// Set when the callbook rejects the saved credentials; cleared when they're changed.
    @Published private(set) var callbookError: String?
    /// Set when QRZ lookups are switched on but can't run because the username or password is
    /// missing; shown in the status bar so it isn't a silent failure.
    @Published private(set) var callbookWarning: String?

    /// When true (the default) the display clears as soon as a decode from a new cycle arrives.
    @Published var clearsOnNewCycle: Bool = AppSettings.clearsOnNewCycle {
        didSet { AppSettings.clearsOnNewCycle = clearsOnNewCycle }
    }

    @Published var myCallsign: String = AppSettings.myCallsign {
        didSet { AppSettings.myCallsign = myCallsign }
    }

    @Published var myGrid: String = AppSettings.myGrid {
        didSet { AppSettings.myGrid = myGrid }
    }

    /// Decodes addressed to `myCallsign`. Unlike `entries` these survive cycle changes and
    /// persist until the user clears them.
    @Published private(set) var callingMeEntries: [DecodeEntry] = []

    var cqEntries: [DecodeEntry] {
        entries.filter { MessageClassifier.isCQ($0.decode.message) }
    }

    @Published var wantedList: WantedList {
        didSet {
            engine.wantedList = wantedList
            AppSettings.saveWantedList(wantedList)
        }
    }

    /// Keeps at most this many recent items in `entries`/`alerts`, so a long unattended
    /// session doesn't grow these arrays without bound.
    private let historyLimit = 300

    private var engine: AlertEngine
    private var listener: WSJTXUDPListener?
    private var logbookWatcher: Task<Void, Never>?
    /// Modification time of each logbook file as of its last read, so the watcher only re-reads
    /// a log that actually changed (e.g. MacLoggerDX saved a new QSO).
    private var logbookModificationDates: [UUID: Date] = [:]
    private var logbookLoadGeneration = 0
    private var callbook: (any CallbookProvider)?
    /// Callsigns already looked up (found or not) or queued, so each is asked for once.
    private var callbookRequested: Set<String> = []
    private var callbookQueue: [String] = []
    private var callbookWorker: Task<Void, Never>?
    /// How to reach each WSJT-X instance (keyed by its client id), refreshed by every datagram it
    /// sends, so a reply always goes to the instance that produced the decode.
    private var responders: [String: WSJTXUDPListener.Responder] = [:]

    init() {
        let storedWantedList = AppSettings.loadWantedList() ?? WantedList()
        wantedList = storedWantedList
        let database = Self.loadDXCCDatabase()
        engine = AlertEngine(wantedList: storedWantedList, dxccLookup: database)
        dxccDatabaseEntityCount = database.prefixes.count + database.exactCallsigns.count
        configureCallbook()
    }

    func clearCallingMe(_ entry: DecodeEntry) {
        callingMeEntries.removeAll { $0.id == entry.id }
    }

    func clearAllCallingMe() {
        callingMeEntries.removeAll()
    }

    func start() {
        guard listener == nil else { return }
        let port = AppSettings.udpPort
        let listener = WSJTXUDPListener(port: port, multicastAddress: AppSettings.multicastAddress)
        listener.onMessage = { [weak self] message, respond in
            Task { @MainActor in self?.handle(message, respond: respond) }
        }
        listener.onError = { [weak self] error in
            Task { @MainActor in self?.lastErrorDescription = error.localizedDescription }
        }
        listener.start()
        self.listener = listener
        isListening = true
        startWatchingLogbooks()
    }

    func stop() {
        listener?.stop()
        listener = nil
        responders.removeAll()
        isListening = false
        logbookWatcher?.cancel()
        logbookWatcher = nil
    }

    /// Saves the logbook connections and re-reads every enabled log.
    func setLogbookConnections(_ connections: [LogbookConnection]) {
        guard connections != logbookConnections else { return }
        logbookConnections = connections
        AppSettings.logbookConnections = connections
        reloadLogbooks()
    }

    /// Saves the QRZ credentials and restarts callbook lookups with them.
    func setQRZCredentials(enabled: Bool, username: String, password: String) {
        AppSettings.qrzEnabled = enabled
        AppSettings.qrzUsername = username
        AppSettings.qrzPassword = password
        configureCallbook()
    }

    private func configureCallbook() {
        callbookWorker?.cancel()
        callbookWorker = nil
        callbookQueue.removeAll()
        callbookRequested.removeAll()
        callbookRecords.removeAll()
        callbookError = nil
        let username = AppSettings.qrzUsername, password = AppSettings.qrzPassword
        if AppSettings.qrzEnabled, username.isEmpty || password.isEmpty {
            callbookWarning = "QRZ lookups are on but no \(username.isEmpty ? "username" : "password") is saved — set it in Settings → Lookup"
        } else {
            callbookWarning = nil
        }
        callbook = AppSettings.qrzEnabled && !username.isEmpty && !password.isEmpty
            ? QRZClient(username: username, password: password) : nil
    }

    /// Queues a callbook lookup for `callsign` unless it has been asked for already. Lookups run
    /// one at a time so a busy band doesn't flood the service.
    private func requestCallbook(for callsign: String) {
        guard callbook != nil, callbookError == nil, callbookRequested.insert(callsign).inserted else { return }
        callbookQueue.append(callsign)
        guard callbookWorker == nil else { return }
        callbookWorker = Task { [weak self] in
            while let self, let next = self.nextCallbookRequest() {
                await self.performCallbookLookup(next)
            }
            self?.callbookWorker = nil
        }
    }

    private func nextCallbookRequest() -> (callsign: String, provider: any CallbookProvider)? {
        guard !Task.isCancelled, let provider = callbook, !callbookQueue.isEmpty else { return nil }
        return (callbookQueue.removeFirst(), provider)
    }

    private func performCallbookLookup(_ request: (callsign: String, provider: any CallbookProvider)) async {
        do {
            let record = try await request.provider.lookup(callsign: request.callsign)
            guard !Task.isCancelled else { return }
            if let record { callbookRecords[request.callsign] = record }
        } catch let error as CallbookError {
            guard !Task.isCancelled else { return }
            if case .authenticationFailed = error {
                callbookError = error.localizedDescription
                callbookQueue.removeAll()
            } else {
                callbookRequested.remove(request.callsign)   // transient; may retry on a later decode
            }
        } catch {
            callbookRequested.remove(request.callsign)
        }
    }

    /// Re-reads all enabled logbooks off the main thread, then swaps the result into the engine.
    func reloadLogbooks() {
        logbookLoadGeneration += 1
        let generation = logbookLoadGeneration
        let connections = logbookConnections.filter(\.isEnabled)

        Task {
            let results = await Task.detached(priority: .utility) {
                connections.map { connection -> (LogbookConnection, Result<[LogbookQSO], Error>, Date?) in
                    let modified = try? FileManager.default.attributesOfItem(atPath: connection.path)[.modificationDate] as? Date
                    return (connection, Result { try connection.readQSOs() }, modified)
                }
            }.value

            // A newer reload (or a settings change) started while this one ran; drop this result.
            guard generation == logbookLoadGeneration else { return }

            var combined = WorkedLog()
            var statuses: [UUID: String] = [:]
            var modificationDates: [UUID: Date] = [:]
            for (connection, result, modified) in results {
                if let modified { modificationDates[connection.id] = modified }
                switch result {
                case let .success(qsos):
                    combined.merge(WorkedLog(qsos: qsos))
                    statuses[connection.id] = "\(qsos.count.formatted()) QSOs loaded"
                case let .failure(error):
                    statuses[connection.id] = error.localizedDescription
                }
            }
            engine.setLogbook(combined)
            logbookCallsignCount = combined.callsignCount
            logbookStatuses = statuses
            logbookModificationDates = modificationDates
        }
    }

    private func startWatchingLogbooks() {
        guard logbookWatcher == nil else { return }
        reloadLogbooks()
        logbookWatcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                self?.reloadLogbooksIfChanged()
            }
        }
    }

    private func reloadLogbooksIfChanged() {
        let changed = logbookConnections.filter(\.isEnabled).contains { connection in
            let modified = try? FileManager.default.attributesOfItem(atPath: connection.path)[.modificationDate] as? Date
            return modified != logbookModificationDates[connection.id]
        }
        if changed { reloadLogbooks() }
    }

    /// Does what double-clicking `decode` in WSJT-X would: selects the station and queues the
    /// reply (for a CQ, `<their call> <my call> <my grid>`), enabling Tx per WSJT-X's own
    /// "Double-click on call sets Tx Enable" setting. WSJT-X composes the message from its own
    /// configured callsign/grid.
    func reply(to decode: WSJTXDecode) {
        Self.log.info("reply requested: id=\(decode.id, privacy: .public) msg=\(decode.message, privacy: .public) known clients=\(self.responders.keys.sorted().joined(separator: ","), privacy: .public)")
        guard let respond = responders[decode.id] else {
            lastErrorDescription = "Can't reach WSJT-X (\(decode.id)) to reply — no datagram received from it yet."
            return
        }
        lastErrorDescription = nil
        let datagram = WSJTXMessageEncoder.encodeReply(for: decode)
        respond(datagram)
        replyStatus = "Reply sent to WSJT-X: \(decode.message) (\(datagram.count) bytes)"
        Self.log.info("reply sent: \(datagram.count) bytes")
    }

    /// Reloads the DXCC database from whatever cty.dat path Settings currently points at, and
    /// re-checks all wanted-DXCC entries against it. Call after the user picks a new file.
    func reloadDXCCDatabase() {
        let database = Self.loadDXCCDatabase()
        engine.dxccLookup = database
        dxccDatabaseEntityCount = database.prefixes.count + database.exactCallsigns.count
    }

    private static func loadDXCCDatabase() -> CTYDatabase {
        guard
            let path = AppSettings.ctyDatPath,
            let text = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            return CTYDatabase()
        }
        return CTYDatParser.parse(text)
    }

    private func handle(_ message: WSJTXMessage, respond: @escaping WSJTXUDPListener.Responder) {
        switch message {
        case let .decode(decode):
            responders[decode.id] = respond
            if clearsOnNewCycle, let cycle = cycleTimeMillis, decode.timeMillisSinceMidnightUTC != cycle {
                entries.removeAll()
            }
            cycleTimeMillis = decode.timeMillisSinceMidnightUTC
            stationsHeard += 1

            let newAlerts = engine.process(decode)
            let callsign = MessageClassifier.senderCallsign(decode.message)
            entries.append(DecodeEntry(
                decode: decode, alert: newAlerts.first,
                callsign: callsign,
                country: callsign.flatMap { engine.dxccLookup.entity(forCallsign: $0)?.name },
                worked: workedInfo(for: decode)
            ))
            trimIfNeeded(&entries)
            if let callsign { requestCallbook(for: callsign) }
            // Skip WSJT-X's re-deliveries of a decode. One box per calling station: a later message
            // from the same callsign (report, then RR73) updates its box in place.
            if decode.isNew, MessageClassifier.isDirected(decode.message, to: myCallsign) {
                let latest = entries[entries.count - 1]
                let sender = MessageClassifier.sender(of: decode.message)
                if let sender, let index = callingMeEntries.firstIndex(where: {
                    MessageClassifier.sender(of: $0.decode.message) == sender
                }) {
                    callingMeEntries[index] = latest
                } else {
                    callingMeEntries.append(latest)
                    trimIfNeeded(&callingMeEntries)
                }
            }
            guard !newAlerts.isEmpty else { return }
            alerts.insert(contentsOf: newAlerts, at: 0)
            trimIfNeeded(&alerts, newestFirst: true)
            latestAlert = newAlerts.first
            for alert in newAlerts {
                AlertSoundPlayer.play(alreadyWorked: alert.alreadyWorked)
            }

        case let .qsoLogged(qso):
            engine.recordQSOLogged(qso)

        case .clear:
            entries.removeAll()
            cycleTimeMillis = nil

        case let .heartbeat(heartbeat):
            responders[heartbeat.id] = respond

        case let .status(status):
            responders[status.id] = respond
            currentBand = Band.name(forFrequencyHz: status.dialFrequencyHz)
            currentMode = status.mode

        case .close, .wsprDecode, .loggedADIF, .unsupported:
            break
        }
    }

    private func workedInfo(for decode: WSJTXDecode) -> WorkedInfo? {
        guard let currentBand, let currentMode else { return nil }
        return engine.workedInfo(for: decode, band: currentBand, mode: currentMode)
    }

    private func trimIfNeeded<T>(_ array: inout [T], newestFirst: Bool = false) {
        guard array.count > historyLimit else { return }
        let excess = array.count - historyLimit
        if newestFirst {
            array.removeLast(excess)
        } else {
            array.removeFirst(excess)
        }
    }
}
