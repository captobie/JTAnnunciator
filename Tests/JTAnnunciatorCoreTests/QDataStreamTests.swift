import XCTest
@testable import JTAnnunciatorCore

final class QDataStreamTests: XCTestCase {
    func testPrimitiveRoundTrip() throws {
        var writer = QDataStreamWriter()
        writer.writeUInt8(0xAB)
        writer.writeBool(true)
        writer.writeBool(false)
        writer.writeUInt32(0x1234_5678)
        writer.writeInt32(-42)
        writer.writeUInt64(0x0102_0304_0506_0708)
        writer.writeDouble(3.5)

        var reader = QDataStreamReader(writer.data)
        XCTAssertEqual(try reader.readUInt8(), 0xAB)
        XCTAssertEqual(try reader.readBool(), true)
        XCTAssertEqual(try reader.readBool(), false)
        XCTAssertEqual(try reader.readUInt32(), 0x1234_5678)
        XCTAssertEqual(try reader.readInt32(), -42)
        XCTAssertEqual(try reader.readUInt64(), 0x0102_0304_0506_0708)
        XCTAssertEqual(try reader.readDouble(), 3.5)
        XCTAssertTrue(reader.isAtEnd)
    }

    func testQStringRoundTrip() throws {
        var writer = QDataStreamWriter()
        writer.writeQString("WSJT-X")
        writer.writeQString("")

        var reader = QDataStreamReader(writer.data)
        XCTAssertEqual(try reader.readQString(), "WSJT-X")
        XCTAssertEqual(try reader.readQString(), "")
    }

    func testQStringNullSentinelDecodesAsEmpty() throws {
        // 0xFFFFFFFF length prefix means "null string", not an empty (zero-length) string.
        var writer = QDataStreamWriter()
        writer.writeUInt32(0xFFFF_FFFF)

        var reader = QDataStreamReader(writer.data)
        XCTAssertEqual(try reader.readQString(), "")
        XCTAssertTrue(reader.isAtEnd)
    }

    func testQTimeNullSentinel() throws {
        var writer = QDataStreamWriter()
        writer.writeUInt32(0xFFFF_FFFF)
        writer.writeUInt32(12_345)

        var reader = QDataStreamReader(writer.data)
        XCTAssertNil(try reader.readQTimeMillisSinceMidnight())
        XCTAssertEqual(try reader.readQTimeMillisSinceMidnight(), 12_345)
    }

    func testQDateTimeAtUnixEpoch() throws {
        // Julian day 2440588 is the well-documented Julian day number for 1970-01-01, the
        // instant this app's own Date/TimeInterval representation is anchored to. This is the
        // one absolute (not just self-consistent round-trip) check on readQDateTime.
        var writer = QDataStreamWriter()
        writer.writeInt64(2_440_588)
        writer.writeUInt32(0) // midnight
        writer.writeUInt8(1) // Qt::UTC

        var reader = QDataStreamReader(writer.data)
        let date = try reader.readQDateTime()
        XCTAssertEqual(date.timeIntervalSince1970, 0, accuracy: 0.001)
    }

    func testQDateTimeWithOffsetFromUTCIsSkippedCorrectly() throws {
        var writer = QDataStreamWriter()
        writer.writeInt64(2_440_589) // one day after epoch
        writer.writeUInt32(0)
        writer.writeUInt8(2) // Qt::OffsetFromUTC
        writer.writeInt32(3600) // offset seconds (ignored by the reader, but must be consumed)
        writer.writeQString("next field") // proves the reader consumed exactly the offset int32

        var reader = QDataStreamReader(writer.data)
        let date = try reader.readQDateTime()
        XCTAssertEqual(date.timeIntervalSince1970, 86_400, accuracy: 0.001)
        XCTAssertEqual(try reader.readQString(), "next field")
    }

    func testTruncatedDataThrows() {
        var writer = QDataStreamWriter()
        writer.writeUInt8(1)
        var reader = QDataStreamReader(writer.data)
        XCTAssertThrowsError(try reader.readUInt32())
    }
}

private extension QDataStreamWriter {
    mutating func writeInt64(_ value: Int64) {
        writeUInt64(UInt64(bitPattern: value))
    }
}
