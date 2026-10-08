import SwiftUI

/// The how-to guide. Short steps, big pictures, no jargon.
struct HelpGuideView: View {
    @Environment(ShiftStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Easy as 1, 2, 3. Each step has a picture showing what to tap.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HelpStep(number: 1, title: "Colours = shifts",
                         text: "Each square is a day. The colour tells you your shift.\nGreen = Early. Yellow = Late. Red = Night. Grey = Rest Day.") {
                    MockWeek(codes: ["E", "E", "L", "L", "N", "RD", "RD"])
                }

                HelpStep(number: 2, title: "Put your rota in (only once)",
                         text: "Tap the cog at the top right.\nTap Shift patterns.\nTap the + at the top.") {
                    MockTapPath(steps: [
                        .init(icon: "gearshape.fill", label: "Cog"),
                        .init(icon: "repeat", label: "Shift patterns"),
                        .init(icon: "plus", label: "+"),
                    ])
                }

                HelpStep(number: 3, title: "Build your pattern",
                         text: "Easiest way: tap Start from a template and pick the one like yours.\n\nOr do it yourself: tap Add block. Pick the shift. Press + or − to set how many days. Add the next block. Keep going until it matches your rota.") {
                    VStack(spacing: 8) {
                        MockBlock(code: "E", days: 7)
                        MockBlock(code: "RD", days: 3)
                        MockBlock(code: "L", days: 7)
                    }
                }

                HelpStep(number: 4, title: "Pick Day 1, then Save",
                         text: "Day 1 is the first day of your pattern, e.g. your first Early of the run.\nTap Save. That's it! Every month fills in, years ahead.") {
                    MockTapPath(steps: [
                        .init(icon: "calendar", label: "Day 1"),
                        .init(icon: "checkmark", label: "Save"),
                    ])
                }

                HelpStep(number: 5, title: "Overtime, leave or a swap",
                         text: "Tap the day.\nTap Shift and pick what you're doing instead, like Overtime or Annual Leave.\nChanged your mind? Pick Follow the rota.") {
                    MockShiftMenu(codes: ["OT", "AL", "RDIL"])
                }

                HelpStep(number: 6, title: "Write a note",
                         text: "Tap the day and type in the Note box, e.g. \"Court\".\nA little speech bubble shows on that day so you don't forget.\nKeep it simple: no case details or work secrets in notes.") {
                    MockWeek(codes: ["E", "L", "L"], noteIndex: 1)
                }

                HelpStep(number: 7, title: "Dots = your other plans",
                         text: "A small dot means something is in your Apple or Google calendar that day, such as the dentist.\nTap the day to see what it is.") {
                    MockWeek(codes: ["N", "RD", "RD"], dotIndex: 2)
                }

                HelpStep(number: 8, title: "Find a date fast",
                         text: "Tap Today to jump back to today.\nTap the calendar button at the top to go straight to any date, even next year.") {
                    MockTapPath(steps: [
                        .init(icon: "arrow.uturn.backward", label: "Today"),
                        .init(icon: "calendar.badge.clock", label: "Go to date"),
                    ])
                }

                HelpStep(number: 9, title: "Change colours or add your own",
                         text: "Cog, then Shift types & colours.\nTap one to change its name or colour. Tap + to add a new one, like Training or Court.") {
                    MockTapPath(steps: [
                        .init(icon: "gearshape.fill", label: "Cog"),
                        .init(icon: "paintpalette", label: "Shift types"),
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Still stuck?")
                        .font(.title2.bold())
                    Text("Send us a message and we'll help.")
                        .font(.title3)
                    Button {
                        if let url = AppInfo.bugReportURL { openURL(url) }
                    } label: {
                        Label("Report a problem", systemImage: "envelope.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("How to use this app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpStep<Picture: View>: View {
    let number: Int
    let title: String
    let text: String
    @ViewBuilder let picture: () -> Picture

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.blue))
                Text(title)
                    .font(.title2.bold())
            }
            Text(text)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
            picture()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A row of calendar days, drawn exactly like the real calendar.
private struct MockWeek: View {
    let codes: [String]
    var noteIndex: Int?
    var dotIndex: Int?
    @Environment(ShiftStore.self) private var store

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(codes.enumerated()), id: \.offset) { i, code in
                DayCell(
                    day: DayKey(year: 2026, month: 1, day: 12 + i),
                    shift: store.shiftType(code: code),
                    isChanged: false,
                    hasNote: i == noteIndex,
                    hasEvents: i == dotIndex,
                    isToday: false
                )
                .frame(maxWidth: 48)
            }
        }
    }
}

private struct MockTapPath: View {
    struct Step: Hashable {
        let icon: String
        let label: String
    }

    let steps: [Step]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                if i > 0 {
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.title2)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.blue.opacity(0.15)))
                        .foregroundStyle(.blue)
                    Text(step.label)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: 90)
            }
        }
    }
}

private struct MockBlock: View {
    let code: String
    let days: Int
    @Environment(ShiftStore.self) private var store

    var body: some View {
        let type = store.shiftType(code: code)
        HStack {
            ShiftBadge(type: type, size: 28)
            Text(type?.name ?? code)
            Spacer()
            Text("\(days)").monospacedDigit().fontWeight(.semibold)
            HStack(spacing: 0) {
                Image(systemName: "minus").frame(width: 34, height: 28)
                Divider().frame(height: 16)
                Image(systemName: "plus").frame(width: 34, height: 28)
            }
            .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MockShiftMenu: View {
    let codes: [String]
    @Environment(ShiftStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ShiftBadge(type: store.shiftType(code: "E"), size: 26)
                Text("Shift")
                Spacer()
                Text("Follow the rota").foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").foregroundStyle(.blue)
            }
            Divider()
            ForEach(codes, id: \.self) { code in
                HStack {
                    ShiftBadge(type: store.shiftType(code: code), size: 22)
                    Text(store.shiftType(code: code)?.name ?? code)
                }
            }
        }
    }
}
