import EventKit
import Foundation
import Observation

/// Reads the user's Apple Calendar so days with bookings can show a dot.
@MainActor
@Observable
final class CalendarService {
    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var eventDays: Set<DayKey> = []
    private(set) var calendars: [EKCalendar] = []

    private let eventStore = EKEventStore()
    @ObservationIgnored private var range: ClosedRange<DayKey>?
    @ObservationIgnored private var hiddenCalendarIDs: Set<String> = []
    @ObservationIgnored private var observer: NSObjectProtocol?

    var hasAccess: Bool { status == .fullAccess }

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: eventStore, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func configure(range: ClosedRange<DayKey>, hiddenCalendarIDs: Set<String>) {
        self.range = range
        self.hiddenCalendarIDs = hiddenCalendarIDs
        reload()
    }

    func setHiddenCalendars(_ ids: Set<String>) {
        hiddenCalendarIDs = ids
        reload()
    }

    func requestAccess() async {
        _ = try? await eventStore.requestFullAccessToEvents()
        status = EKEventStore.authorizationStatus(for: .event)
        reload()
    }

    func events(on day: DayKey) -> [EKEvent] {
        guard hasAccess else { return [] }
        let start = day.date()
        let end = day.adding(days: 1).date()
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: visibleCalendars())
        return eventStore.events(matching: predicate).sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            return a.startDate < b.startDate
        }
    }

    func reload() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess, let range else {
            calendars = []
            eventDays = []
            return
        }
        calendars = eventStore.calendars(for: .event)
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
        let visible = visibleCalendars()
        guard !visible.isEmpty else {
            eventDays = []
            return
        }

        // EventKit only searches up to four years per query, so go a year at a time.
        var days = Set<DayKey>()
        var chunkStart = range.lowerBound
        while chunkStart <= range.upperBound {
            let chunkEnd = min(chunkStart.adding(days: 365), range.upperBound.adding(days: 1))
            let predicate = eventStore.predicateForEvents(
                withStart: chunkStart.date(), end: chunkEnd.date(), calendars: visible
            )
            for event in eventStore.events(matching: predicate) {
                let first = DayKey(event.startDate)
                // End dates are exclusive in practice (all-day events end at midnight
                // or 23:59:59), so step back a second before taking the day.
                let last = max(first, DayKey(event.endDate.addingTimeInterval(-1)))
                var d = first
                var guardCount = 0
                while d <= last && guardCount < 62 {
                    days.insert(d)
                    d = d.adding(days: 1)
                    guardCount += 1
                }
            }
            chunkStart = chunkEnd
        }
        eventDays = days
    }

    private func visibleCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event).filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
    }
}
