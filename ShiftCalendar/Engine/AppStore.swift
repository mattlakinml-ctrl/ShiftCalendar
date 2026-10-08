import Foundation
import Observation

/// Holds everything the user has set up and saves it to disk on every change.
@Observable
final class AppStore {
    var data: AppData {
        didSet {
            engine = ShiftEngine(rotas: data.rotas, overrides: data.overrides)
            save()
        }
    }

    private(set) var engine: ShiftEngine

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL()
        self.fileURL = url
        let loaded = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AppData.self, from: $0) }
        let data = loaded ?? AppData()
        self.data = data
        self.engine = ShiftEngine(rotas: data.rotas, overrides: data.overrides)
    }

    // MARK: Lookups

    func resolve(_ day: DayKey) -> ResolvedDay { engine.resolve(day) }

    func shiftType(_ id: UUID?) -> ShiftType? {
        guard let id else { return nil }
        return data.shiftTypes.first { $0.id == id }
    }

    func shiftType(code: String) -> ShiftType? {
        data.shiftTypes.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    func isInUse(_ type: ShiftType) -> Bool {
        data.rotas.contains { rota in rota.blocks.contains { $0.shiftTypeID == type.id } }
    }

    // MARK: Day changes

    func setOverride(_ shiftTypeID: UUID?, on day: DayKey) {
        var o = data.overrides[day] ?? DayOverride()
        o.shiftTypeID = shiftTypeID
        store(o, on: day)
    }

    func setNote(_ note: String, on day: DayKey) {
        var o = data.overrides[day] ?? DayOverride()
        guard o.note != note else { return }
        o.note = note
        store(o, on: day)
    }

    private func store(_ o: DayOverride, on day: DayKey) {
        data.overrides[day] = o.isEmpty ? nil : o
    }

    // MARK: Rotas and shift types

    func upsert(_ rota: Rota) {
        if let i = data.rotas.firstIndex(where: { $0.id == rota.id }) {
            data.rotas[i] = rota
        } else {
            data.rotas.append(rota)
        }
    }

    func delete(_ rota: Rota) {
        data.rotas.removeAll { $0.id == rota.id }
    }

    func upsert(_ type: ShiftType) {
        if let i = data.shiftTypes.firstIndex(where: { $0.id == type.id }) {
            data.shiftTypes[i] = type
        } else {
            data.shiftTypes.append(type)
        }
    }

    func delete(_ type: ShiftType) {
        data.shiftTypes.removeAll { $0.id == type.id }
        for (day, o) in data.overrides where o.shiftTypeID == type.id {
            var changed = o
            changed.shiftTypeID = nil
            data.overrides[day] = changed.isEmpty ? nil : changed
        }
    }

    // MARK: Persistence

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoded.write(to: fileURL, options: .atomic)
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("ShiftCalendar.json")
    }
}
