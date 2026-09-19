import XCTest
@testable import JTAnnunciatorCore

final class CallsignParserTests: XCTestCase {
    func testPlainCallsignIsUnchanged() {
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("K1ABC"), "K1ABC")
    }

    func testCallAreaDigitSuffixKeepsHomeCallsign() {
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("W1AW/4"), "W1AW")
    }

    func testOperatingConditionSuffixesKeepHomeCallsign() {
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("W1AW/P"), "W1AW")
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("W1AW/MM"), "W1AW")
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("W1AW/QRP"), "W1AW")
    }

    func testDXPrefixSuffixIsUsedForCountryLookup() {
        // "home/DXprefix" — the DX prefix determines the country, not the home callsign.
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("G4ABC/VP8"), "VP8")
    }

    func testShorterSideWinsOnlyWhenLongerSideIsNotASuffixKeyword() {
        XCTAssertEqual(CallsignParser.baseCallsignForCountryLookup("VP8/G4ABC"), "VP8")
    }
}
