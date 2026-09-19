import Foundation

/// Matches WSJT-X Decode messages against a `WantedList` and tracks which callsigns/entities
/// have already been logged this session (from QSO Logged messages), so the UI can dim
/// already-worked stations the way JTAlert does rather than hide them.
///
/// A plain struct, not an actor/class: callers (the Mac app's view model) own threading and
/// simply hold a `var` of this, same pattern as `RigState` in the sibling FTX1Remote project.
public struct AlertEngine {
    public var wantedList: WantedList
    public var dxccLookup: DXCCLookup {
        didSet { rebuildLogbookDXCC() }
    }

    /// Callsigns/entities logged this session (from QSO Logged messages).
    public private(set) var workedCallsigns: Set<String> = []
    public private(set) var workedDXCCPrimaryPrefixes: Set<String> = []

    /// Everything read from the user's logging programs, plus the entities those calls belong to.
    public private(set) var logbook = WorkedLog()
    private var logbookDXCCPrimaryPrefixes: Set<String> = []
    /// Entities (by primary prefix) worked per band+mode, from the logbook and this session.
    private var entityBandModes: Set<EntityBandMode> = []
    private var sessionEntityBandModes: Set<EntityBandMode> = []

    private struct EntityBandMode: Hashable {
        var primaryPrefix: String
        var band: String
        var mode: String
    }

    public init(wantedList: WantedList, dxccLookup: DXCCLookup) {
        self.wantedList = wantedList
        self.dxccLookup = dxccLookup
    }

    /// Replaces the logbook-derived history (e.g. after re-reading the log files).
    public mutating func setLogbook(_ log: WorkedLog) {
        logbook = log
        rebuildLogbookDXCC()
    }

    private mutating func rebuildLogbookDXCC() {
        logbookDXCCPrimaryPrefixes = Set(logbook.callsigns.compactMap { dxccLookup.entity(forCallsign: $0)?.primaryPrefix })
        entityBandModes = Set(logbook.callsignBandModes.compactMap { call, band, mode in
            dxccLookup.entity(forCallsign: call).map { EntityBandMode(primaryPrefix: $0.primaryPrefix, band: band, mode: mode) }
        })
    }

    /// True if `callsign` was worked this session or appears in the logbook.
    public func hasWorked(_ callsign: String) -> Bool {
        let call = callsign.uppercased()
        return workedCallsigns.contains(call) || logbook.contains(call)
    }

    /// Contacts logged this session (QSO Logged messages), kept with band/mode so they take part
    /// in band+mode matching like logbook contacts.
    private var sessionLog = WorkedLog()

    private func hasWorkedDXCC(_ primaryPrefix: String) -> Bool {
        workedDXCCPrimaryPrefixes.contains(primaryPrefix) || logbookDXCCPrimaryPrefixes.contains(primaryPrefix)
    }

    /// What's known about contacts with the station that sent `decode` on this exact `band` and
    /// `mode` (e.g. "20M", "FT8"), or `nil` if it hasn't been worked that way — worked on another
    /// band or mode doesn't count.
    public func workedInfo(for decode: WSJTXDecode, band: String, mode: String) -> WorkedInfo? {
        guard let call = MessageClassifier.senderCallsign(decode.message) else { return nil }
        return logbook.info(for: call, band: band, mode: mode)
            ?? sessionLog.info(for: call, band: band, mode: mode)
    }

    /// The DXCC entity name if `callsign`'s country has never been worked on this exact band and
    /// mode (this session or in the logbook); `nil` if it has, or if the country can't be
    /// determined.
    public func newCountry(forCallsign callsign: String, band: String, mode: String) -> String? {
        guard let entity = dxccLookup.entity(forCallsign: callsign) else { return nil }
        let key = EntityBandMode(primaryPrefix: entity.primaryPrefix, band: band.uppercased(), mode: mode.uppercased())
        return entityBandModes.contains(key) || sessionEntityBandModes.contains(key) ? nil : entity.name
    }

    /// True if no contact with a station in `state` on this band and mode is in the logbook.
    public func hasWorkedState(_ state: String, band: String, mode: String) -> Bool {
        logbook.hasWorkedState(state, band: band, mode: mode)
    }

    /// Records a completed, logged QSO so future alerts for that callsign/entity can be marked
    /// "already worked" instead of suppressed outright.
    public mutating func recordQSOLogged(_ qso: WSJTXQSOLogged) {
        let call = qso.dxCall.uppercased()
        guard !call.isEmpty else { return }
        workedCallsigns.insert(call)
        sessionLog.add(LogbookQSO(
            callsign: call, band: Band.name(forFrequencyHz: qso.txFrequencyHz) ?? "", mode: qso.mode,
            date: qso.dateTimeOff
        ))
        if let entity = dxccLookup.entity(forCallsign: call) {
            workedDXCCPrimaryPrefixes.insert(entity.primaryPrefix)
            if let band = Band.name(forFrequencyHz: qso.txFrequencyHz), !qso.mode.isEmpty {
                sessionEntityBandModes.insert(EntityBandMode(
                    primaryPrefix: entity.primaryPrefix, band: band, mode: qso.mode.uppercased()
                ))
            }
        }
    }

    /// Produces zero or more alerts for a single Decode message. Only genuinely new decodes
    /// (`decode.isNew`) are considered — WSJT-X redelivers the same decode across the rest of its
    /// 15s cycle, and re-alerting on every redelivery would be noisy rather than useful.
    public mutating func process(_ decode: WSJTXDecode) -> [AlertEvent] {
        guard decode.isNew else { return [] }

        var events: [AlertEvent] = []
        var seenInThisMessage: Set<String> = []

        for rawCallsign in FT8MessageParser.candidateCallsigns(inMessage: decode.message) {
            guard seenInThisMessage.insert(rawCallsign).inserted else { continue }

            if wantedList.wantedCallsigns.contains(rawCallsign) {
                events.append(
                    AlertEvent(
                        callsign: rawCallsign, reason: .wantedCallsign, decode: decode,
                        alreadyWorked: hasWorked(rawCallsign)
                    )
                )
                continue
            }

            guard let entity = dxccLookup.entity(forCallsign: rawCallsign),
                  wantedList.wantedDXCCPrimaryPrefixes.contains(entity.primaryPrefix)
            else { continue }

            events.append(
                AlertEvent(
                    callsign: rawCallsign,
                    reason: .wantedDXCC(entityName: entity.name, primaryPrefix: entity.primaryPrefix),
                    decode: decode,
                    alreadyWorked: hasWorkedDXCC(entity.primaryPrefix)
                )
            )
        }

        return events
    }
}
