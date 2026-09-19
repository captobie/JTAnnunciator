import XCTest
@testable import JTAnnunciatorCore

private struct StubDXCCLookup: DXCCLookup {
    var entities: [String: CTYEntry]

    func entity(forCallsign callsign: String) -> CTYEntry? {
        entities[callsign.uppercased()]
    }
}

final class AlertEngineTests: XCTestCase {
    private func makeDecode(isNew: Bool = true, message: String) -> WSJTXDecode {
        WSJTXDecode(
            id: "WSJT-X", isNew: isNew, timeMillisSinceMidnightUTC: 0, snr: -10,
            deltaTimeSeconds: 0.1, deltaFrequencyHz: 1500, mode: "FT8", message: message,
            lowConfidence: false, offAir: false
        )
    }

    func testWantedCallsignTriggersAlert() {
        let wantedList = WantedList(wantedCallsigns: ["K1ABC"])
        var engine = AlertEngine(wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: [:]))

        let events = engine.process(makeDecode(message: "CQ K1ABC FN42"))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.callsign, "K1ABC")
        XCTAssertEqual(events.first?.reason, .wantedCallsign)
        XCTAssertEqual(events.first?.alreadyWorked, false)
    }

    func testNonWantedCallsignProducesNoAlert() {
        let wantedList = WantedList(wantedCallsigns: ["K1ABC"])
        var engine = AlertEngine(wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: [:]))

        XCTAssertEqual(engine.process(makeDecode(message: "CQ W9XYZ FN42")), [])
    }

    func testRepeatedDecodeWithoutNewFlagProducesNoAlert() {
        let wantedList = WantedList(wantedCallsigns: ["K1ABC"])
        var engine = AlertEngine(wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: [:]))

        XCTAssertEqual(engine.process(makeDecode(isNew: false, message: "CQ K1ABC FN42")), [])
    }

    func testWantedDXCCTriggersAlert() {
        let fiji = CTYEntry(
            name: "Fiji", cqZone: 32, ituZone: 56, continent: "OC", latitude: -17.78,
            longitude: -177.92, utcOffsetHours: -12, primaryPrefix: "3D2"
        )
        let wantedList = WantedList(wantedDXCCPrimaryPrefixes: ["3D2"])
        var engine = AlertEngine(
            wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: ["3D2XY": fiji])
        )

        let events = engine.process(makeDecode(message: "CQ 3D2XY RN42"))

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.callsign, "3D2XY")
        XCTAssertEqual(events.first?.reason, .wantedDXCC(entityName: "Fiji", primaryPrefix: "3D2"))
    }

    func testAlreadyWorkedCallsignStillAlertsButIsFlagged() {
        let wantedList = WantedList(wantedCallsigns: ["K1ABC"])
        var engine = AlertEngine(wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: [:]))
        engine.recordQSOLogged(
            WSJTXQSOLogged(
                id: "WSJT-X", dateTimeOff: Date(), dxCall: "K1ABC", dxGrid: "FN42",
                txFrequencyHz: 14_074_000, mode: "FT8", reportSent: "-10", reportReceived: "-08",
                txPower: "100W", comments: "", name: "", dateTimeOn: Date(), operatorCall: "W1AW",
                myCall: "W1AW", myGrid: "FN31", exchangeSent: "", exchangeReceived: ""
            )
        )

        let events = engine.process(makeDecode(message: "CQ K1ABC FN42"))

        XCTAssertEqual(events.first?.alreadyWorked, true)
    }

    func testDuplicateCallsignInSameMessageProducesOneEvent() {
        // Not a realistic FT8 message, but guards against double-counting if the token scanner
        // ever sees the same callsign twice in one message.
        let wantedList = WantedList(wantedCallsigns: ["K1ABC"])
        var engine = AlertEngine(wantedList: wantedList, dxccLookup: StubDXCCLookup(entities: [:]))

        let events = engine.process(makeDecode(message: "K1ABC K1ABC RR73"))

        XCTAssertEqual(events.count, 1)
    }
}
