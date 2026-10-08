import SwiftUI

@main
struct ShiftCalendarApp: App {
    @State private var store = ShiftStore()
    @State private var calendarService = CalendarService()
    @State private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                CalendarScreen()
                if !purchases.hasAccess {
                    PaywallView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                        .transition(.opacity)
                }
            }
            .animation(.default, value: purchases.hasAccess)
            .environment(store)
            .environment(calendarService)
            .environment(purchases)
        }
    }
}
