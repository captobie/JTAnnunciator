import Foundation
import JTAnnunciatorCore

@MainActor
final class AnnunciatorViewModel: ObservableObject {
    @Published private(set) var recentDecodes: [WSJTXDecode] = []
    @Published private(set) var alerts: [AlertEvent] = []
    @Published private(set) var latestAlert: AlertEvent?
    @Published private(set) var isListening = false
    @Published private(set) var lastErrorDescription: String?
    @Published private(set) var stationsHeard = 0
    @Published private(set) var dxccDatabaseEntityCount = 0

    @Published var wantedList: WantedList {
        didSet {
            engine.wantedList = wantedList
            AppSettings.saveWantedList(wantedList)
        }
    }

    /// Keeps at most this many recent items in `recentDecodes`/`alerts`, so a long unattended
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
        let listener = WSJTXUDPListener(port: port)
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
            recentDecodes.insert(decode, at: 0)
            trimIfNeeded(&recentDecodes)
            stationsHeard += 1

            let newAlerts = engine.process(decode)
            guard !newAlerts.isEmpty else { return }
            alerts.insert(contentsOf: newAlerts, at: 0)
            trimIfNeeded(&alerts)
            latestAlert = newAlerts.first
            for alert in newAlerts {
                AlertSoundPlayer.play(alreadyWorked: alert.alreadyWorked)
            }

        case let .qsoLogged(qso):
            engine.recordQSOLogged(qso)

        case .clear:
            recentDecodes.removeAll()

        case .heartbeat, .status, .close, .wsprDecode, .loggedADIF, .unsupported:
            break
        }
    }

    private func trimIfNeeded<T>(_ array: inout [T]) {
        if array.count > historyLimit {
            array.removeLast(array.count - historyLimit)
        }
    }
}
