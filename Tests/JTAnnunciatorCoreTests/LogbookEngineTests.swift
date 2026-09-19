import XCTest
@testable import JTAnnunciatorCore

private struct NoDXCC: DXCCLookup {
    func entity(forCallsign callsign: String) -> CTYEntry? { nil }
}

private struct FixedDXCC: DXCCLookup {
    var entity: CTYEntry
    func entity(forCallsign callsign: String) -> CTYEntry? { entity }
}

final class LogbookEngineTests: XCTestCase {
    private func decode(_ message: String) -> WSJTXDecode {
        WSJTXDecode(
            id: "WSJT-X", isNew: true, timeMillisSinceMidnightUTC: 0, snr: -10, deltaTimeSeconds: 0.1,
            deltaFrequencyHz: 1500, mode: "FT8", message: message, lowConfidence: false, offAir: false
        )
    }

    func testWorkedInfoForDecodeSender() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "K1ABC", band: "20M", mode: "FT8")]))

        XCTAssertEqual(engine.workedInfo(for: decode("CQ K1ABC FN42"))?.bands, ["20M"])
        XCTAssertNil(engine.workedInfo(for: decode("CQ W9XYZ EN52")))
    }

    func testWantedCallsignAlreadyWorkedFromLogbook() {
        var engine = AlertEngine(wantedList: WantedList(wantedCallsigns: ["K1ABC"]), dxccLookup: NoDXCC())
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "K1ABC", band: "20M", mode: "FT8")]))

        XCTAssertEqual(engine.process(decode("CQ K1ABC FN42")).first?.alreadyWorked, true)
    }

    func testWantedDXCCAlreadyWorkedFromLogbookEntity() {
        let japan = CTYEntry(
            name: "Japan", cqZone: 25, ituZone: 45, continent: "AS", latitude: 36, longitude: -138,
            utcOffsetHours: -9, primaryPrefix: "JA"
        )
        var engine = AlertEngine(
            wantedList: WantedList(wantedDXCCPrimaryPrefixes: ["JA"]), dxccLookup: FixedDXCC(entity: japan)
        )
        // Logbook holds a *different* Japanese station; the entity itself is already worked.
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "JH4HVL", band: "20M", mode: "FT8")]))

        XCTAssertEqual(engine.process(decode("CQ JA1ZZZ PM95")).first?.alreadyWorked, true)
    }

    func testDXCCLookupChangeRebuildsLogbookEntities() {
        let japan = CTYEntry(
            name: "Japan", cqZone: 25, ituZone: 45, continent: "AS", latitude: 36, longitude: -138,
            utcOffsetHours: -9, primaryPrefix: "JA"
        )
        var engine = AlertEngine(wantedList: WantedList(wantedDXCCPrimaryPrefixes: ["JA"]), dxccLookup: NoDXCC())
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "JH4HVL", band: "20M", mode: "FT8")]))
        engine.dxccLookup = FixedDXCC(entity: japan)

        XCTAssertEqual(engine.process(decode("CQ JA1ZZZ PM95")).first?.alreadyWorked, true)
    }

    func testSessionLoggedQSOCountsAsWorkedWithoutBands() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        let qso = WSJTXQSOLogged(
            id: "WSJT-X", dateTimeOff: Date(), dxCall: "K1ABC", dxGrid: "", txFrequencyHz: 0, mode: "FT8",
            reportSent: "", reportReceived: "", txPower: "", comments: "", name: "", dateTimeOn: Date(),
            operatorCall: "", myCall: "", myGrid: "", exchangeSent: "", exchangeReceived: ""
        )
        engine.recordQSOLogged(qso)

        let info = engine.workedInfo(for: decode("CQ K1ABC FN42"))
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.bands, [])
    }
}
