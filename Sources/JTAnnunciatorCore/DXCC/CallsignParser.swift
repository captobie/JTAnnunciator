import Foundation

/// Helpers for turning a raw on-air callsign (as it appears in a WSJT-X Decode message, e.g.
/// "CQ DX G4ABC/VP8 IO91") into the token used for DXCC country lookup.
enum CallsignParser {
    /// Suffixes hams append to a callsign that describe an *operating condition*, not a
    /// different country — e.g. "W1AW/P" (portable), "W1AW/MM" (maritime mobile, DXCC-wise
    /// still credited to the operator's home entity unless the file has an explicit override),
    /// or "W1AW/4" (temporarily in US call area 4). None of these should redirect the DXCC
    /// lookup to the suffix itself.
    private static let operatingConditionSuffixes: Set<String> = [
        "P", "M", "MM", "AM", "A", "R", "QRP"
    ]

    /// Given a callsign that may carry a "/" prefix or suffix (portable operation, e.g.
    /// "G4ABC/VP8" or "VP8/G4ABC"), returns the token to actually run through the DXCC prefix
    /// table. This is a heuristic, not a parser of record — cty.dat's own exact-callsign
    /// overrides exist precisely because this heuristic isn't always right (see CTYEntry.swift).
    static func baseCallsignForCountryLookup(_ callsign: String) -> String {
        let parts = callsign.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return callsign }

        let left = String(parts[0])
        let right = String(parts[1])
        let rightUpper = right.uppercased()

        // A trailing call-area digit or a known operating-condition suffix: the country is
        // determined by the callsign itself, not the suffix.
        if rightUpper.allSatisfy(\.isNumber) || operatingConditionSuffixes.contains(rightUpper) {
            return left
        }

        // Otherwise the suffix is standing in for a DXCC prefix (portable DX operation, e.g.
        // "G4ABC/VP8", or written the other way round as "VP8/G4ABC"): prefixes are almost
        // always shorter than a full callsign (1-4 characters vs. 4+ for a callsign with its
        // digit and suffix letters), so prefer whichever side is shorter as the country
        // indicator. Ties favor the left side.
        return left.count <= right.count ? left : right
    }
}
