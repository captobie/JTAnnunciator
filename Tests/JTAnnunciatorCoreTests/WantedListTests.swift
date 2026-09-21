import XCTest
@testable import JTAnnunciatorCore

final class WantedListTests: XCTestCase {
    func testListSavedBeforeWantedStatesExistedStillDecodes() throws {
        let json = #"{"wantedCallsigns":["K1ABC"],"wantedDXCCPrimaryPrefixes":["3D2"]}"#
        let list = try JSONDecoder().decode(WantedList.self, from: Data(json.utf8))
        XCTAssertEqual(list.wantedCallsigns, ["K1ABC"])
        XCTAssertEqual(list.wantedStates, [])
    }

    func testWantedStatesRoundTrip() throws {
        let list = WantedList(wantedStates: ["Wyoming"])
        let decoded = try JSONDecoder().decode(WantedList.self, from: JSONEncoder().encode(list))
        XCTAssertEqual(decoded, list)
    }
}
