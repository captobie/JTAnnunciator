import Foundation

/// Pulls candidate callsigns out of a decoded FT8/FT4/WSPR message string.
///
/// This is deliberately a token-scanning heuristic, not a full standard-messages grammar
/// (WSJT-X's own `Varicode`/message-packing rules distinguish "CQ <call> <grid>",
/// "<call1> <call2> <report>", "<call1> <call2> RR73", free text, etc.). Scanning every
/// whitespace-separated token and filtering out the ones that are clearly *not* callsigns (grid
/// squares, signal reports, protocol keywords) means every message shape alerts correctly on
/// any wanted station present, at the cost of occasionally mis-flagging a token as a callsign in
/// a free-text message. Good enough for v1's alerting purpose; a real grammar-based parser is a
/// reasonable future improvement, not a correctness requirement for this feature.
enum FT8MessageParser {
    private static let protocolKeywords: Set<String> = [
        "CQ", "DE", "QRZ", "RR73", "RRR", "RR", "73", "TU", "AGN", "NIL", "DX", "POTA", "HP"
    ]

    /// Grid squares: 2 letters + 2 digits, optionally + 2 more letters (Maidenhead field/square,
    /// or field/square/subsquare).
    private static let gridSquareRegex = try! NSRegularExpression(
        pattern: "^[A-R]{2}[0-9]{2}([A-X]{2})?$"
    )

    /// Signal reports: e.g. "-12", "+03", "R-12", "R+03".
    private static let signalReportRegex = try! NSRegularExpression(
        pattern: "^R?[+-][0-9]{1,2}$"
    )

    /// A plausible callsign shape: some letters/digits, at least one digit not in the leading or
    /// trailing position pattern seen in real prefixes (simplified: just require both a letter
    /// and a digit somewhere, plus 3-12 total characters, optionally with a "/" suffix/prefix).
    private static let callsignShapeRegex = try! NSRegularExpression(
        pattern: "^[A-Z0-9]{1,4}[0-9][A-Z0-9]{0,5}(/[A-Z0-9]{1,4})?$"
    )

    static func candidateCallsigns(inMessage message: String) -> [String] {
        message
            .uppercased()
            .split(separator: " ")
            .map(String.init)
            .filter(isPlausibleCallsign)
    }

    private static func isPlausibleCallsign(_ token: String) -> Bool {
        guard token.count >= 3, token.count <= 13 else { return false }
        guard !protocolKeywords.contains(token) else { return false }
        let range = NSRange(token.startIndex..<token.endIndex, in: token)
        if gridSquareRegex.firstMatch(in: token, range: range) != nil { return false }
        if signalReportRegex.firstMatch(in: token, range: range) != nil { return false }
        guard token.contains(where: \.isLetter) else { return false }
        return callsignShapeRegex.firstMatch(in: token, range: range) != nil
    }
}
