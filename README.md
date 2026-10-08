# Shift Calendar

An iPhone app for police shift rotas. Set up any repeating pattern once and see what you're on for years ahead, colour coded, with a dot on days where Apple Calendar already has something booked.

## What it does

- **Any pattern.** Build a rota from blocks: "6 × Early, 4 × Rest Day", or "7 on 3 off, 7 on 4 off, 7 on 3 off", or "2 Earlies, 2 Lates, 2 Nights, 4 off". Pick the date that was day 1 and it repeats forever.
- **Changing rota?** Add a new pattern from the day it starts. Earlier dates keep the old one.
- **Colour-coded shift types.** Comes with Early (green), Mid Late (orange), Late (yellow), Night (red), Rest Day, Overtime, Rest Day in Lieu and Annual Leave. Rename, recolour or add your own (Training, Court, Sick…).
- **One-off changes.** Tap any day to mark it OT, annual leave, RDIL, a swap, or add a note. A small pencil shows on changed days.
- **Apple Calendar dots.** Days with a booking (dentist etc.) get a small dot. Tap the day to see what it is. You can hide calendars like Birthdays or Holidays in Settings.
- **Look ahead fast.** Scroll through months, tap **Today**, or use the calendar button to jump straight to any date up to 5 years out.

Everything is stored on the phone. Nothing is sent anywhere.

## Running it on your iPhone

You need a Mac with Xcode 16 or newer.

1. Open `ShiftCalendar.xcodeproj` in Xcode.
2. Click the **ShiftCalendar** project, then the **ShiftCalendar** target, then **Signing & Capabilities**, and choose your Apple ID as the Team. If the bundle ID clashes, change `com.mattlakin.ShiftCalendar` to something unique.
3. Plug in your iPhone (turn on Developer Mode when it asks), pick it as the run destination, and press ▶.

With a free Apple ID the app needs reinstalling from Xcode every 7 days. A paid Apple Developer account (£79/yr) removes that and lets you use TestFlight.

## Code layout

- `ShiftCalendar/Model` – days, shift types, patterns, overrides
- `ShiftCalendar/Engine` – `ShiftEngine` works out the shift for any date; `AppStore` saves everything to a JSON file
- `ShiftCalendar/Services/CalendarService.swift` – reads Apple Calendar via EventKit for the dots
- `ShiftCalendar/Views` – the SwiftUI screens
- `ShiftCalendarTests` – unit tests for the pattern maths (⌘U in Xcode)
