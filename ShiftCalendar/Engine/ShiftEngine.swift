import Foundation

enum ShiftMath {
    /// Modulo that is never negative, so days before a rota's start still map into the cycle.
    static func positiveMod(_ a: Int, _ n: Int) -> Int {
        ((a % n) + n) % n
    }
}

struct ResolvedDay {
    let day: DayKey
    let rota: Rota?
    let cycleDay: Int?
    let rotaShiftID: UUID?
    let overrideShiftID: UUID?
    let note: String

    var shiftTypeID: UUID? { overrideShiftID ?? rotaShiftID }
    var isChanged: Bool { overrideShiftID != nil && overrideShiftID != rotaShiftID }
}

/// Works out what you are on for any day: the rota in force that day, then any
/// one-off change on top.
struct ShiftEngine {
    private let rotas: [Rota]
    private let cycles: [[UUID]]
    private let overrides: [DayKey: DayOverride]

    init(rotas: [Rota], overrides: [DayKey: DayOverride]) {
        let sorted = rotas.filter { $0.cycleLength > 0 }.sorted { $0.startDay < $1.startDay }
        self.rotas = sorted
        self.cycles = sorted.map(\.cycle)
        self.overrides = overrides
    }

    /// The latest rota that has started by `day`. Days before the first rota use
    /// the first rota, projected backwards.
    private func rotaIndex(for day: DayKey) -> Int? {
        guard !rotas.isEmpty else { return nil }
        return rotas.lastIndex { $0.startDay <= day } ?? 0
    }

    func resolve(_ day: DayKey) -> ResolvedDay {
        var rota: Rota?
        var cycleDay: Int?
        var rotaShift: UUID?
        if let i = rotaIndex(for: day) {
            let cycle = cycles[i]
            let index = ShiftMath.positiveMod(day.ordinal - rotas[i].startDay.ordinal, cycle.count)
            rota = rotas[i]
            cycleDay = index + 1
            rotaShift = cycle[index]
        }
        let override = overrides[day]
        return ResolvedDay(
            day: day,
            rota: rota,
            cycleDay: cycleDay,
            rotaShiftID: rotaShift,
            overrideShiftID: override?.shiftTypeID,
            note: override?.note ?? ""
        )
    }
}
