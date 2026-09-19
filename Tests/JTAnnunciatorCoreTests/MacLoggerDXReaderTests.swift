import XCTest
@testable import JTAnnunciatorCore

#if canImport(SQLite3)
import SQLite3

final class MacLoggerDXReaderTests: XCTestCase {
    private var path: String!

    override func setUp() {
        path = NSTemporaryDirectory() + "mldx-\(UUID().uuidString).sql"
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: path)
    }

    private func makeDatabase(table: String, rows: [String]) {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        let statements = [
            "CREATE TABLE \(table) (pk INTEGER PRIMARY KEY, call TEXT, band_tx TEXT, mode TEXT, qso_done REAL)"
        ] + rows.map { "INSERT INTO \(table) (call, band_tx, mode, qso_done) VALUES \($0)" }
        for sql in statements {
            XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql)
        }
    }

    func testReadsQSOsAndSkipsBlankCalls() throws {
        makeDatabase(table: "qso_table_v008", rows: [
            "('K1ABC', '20m', 'FT8', 1789832295.5)",
            "('JA8CPF/P', '40M', 'FT4', NULL)",
            "('', '20M', 'FT8', 1.0)",
            "(NULL, '20M', 'FT8', 1.0)",
        ])

        let qsos = try MacLoggerDXReader.readQSOs(atPath: path)

        XCTAssertEqual(qsos.map(\.callsign), ["K1ABC", "JA8CPF/P"])
        XCTAssertEqual(qsos[0].band, "20M")
        XCTAssertEqual(qsos[0].date, Date(timeIntervalSince1970: 1789832295.5))
        XCTAssertNil(qsos[1].date)
    }

    func testFindsNewerTableVersion() throws {
        makeDatabase(table: "qso_table_v009", rows: ["('K1ABC', '20M', 'FT8', 1.0)"])
        XCTAssertEqual(try MacLoggerDXReader.readQSOs(atPath: path).count, 1)
    }

    func testMissingFileAndWrongDatabaseThrow() {
        XCTAssertThrowsError(try MacLoggerDXReader.readQSOs(atPath: path)) {
            XCTAssertEqual($0 as? MacLoggerDXReader.ReadError, .fileNotFound(path))
        }
        makeDatabase(table: "something_else", rows: [])
        XCTAssertThrowsError(try MacLoggerDXReader.readQSOs(atPath: path)) {
            XCTAssertEqual($0 as? MacLoggerDXReader.ReadError, .noQSOTable)
        }
    }
}
#endif
