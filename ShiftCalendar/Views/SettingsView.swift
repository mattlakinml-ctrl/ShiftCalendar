import EventKit
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(CalendarService.self) private var calendarService
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @AppStorage("hideWelcomeTip") private var hideWelcomeTip = false
    @State private var showMailFallback = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        HelpGuideView()
                    } label: {
                        Label("How to use this app", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                    }
                    Toggle("Show the help tip when the app opens", isOn: Binding(
                        get: { !hideWelcomeTip },
                        set: { hideWelcomeTip = !$0 }
                    ))
                } header: {
                    Text("Help")
                }

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

                Section {
                    if purchases.isUnlocked {
                        Label("Full version unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text(purchases.daysLeftInTrial > 0
                             ? "Free trial: \(purchases.daysLeftInTrial) days left"
                             : "Free trial finished")
                            .font(.headline)
                        UnlockButtons()
                            .padding(.vertical, 4)
                    }
                } header: {
                    Text("Full version")
                } footer: {
                    if !purchases.isUnlocked {
                        Text("One payment of \(purchases.priceText). No subscription and no adverts.")
                    }
                }

                Section("Feedback") {
                    Button {
                        guard let url = AppInfo.bugReportURL else { return }
                        openURL(url) { accepted in
                            if !accepted { showMailFallback = true }
                        }
                    } label: {
                        Label("Report a problem", systemImage: "ladybug.fill")
                    }
                    Button {
                        if let url = AppInfo.reviewURL {
                            openURL(url)
                        } else {
                            requestReview()
                        }
                    } label: {
                        Label("Rate us on the App Store", systemImage: "star.fill")
                    }
                }

                #if DEBUG
                Section("Developer (test builds only)") {
                    Button("End free trial now") { purchases.debugEndTrial() }
                    Button("Restart free trial") { purchases.debugRestartTrial() }
                }
                #endif

                Section {
                    Text("Shift Calendar \(AppInfo.version)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .alert("Email isn't set up on this phone", isPresented: $showMailFallback) {
                Button("Copy email address") { UIPasteboard.general.string = AppInfo.supportEmail }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Send your message to \(AppInfo.supportEmail) from any email app.")
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
    @Environment(ShiftStore.self) private var store
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
