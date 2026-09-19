import Foundation

#if canImport(SQLite3)
import SQLite3

/// Reads MacLoggerDX's `MacLoggerDX.sql` (a SQLite database, by default in
/// `~/Documents/MLDX_Logs/`). The file is opened read-only, so it's safe to read while
/// MacLoggerDX itself has the log open.
///
/// MacLoggerDX versions its QSO table's name (`qso_table_v008` at the time of writing) and bumps
/// it when the schema changes, so the table is discovered by prefix rather than hard-coded.
public enum MacLoggerDXReader {
    public enum ReadError: Error, LocalizedError, Equatable {
        case fileNotFound(String)
        case cannotOpen(String)
        case noQSOTable
        case query(String)

        public var errorDescription: String? {
            switch self {
            case let .fileNotFound(path): return "File not found: \(path)"
            case let .cannotOpen(message): return "Couldn't open the log: \(message)"
            case .noQSOTable: return "Not a MacLoggerDX log (no QSO table found)."
            case let .query(message): return "Couldn't read the log: \(message)"
            }
        }
    }

    public static func readQSOs(atPath path: String) throws -> [LogbookQSO] {
        guard FileManager.default.fileExists(atPath: path) else { throw ReadError.fileNotFound(path) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw ReadError.cannotOpen(message)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 2000)

        let table = try qsoTableName(in: db)
        let stateColumn = try hasColumn("state", in: table, db: db) ? "state" : "''"
        let sql = "SELECT call, band_tx, mode, qso_done, \(stateColumn) FROM \(table) WHERE call IS NOT NULL AND call != ''"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ReadError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        var qsos: [LogbookQSO] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let date: Date? = sqlite3_column_type(statement, 3) == SQLITE_NULL
                ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
            qsos.append(LogbookQSO(
                callsign: text(statement, 0), band: text(statement, 1), mode: text(statement, 2),
                date: date, state: text(statement, 4)
            ))
        }
        return qsos
    }

    private static func hasColumn(_ column: String, in table: String, db: OpaquePointer) throws -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            throw ReadError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if text(statement, 1) == column { return true }
        }
        return false
    }

    private static func qsoTableName(in db: OpaquePointer) throws -> String {
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'qso_table_v%' ORDER BY name DESC LIMIT 1"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ReadError.query(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw ReadError.noQSOTable }
        return text(statement, 0)
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: cString)
    }
}

extension LogbookConnection {
    /// Reads this connection's log with the reader for its kind.
    public func readQSOs() throws -> [LogbookQSO] {
        switch kind {
        case .macLoggerDX: return try MacLoggerDXReader.readQSOs(atPath: path)
        }
    }
}
#endif
