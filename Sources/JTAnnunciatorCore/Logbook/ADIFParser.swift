import Foundation

/// A minimal reader for ADIF (Amateur Data Interchange Format), the contact-export format shared
/// by essentially every logging program. Only the fields this app cares about are extracted;
/// unknown fields, and the free-text header before `<EOH>`, are ignored. Not a validator — a
/// malformed record is simply skipped rather than rejecting the whole file, since a single bad
/// row from a third-party export shouldn't lose every other row.
public enum ADIFParser {
    /// One ADIF record's fields, keyed by uppercased field name (e.g. "CALL", "QSO_DATE").
    static func records(_ text: String) -> [[String: String]] {
        var body = Substring(text)
        if let headerEnd = body.range(of: "<eoh>", options: [.caseInsensitive]) {
            body = body[headerEnd.upperBound...]
        }

        var records: [[String: String]] = []
        var current: [String: String] = [:]
        let characters = Array(body)
        var index = 0
        while index < characters.count {
            guard characters[index] == "<" else { index += 1; continue }
            guard let close = characters[index...].firstIndex(of: ">") else { break }
            let tag = String(characters[(index + 1)..<close])
            let parts = tag.split(separator: ":", maxSplits: 2)
            let name = parts.first.map { $0.uppercased() } ?? ""

            if name == "EOR" {
                records.append(current)
                current = [:]
                index = close + 1
                continue
            }
            guard name != "EOH", parts.count >= 2, let length = Int(parts[1]), length >= 0 else {
                index = close + 1
                continue
            }
            let valueStart = close + 1
            let valueEnd = min(valueStart + length, characters.count)
            current[name] = String(characters[valueStart..<valueEnd])
            index = valueEnd
        }
        return records
    }

    /// Parses ADIF text into `LogbookQSO`s, skipping any record without a callsign.
    public static func qsos(fromADIF text: String) -> [LogbookQSO] {
        records(text).compactMap { record in
            guard let call = record["CALL"], !call.isEmpty else { return nil }
            return LogbookQSO(
                callsign: call,
                band: record["BAND"] ?? "",
                mode: record["MODE"] ?? "",
                date: date(qsoDate: record["QSO_DATE"], timeOn: record["TIME_ON"]),
                state: record["STATE"] ?? ""
            )
        }
    }

    /// ADIF dates/times are UTC: `QSO_DATE` is `YYYYMMDD`, `TIME_ON` is `HHMM` or `HHMMSS`.
    private static func date(qsoDate: String?, timeOn: String?) -> Date? {
        guard let qsoDate, qsoDate.count == 8 else { return nil }
        var components = DateComponents()
        components.year = Int(qsoDate.prefix(4))
        components.month = Int(qsoDate.dropFirst(4).prefix(2))
        components.day = Int(qsoDate.suffix(2))
        if let timeOn, timeOn.count >= 4 {
            components.hour = Int(timeOn.prefix(2))
            components.minute = Int(timeOn.dropFirst(2).prefix(2))
            components.second = timeOn.count >= 6 ? Int(timeOn.dropFirst(4).prefix(2)) : 0
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)
    }
}
