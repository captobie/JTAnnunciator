import XCTest
@testable import JTAnnunciatorCore

final class FT8MessageParserTests: XCTestCase {
    func testCQMessage() {
        XCTAssertEqual(
            FT8MessageParser.candidateCallsigns(inMessage: "CQ K1ABC FN42"),
            ["K1ABC"]
        )
    }

    func testCQDXMessage() {
        XCTAssertEqual(
            FT8MessageParser.candidateCallsigns(inMessage: "CQ DX K1ABC FN42"),
            ["K1ABC"]
        )
    }

    func testTwoStationExchangeWithSignalReport() {
        XCTAssertEqual(
            FT8MessageParser.candidateCallsigns(inMessage: "K1ABC W9XYZ -12"),
            ["K1ABC", "W9XYZ"]
        )
    }

    func testRR73Message() {
        XCTAssertEqual(
            FT8MessageParser.candidateCallsigns(inMessage: "K1ABC W9XYZ RR73"),
            ["K1ABC", "W9XYZ"]
        )
    }

    func testGridSquareIsNotMistakenForCallsign() {
        // "FN42" alone shouldn't happen in practice without a callsign, but the filter itself
        // should reject grid-square-shaped tokens regardless of context.
        XCTAssertFalse(FT8MessageParser.candidateCallsigns(inMessage: "FN42 IO91").contains("FN42"))
    }

    func testPlainSeventyThreeHasNoCallsigns() {
        XCTAssertEqual(FT8MessageParser.candidateCallsigns(inMessage: "73"), [])
    }

    func testPortableSuffixCallsignIsKept() {
        XCTAssertEqual(
            FT8MessageParser.candidateCallsigns(inMessage: "CQ G4ABC/VP8 IO91"),
            ["G4ABC/VP8"]
        )
    }
}
