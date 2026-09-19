import XCTest
@testable import JTAnnunciatorCore

final class WSJTXMessageDecoderTests: XCTestCase {
    private func header(type: WSJTXMessageType, schema: UInt32 = 2) -> QDataStreamWriter {
        var writer = QDataStreamWriter()
        writer.writeUInt32(WSJTXMessageDecoder.magicNumber)
        writer.writeUInt32(schema)
        writer.writeUInt32(type.rawValue)
        return writer
    }

    func testDecodeHeartbeat() throws {
        var writer = header(type: .heartbeat)
        writer.writeQString("WSJT-X")
        writer.writeUInt32(3)
        writer.writeQString("2.6.1")
        writer.writeQString("abc1234")

        let message = try WSJTXMessageDecoder.decode(writer.data)
        XCTAssertEqual(
            message,
            .heartbeat(
                WSJTXHeartbeat(id: "WSJT-X", maximumSchemaNumber: 3, version: "2.6.1", revision: "abc1234")
            )
        )
    }

    func testDecodeStatus() throws {
        var writer = header(type: .status)
        writer.writeQString("WSJT-X")
        writer.writeUInt64(14_074_000)
        writer.writeQString("FT8")
        writer.writeQString("K1ABC")
        writer.writeQString("-05")
        writer.writeQString("FT8")
        writer.writeBool(true)
        writer.writeBool(false)
        writer.writeBool(true)
        writer.writeInt32(1500)
        writer.writeInt32(1500)
        writer.writeQString("W1AW")
        writer.writeQString("FN42")
        writer.writeQString("FN31")
        writer.writeBool(false)
        writer.writeQString("")
        writer.writeBool(false)
        writer.writeUInt8(0)

        let message = try WSJTXMessageDecoder.decode(writer.data)
        guard case let .status(status) = message else {
            return XCTFail("expected .status, got \(message)")
        }
        XCTAssertEqual(status.dialFrequencyHz, 14_074_000)
        XCTAssertEqual(status.mode, "FT8")
        XCTAssertEqual(status.dxCall, "K1ABC")
        XCTAssertEqual(status.deCall, "W1AW")
        XCTAssertEqual(status.txEnabled, true)
        XCTAssertEqual(status.transmitting, false)
        XCTAssertEqual(status.decoding, true)
    }

    func testDecodeDecodeMessageWithOffAirField() throws {
        var writer = header(type: .decode)
        writer.writeQString("WSJT-X")
        writer.writeBool(true)
        writer.writeUInt32(43_200_000)
        writer.writeInt32(-12)
        writer.writeDouble(0.2)
        writer.writeUInt32(1500)
        writer.writeQString("FT8")
        writer.writeQString("CQ DX K1ABC FN42")
        writer.writeBool(false)
        writer.writeBool(false)

        let message = try WSJTXMessageDecoder.decode(writer.data)
        XCTAssertEqual(
            message,
            .decode(
                WSJTXDecode(
                    id: "WSJT-X", isNew: true, timeMillisSinceMidnightUTC: 43_200_000, snr: -12,
                    deltaTimeSeconds: 0.2, deltaFrequencyHz: 1500, mode: "FT8",
                    message: "CQ DX K1ABC FN42", lowConfidence: false, offAir: false
                )
            )
        )
    }

    func testDecodeDecodeMessageWithoutOffAirFieldFromOlderPeer() throws {
        // Simulates an older WSJT-X release whose schema-2 Decode message stops right after
        // "Low confidence" (no "Off air" byte) — the decoder must not treat this as truncated.
        var writer = header(type: .decode)
        writer.writeQString("WSJT-X")
        writer.writeBool(true)
        writer.writeUInt32(43_200_000)
        writer.writeInt32(-12)
        writer.writeDouble(0.2)
        writer.writeUInt32(1500)
        writer.writeQString("FT8")
        writer.writeQString("K1ABC W9XYZ -12")
        writer.writeBool(false)

        let message = try WSJTXMessageDecoder.decode(writer.data)
        guard case let .decode(decode) = message else {
            return XCTFail("expected .decode, got \(message)")
        }
        XCTAssertEqual(decode.offAir, false)
        XCTAssertEqual(decode.message, "K1ABC W9XYZ -12")
    }

    func testDecodeClear() throws {
        var writer = header(type: .clear)
        writer.writeQString("WSJT-X")

        let message = try WSJTXMessageDecoder.decode(writer.data)
        XCTAssertEqual(message, .clear(WSJTXClear(id: "WSJT-X")))
    }

