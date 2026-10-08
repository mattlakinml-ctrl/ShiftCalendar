import Foundation

/// A colour-coded "tab": Early, Late, Night, OT, Annual Leave, anything you like.
struct ShiftType: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var code: String
    var colorHex: String
    var times: String = ""
}

extension ShiftType {
    static let defaults: [ShiftType] = [
        ShiftType(name: "Early", code: "E", colorHex: "#34C759"),
        ShiftType(name: "Mid Late", code: "ML", colorHex: "#FF9F0A"),
        ShiftType(name: "Late", code: "L", colorHex: "#FFD60A"),
        ShiftType(name: "Night", code: "N", colorHex: "#FF3B30"),
        ShiftType(name: "Rest Day", code: "RD", colorHex: "#D1D1D6"),
        ShiftType(name: "Overtime", code: "OT", colorHex: "#AF52DE"),
        ShiftType(name: "Rest Day in Lieu", code: "RDIL", colorHex: "#5AC8FA"),
        ShiftType(name: "Annual Leave", code: "AL", colorHex: "#0A84FF"),
    ]
}

/// A run of consecutive days on the same shift, e.g. "7 × Early".
struct PatternBlock: Identifiable, Codable, Hashable {
    var id = UUID()
    var shiftTypeID: UUID
    var days: Int
}

/// A repeating shift pattern that takes effect from `startDay`, which is also
/// day 1 of the cycle.
struct Rota: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var startDay: DayKey
    var blocks: [PatternBlock]

    var cycle: [UUID] {
        blocks.flatMap { Array(repeating: $0.shiftTypeID, count: max(0, $0.days)) }
    }

    var cycleLength: Int { blocks.reduce(0) { $0 + max(0, $1.days) } }

    /// 1-based position in the cycle on the given day.
    func cycleDay(on day: DayKey) -> Int? {
        let n = cycleLength
        guard n > 0 else { return nil }
        return ShiftMath.positiveMod(day.ordinal - startDay.ordinal, n) + 1
    }
}

/// A one-off change to a single day: overtime, leave, a swap, or just a note.
struct DayOverride: Codable, Hashable {
    var shiftTypeID: UUID?
    var note: String = ""

    var isEmpty: Bool {
        shiftTypeID == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AppData: Codable {
    var shiftTypes: [ShiftType] = ShiftType.defaults
    var rotas: [Rota] = []
    var overrides: [DayKey: DayOverride] = [:]
    var showCalendarDots = true
    var hiddenCalendarIDs: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shiftTypes = try c.decodeIfPresent([ShiftType].self, forKey: .shiftTypes) ?? ShiftType.defaults
        rotas = try c.decodeIfPresent([Rota].self, forKey: .rotas) ?? []
        overrides = try c.decodeIfPresent([DayKey: DayOverride].self, forKey: .overrides) ?? [:]
        showCalendarDots = try c.decodeIfPresent(Bool.self, forKey: .showCalendarDots) ?? true
        hiddenCalendarIDs = try c.decodeIfPresent(Set<String>.self, forKey: .hiddenCalendarIDs) ?? []
    }
}
