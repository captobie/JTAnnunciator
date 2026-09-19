import Foundation

/// Reads Qt's `QDataStream` binary wire format (big-endian), the framing WSJT-X uses for every
/// UDP datagram it sends/receives. Only the subset of Qt types the WSJT-X protocol actually uses
/// is implemented here (see `WSJTXMessage`), not general QDataStream support.
///
/// Reference: WSJT-X's `Network/NetworkMessage.hpp`, and Qt's own `QDataStream` operator<</>>
/// implementations for the types below (`QString`, `QDateTime`, `QColor`). Grounded against a
/// live cty.dat/NetworkMessage.hpp read rather than assumed, but never exercised against a real
/// running WSJT-X instance in this session — see the repo README's validation-status note.
struct QDataStreamReader {
    private let data: Data
    private(set) var offset: Int

    enum Error: Swift.Error, Equatable {
        case truncated
        case invalidString
    }

    init(_ data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    var bytesRemaining: Int { data.count - offset }
    var isAtEnd: Bool { offset >= data.count }

    private mutating func take(_ count: Int) throws -> Data {
        guard offset + count <= data.count else { throw Error.truncated }
        let slice = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + count))
        offset += count
        return slice
    }

    mutating func readUInt8() throws -> UInt8 {
        try take(1).first!
    }

    mutating func readBool() throws -> Bool {
        try readUInt8() != 0
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try take(4)
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    mutating func readInt32() throws -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    mutating func readUInt64() throws -> UInt64 {
        let bytes = try take(8)
        return bytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
    }

    mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readUInt64())
    }

    mutating func readDouble() throws -> Double {
        let bits = try readUInt64()
        return Double(bitPattern: bits)
    }

    /// Qt serializes `QString` as a 4-byte length **in bytes** of the UTF-16BE payload that
    /// follows (`0xFFFFFFFF` for a null string, distinct from an empty string of length 0).
    mutating func readQString() throws -> String {
        let length = try readUInt32()
        if length == 0xFFFF_FFFF {
            return ""
        }
        guard length % 2 == 0 else { throw Error.invalidString }
        let bytes = try take(Int(length))
        var utf16 = [UInt16]()
        utf16.reserveCapacity(bytes.count / 2)
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let hi = UInt16(bytes[index])
            let lo = UInt16(bytes[index + 1])
            utf16.append((hi << 8) | lo)
            index += 2
        }
        return String(utf16CodeUnits: utf16, count: utf16.count)
    }

    /// Qt's `QTime` (as used inside WSJT-X's Decode/Reply/WSPR Decode messages) is just
    /// milliseconds-since-midnight; `0xFFFFFFFF` means "null/invalid time".
    mutating func readQTimeMillisSinceMidnight() throws -> UInt32? {
        let raw = try readUInt32()
        return raw == 0xFFFF_FFFF ? nil : raw
    }

    /// Qt's `QDateTime` under stream version >= 13 (Qt 5.0+, which is what WSJT-X's schema 2/3
    /// use): Julian day number (Int64), milliseconds-since-midnight (UInt32), a `Qt::TimeSpec`
    /// byte (0 local, 1 UTC, 2 offset-from-UTC, 3 named time zone), then a spec-dependent tail.
    /// WSJT-X always sends UTC (spec 1) in practice; the other cases are decoded to stay in sync
    /// with the stream even though nothing in this app currently needs them.
    mutating func readQDateTime() throws -> Date {
        let julianDay = try readInt64()
        let millisSinceMidnight = try readUInt32()
        let timeSpec = try readUInt8()
        switch timeSpec {
        case 2: // Qt::OffsetFromUTC
            _ = try readInt32() // offset seconds, ignored: we already interpret the instant as UTC
        case 3: // Qt::TimeZone
            _ = try readQByteArray() // IANA zone id
        default:
            break // Qt::LocalTime (0) or Qt::UTC (1): nothing further to read
        }
        // Julian day 2440588 == 1970-01-01. Qt's QDate julian day is noon-based; converting via
        // the standard offset used by every published QDataStream-format writeup for this type.
        let daysSinceEpoch = julianDay - 2_440_588
        let seconds = TimeInterval(daysSinceEpoch) * 86_400 + TimeInterval(millisSinceMidnight) / 1000
        return Date(timeIntervalSince1970: seconds)
    }

    /// `QByteArray`: a 4-byte length prefix (`0xFFFFFFFF` for null) followed by raw bytes.
    mutating func readQByteArray() throws -> Data {
        let length = try readUInt32()
        if length == 0xFFFF_FFFF { return Data() }
        return try take(Int(length))
    }
}

/// Writes the same subset of `QDataStream` needed to send messages back to WSJT-X (Heartbeat,
/// and in future the "In" message types like Reply/Highlight Callsign).
struct QDataStreamWriter {
    private(set) var data = Data()

    mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    mutating func writeBool(_ value: Bool) {
        writeUInt8(value ? 1 : 0)
    }

    mutating func writeUInt32(_ value: UInt32) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    mutating func writeUInt64(_ value: UInt64) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }

    mutating func writeDouble(_ value: Double) {
        writeUInt64(value.bitPattern)
    }

    mutating func writeQString(_ string: String) {
        let utf16 = Array(string.utf16)
        writeUInt32(UInt32(utf16.count * 2))
        for unit in utf16 {
            data.append(UInt8(unit >> 8))
            data.append(UInt8(unit & 0xFF))
        }
    }
}
