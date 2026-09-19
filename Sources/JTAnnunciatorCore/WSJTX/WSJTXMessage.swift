import Foundation

/// The subset of WSJT-X's UDP protocol message types this app understands. Field order/types are
/// taken directly from WSJT-X's `Network/NetworkMessage.hpp` (schema 3 / Qt_5_4, the current
/// schema as of WSJT-X 2.x). Message types WSJT-X only *receives* (Reply, Halt Tx, Free Text,
/// Location, Highlight Callsign) aren't modeled yet — v1 is alert-only (listening), not control.
enum WSJTXMessageType: UInt32 {
    case heartbeat = 0
    case status = 1
    case decode = 2
    case clear = 3
    case reply = 4
    case qsoLogged = 5
    case close = 6
    case replay = 7
    case haltTx = 8
    case freeText = 9
    case wsprDecode = 10
    case location = 11
    case loggedADIF = 12
    case highlightCallsign = 13
}

struct WSJTXHeartbeat: Equatable {
    var id: String
    var maximumSchemaNumber: UInt32
    var version: String
    var revision: String
}

struct WSJTXStatus: Equatable {
    var id: String
    var dialFrequencyHz: UInt64
    var mode: String
    var dxCall: String
    var report: String
    var txMode: String
    var txEnabled: Bool
    var transmitting: Bool
    var decoding: Bool
    var rxDF: Int32
    var txDF: Int32
    var deCall: String
    var deGrid: String
    var dxGrid: String
    var txWatchdog: Bool
    var subMode: String
    var fastMode: Bool
    var specialOperationMode: UInt8
}

struct WSJTXDecode: Equatable {
    var id: String
    var isNew: Bool
    var timeMillisSinceMidnightUTC: UInt32?
    var snr: Int32
    var deltaTimeSeconds: Double
    var deltaFrequencyHz: UInt32
    var mode: String
    var message: String
    var lowConfidence: Bool
    var offAir: Bool
}

struct WSJTXClear: Equatable {
    var id: String
}

struct WSJTXQSOLogged: Equatable {
    var id: String
    var dateTimeOff: Date
    var dxCall: String
    var dxGrid: String
    var txFrequencyHz: UInt64
    var mode: String
    var reportSent: String
    var reportReceived: String
    var txPower: String
    var comments: String
    var name: String
    var dateTimeOn: Date
    var operatorCall: String
    var myCall: String
    var myGrid: String
    var exchangeSent: String
    var exchangeReceived: String
}

struct WSJTXClose: Equatable {
    var id: String
}

struct WSJTXWSPRDecode: Equatable {
    var id: String
    var isNew: Bool
    var timeMillisSinceMidnightUTC: UInt32?
    var snr: Int32
    var deltaTimeSeconds: Double
    var frequencyHz: UInt64
    var driftHz: Int32
    var callsign: String
    var grid: String
    var powerDBm: Int32
    var offAir: Bool
}

struct WSJTXLoggedADIF: Equatable {
    var id: String
    var adifText: String
}

/// A fully decoded WSJT-X UDP datagram. `.unsupported` covers message types this app doesn't
/// need to act on (Reply/HaltTx/FreeText/Location/HighlightCallsign are "In" messages WSJT-X
/// never sends us; Replay is a request we'd send, not receive) plus any schema/type this decoder
/// doesn't recognize.
enum WSJTXMessage: Equatable {
    case heartbeat(WSJTXHeartbeat)
    case status(WSJTXStatus)
    case decode(WSJTXDecode)
    case clear(WSJTXClear)
    case qsoLogged(WSJTXQSOLogged)
    case close(WSJTXClose)
    case wsprDecode(WSJTXWSPRDecode)
    case loggedADIF(WSJTXLoggedADIF)
    case unsupported(type: UInt32)
}
