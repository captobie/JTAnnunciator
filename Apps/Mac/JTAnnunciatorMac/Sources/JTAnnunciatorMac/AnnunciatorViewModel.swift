import Foundation
import JTAnnunciatorCore

/// One decode as shown on screen, paired with the alert (if any) it triggered.
struct DecodeEntry: Identifiable {
    let id = UUID()
    let decode: WSJTXDecode
    var alert: AlertEvent?
}

@MainActor
final class AnnunciatorViewModel: ObservableObject {
    /// Decodes on display, in arrival order. By default holds only the current cycle.
    @Published private(set) var entries: [DecodeEntry] = []
    /// Timestamp (ms since midnight UTC) of the cycle currently on display.
    @Published private(set) var cycleTimeMillis: UInt32?
    @Published private(set) var alerts: [AlertEvent] = []
    @Published private(set) var latestAlert: AlertEvent?
    @Published private(set) var isListening = false
    @Published private(set) var lastErrorDescription: String?
    @Published private(set) var stationsHeard = 0
    @Published private(set) var dxccDatabaseEntityCount = 0

    /// When true (the default) the display clears as soon as a decode from a new cycle arrives.
    @Published var clearsOnNewCycle: Bool = AppSettings.clearsOnNewCycle {
        didSet { AppSettings.clearsOnNewCycle = clearsOnNewCycle }
    }

    @Published var myCallsign: String = AppSettings.myCallsign {
        didSet { AppSettings.myCallsign = myCallsign }
    }

    var callingMeEntries: [DecodeEntry] {
        entries.filter { MessageClassifier.isDirected($0.decode.message, to: myCallsign) }
    }

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

    init() {
        let storedWantedList = AppSettings.loadWantedList() ?? WantedList()
        wantedList = storedWantedList
        let database = Self.loadDXCCDatabase()
        engine = AlertEngine(wantedList: storedWantedList, dxccLookup: database)
        dxccDatabaseEntityCount = database.prefixes.count + database.exactCallsigns.count
    }

    func start() {
        guard listener == nil else { return }
        let port = AppSettings.udpPort
        let listener = WSJTXUDPListener(port: port, multicastAddress: AppSettings.multicastAddress)
        listener.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        listener.onError = { [weak self] error in
            Task { @MainActor in self?.lastErrorDescription = error.localizedDescription }
        }
        listener.start()
        self.listener = listener
        isListening = true
    }

    func stop() {
        listener?.stop()
        listener = nil
        isListening = false
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

    private func handle(_ message: WSJTXMessage) {
        switch message {
        case let .decode(decode):
            if clearsOnNewCycle, let cycle = cycleTimeMillis, decode.timeMillisSinceMidnightUTC != cycle {
                entries.removeAll()
            }
            cycleTimeMillis = decode.timeMillisSinceMidnightUTC
            stationsHeard += 1

            let newAlerts = engine.process(decode)
            entries.append(DecodeEntry(decode: decode, alert: newAlerts.first))
            trimIfNeeded(&entries)
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

        case .heartbeat, .status, .close, .wsprDecode, .loggedADIF, .unsupported:
            break
        }
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
