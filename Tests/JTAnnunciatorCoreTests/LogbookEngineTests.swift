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

        XCTAssertEqual(engine.workedInfo(for: decode("CQ K1ABC FN42"), band: "20M", mode: "FT8")?.bands, ["20M"])
        XCTAssertNil(engine.workedInfo(for: decode("CQ W9XYZ EN52"), band: "20M", mode: "FT8"))
    }

    func testWorkedOnlyOnMatchingBandAndMode() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "K1ABC", band: "20M", mode: "FT8")]))
        let cq = decode("CQ K1ABC FN42")

        XCTAssertNil(engine.workedInfo(for: cq, band: "40M", mode: "FT8"))
        XCTAssertNil(engine.workedInfo(for: cq, band: "20M", mode: "FT4"))
        XCTAssertNotNil(engine.workedInfo(for: cq, band: "20m", mode: "ft8"))
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

    func testSessionLoggedQSOMatchesBandAndMode() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        let qso = WSJTXQSOLogged(
            id: "WSJT-X", dateTimeOff: Date(), dxCall: "K1ABC", dxGrid: "", txFrequencyHz: 14_074_000, mode: "FT8",
            reportSent: "", reportReceived: "", txPower: "", comments: "", name: "", dateTimeOn: Date(),
            operatorCall: "", myCall: "", myGrid: "", exchangeSent: "", exchangeReceived: ""
        )
        engine.recordQSOLogged(qso)

        XCTAssertNotNil(engine.workedInfo(for: decode("CQ K1ABC FN42"), band: "20M", mode: "FT8"))
        XCTAssertNil(engine.workedInfo(for: decode("CQ K1ABC FN42"), band: "40M", mode: "FT8"))
    }

    private var japan: CTYEntry {
        CTYEntry(
            name: "Japan", cqZone: 25, ituZone: 45, continent: "AS", latitude: 36, longitude: -138,
            utcOffsetHours: -9, primaryPrefix: "JA"
        )
    }

    func testNewCountryOnlyWhenNotWorkedOnThisBandAndMode() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: FixedDXCC(entity: japan))
        engine.setLogbook(WorkedLog(qsos: [LogbookQSO(callsign: "JH4HVL", band: "20M", mode: "FT8")]))

        // A different Japanese station: the country is what counts, on the band and mode.
        XCTAssertNil(engine.newCountry(forCallsign: "JA1ZZZ", band: "20M", mode: "FT8"))
        XCTAssertEqual(engine.newCountry(forCallsign: "JA1ZZZ", band: "40M", mode: "FT8"), "Japan")
        XCTAssertEqual(engine.newCountry(forCallsign: "JA1ZZZ", band: "20M", mode: "FT4"), "Japan")
    }

    func testNewCountryUnknownWithoutDXCCData() {
        let engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        XCTAssertNil(engine.newCountry(forCallsign: "JA1ZZZ", band: "20M", mode: "FT8"))
    }

    func testSessionQSOClearsNewCountry() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: FixedDXCC(entity: japan))
        XCTAssertNotNil(engine.newCountry(forCallsign: "JA1ZZZ", band: "20M", mode: "FT8"))
        engine.recordQSOLogged(WSJTXQSOLogged(
            id: "WSJT-X", dateTimeOff: Date(), dxCall: "JH4HVL", dxGrid: "", txFrequencyHz: 14_074_000, mode: "FT8",
            reportSent: "", reportReceived: "", txPower: "", comments: "", name: "", dateTimeOn: Date(),
            operatorCall: "", myCall: "", myGrid: "", exchangeSent: "", exchangeReceived: ""
        ))
        XCTAssertNil(engine.newCountry(forCallsign: "JA1ZZZ", band: "20M", mode: "FT8"))
        XCTAssertNotNil(engine.newCountry(forCallsign: "JA1ZZZ", band: "40M", mode: "FT8"))
    }

    func testStateWorkedPerBandAndMode() {
        var engine = AlertEngine(wantedList: WantedList(), dxccLookup: NoDXCC())
        engine.setLogbook(WorkedLog(qsos: [
            LogbookQSO(callsign: "W1AW", band: "20M", mode: "FT8", state: "CT"),
            LogbookQSO(callsign: "JH4HVL", band: "20M", mode: "FT8", state: "Kan"),
        ]))

        XCTAssertTrue(engine.hasWorkedState("Connecticut", band: "20M", mode: "FT8"))
        XCTAssertFalse(engine.hasWorkedState("Connecticut", band: "40M", mode: "FT8"))
        XCTAssertFalse(engine.hasWorkedState("Ohio", band: "20M", mode: "FT8"))
        // Non-US/Canada regions (Japanese prefectures etc.) are not tracked as states.
        XCTAssertFalse(engine.hasWorkedState("Kan", band: "20M", mode: "FT8"))
    }
}
