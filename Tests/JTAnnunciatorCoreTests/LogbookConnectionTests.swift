import XCTest
@testable import JTAnnunciatorCore

final class LogbookConnectionTests: XCTestCase {
    /// A connection saved before Wavelog (and its network fields) existed — just the original
    /// four properties. Must still decode, or upgrading this app would silently drop a user's
    /// already-configured MacLoggerDX connection.
    func testConnectionSavedBeforeWavelogStillDecodes() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","kind":"macLoggerDX","path":"/Users/x/log.sql","isEnabled":true}
        """
        let connection = try JSONDecoder().decode(LogbookConnection.self, from: Data(json.utf8))

        XCTAssertEqual(connection.id, id)
        XCTAssertEqual(connection.kind, .macLoggerDX)
        XCTAssertEqual(connection.path, "/Users/x/log.sql")
        XCTAssertTrue(connection.isEnabled)
        XCTAssertNil(connection.serverURL)
        XCTAssertNil(connection.apiKey)
        XCTAssertNil(connection.stationID)
        XCTAssertNil(connection.lastFetchedID)
    }

    func testWavelogConnectionRoundTrips() throws {
        let original = LogbookConnection(
            kind: .wavelog, serverURL: "https://log.example.com", apiKey: "KEY",
            stationID: 2, lastFetchedID: 99
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogbookConnection.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMacLoggerDXIsFileBasedWavelogIsNot() {
        XCTAssertTrue(LogbookKind.macLoggerDX.isFileBased)
        XCTAssertFalse(LogbookKind.wavelog.isFileBased)
    }
}
