import Foundation

/// Why a station triggered an alert. A station can match both — matching on the more specific
/// reason (`wantedCallsign`) takes priority when both are true, but the event records whichever
/// actually matched so the UI can show the right badge/color.
public enum AlertReason: Equatable {
    case wantedCallsign
    case wantedDXCC(entityName: String, primaryPrefix: String)
}

/// A single "this station is worth your attention" event, produced by `AlertEngine` from a
/// WSJT-X Decode message.
public struct AlertEvent: Identifiable, Equatable {
    public let id: UUID
    public var callsign: String
    public var reason: AlertReason
    public var decode: WSJTXDecode
    public var alreadyWorked: Bool
    public var timestamp: Date

    public init(
        id: UUID = UUID(), callsign: String, reason: AlertReason, decode: WSJTXDecode,
        alreadyWorked: Bool, timestamp: Date = Date()
    ) {
        self.id = id
        self.callsign = callsign
        self.reason = reason
        self.decode = decode
        self.alreadyWorked = alreadyWorked
        self.timestamp = timestamp
    }
}
