import Foundation

/// A calendar day with no time or time zone attached, so shift maths never
/// drifts across daylight-saving changes.
struct DayKey: Hashable, Codable, Comparable, Identifiable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Days since 1970-01-01 (Howard Hinnant's days_from_civil).
    init(ordinal: Int) {
        let z = ordinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    var ordinal: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    var id: Int { ordinal }

    static var today: DayKey { DayKey(Date()) }

    func adding(days: Int) -> DayKey { DayKey(ordinal: ordinal + days) }

    /// 0 = Monday ... 6 = Sunday. 1970-01-01 was a Thursday.
    var weekdayIndexMondayFirst: Int { ShiftMath.positiveMod(ordinal + 3, 7) }

    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    var longTitle: String { Self.longFormatter.string(from: date()) }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.ordinal < rhs.ordinal }

    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return f
    }()
}

struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ day: DayKey) {
        self.init(year: day.year, month: day.month)
    }

    private var index: Int { year * 12 + (month - 1) }

    func adding(months n: Int) -> MonthKey {
        let t = index + n
        return MonthKey(year: t / 12, month: t % 12 + 1)
    }

    var firstDay: DayKey { DayKey(year: year, month: month, day: 1) }
    var numberOfDays: Int { adding(months: 1).firstDay.ordinal - firstDay.ordinal }
    var lastDay: DayKey { firstDay.adding(days: numberOfDays - 1) }

    /// Grid cells for a Monday-first month view; nil is a blank leading cell.
    var gridCells: [DayKey?] {
        let blanks: [DayKey?] = Array(repeating: nil, count: firstDay.weekdayIndexMondayFirst)
        return blanks + (0..<numberOfDays).map { firstDay.adding(days: $0) }
    }

    var title: String { Self.titleFormatter.string(from: firstDay.date()) }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool { lhs.index < rhs.index }

    static func range(around day: DayKey, before: Int, after: Int) -> [MonthKey] {
        let centre = MonthKey(day)
        return (-before...after).map { centre.adding(months: $0) }
    }

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()
}
