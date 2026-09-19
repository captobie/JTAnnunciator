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
    }

    /// True if `callsign` was worked this session or appears in the logbook.
    public func hasWorked(_ callsign: String) -> Bool {
        let call = callsign.uppercased()
        return workedCallsigns.contains(call) || logbook.contains(call)
    }

    private func hasWorkedDXCC(_ primaryPrefix: String) -> Bool {
        workedDXCCPrimaryPrefixes.contains(primaryPrefix) || logbookDXCCPrimaryPrefixes.contains(primaryPrefix)
    }

    /// What's known about the station that sent `decode`, or `nil` if it has never been worked.
    /// Bands/modes come from the logbook; a station worked only this session has none listed.
    public func workedInfo(for decode: WSJTXDecode) -> WorkedInfo? {
        guard let call = MessageClassifier.senderCallsign(decode.message) else { return nil }
        if let info = logbook.info(for: call) { return info }
        guard workedCallsigns.contains(call) else { return nil }
        return WorkedInfo(callsign: call, bands: [], modes: [], qsoCount: 1, lastWorked: nil)
    }

    /// Records a completed, logged QSO so future alerts for that callsign/entity can be marked
    /// "already worked" instead of suppressed outright.
    public mutating func recordQSOLogged(_ qso: WSJTXQSOLogged) {
        let call = qso.dxCall.uppercased()
        guard !call.isEmpty else { return }
        workedCallsigns.insert(call)
        if let entity = dxccLookup.entity(forCallsign: call) {
            workedDXCCPrimaryPrefixes.insert(entity.primaryPrefix)
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
