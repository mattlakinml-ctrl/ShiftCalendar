import EventKit
import SwiftUI

/// Tap a day to see what you're on, change it (OT, leave, swaps), add a note,
/// and see what's booked in Apple Calendar.
struct DayDetailView: View {
    let day: DayKey

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        let resolved = store.resolve(day)
        let current = store.shiftType(resolved.shiftTypeID)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ShiftBadge(type: current, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(current?.name ?? "Nothing set")
                                .font(.headline)
                            if let times = current?.times, !times.isEmpty {
                                Text(times).font(.subheadline)
                            }
                            if let rota = resolved.rota, let cycleDay = resolved.cycleDay {
                                Text("\(rota.name) · day \(cycleDay) of \(rota.cycleLength)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if resolved.isChanged {
                                Text("Changed from \(store.shiftType(resolved.rotaShiftID)?.name ?? "rota")")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Change this day") {
                    Button {
                        store.setOverride(nil, on: day)
                    } label: {
                        HStack {
                            ShiftBadge(type: store.shiftType(resolved.rotaShiftID), size: 26)
                            Text("Follow the rota")
                                .foregroundStyle(.primary)
                            Spacer()
                            if resolved.overrideShiftID == nil {
                                Image(systemName: "checkmark").fontWeight(.semibold)
                            }
                        }
                    }
                    ForEach(store.data.shiftTypes) { type in
                        Button {
                            store.setOverride(type.id, on: day)
                        } label: {
                            HStack {
                                ShiftBadge(type: type, size: 26)
                                Text(type.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if resolved.overrideShiftID == type.id {
                                    Image(systemName: "checkmark").fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                Section("Note") {
                    TextField("e.g. court, swapped with a colleague", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Apple Calendar") {
                    CalendarEventsList(day: day)
                }
            }
            .navigationTitle(day.longTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { note = resolved.note }
            .onChange(of: note) { _, newValue in
                store.setNote(newValue, on: day)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CalendarEventsList: View {
    let day: DayKey
    @Environment(CalendarService.self) private var calendarService

    var body: some View {
        if calendarService.hasAccess {
            let events = calendarService.events(on: day)
            if events.isEmpty {
                Text("Nothing booked")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title ?? "Untitled")
                            Text(timeText(event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else if calendarService.status == .notDetermined {
            Button("Connect Apple Calendar") {
                Task { await calendarService.requestAccess() }
            }
        } else {
            Text("Calendar access is off. Turn it on in the Settings app under Privacy & Security › Calendars › Shift Calendar (Full Access).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func timeText(_ event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }
}
