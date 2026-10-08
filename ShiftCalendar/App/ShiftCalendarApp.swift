import SwiftUI

@main
struct ShiftCalendarApp: App {
    @State private var store = AppStore()
    @State private var calendarService = CalendarService()

    var body: some Scene {
        WindowGroup {
            CalendarScreen()
                .environment(store)
                .environment(calendarService)
        }
    }
}
