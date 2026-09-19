import Foundation

/// The subset of WSJT-X's UDP protocol message types this app understands. Field order/types are
/// taken directly from WSJT-X's `Network/NetworkMessage.hpp` (schema 3 / Qt_5_4, the current
/// schema as of WSJT-X 2.x). Message types WSJT-X only *receives* (Reply, Halt Tx, Free Text,
/// Location, Highlight Callsign) aren't modeled yet — v1 is alert-only (listening), not control.
public enum WSJTXMessageType: UInt32 {
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

public struct WSJTXHeartbeat: Equatable {
    public var id: String
    public var maximumSchemaNumber: UInt32
    public var version: String
    public var revision: String
}

public struct WSJTXStatus: Equatable {
    public var id: String
    public var dialFrequencyHz: UInt64
    public var mode: String
    public var dxCall: String
    public var report: String
    public var txMode: String
    public var txEnabled: Bool
    public var transmitting: Bool
    public var decoding: Bool
    public var rxDF: Int32
    public var txDF: Int32
    public var deCall: String
    public var deGrid: String
    public var dxGrid: String
    public var txWatchdog: Bool
    public var subMode: String
    public var fastMode: Bool
    public var specialOperationMode: UInt8
}

public struct WSJTXDecode: Equatable {
    public var id: String
    public var isNew: Bool
    public var timeMillisSinceMidnightUTC: UInt32?
    public var snr: Int32
    public var deltaTimeSeconds: Double
    public var deltaFrequencyHz: UInt32
    public var mode: String
    public var message: String
    public var lowConfidence: Bool
    public var offAir: Bool
}

public struct WSJTXClear: Equatable {
    public var id: String
}

public struct WSJTXQSOLogged: Equatable {
    public var id: String
    public var dateTimeOff: Date
    public var dxCall: String
    public var dxGrid: String
    public var txFrequencyHz: UInt64
    public var mode: String
    public var reportSent: String
    public var reportReceived: String
    public var txPower: String
    public var comments: String
    public var name: String
    public var dateTimeOn: Date
    public var operatorCall: String
    public var myCall: String
    public var myGrid: String
    public var exchangeSent: String
    public var exchangeReceived: String
}

public struct WSJTXClose: Equatable {
    public var id: String
}

public struct WSJTXWSPRDecode: Equatable {
    public var id: String
    public var isNew: Bool
    public var timeMillisSinceMidnightUTC: UInt32?
    public var snr: Int32
    public var deltaTimeSeconds: Double
    public var frequencyHz: UInt64
    public var driftHz: Int32
    public var callsign: String
    public var grid: String
    public var powerDBm: Int32
    public var offAir: Bool
}

public struct WSJTXLoggedADIF: Equatable {
    public var id: String
    public var adifText: String
}

/// A fully decoded WSJT-X UDP datagram. `.unsupported` covers message types this app doesn't
/// need to act on (Reply/HaltTx/FreeText/Location/HighlightCallsign are "In" messages WSJT-X
/// never sends us; Replay is a request we'd send, not receive) plus any schema/type this decoder
/// doesn't recognize.
public enum WSJTXMessage: Equatable {
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
