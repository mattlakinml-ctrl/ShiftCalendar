import SwiftUI

extension Rota {
    static func newDraft(using store: ShiftStore) -> Rota {
        Rota(name: store.data.rotas.isEmpty ? "My rota" : "New rota", startDay: .today, blocks: [])
    }
}

struct RotaListView: View {
    @Environment(ShiftStore.self) private var store
    @State private var editing: Rota?
    @State private var editingIsNew = false

    var body: some View {
        List {
            Section {
                ForEach(store.data.rotas.sorted { $0.startDay < $1.startDay }) { rota in
                    Button {
                        editingIsNew = false
                        editing = rota
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(rota.name).font(.headline).foregroundStyle(.primary)
                            Text("From \(rota.startDay.longTitle) · \(rota.cycleLength)-day cycle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            CycleStrip(cycle: rota.cycle)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { offsets in
                    let sorted = store.data.rotas.sorted { $0.startDay < $1.startDay }
                    for i in offsets { store.delete(sorted[i]) }
                }
            } footer: {
                Text("Changing team or rota? Add a new pattern starting on the day it changes. Earlier dates keep the old one.")
            }
        }
        .navigationTitle("Shift patterns")
        .toolbar {
            Button {
                editingIsNew = true
                editing = Rota.newDraft(using: store)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add pattern")
        }
        .sheet(item: $editing) { rota in
            RotaEditor(rota: rota, isNew: editingIsNew)
        }
        .overlay {
            if store.data.rotas.isEmpty {
                ContentUnavailableView(
                    "No pattern yet",
                    systemImage: "repeat",
                    description: Text("Tap + to set up your shift pattern, e.g. 6 on 4 off.")
                )
            }
        }
    }
}

struct RotaEditor: View {
    let isNew: Bool
    @State private var draft: Rota

    @Environment(ShiftStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    init(rota: Rota, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: rota)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    DatePicker("Day 1 of the pattern", selection: Binding(
                        get: { draft.startDay.date() },
                        set: { draft.startDay = DayKey($0) }
                    ), displayedComponents: .date)
                } footer: {
                    Text("Pick the first day of the pattern, e.g. your first early of the cycle. It repeats forever from there.")
                }

                Section {
                    ForEach($draft.blocks) { $block in
                        BlockRow(block: $block, types: store.data.shiftTypes)
                    }
                    .onDelete { draft.blocks.remove(atOffsets: $0) }
                    .onMove { draft.blocks.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        addBlock()
                    } label: {
                        Label("Add block", systemImage: "plus.circle.fill")
                    }
                    Menu {
                        ForEach(RotaTemplate.all) { template in
                            Button(template.name) {
                                draft.blocks = template.blocks(using: store)
                            }
                        }
                    } label: {
                        Label("Start from a template", systemImage: "wand.and.stars")
                    }
                } header: {
                    HStack {
                        Text("Pattern")
                        Spacer()
                        if draft.blocks.count > 1 {
                            EditButton().font(.caption)
                        }
                    }
                } footer: {
                    Text("Build it from blocks, e.g. 2 Earlies, 2 Lates, 2 Nights, 4 Rest Days. Mix any shift types and lengths.")
                }

                if draft.cycleLength > 0 {
                    Section {
                        CycleGrid(cycle: draft.cycle, startDay: draft.startDay)
                        if let today = draft.cycleDay(on: .today) {
                            Text("Today is day \(today) of \(draft.cycleLength)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Preview · \(draft.cycleLength)-day cycle")
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete pattern", role: .destructive) {
                            store.delete(draft)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New pattern" : "Edit pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(draft.cycleLength == 0)
                }
            }
        }
    }

    private func addBlock() {
        // Alternate between working and rest by default, the most common shape.
        let rest = store.shiftType(code: "RD")
        let lastWasRest = draft.blocks.last.map { $0.shiftTypeID == rest?.id } ?? true
        let type = lastWasRest ? store.data.shiftTypes.first : (rest ?? store.data.shiftTypes.first)
        guard let type else { return }
        draft.blocks.append(PatternBlock(shiftTypeID: type.id, days: lastWasRest ? 5 : 3))
    }
}

private struct BlockRow: View {
    @Binding var block: PatternBlock
    let types: [ShiftType]

    var body: some View {
        HStack {
            ShiftBadge(type: types.first { $0.id == block.shiftTypeID }, size: 26)
            Picker("Shift", selection: $block.shiftTypeID) {
                ForEach(types) { type in
                    Text(type.name).tag(type.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            Spacer(minLength: 4)
            Stepper(value: $block.days, in: 1...60) {
                Text("\(block.days)")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .fixedSize()
        }
    }
}

/// The full cycle laid out in weeks, aligned so each column is a weekday.
private struct CycleGrid: View {
    let cycle: [UUID]
    let startDay: DayKey
    @Environment(ShiftStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        let lead = startDay.weekdayIndexMondayFirst
        let cells: [UUID?] = Array(repeating: nil, count: lead) + cycle.map { Optional($0) }
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, id in
                    if let id {
                        let type = store.shiftType(id)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(type?.color ?? Color(.tertiarySystemFill))
                            .frame(height: 24)
                            .overlay {
                                Text(type?.code ?? "?")
                                    .font(.system(size: 10, weight: .bold))
                                    .minimumScaleFactor(0.5)
                                    .foregroundStyle(type?.textColor ?? .secondary)
                            }
                    } else {
                        Color.clear.frame(height: 24)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// A thin coloured bar summarising a cycle in the pattern list.
private struct CycleStrip: View {
    let cycle: [UUID]
    @Environment(ShiftStore.self) private var store

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(cycle.enumerated()), id: \.offset) { _, id in
                Rectangle()
                    .fill(store.shiftType(id)?.color ?? Color(.tertiarySystemFill))
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct RotaTemplate: Identifiable {
    let name: String
    /// (shift code, days). Codes fall back to the first shift type if renamed.
    let parts: [(String, Int)]

    var id: String { name }

    func blocks(using store: ShiftStore) -> [PatternBlock] {
        parts.compactMap { code, days in
            guard let type = store.shiftType(code: code) ?? store.data.shiftTypes.first else { return nil }
            return PatternBlock(shiftTypeID: type.id, days: days)
        }
    }

    static let all: [RotaTemplate] = [
        RotaTemplate(name: "6 on, 4 off", parts: [("E", 6), ("RD", 4)]),
        RotaTemplate(name: "2 Earlies, 2 Lates, 2 Nights, 4 off", parts: [("E", 2), ("L", 2), ("N", 2), ("RD", 4)]),
        RotaTemplate(name: "7 on 3 off, 7 on 4 off, 7 on 3 off", parts: [("E", 7), ("RD", 3), ("L", 7), ("RD", 4), ("N", 7), ("RD", 3)]),
        RotaTemplate(name: "4 on, 4 off", parts: [("E", 4), ("RD", 4)]),
        RotaTemplate(name: "5 on, 2 off", parts: [("E", 5), ("RD", 2)]),
    ]
}
