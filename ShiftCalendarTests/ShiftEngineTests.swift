import XCTest
@testable import ShiftCalendar

final class ShiftEngineTests: XCTestCase {
    private let early = ShiftType(name: "Early", code: "E", colorHex: "#34C759")
    private let late = ShiftType(name: "Late", code: "L", colorHex: "#FFD60A")
    private let night = ShiftType(name: "Night", code: "N", colorHex: "#FF3B30")
    private let rest = ShiftType(name: "Rest Day", code: "RD", colorHex: "#D1D1D6")
    private let annualLeave = ShiftType(name: "Annual Leave", code: "AL", colorHex: "#0A84FF")

    private func rota(_ start: DayKey, _ parts: [(ShiftType, Int)]) -> Rota {
        Rota(name: "Test", startDay: start, blocks: parts.map { PatternBlock(shiftTypeID: $0.0.id, days: $0.1) })
    }

    func testDayKeyRoundTripsAcrossLeapYearsAndCenturies() {
        for ordinal in stride(from: -40_000, through: 60_000, by: 7) {
            XCTAssertEqual(DayKey(ordinal: ordinal).ordinal, ordinal)
        }
        XCTAssertEqual(DayKey(year: 1970, month: 1, day: 1).ordinal, 0)
        XCTAssertEqual(DayKey(year: 2028, month: 2, day: 29).adding(days: 1), DayKey(year: 2028, month: 3, day: 1))
    }

    func testWeekdayIsMondayFirst() {
        XCTAssertEqual(DayKey(year: 2026, month: 10, day: 5).weekdayIndexMondayFirst, 0) // Monday
        XCTAssertEqual(DayKey(year: 2026, month: 10, day: 11).weekdayIndexMondayFirst, 6) // Sunday
    }

    func testSixOnFourOffRepeats() {
        let start = DayKey(year: 2026, month: 1, day: 1)
        let engine = ShiftEngine(rotas: [rota(start, [(early, 6), (rest, 4)])], overrides: [:])
        let expected = Array(repeating: early.id, count: 6) + Array(repeating: rest.id, count: 4)
        for offset in 0..<40 {
            XCTAssertEqual(engine.resolve(start.adding(days: offset)).shiftTypeID, expected[offset % 10])
        }
    }

    func testIrregularPatternEighteenMonthsAhead() {
        // 7 on 3 off, 7 on 4 off, 7 on 3 off = 31-day cycle.
        let start = DayKey(year: 2026, month: 10, day: 8)
        let r = rota(start, [(early, 7), (rest, 3), (late, 7), (rest, 4), (night, 7), (rest, 3)])
        let engine = ShiftEngine(rotas: [r], overrides: [:])
        XCTAssertEqual(r.cycleLength, 31)

        let target = DayKey(year: 2028, month: 4, day: 8)
        let index = (target.ordinal - start.ordinal) % 31
        XCTAssertEqual(engine.resolve(target).shiftTypeID, r.cycle[index])
        XCTAssertEqual(engine.resolve(target).cycleDay, index + 1)

        XCTAssertEqual(engine.resolve(start.adding(days: 10)).shiftTypeID, late.id)
        XCTAssertEqual(engine.resolve(start.adding(days: 17)).shiftTypeID, rest.id)
        XCTAssertEqual(engine.resolve(start.adding(days: 21)).shiftTypeID, night.id)
        XCTAssertEqual(engine.resolve(start.adding(days: 31)).shiftTypeID, early.id)
    }

    func testDaysBeforeStartProjectBackwards() {
        let start = DayKey(year: 2026, month: 1, day: 1)
        let engine = ShiftEngine(rotas: [rota(start, [(early, 6), (rest, 4)])], overrides: [:])
        XCTAssertEqual(engine.resolve(start.adding(days: -1)).shiftTypeID, rest.id)
        XCTAssertEqual(engine.resolve(start.adding(days: -4)).shiftTypeID, rest.id)
        XCTAssertEqual(engine.resolve(start.adding(days: -5)).shiftTypeID, early.id)
        XCTAssertEqual(engine.resolve(start.adding(days: -1)).cycleDay, 10)
    }

    func testNewRotaTakesOverFromItsStartDate() {
        let first = rota(DayKey(year: 2026, month: 1, day: 1), [(early, 1)])
        let second = rota(DayKey(year: 2026, month: 6, day: 1), [(night, 1)])
        let engine = ShiftEngine(rotas: [second, first], overrides: [:])
        XCTAssertEqual(engine.resolve(DayKey(year: 2026, month: 5, day: 31)).shiftTypeID, early.id)
        XCTAssertEqual(engine.resolve(DayKey(year: 2026, month: 6, day: 1)).shiftTypeID, night.id)
        XCTAssertEqual(engine.resolve(DayKey(year: 2030, month: 1, day: 1)).shiftTypeID, night.id)
    }

    func testOverrideWinsOverRota() {
        let start = DayKey(year: 2026, month: 1, day: 1)
        let leaveDay = start.adding(days: 2)
        let engine = ShiftEngine(
            rotas: [rota(start, [(early, 6), (rest, 4)])],
            overrides: [leaveDay: DayOverride(shiftTypeID: annualLeave.id, note: "Holiday")]
        )
        let resolved = engine.resolve(leaveDay)
        XCTAssertEqual(resolved.shiftTypeID, annualLeave.id)
        XCTAssertEqual(resolved.rotaShiftID, early.id)
        XCTAssertTrue(resolved.isChanged)
        XCTAssertEqual(resolved.note, "Holiday")
    }

    func testNoRotaMeansNothingSet() {
        let engine = ShiftEngine(rotas: [], overrides: [:])
        XCTAssertNil(engine.resolve(.today).shiftTypeID)
    }

    func testStoreSavesAndReloads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ShiftStore(fileURL: url)
        let e = store.data.shiftTypes[0]
        store.upsert(rota(DayKey(year: 2026, month: 1, day: 1), [(e, 6), (rest, 4)]))
        store.setNote("Court", on: DayKey(year: 2026, month: 2, day: 3))

        let reloaded = ShiftStore(fileURL: url)
        XCTAssertEqual(reloaded.data.rotas.count, 1)
        XCTAssertEqual(reloaded.data.overrides[DayKey(year: 2026, month: 2, day: 3)]?.note, "Court")
        XCTAssertEqual(reloaded.data.shiftTypes.count, ShiftType.defaults.count)
    }
}
