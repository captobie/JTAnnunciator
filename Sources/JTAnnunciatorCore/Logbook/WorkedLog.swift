import Foundation

/// One contact read from a logging program. Only the fields needed to answer "have I worked this
/// station before, and where?" are carried.
public struct LogbookQSO: Equatable {
    public var callsign: String
    /// Band as the logger spells it, normalized to uppercase (e.g. "20M"); empty if unknown.
    public var band: String
    public var mode: String
    public var date: Date?
    /// The state/province as the logger spells it ("CT", "ON"); empty if unknown. Only
    /// US states and Canadian provinces are tracked (see `WorkedLog.hasWorkedState`).
    public var state: String

    public init(callsign: String, band: String, mode: String, date: Date? = nil, state: String = "") {
        self.callsign = callsign
        self.band = band.trimmingCharacters(in: .whitespaces).uppercased()
        self.mode = mode.trimmingCharacters(in: .whitespaces).uppercased()
        self.date = date
        self.state = state.trimmingCharacters(in: .whitespaces)
    }
}

/// What the logbook knows about a station, for display next to a decode.
public struct WorkedInfo: Equatable {
    public var callsign: String
    /// Bands worked, as strings sorted alphabetically (not by frequency).
    public var bands: [String]
    public var modes: [String]
    public var qsoCount: Int
    public var lastWorked: Date?
}

/// Index of every callsign in one or more logbooks.
///
/// Callsigns are keyed by their "identity" (see `identity(of:)`), so a log entry for `JA8CPF/P`
/// counts as having worked `JA8CPF` and vice versa.
public struct WorkedLog: Equatable {
    private struct Entry: Equatable {
        var bands: Set<String> = []
        var modes: Set<String> = []
        var count = 0
        var lastWorked: Date?
        /// Contacts per band+mode combination, for "worked on this band and mode" lookups.
        var byBandMode: [BandMode: Stat] = [:]
    }

    private struct BandMode: Hashable {
        var band: String
        var mode: String
    }

    private struct Stat: Equatable {
        var count = 0
        var lastWorked: Date?

        mutating func absorb(count: Int, lastWorked date: Date?) {
            self.count += count
            if let date, date > (lastWorked ?? .distantPast) { lastWorked = date }
        }
    }

    private var entries: [String: Entry] = [:]
    private var stateBandModes: Set<StateBandMode> = []

    private struct StateBandMode: Hashable {
        var state: String
        var band: String
        var mode: String
    }

    public init() {}

    public init(qsos: [LogbookQSO]) {
        for qso in qsos { add(qso) }
    }

    public var callsignCount: Int { entries.count }
    public var callsigns: [String] { Array(entries.keys) }

    public mutating func add(_ qso: LogbookQSO) {
        let key = Self.identity(of: qso.callsign)
        guard !key.isEmpty else { return }
        var entry = entries[key, default: Entry()]
        if !qso.band.isEmpty { entry.bands.insert(qso.band) }
        if !qso.mode.isEmpty { entry.modes.insert(qso.mode) }
        entry.count += 1
        if let date = qso.date, date > (entry.lastWorked ?? .distantPast) { entry.lastWorked = date }
        if !qso.band.isEmpty, !qso.mode.isEmpty {
            entry.byBandMode[BandMode(band: qso.band, mode: qso.mode), default: Stat()]
                .absorb(count: 1, lastWorked: qso.date)
        }
        entries[key] = entry
        if !qso.band.isEmpty, !qso.mode.isEmpty, let state = RegionNames.knownName(forState: qso.state) {
            stateBandModes.insert(StateBandMode(state: state, band: qso.band, mode: qso.mode))
        }
    }

    public mutating func merge(_ other: WorkedLog) {
        stateBandModes.formUnion(other.stateBandModes)
        for (key, theirs) in other.entries {
            var entry = entries[key, default: Entry()]
            entry.bands.formUnion(theirs.bands)
            entry.modes.formUnion(theirs.modes)
            entry.count += theirs.count
            if let date = theirs.lastWorked, date > (entry.lastWorked ?? .distantPast) {
                entry.lastWorked = date
            }
            for (bandMode, stat) in theirs.byBandMode {
                entry.byBandMode[bandMode, default: Stat()].absorb(count: stat.count, lastWorked: stat.lastWorked)
            }
            entries[key] = entry
        }
    }

    public func info(for callsign: String) -> WorkedInfo? {
        let key = Self.identity(of: callsign)
        guard let entry = entries[key] else { return nil }
        return WorkedInfo(
            callsign: key, bands: entry.bands.sorted(), modes: entry.modes.sorted(),
            qsoCount: entry.count, lastWorked: entry.lastWorked
        )
    }

    /// What the logbook knows about contacts with `callsign` on exactly this band and mode, or
    /// `nil` if there are none. The result's `bands`/`modes`/`qsoCount`/`lastWorked` describe only
    /// those matching contacts.
    public func info(for callsign: String, band: String, mode: String) -> WorkedInfo? {
        let key = Self.identity(of: callsign)
        let bandMode = BandMode(band: band.uppercased(), mode: mode.uppercased())
        guard let stat = entries[key]?.byBandMode[bandMode] else { return nil }
        return WorkedInfo(
            callsign: key, bands: [bandMode.band], modes: [bandMode.mode],
            qsoCount: stat.count, lastWorked: stat.lastWorked
        )
    }

    /// True if the log has a contact with a station in `state` (a US state or Canadian province,
    /// code or full name) on exactly this band and mode.
    public func hasWorkedState(_ state: String, band: String, mode: String) -> Bool {
        guard let name = RegionNames.knownName(forState: state) else { return false }
        return stateBandModes.contains(StateBandMode(state: name, band: band.uppercased(), mode: mode.uppercased()))
    }

    /// Every distinct callsign/band/mode combination in the log.
    public var callsignBandModes: [(callsign: String, band: String, mode: String)] {
        entries.flatMap { call, entry in entry.byBandMode.keys.map { (call, $0.band, $0.mode) } }
    }

    public func contains(_ callsign: String) -> Bool {
        entries[Self.identity(of: callsign)] != nil
    }

    /// The part of a callsign that identifies the operator: uppercased, hashed-call brackets
    /// removed, and for slashed calls the longest part ("JA8CPF/P" → "JA8CPF", "BW2/JP1RIW" →
    /// "JP1RIW", "W1AW/4" → "W1AW"). Ties favor the left side.
    static func identity(of callsign: String) -> String {
        let cleaned = callsign.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")).uppercased()
        let parts = cleaned.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count > 1 else { return cleaned }
        return String(parts.reduce(parts[0]) { $1.count > $0.count ? $1 : $0 })
    }
}
