import Foundation

/// The logging programs this app can read "worked before" history from. Each program gets its
/// own connection entry, so adding another logger later is a new case here plus a reader, not a
/// change to the connection model.
public enum LogbookKind: String, Codable, CaseIterable, Equatable {
    case macLoggerDX
    case wavelog

    public var displayName: String {
        switch self {
        case .macLoggerDX: return "MacLoggerDX"
        case .wavelog: return "Wavelog"
        }
    }

    /// True for a logger read from a local file (`path`); false for one read over the network
    /// (`serverURL`/`apiKey`/`stationID`) — see `LogbookConnection`.
    public var isFileBased: Bool {
        switch self {
        case .macLoggerDX: return true
        case .wavelog: return false
        }
    }

    /// Where this program keeps its log by default, relative to the user's home directory.
    /// `nil` when there's no well-known location (or this isn't a file-based logger).
    public var defaultRelativePath: String? {
        switch self {
        case .macLoggerDX: return "Documents/MLDX_Logs/MacLoggerDX.sql"
        case .wavelog: return nil
        }
    }
}

/// One configured logbook: which program, how to reach it, and whether it's in use.
///
/// File-based kinds (MacLoggerDX) use `path`; network-based kinds (Wavelog) use `serverURL`,
/// `apiKey` and `stationID` instead, plus `lastFetchedID` to resume an incremental pull rather
/// than re-downloading the whole log on every poll. The network fields are optional so a
/// `LogbookConnection` saved before Wavelog existed still decodes — see
/// `AppSettings.logbookConnections`.
public struct LogbookConnection: Codable, Identifiable, Equatable {
    public var id: UUID
    public var kind: LogbookKind
    public var path: String
    public var isEnabled: Bool
    public var serverURL: String?
    public var apiKey: String?
    public var stationID: Int?
    /// The highest QSO primary key already fetched from a network-based logger. `nil` until the
    /// first successful pull, or after `serverURL`/`stationID` changes invalidate the old
    /// position (a fresh full pull is needed rather than resuming from a now-meaningless id).
    public var lastFetchedID: Int?

    public init(
        id: UUID = UUID(), kind: LogbookKind, path: String = "", isEnabled: Bool = true,
        serverURL: String = "", apiKey: String = "", stationID: Int = 1, lastFetchedID: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.path = path
        self.isEnabled = isEnabled
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.stationID = stationID
        self.lastFetchedID = lastFetchedID
    }
}

/// The result of one logbook read: the QSOs found, whether they should be merged into
/// (`isDelta == true`) or replace (`isDelta == false`) what's already known about this
/// connection, and any connection state (e.g. Wavelog's `lastFetchedID`) the caller should
/// persist for next time.
public struct LogbookReadResult: Equatable {
    public var qsos: [LogbookQSO]
    public var isDelta: Bool
    public var updatedConnection: LogbookConnection
}

/// Reading a logbook kind that isn't supported in this build (e.g. MacLoggerDX on a platform
/// without SQLite3).
public enum LogbookFetchError: Error, LocalizedError, Equatable {
    case unsupportedOnThisPlatform(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedOnThisPlatform(name): return "\(name) logs aren't supported on this platform."
        }
    }
}

extension LogbookConnection {
    /// Reads (or re-reads) this connection's log with the reader for its kind.
    public func fetch() async throws -> LogbookReadResult {
        switch kind {
        case .macLoggerDX:
            #if canImport(SQLite3)
            let qsos = try MacLoggerDXReader.readQSOs(atPath: path)
            return LogbookReadResult(qsos: qsos, isDelta: false, updatedConnection: self)
            #else
            throw LogbookFetchError.unsupportedOnThisPlatform(kind.displayName)
            #endif
        case .wavelog:
            return try await WavelogReader.fetch(connection: self)
        }
    }
}
