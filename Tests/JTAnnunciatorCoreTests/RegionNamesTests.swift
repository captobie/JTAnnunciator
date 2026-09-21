import XCTest
@testable import JTAnnunciatorCore

final class RegionNamesTests: XCTestCase {
    func testStateAndProvinceCodesExpand() {
        XCTAssertEqual(RegionNames.fullName(forState: "CT", country: "United States"), "Connecticut")
        XCTAssertEqual(RegionNames.fullName(forState: "on", country: "Canada"), "Ontario")
        XCTAssertEqual(RegionNames.fullName(forState: "PQ"), "Quebec")
    }

    func testUnknownOrForeignValuesPassThrough() {
        XCTAssertEqual(RegionNames.fullName(forState: "Bavaria", country: "Germany"), "Bavaria")
        XCTAssertEqual(RegionNames.fullName(forState: "CA", country: "Germany"), "CA")
        XCTAssertEqual(RegionNames.fullName(forState: "Texas", country: "United States"), "Texas")
    }

    func testKnownNameIsCaseInsensitive() {
        XCTAssertEqual(RegionNames.knownName(forState: "wyoming"), "Wyoming")
        XCTAssertEqual(RegionNames.knownName(forState: "wy"), "Wyoming")
        XCTAssertNil(RegionNames.knownName(forState: "Bavaria"))
    }
}
