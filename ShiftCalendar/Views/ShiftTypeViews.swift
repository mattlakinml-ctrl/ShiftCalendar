import SwiftUI

struct ShiftTypesView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: ShiftType?
    @State private var editingIsNew = false
    @State private var blockedDelete: ShiftType?

    var body: some View {
        List {
            Section {
                ForEach(store.data.shiftTypes) { type in
                    Button {
                        editingIsNew = false
                        editing = type
                    } label: {
                        HStack(spacing: 12) {
                            ShiftBadge(type: type, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.name).foregroundStyle(.primary)
                                if !type.times.isEmpty {
                                    Text(type.times).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .onMove { store.data.shiftTypes.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    for type in offsets.map({ store.data.shiftTypes[$0] }) {
                        if store.isInUse(type) {
                            blockedDelete = type
                        } else {
                            store.delete(type)
                        }
                    }
                }
            } footer: {
                Text("These are your colour-coded tabs. Use them in patterns, or tap any day on the calendar to mark it as OT, leave and so on.")
            }
        }
        .navigationTitle("Shift types")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingIsNew = true
                    editing = ShiftType(name: "", code: "", colorHex: "#64D2FF")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add shift type")
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(item: $editing) { type in
            ShiftTypeEditor(type: type, isNew: editingIsNew)
        }
        .alert(
            "\(blockedDelete?.name ?? "This") is used in a pattern",
            isPresented: Binding(get: { blockedDelete != nil }, set: { if !$0 { blockedDelete = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Change those days in your pattern to something else first.")
        }
    }
}

struct ShiftTypeEditor: View {
    let isNew: Bool
    @State private var draft: ShiftType

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let swatches = [
        "#34C759", "#30B0C7", "#FFD60A", "#FF9F0A", "#FF3B30", "#FF2D55",
        "#AF52DE", "#5856D6", "#0A84FF", "#5AC8FA", "#A2845E", "#D1D1D6",
    ]

    init(type: ShiftType, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ShiftBadge(type: draft.code.isEmpty ? nil : draft, size: 64)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name, e.g. Overtime", text: $draft.name)
                    TextField("Short code, e.g. OT", text: $draft.code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: draft.code) { _, new in
                            if new.count > 4 { draft.code = String(new.prefix(4)) }
                        }
                    TextField("Times (optional), e.g. 07:00–17:00", text: $draft.times)
                } footer: {
                    Text("The short code is what shows on the calendar. Up to 4 letters.")
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(swatches, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if hex.caseInsensitiveCompare(draft.colorHex) == .orderedSame {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(HexColor.prefersDarkText(hex) ? Color.black : Color.white)
                                    }
                                }
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 6)
                    ColorPicker("Custom colour", selection: Binding(
                        get: { Color(hex: draft.colorHex) },
                        set: { draft.colorHex = $0.hexString }
                    ), supportsOpacity: false)
                }

                if !isNew {
                    Section {
                        Button("Delete shift type", role: .destructive) {
                            store.delete(draft)
                            dismiss()
                        }
                        .disabled(store.isInUse(draft))
                    } footer: {
                        if store.isInUse(draft) {
                            Text("Used in a shift pattern, so it can't be deleted.")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New shift type" : "Edit shift type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
                        draft.code = draft.code.trimmingCharacters(in: .whitespaces)
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty
                        || draft.code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
