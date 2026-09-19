import Foundation

/// One DXCC entity (a "country" in ham-radio terms) as described by a cty.dat entry.
public struct CTYEntry: Equatable {
    public var name: String
    public var cqZone: Int
    public var ituZone: Int
    public var continent: String
    public var latitude: Double
    public var longitude: Double
    /// As stored in cty.dat: hours to add to local standard time to get UTC. Carried through
    /// unmodified from the file; not validated against a reference in this session, so treat it
    /// as informational only until double-checked.
    public var utcOffsetHours: Double
    public var primaryPrefix: String
}

/// Looks up the DXCC entity for a callsign.
public protocol DXCCLookup {
    func entity(forCallsign callsign: String) -> CTYEntry?
}

/// A parsed cty.dat file, queryable by callsign.
///
/// Resolution order (matches every mainstream logger's convention for this file format):
/// 1. An exact-callsign override (`=CALL` tokens in the file), checked against the callsign
///    exactly as heard — *before* the portable-suffix heuristic below runs. Some exact overrides
///    are themselves slash-suffixed special-event calls (e.g. cty.dat's `=4S7CGM/AVR`), so
///    stripping a "/SUFFIX" first would break the very match this step exists for.
/// 2. `CallsignParser`'s portable-suffix heuristic, then the longest prefix match against the
///    result (checked from the full token down to a single leading character).
public struct CTYDatabase: DXCCLookup {
    public private(set) var exactCallsigns: [String: CTYEntry] = [:]
    public private(set) var prefixes: [String: CTYEntry] = [:]

    public init(exactCallsigns: [String: CTYEntry] = [:], prefixes: [String: CTYEntry] = [:]) {
        self.exactCallsigns = exactCallsigns
        self.prefixes = prefixes
    }

    public func entity(forCallsign callsign: String) -> CTYEntry? {
        let rawCall = callsign.uppercased()
        if let exact = exactCallsigns[rawCall] {
            return exact
        }

        var candidate = CallsignParser.baseCallsignForCountryLookup(rawCall).uppercased()
        if let exact = exactCallsigns[candidate] {
            return exact
        }
        while !candidate.isEmpty {
            if let entry = prefixes[candidate] {
                return entry
            }
            candidate.removeLast()
        }
        return nil
    }
}
