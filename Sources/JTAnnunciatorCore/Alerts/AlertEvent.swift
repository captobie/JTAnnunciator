import Foundation

/// Why a station triggered an alert. A station can match both — matching on the more specific
/// reason (`wantedCallsign`) takes priority when both are true, but the event records whichever
/// actually matched so the UI can show the right badge/color.
enum AlertReason: Equatable {
    case wantedCallsign
    case wantedDXCC(entityName: String, primaryPrefix: String)
}

/// A single "this station is worth your attention" event, produced by `AlertEngine` from a
/// WSJT-X Decode message.
struct AlertEvent: Identifiable, Equatable {
    let id: UUID
    var callsign: String
    var reason: AlertReason
    var decode: WSJTXDecode
    var alreadyWorked: Bool
    var timestamp: Date

    init(
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
