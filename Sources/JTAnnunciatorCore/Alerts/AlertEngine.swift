import Foundation

/// Matches WSJT-X Decode messages against a `WantedList` and tracks which callsigns/entities
/// have already been logged this session (from QSO Logged messages), so the UI can dim
/// already-worked stations the way JTAlert does rather than hide them.
///
/// A plain struct, not an actor/class: callers (the Mac app's view model) own threading and
/// simply hold a `var` of this, same pattern as `RigState` in the sibling FTX1Remote project.
public struct AlertEngine {
    public var wantedList: WantedList
    public var dxccLookup: DXCCLookup

    public private(set) var workedCallsigns: Set<String> = []
    public private(set) var workedDXCCPrimaryPrefixes: Set<String> = []

    public init(wantedList: WantedList, dxccLookup: DXCCLookup) {
        self.wantedList = wantedList
        self.dxccLookup = dxccLookup
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
                        alreadyWorked: workedCallsigns.contains(rawCallsign)
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
                    alreadyWorked: workedDXCCPrimaryPrefixes.contains(entity.primaryPrefix)
                )
            )
        }

        return events
    }
}
