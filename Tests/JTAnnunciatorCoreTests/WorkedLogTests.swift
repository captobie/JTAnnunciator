import XCTest
@testable import JTAnnunciatorCore

final class WorkedLogTests: XCTestCase {
    func testIdentityStripsOperatingSuffixesAndPrefixes() {
        XCTAssertEqual(WorkedLog.identity(of: "ja8cpf/p"), "JA8CPF")
        XCTAssertEqual(WorkedLog.identity(of: "BW2/JP1RIW"), "JP1RIW")
        XCTAssertEqual(WorkedLog.identity(of: "W1AW/4"), "W1AW")
        XCTAssertEqual(WorkedLog.identity(of: "<K1ABC>"), "K1ABC")
    }

    func testSlashedLogEntryMatchesBaseCall() {
        let log = WorkedLog(qsos: [LogbookQSO(callsign: "JA8CPF/P", band: "20m", mode: "ft8")])
        XCTAssertTrue(log.contains("JA8CPF"))
        XCTAssertEqual(log.info(for: "JA8CPF")?.bands, ["20M"])
        XCTAssertEqual(log.info(for: "JA8CPF")?.modes, ["FT8"])
    }

    func testAggregatesBandsAndCounts() {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)
        let log = WorkedLog(qsos: [
            LogbookQSO(callsign: "K1ABC", band: "20M", mode: "FT8", date: later),
            LogbookQSO(callsign: "K1ABC", band: "40m", mode: "FT4", date: earlier),
            LogbookQSO(callsign: "K1ABC", band: "20m", mode: "FT8"),
        ])
        let info = log.info(for: "k1abc")
        XCTAssertEqual(info?.bands, ["20M", "40M"])
        XCTAssertEqual(info?.qsoCount, 3)
        XCTAssertEqual(info?.lastWorked, later)
        XCTAssertNil(log.info(for: "W9XYZ"))
    }

    func testMergeCombinesLogs() {
        var a = WorkedLog(qsos: [LogbookQSO(callsign: "K1ABC", band: "20M", mode: "FT8")])
        a.merge(WorkedLog(qsos: [
            LogbookQSO(callsign: "K1ABC", band: "15M", mode: "FT8"),
            LogbookQSO(callsign: "W9XYZ", band: "20M", mode: "FT8"),
        ]))
        XCTAssertEqual(a.callsignCount, 2)
        XCTAssertEqual(a.info(for: "K1ABC")?.bands, ["15M", "20M"])
        XCTAssertEqual(a.info(for: "K1ABC")?.qsoCount, 2)
    }

    func testSenderCallsign() {
        XCTAssertEqual(MessageClassifier.senderCallsign("CQ K1ABC FN42"), "K1ABC")
        XCTAssertEqual(MessageClassifier.senderCallsign("CQ DX K1ABC FN42"), "K1ABC")
        XCTAssertEqual(MessageClassifier.senderCallsign("K1ABC W9XYZ -12"), "W9XYZ")
        XCTAssertEqual(MessageClassifier.senderCallsign("<K1ABC> W9XYZ R-05"), "W9XYZ")
        XCTAssertNil(MessageClassifier.senderCallsign("TNX 73"))
    }
}
