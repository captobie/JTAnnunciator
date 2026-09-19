import Foundation

/// Coarse classification of a decoded message, used to route decodes into the UI's panes.
public enum MessageClassifier {
    /// True for "CQ ...", "CQ DX ...", "CQ POTA ..." etc.
    public static func isCQ(_ message: String) -> Bool {
        tokens(message).first == "CQ"
    }

    /// True when `myCallsign` is the addressee — the first token of a directed message such as
    /// "K1ABC W9XYZ -12". A message *from* me (second token) does not count, and neither does a CQ.
    /// Angle brackets WSJT-X puts around hashed callsigns (`<K1ABC>`) are ignored.
    public static func isDirected(_ message: String, to myCallsign: String) -> Bool {
        let mine = normalize(myCallsign)
        guard !mine.isEmpty, let first = tokens(message).first else { return false }
        return first == mine
    }

    /// The station that transmitted the message: the callsign after "CQ [modifier]", or the
    /// second callsign of a directed message ("K1ABC W9XYZ -12" → W9XYZ). `nil` if none found.
    public static func senderCallsign(_ message: String) -> String? {
        let bracketless = message.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "")
        let candidates = FT8MessageParser.candidateCallsigns(inMessage: bracketless)
        return isCQ(message) ? candidates.first : candidates.last
    }

    /// The transmitting station of a directed message: the second token of "K7CMA AA6NN -12"
    /// is AA6NN. Returns nil for messages with fewer than two tokens.
    public static func sender(of message: String) -> String? {
        let all = tokens(message)
        return all.count >= 2 ? all[1] : nil
    }

    private static func tokens(_ message: String) -> [String] {
        message.split(separator: " ").map { normalize(String($0)) }
    }

    private static func normalize(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")).uppercased()
    }
}
