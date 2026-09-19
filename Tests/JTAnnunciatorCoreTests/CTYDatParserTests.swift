import XCTest
@testable import JTAnnunciatorCore

final class CTYDatParserTests: XCTestCase {
    // Verbatim excerpts from a real, current cty.dat (as bundled with WSJT-X), used only as
    // fixtures to exercise the parser's grammar — not shipped with the app itself. See
    // CTYDatParser.swift's doc comment for why this app doesn't bundle a full copy.
    private static let fixture = """
    Sov Mil Order of Malta:   15:  28:  EU:   41.90:   -12.43:    -1.0:  1A:
        1A;
    Fiji:                     32:  56:  OC:  -17.78:  -177.92:   -12.0:  3D2:
        3D2,=3D5X;
    Conway Reef:              32:  56:  OC:  -22.00:  -175.00:   -12.0:  3D2/c:
        =3D20CR,=3D2C,=3D2CI,=3D2CR,=3D2CY;
    Rotuma Island:            32:  56:  OC:  -12.48:  -177.08:   -12.0:  3D2/r:
        =3D2AG/P,=3D2EU,=3D2GC/P,=3D2HY/R,=3D2NV/P,=3D2NV/R,=3D2R,=3D2RA,=3D2RI,=3D2RO,=3D2RR,=3D2RX,
        =3D2VB/R;
    Sri Lanka:                22:  41:  AS:    7.60:   -80.70:    -5.5:  4S:
        4P,4Q,4R,4S,=4S7CGM/AVR;
    Vienna Intl Ctr:          15:  28:  EU:   48.20:   -16.30:    -1.0:  *4U1V:
        =4U0R,=4U10NPT,=4U18FIFA,=4U1A,=4U1VIC,=4U1WED,=4U1XMAS,=4U2STAYHOME,=4U2U,=4U30VIC,=4U500M,
        =4U70VIC,=4U75A,=4UNR,=4Y1A,=C7A;
    Mongolia:                 23:  32:  AS:   46.77:  -102.17:    -7.0:  JT:
        JT,JU,JV,
        JT2[33],JU2[33],JV2[33],
        JT3[33],JU3[33],JV3[33];
    """

    func testParsesSimplePrefixEntry() {
        let db = CTYDatParser.parse(Self.fixture)
        let entity = db.entity(forCallsign: "1AXYZ")
        XCTAssertEqual(entity?.name, "Sov Mil Order of Malta")
        XCTAssertEqual(entity?.cqZone, 15)
        XCTAssertEqual(entity?.ituZone, 28)
        XCTAssertEqual(entity?.continent, "EU")
        XCTAssertEqual(entity?.primaryPrefix, "1A")
    }

    func testDistinguishesSubEntitiesOnTheSamePrefix() {
        let db = CTYDatParser.parse(Self.fixture)
        // "3D2" alone (no exact override) is plain Fiji.
        XCTAssertEqual(db.entity(forCallsign: "3D2XY")?.name, "Fiji")
        // But an exact-callsign override under Conway Reef takes precedence.
        XCTAssertEqual(db.entity(forCallsign: "3D2CR")?.name, "Conway Reef")
        XCTAssertEqual(db.entity(forCallsign: "3D2CR")?.primaryPrefix, "3D2/c")
        // Rotuma's exact overrides include a portable suffix baked into the exact match itself.
        XCTAssertEqual(db.entity(forCallsign: "3D2NV/P")?.name, "Rotuma Island")
    }

    func testExactMatchWithSlashSuffixIsNotBrokenByPortableHeuristic() {
        let db = CTYDatParser.parse(Self.fixture)
        // "/AVR" isn't a portable-operation suffix (P/M/MM/AM/A/R/QRP) or a call-area digit, so
        // naive stripping would misroute this to a "4S7CGM" vs "AVR" prefix decision. It must
        // hit the exact override verbatim instead.
        XCTAssertEqual(db.entity(forCallsign: "4S7CGM/AVR")?.name, "Sri Lanka")
    }

    func testStripsAsteriskFromPrimaryPrefix() {
        let db = CTYDatParser.parse(Self.fixture)
        XCTAssertEqual(db.entity(forCallsign: "4U1VIC")?.primaryPrefix, "4U1V")
    }

    func testAliasSpecificZoneOverrideAppliesOnlyToThatAlias() {
        let db = CTYDatParser.parse(Self.fixture)
        let overridden = db.entity(forCallsign: "JT2ABC")
        XCTAssertEqual(overridden?.name, "Mongolia")
        XCTAssertEqual(overridden?.ituZone, 33, "JT2 carries an explicit [33] ITU zone override")

        let plain = db.entity(forCallsign: "JTABC")
        XCTAssertEqual(plain?.ituZone, 32, "plain JT prefix keeps the header's ITU zone")
    }

    func testUnknownCallsignReturnsNil() {
        let db = CTYDatParser.parse(Self.fixture)
        XCTAssertNil(db.entity(forCallsign: "ZZZZZ"))
    }
}
