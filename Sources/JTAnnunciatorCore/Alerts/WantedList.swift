import Foundation

/// The operator's "wanted" configuration: specific callsigns to watch for, DXCC entities still
/// needed, and US states/Canadian provinces still needed. Other JTAlert-style categories (US
/// counties, CQ/ITU zones, continents, LoTW/eQSL status) aren't built yet; see the README.
public struct WantedList: Codable, Equatable {
    /// Exact callsigns to alert on, uppercased.
    public var wantedCallsigns: Set<String> = []

    /// DXCC entities to alert on, keyed by `CTYEntry.primaryPrefix` (the stable identifier a
    /// cty.dat file gives us — see CTYEntry.swift). Not ADIF's numeric DXCC id, since the classic
    /// cty.dat format this app parses doesn't carry one.
    public var wantedDXCCPrimaryPrefixes: Set<String> = []

    /// US states and Canadian provinces still needed, as full names (`RegionNames.knownName`).
    /// A station's state only becomes known once the callbook answers, so unlike the other two
    /// categories this one is matched by the app after the lookup, not by `AlertEngine`.
    public var wantedStates: Set<String> = []

    public init(
        wantedCallsigns: Set<String> = [], wantedDXCCPrimaryPrefixes: Set<String> = [],
        wantedStates: Set<String> = []
    ) {
        self.wantedCallsigns = wantedCallsigns
        self.wantedDXCCPrimaryPrefixes = wantedDXCCPrimaryPrefixes
        self.wantedStates = wantedStates
    }

    // Lists saved before `wantedStates` existed have no such key; decode them with it empty
    // rather than discarding the whole saved list.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wantedCallsigns = try container.decodeIfPresent(Set<String>.self, forKey: .wantedCallsigns) ?? []
        wantedDXCCPrimaryPrefixes = try container.decodeIfPresent(Set<String>.self, forKey: .wantedDXCCPrimaryPrefixes) ?? []
        wantedStates = try container.decodeIfPresent(Set<String>.self, forKey: .wantedStates) ?? []
    }
}
