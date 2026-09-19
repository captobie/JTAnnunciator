import Foundation

/// Decodes a single WSJT-X UDP datagram into a `WSJTXMessage`.
///
/// Every WSJT-X UDP packet starts with a fixed 12-byte header: a magic number, a schema number,
/// and the message type — all `quint32`, all big-endian (Qt's `QDataStream` default). This
/// decoder targets schema 2/3 (Qt_5_2 / Qt_5_4), which is what every WSJT-X release since 1.9
/// has sent; schema 1 (Qt_5_0) is documented upstream as broken and unsupported by WSJT-X itself.
enum WSJTXMessageDecoder {
    /// WSJT-X's fixed magic number identifying a datagram as its own protocol, not stray UDP
    /// traffic on the same port.
    static let magicNumber: UInt32 = 0xadbc_cbda

    enum Error: Swift.Error, Equatable {
        case badMagicNumber
        case truncated
    }

    static func decode(_ datagram: Data) throws -> WSJTXMessage {
        var reader = QDataStreamReader(datagram)
        let magic = try readOrThrow { try reader.readUInt32() }
        guard magic == magicNumber else { throw Error.badMagicNumber }
        _ = try readOrThrow { try reader.readUInt32() } // schema number: fields below are schema 2/3 either way
        let rawType = try readOrThrow { try reader.readUInt32() }

        guard let type = WSJTXMessageType(rawValue: rawType) else {
            return .unsupported(type: rawType)
        }

        do {
            switch type {
            case .heartbeat:
                return .heartbeat(try decodeHeartbeat(&reader))
            case .status:
                return .status(try decodeStatus(&reader))
            case .decode:
                return .decode(try decodeDecode(&reader))
            case .clear:
                return .clear(WSJTXClear(id: try reader.readQString()))
            case .qsoLogged:
                return .qsoLogged(try decodeQSOLogged(&reader))
            case .close:
                return .close(WSJTXClose(id: try reader.readQString()))
            case .wsprDecode:
                return .wsprDecode(try decodeWSPRDecode(&reader))
            case .loggedADIF:
                return .loggedADIF(WSJTXLoggedADIF(id: try reader.readQString(), adifText: try reader.readQString()))
            case .reply, .replay, .haltTx, .freeText, .location, .highlightCallsign:
                return .unsupported(type: rawType)
            }
        } catch is QDataStreamReader.Error {
            throw Error.truncated
        }
    }