    func testDecodeClose() throws {
        var writer = header(type: .close)
        writer.writeQString("WSJT-X")

        let message = try WSJTXMessageDecoder.decode(writer.data)
        XCTAssertEqual(message, .close(WSJTXClose(id: "WSJT-X")))
    }

    func testDecodeQSOLogged() throws {
        var writer = header(type: .qsoLogged)
        writer.writeQString("WSJT-X")
        writer.writeInt64QDateTime(julianDay: 2_440_588, msecs: 0, timeSpec: 1) // dateTimeOff
        writer.writeQString("K1ABC")
        writer.writeQString("FN42")
        writer.writeUInt64(14_074_000)
        writer.writeQString("FT8")
        writer.writeQString("-12")
        writer.writeQString("-05")
        writer.writeQString("100W")
        writer.writeQString("")
        writer.writeQString("")
        writer.writeInt64QDateTime(julianDay: 2_440_588, msecs: 0, timeSpec: 1) // dateTimeOn
        writer.writeQString("W1AW")
        writer.writeQString("W1AW")
        writer.writeQString("FN31")
        writer.writeQString("")
        writer.writeQString("")

        let message = try WSJTXMessageDecoder.decode(writer.data)
        guard case let .qsoLogged(qso) = message else {
            return XCTFail("expected .qsoLogged, got \(message)")
        }
        XCTAssertEqual(qso.dxCall, "K1ABC")
        XCTAssertEqual(qso.dxGrid, "FN42")
        XCTAssertEqual(qso.myCall, "W1AW")
        XCTAssertEqual(qso.dateTimeOff.timeIntervalSince1970, 0, accuracy: 0.001)
    }

    func testBadMagicNumberThrows() {
        var writer = QDataStreamWriter()
        writer.writeUInt32(0xDEAD_BEEF)
        writer.writeUInt32(2)
        writer.writeUInt32(WSJTXMessageType.heartbeat.rawValue)

        XCTAssertThrowsError(try WSJTXMessageDecoder.decode(writer.data)) { error in
            XCTAssertEqual(error as? WSJTXMessageDecoder.Error, .badMagicNumber)
        }
    }

    func testUnknownMessageTypeDecodesAsUnsupported() throws {
        var writer = QDataStreamWriter()
        writer.writeUInt32(WSJTXMessageDecoder.magicNumber)
        writer.writeUInt32(2)
        writer.writeUInt32(999)

        let message = try WSJTXMessageDecoder.decode(writer.data)
        XCTAssertEqual(message, .unsupported(type: 999))
    }

    func testHeartbeatEncoderRoundTrips() throws {
        let data = WSJTXMessageEncoder.encodeHeartbeat(id: "JTAnnunciator", version: "0.1", revision: "dev")
        let message = try WSJTXMessageDecoder.decode(data)
        XCTAssertEqual(
            message,
            .heartbeat(
                WSJTXHeartbeat(id: "JTAnnunciator", maximumSchemaNumber: 3, version: "0.1", revision: "dev")
            )
        )
    }

    /// A heartbeat captured verbatim from a live WSJT-X 3.0.1 instance: strings are UTF-8
    /// `QByteArray`s, not UTF-16 `QString`s.
    func testDecodeHeartbeatCapturedFromRealWSJTX() throws {
        let bytes: [UInt8] = [
            0xad, 0xbc, 0xcb, 0xda, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 6,
            0x57, 0x53, 0x4a, 0x54, 0x2d, 0x58, 0, 0, 0, 3, 0, 0, 0, 5,
            0x33, 0x2e, 0x30, 0x2e, 0x31, 0, 0, 0, 6,
            0x63, 0x30, 0x34, 0x64, 0x64, 0x38,
        ]
        let message = try WSJTXMessageDecoder.decode(Data(bytes))
        XCTAssertEqual(
            message,
            .heartbeat(WSJTXHeartbeat(id: "WSJT-X", maximumSchemaNumber: 3, version: "3.0.1", revision: "c04dd8"))
        )
    }
}

private extension QDataStreamWriter {
    /// Test-only helper matching the exact wire layout `QDataStreamReader.readQDateTime` expects.
    mutating func writeInt64QDateTime(julianDay: Int64, msecs: UInt32, timeSpec: UInt8) {
        writeUInt64(UInt64(bitPattern: julianDay))
        writeUInt32(msecs)
        writeUInt8(timeSpec)
    }
}
