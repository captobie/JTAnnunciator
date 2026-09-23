import XCTest
@testable import JTAnnunciatorCore

final class WavelogReaderTests: XCTestCase {
    private func makeConnection(
        serverURL: String = "https://log.example.com", apiKey: String = "MYKEY",
        stationID: Int = 1, lastFetchedID: Int? = nil
    ) -> LogbookConnection {
        LogbookConnection(
            kind: .wavelog, serverURL: serverURL, apiKey: apiKey, stationID: stationID,
            lastFetchedID: lastFetchedID
        )
    }

    private func jsonResponse(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    func testFirstPullIsNotDeltaAndRequestsFromZero() async throws {
        var capturedURL: URL?
        var capturedBody: [String: Any] = [:]
        let post: WavelogReader.Post = { url, body in
            capturedURL = url
            capturedBody = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
            return self.jsonResponse([
                "exported_qsos": 1, "lastfetchedid": 42, "message": "Export successful",
                "adif": "<CALL:5>K1ABC<BAND:3>20M<MODE:3>FT8<EOR>",
            ])
        }

        let result = try await WavelogReader.fetch(connection: makeConnection(), post: post)

        XCTAssertEqual(capturedURL?.absoluteString, "https://log.example.com/index.php/api/get_contacts_adif")
        XCTAssertEqual(capturedBody["key"] as? String, "MYKEY")
        XCTAssertEqual(capturedBody["station_id"] as? Int, 1)
        XCTAssertEqual(capturedBody["fetchfromid"] as? Int, 0)
        XCTAssertFalse(result.isDelta)
        XCTAssertEqual(result.qsos.map(\.callsign), ["K1ABC"])
        XCTAssertEqual(result.updatedConnection.lastFetchedID, 42)
    }

    func testSubsequentPullIsDeltaAndResumesFromLastID() async throws {
        var capturedBody: [String: Any] = [:]
        let post: WavelogReader.Post = { _, body in
            capturedBody = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
            return self.jsonResponse(["lastfetchedid": 100, "adif": ""])
        }

        let result = try await WavelogReader.fetch(connection: makeConnection(lastFetchedID: 42), post: post)

        XCTAssertEqual(capturedBody["fetchfromid"] as? Int, 42)
        XCTAssertTrue(result.isDelta)
        XCTAssertEqual(result.qsos, [])
        XCTAssertEqual(result.updatedConnection.lastFetchedID, 100)
    }

    func testMissingAPIKeyThrowsWithoutNetworkCall() async {
        var called = false
        let post: WavelogReader.Post = { _, _ in called = true; return Data() }

        await XCTAssertThrowsErrorAsync(try await WavelogReader.fetch(connection: makeConnection(apiKey: ""), post: post)) {
            XCTAssertEqual($0 as? WavelogReader.ReadError, .missingAPIKey)
        }
        XCTAssertFalse(called)
    }

    func testInvalidServerURLThrows() async {
        let post: WavelogReader.Post = { _, _ in Data() }
        await XCTAssertThrowsErrorAsync(
            try await WavelogReader.fetch(connection: makeConnection(serverURL: "not a url"), post: post)
        ) {
            XCTAssertEqual($0 as? WavelogReader.ReadError, .invalidServerURL("not a url"))
        }
    }

    func testAPIErrorMessageSurfacedWhenNoADIFReturned() async {
        let post: WavelogReader.Post = { _, _ in
            self.jsonResponse(["message": "Invalid API key"])
        }
        await XCTAssertThrowsErrorAsync(try await WavelogReader.fetch(connection: makeConnection(), post: post)) {
            XCTAssertEqual($0 as? WavelogReader.ReadError, .api("Invalid API key"))
        }
    }

    func testTransportErrorIsWrapped() async {
        struct Boom: Error {}
        let post: WavelogReader.Post = { _, _ in throw Boom() }
        await XCTAssertThrowsErrorAsync(try await WavelogReader.fetch(connection: makeConnection(), post: post)) {
            guard case WavelogReader.ReadError.transport = $0 else {
                XCTFail("expected .transport, got \($0)"); return
            }
        }
    }
}

/// `XCTAssertThrowsError` doesn't await its expression; this variant does.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T, _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath, line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error to be thrown", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