    private static func readOrThrow<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch is QDataStreamReader.Error {
            throw Error.truncated
        }
    }

    private static func decodeHeartbeat(_ reader: inout QDataStreamReader) throws -> WSJTXHeartbeat {
        WSJTXHeartbeat(
            id: try reader.readQString(),
            maximumSchemaNumber: try reader.readUInt32(),
            version: try reader.readQString(),
            revision: try reader.readQString()
        )
    }

    private static func decodeStatus(_ reader: inout QDataStreamReader) throws -> WSJTXStatus {
        let id = try reader.readQString()
        let dialFrequencyHz = try reader.readUInt64()
        let mode = try reader.readQString()
        let dxCall = try reader.readQString()
        let report = try reader.readQString()
        let txMode = try reader.readQString()
        let txEnabled = try reader.readBool()
        let transmitting = try reader.readBool()
        let decoding = try reader.readBool()
        let rxDF = try reader.readInt32()
        let txDF = try reader.readInt32()
        let deCall = try reader.readQString()
        let deGrid = try reader.readQString()
        let dxGrid = try reader.readQString()
        let txWatchdog = try reader.readBool()
        let subMode = try reader.readQString()
        let fastMode = try reader.readBool()
        let specialOperationMode = try reader.readUInt8()
        return WSJTXStatus(
            id: id, dialFrequencyHz: dialFrequencyHz, mode: mode, dxCall: dxCall, report: report,
            txMode: txMode, txEnabled: txEnabled, transmitting: transmitting, decoding: decoding,
            rxDF: rxDF, txDF: txDF, deCall: deCall, deGrid: deGrid, dxGrid: dxGrid,
            txWatchdog: txWatchdog, subMode: subMode, fastMode: fastMode,
            specialOperationMode: specialOperationMode
        )
    }

    private static func decodeDecode(_ reader: inout QDataStreamReader) throws -> WSJTXDecode {
        let id = try reader.readQString()
        let isNew = try reader.readBool()
        let time = try reader.readQTimeMillisSinceMidnight()
        let snr = try reader.readInt32()
        let deltaTime = try reader.readDouble()
        let deltaFrequency = try reader.readUInt32()
        let mode = try reader.readQString()
        let message = try reader.readQString()
        let lowConfidence = try reader.readBool()
        // "Off air" was added after schema 2 shipped; a peer on an older WSJT-X release simply
        // omits it, so treat running out of bytes here as "false" rather than a decode failure.
        let offAir = (try? reader.readBool()) ?? false
        return WSJTXDecode(
            id: id, isNew: isNew, timeMillisSinceMidnightUTC: time, snr: snr,
            deltaTimeSeconds: deltaTime, deltaFrequencyHz: deltaFrequency, mode: mode,
            message: message, lowConfidence: lowConfidence, offAir: offAir
        )
    }

    private static func decodeQSOLogged(_ reader: inout QDataStreamReader) throws -> WSJTXQSOLogged {
        let id = try reader.readQString()
        let dateTimeOff = try reader.readQDateTime()
        let dxCall = try reader.readQString()
        let dxGrid = try reader.readQString()
        let txFrequencyHz = try reader.readUInt64()
        let mode = try reader.readQString()
        let reportSent = try reader.readQString()
        let reportReceived = try reader.readQString()
        let txPower = try reader.readQString()
        let comments = try reader.readQString()
        let name = try reader.readQString()
        let dateTimeOn = try reader.readQDateTime()
        let operatorCall = try reader.readQString()
        let myCall = try reader.readQString()
        let myGrid = try reader.readQString()
        let exchangeSent = try reader.readQString()
        let exchangeReceived = try reader.readQString()
        return WSJTXQSOLogged(
            id: id, dateTimeOff: dateTimeOff, dxCall: dxCall, dxGrid: dxGrid,
            txFrequencyHz: txFrequencyHz, mode: mode, reportSent: reportSent,
            reportReceived: reportReceived, txPower: txPower, comments: comments, name: name,
            dateTimeOn: dateTimeOn, operatorCall: operatorCall, myCall: myCall, myGrid: myGrid,
            exchangeSent: exchangeSent, exchangeReceived: exchangeReceived
        )
    }

    private static func decodeWSPRDecode(_ reader: inout QDataStreamReader) throws -> WSJTXWSPRDecode {
        let id = try reader.readQString()
        let isNew = try reader.readBool()
        let time = try reader.readQTimeMillisSinceMidnight()
        let snr = try reader.readInt32()
        let deltaTime = try reader.readDouble()
        let frequencyHz = try reader.readUInt64()
        let driftHz = try reader.readInt32()
        let callsign = try reader.readQString()
        let grid = try reader.readQString()
        let powerDBm = try reader.readInt32()
        let offAir = (try? reader.readBool()) ?? false
        return WSJTXWSPRDecode(
            id: id, isNew: isNew, timeMillisSinceMidnightUTC: time, snr: snr,
            deltaTimeSeconds: deltaTime, frequencyHz: frequencyHz, driftHz: driftHz,
            callsign: callsign, grid: grid, powerDBm: powerDBm, offAir: offAir
        )
    }
}

/// Encodes the one message type this app sends back to WSJT-X in v1: a Heartbeat, which both
/// announces us as a connected UDP client and lets WSJT-X's "UDP Server" list show us.
enum WSJTXMessageEncoder {
    /// The schema number to declare on outgoing datagrams. WSJT-X accepts 2 or 3; 2 (Qt_5_2)
    /// is used here since it's the smaller/older-compatible field set actually needed for a
    /// heartbeat.
    static let schemaNumber: UInt32 = 2

    static func encodeHeartbeat(id: String, maximumSchemaNumber: UInt32 = 3, version: String, revision: String) -> Data {
        var writer = QDataStreamWriter()
        writer.writeUInt32(WSJTXMessageDecoder.magicNumber)
        writer.writeUInt32(schemaNumber)
        writer.writeUInt32(WSJTXMessageType.heartbeat.rawValue)
        writer.writeQString(id)
        writer.writeUInt32(maximumSchemaNumber)
        writer.writeQString(version)
        writer.writeQString(revision)
        return writer.data
    }
}
