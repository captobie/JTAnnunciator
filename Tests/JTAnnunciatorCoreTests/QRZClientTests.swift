import XCTest
@testable import JTAnnunciatorCore

final class QRZClientTests: XCTestCase {
    private func xml(session: String, callsign: String = "") -> Data {
        Data("""
        <?xml version="1.0" ?>
        <QRZDatabase version="1.34" xmlns="http://xmldata.qrz.com">
        \(callsign)<Session>\(session)</Session>
        </QRZDatabase>
        """.utf8)
    }

    private let loginOK = "<Key>abc123</Key><SubExp>Sat Jan 1 00:00:00 2028</SubExp>"
    private let w1aw = """
        <Callsign><call>W1AW</call><fname>Hiram Percy</fname><name>Maxim</name>\
        <addr2>Newington</addr2><state>CT</state><country>United States</country>\
        <grid>FN31pr</grid></Callsign>
        """

    /// Serves `replies` in order and records each requested URL.
    private final class Server: @unchecked Sendable {
        private let lock = NSLock()
        private var replies: [Data]
        private(set) var urls: [URL] = []
        init(_ replies: [Data]) { self.replies = replies }
        func next(_ url: URL) -> Data {
            lock.lock(); defer { lock.unlock() }
            urls.append(url)
            return replies.removeFirst()
        }
    }

    private func client(_ server: Server, password: String = "pw") -> QRZClient {
        QRZClient(username: "N0CALL", password: password) { server.next($0) }
    }

    func testLoginThenLookupParsesRecord() async throws {
        let server = Server([xml(session: loginOK), xml(session: "<Key>abc123</Key>", callsign: w1aw)])
        let record = try await client(server).lookup(callsign: "W1AW")
        XCTAssertEqual(record, CallbookRecord(
            callsign: "W1AW", name: "Hiram Percy Maxim", city: "Newington",
            state: "CT", country: "United States", grid: "FN31pr"))
        XCTAssertEqual(record?.location, "Newington, CT, United States")
        XCTAssertTrue(server.urls[1].absoluteString.contains("s=abc123"))
    }

    func testNotFoundReturnsNil() async throws {
        let server = Server([xml(session: loginOK), xml(session: "<Error>Not found: XX9XX</Error>")])
        let record = try await client(server).lookup(callsign: "XX9XX")
        XCTAssertNil(record)
    }

    func testPortableCallFallsBackToBaseCall() async throws {
        let server = Server([
            xml(session: loginOK),
            xml(session: "<Error>Not found: W1AW/P</Error>"),
            xml(session: "<Key>abc123</Key>", callsign: w1aw),
        ])
        let record = try await client(server).lookup(callsign: "W1AW/P")
        XCTAssertEqual(record?.callsign, "W1AW")
    }

    func testExpiredSessionReLogsInOnce() async throws {
        let server = Server([
            xml(session: loginOK),
            xml(session: "<Error>Session Timeout</Error>"),
            xml(session: "<Key>def456</Key>"),
            xml(session: "<Key>def456</Key>", callsign: w1aw),
        ])
        let record = try await client(server).lookup(callsign: "W1AW")
        XCTAssertEqual(record?.callsign, "W1AW")
        XCTAssertTrue(server.urls[3].absoluteString.contains("s=def456"))
    }

    func testBadCredentialsThrowAuthenticationFailed() async {
        let server = Server([xml(session: "<Error>Username/password incorrect </Error>")])
        do {
            try await client(server).login()
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? CallbookError, .authenticationFailed("Username/password incorrect"))
        }
    }

    func testPasswordIsPercentEncoded() async throws {
        let server = Server([xml(session: loginOK)])
        try await client(server, password: "a+b&c=d").login()
        XCTAssertTrue(server.urls[0].absoluteString.contains("password=a%2Bb%26c%3Dd"))
    }
}
