import EventKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your rota") {
                    NavigationLink {
                        RotaListView()
                    } label: {
                        Label("Shift patterns", systemImage: "repeat")
                    }
                    NavigationLink {
                        ShiftTypesView()
                    } label: {
                        Label("Shift types & colours", systemImage: "paintpalette")
                    }
                }

                Section {
                    Toggle("Show a dot on days with bookings", isOn: Binding(
                        get: { store.data.showCalendarDots },
                        set: { store.data.showCalendarDots = $0 }
                    ))
                    if calendarService.hasAccess {
                        NavigationLink("Choose calendars") {
                            CalendarPickerView()
                        }
                    } else if calendarService.status == .notDetermined {
                        Button("Connect Apple Calendar") {
                            Task { await calendarService.requestAccess() }
                        }
                    } else {
                        Text("Calendar access is off. Turn it on in the Settings app under Privacy & Security › Calendars.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Calendar")
                } footer: {
                    Text("Bookings like a dentist appointment show as a small dot. Tap the day to see what they are.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Lets you hide calendars that would clutter the dots, like Birthdays or Holidays.
struct CalendarPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(CalendarService.self) private var calendarService

    var body: some View {
        List {
            ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                Toggle(isOn: Binding(
                    get: { !store.data.hiddenCalendarIDs.contains(calendar.calendarIdentifier) },
                    set: { show in
                        if show {
                            store.data.hiddenCalendarIDs.remove(calendar.calendarIdentifier)
                        } else {
                            store.data.hiddenCalendarIDs.insert(calendar.calendarIdentifier)
                        }
                    }
                )) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(calendar.title)
                            Text(calendar.source.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendars")
    }
}
