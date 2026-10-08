import SwiftUI

/// The main screen: a continuous scroll of months, each day coloured by shift.
struct CalendarScreen: View {
    @Environment(ShiftStore.self) private var store
    @Environment(CalendarService.self) private var calendarService
    @Environment(PurchaseManager.self) private var purchases
    @AppStorage("hideWelcomeTip") private var hideWelcomeTip = false

    private let months = MonthKey.range(around: .today, before: 12, after: 60)

    @State private var scrolledMonth: MonthKey?
    @State private var selectedDay: DayKey?
    @State private var showSettings = false
    @State private var showJump = false
    @State private var jumpDate = Date()
    @State private var pendingJump: DayKey?
    @State private var newRota: Rota?
    @State private var showWelcome = false
    @State private var showGuide = false
    @State private var pulseSetup = false
    @State private var pulsePhase = false
    @State private var guideRequested = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(months, id: \.self) { month in
                        MonthView(month: month) { selectedDay = $0 }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 10)
                .padding(.bottom, 40)
            }
            .scrollPosition(id: $scrolledMonth, anchor: .top)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    if store.data.rotas.isEmpty {
                        setupBanner
                    }
                    LegendBar()
                    WeekdayHeader()
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    Divider()
                }
                .background(.bar)
            }
            .navigationTitle(scrolledMonth?.title ?? "Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") {
                        withAnimation { scrolledMonth = MonthKey(.today) }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        jumpDate = scrolledMonth?.firstDay.date() ?? Date()
                        showJump = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .accessibilityLabel("Go to date")
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onAppear {
                if scrolledMonth == nil { scrolledMonth = MonthKey(.today) }
            }
            .sheet(item: $selectedDay) { day in
                DayDetailView(day: day)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showWelcome, onDismiss: {
                if guideRequested {
                    guideRequested = false
                    showGuide = true
                }
            }) {
                WelcomeTipView { guideRequested = true }
            }
            .sheet(isPresented: $showGuide, onDismiss: {
                if store.data.rotas.isEmpty { pulseSetup = true }
            }) {
                NavigationStack {
                    HelpGuideView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showGuide = false }
                            }
                        }
                }
            }
            .sheet(item: $newRota) { rota in
                RotaEditor(rota: rota, isNew: true)
            }
            .sheet(isPresented: $showJump, onDismiss: {
                if let day = pendingJump {
                    scrolledMonth = MonthKey(day)
                    selectedDay = day
                    pendingJump = nil
                }
            }) {
                jumpSheet
            }
            .task {
                showWelcome = !hideWelcomeTip && purchases.hasAccess
                calendarService.configure(
                    range: months.first!.firstDay...months.last!.lastDay,
                    hiddenCalendarIDs: store.data.hiddenCalendarIDs
                )
                if store.data.showCalendarDots && calendarService.status == .notDetermined {
                    await calendarService.requestAccess()
                }
            }
            .onChange(of: store.data.hiddenCalendarIDs) { _, ids in
                calendarService.setHiddenCalendars(ids)
            }
        }
    }

    private var setupBanner: some View {
        Button {
            pulseSetup = false
            newRota = Rota.newDraft(using: store)
        } label: {
            HStack {
                Image(systemName: "repeat")
                Text("Set up your shift pattern")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(12)
            .background(
                Color.accentColor.opacity(pulseSetup && pulsePhase ? 0.4 : 0.15),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(pulseSetup && pulsePhase ? 0.9 : 0), lineWidth: 2)
            )
            .scaleEffect(pulseSetup && pulsePhase ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .onChange(of: pulseSetup) { _, pulsing in
            if pulsing {
                // A gentle, repeating glow to show where to go next.
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            } else {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { pulsePhase = false }
            }
        }
    }

    private var jumpSheet: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: $jumpDate,
                in: months.first!.firstDay.date()...months.last!.lastDay.date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Go to date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showJump = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show") {
                        pendingJump = DayKey(jumpDate)
                        showJump = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct WeekdayHeader: View {
    private let symbols = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                Text(s)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Colour key across the top, so the codes always make sense at a glance.
private struct LegendBar: View {
    @Environment(ShiftStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.data.shiftTypes) { type in
                    HStack(spacing: 5) {
                        ShiftBadge(type: type, size: 18)
                        Text(type.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

struct MonthView: View {
    let month: MonthKey
    let onSelect: (DayKey) -> Void

    @Environment(ShiftStore.self) private var store
    @Environment(CalendarService.self) private var calendarService

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let today = DayKey.today
        let showDots = store.data.showCalendarDots
        VStack(alignment: .leading, spacing: 8) {
            Text(month.title)
                .font(.title3.bold())
                .padding(.leading, 4)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(month.gridCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let resolved = store.resolve(day)
                        DayCell(
                            day: day,
                            shift: store.shiftType(resolved.shiftTypeID),
                            isChanged: resolved.isChanged,
                            hasNote: !resolved.note.isEmpty,
                            hasEvents: showDots && calendarService.eventDays.contains(day),
                            isToday: day == today
                        )
                        .onTapGesture { onSelect(day) }
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
        }
    }
}

struct DayCell: View {
    let day: DayKey
    let shift: ShiftType?
    let isChanged: Bool
    let hasNote: Bool
    let hasEvents: Bool
    let isToday: Bool

    var body: some View {
        let fg = shift?.textColor ?? .primary
        VStack(spacing: 2) {
            Text("\(day.day)")
                .font(.caption.weight(isToday ? .heavy : .medium))
            Text(shift?.code ?? " ")
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Circle()
                .fill(hasEvents ? fg : .clear)
                .frame(width: 5, height: 5)
        }
        .foregroundStyle(fg)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(shift?.color ?? Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.primary : .clear, lineWidth: 2.5)
        )
        .overlay(alignment: .topTrailing) {
            if isChanged || hasNote {
                Image(systemName: hasNote ? "text.bubble.fill" : "pencil")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(fg.opacity(0.8))
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.longTitle), \(shift?.name ?? "nothing set")\(hasEvents ? ", has bookings" : "")")
    }
}
