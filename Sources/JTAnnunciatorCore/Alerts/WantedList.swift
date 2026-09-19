import Foundation

/// The operator's "wanted" configuration: specific callsigns to watch for, and/or DXCC entities
/// still needed. Deliberately just these two categories for v1 — JTAlert-style extras (wanted US
/// states/counties, CQ/ITU zones, continents, LoTW/eQSL status, "worked before on this
/// band+mode") are real, useful features but not built yet; see the README's scope note.
public struct WantedList: Codable, Equatable {
    /// Exact callsigns to alert on, uppercased.
    public var wantedCallsigns: Set<String> = []

    /// DXCC entities to alert on, keyed by `CTYEntry.primaryPrefix` (the stable identifier a
    /// cty.dat file gives us — see CTYEntry.swift). Not ADIF's numeric DXCC id, since the classic
    /// cty.dat format this app parses doesn't carry one.
    public var wantedDXCCPrimaryPrefixes: Set<String> = []

    public init(wantedCallsigns: Set<String> = [], wantedDXCCPrimaryPrefixes: Set<String> = []) {
        self.wantedCallsigns = wantedCallsigns
        self.wantedDXCCPrimaryPrefixes = wantedDXCCPrimaryPrefixes
    }
}
