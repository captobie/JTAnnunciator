import XCTest
@testable import JTAnnunciatorCore

final class MessageClassifierTests: XCTestCase {
    func testCQVariants() {
        XCTAssertTrue(MessageClassifier.isCQ("CQ K1ABC FN42"))
        XCTAssertTrue(MessageClassifier.isCQ("CQ DX K1ABC FN42"))
        XCTAssertFalse(MessageClassifier.isCQ("K1ABC W9XYZ -12"))
    }

    func testDirectedToMe() {
        XCTAssertTrue(MessageClassifier.isDirected("W9XYZ K1ABC -12", to: "w9xyz"))
        XCTAssertTrue(MessageClassifier.isDirected("<W9XYZ> K1ABC RR73", to: "W9XYZ"))
    }

    func testNotDirectedToMe() {
        XCTAssertFalse(MessageClassifier.isDirected("K1ABC W9XYZ -12", to: "W9XYZ"))
        XCTAssertFalse(MessageClassifier.isDirected("CQ W9XYZ EN52", to: "W9XYZ"))
        XCTAssertFalse(MessageClassifier.isDirected("W9XYZ K1ABC -12", to: ""))
    }
}
