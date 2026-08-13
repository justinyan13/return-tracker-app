# Refund Tracker

Refund Tracker is a privacy-first iPhone and iPad app for tracking money owed after an online return. It answers two questions at a glance: what money is coming back, and which refund needs a nudge?

The app is built entirely with Apple frameworks. Records, preferences, and attachments remain on the device; there is no account, analytics SDK, API key, or server component.

## Requirements

- Xcode 16 or later
- iOS 17 or later
- Swift 5 language mode

## Run the app

1. Open `RefundTracker.xcodeproj` in Xcode.
2. Select the `RefundTracker` scheme and an iOS 17+ simulator.
3. Build and run with **Command-R**.

No package resolution or service configuration is required. Notification permission is requested contextually—when reminders are enabled or when the first refund is saved—not at launch.

## Product experience

Capturing a refund is intentionally lightweight. The add screen presents four essentials:

- Merchant name
- Refund amount
- The default currency from Settings
- Shipped date

The currency is already selected, and the expected refund date is calculated from the configured business-day window. The user can start tracking without entering an item name, order number, carrier, tracking number, notes, or other purchase details.

The interface is editorial rather than decorative: warm paper, near-black ink, hairline rules, and a serif reserved for figures and display titles. The content layer avoids gradients, glass, and shadows, while native iOS Liquid Glass keeps navigation distinct above it. Colour appears only where something is late or has landed. The Overview screen leads with the outstanding balance and the open, overdue, and refunded counts on a ruled strip. Returns then read as one ruled list — merchant, item, what happens next, and the amount — with status shown as a dot and a letterspaced word.

## Architecture

The project uses feature-oriented MVVM with small services around platform APIs:

```text
RefundTracker/
├── App/                 App entry point and tab navigation
├── Models/              SwiftData models and domain enums
├── ViewModels/          Form, filtering, dashboard, and insight state
├── Views/
│   ├── Components/      Reusable status, amount, and empty-state views
│   ├── Dashboard/
│   ├── Refunds/
│   ├── Insights/
│   ├── Settings/
│   └── Onboarding/
├── Services/            Notifications, attachments, CSV, settings, samples
├── Utilities/           Business-day, metrics, filtering, and formatting logic
└── Resources/           App icon and color assets
```

SwiftUI views own presentation state and use SwiftData's `ModelContext` for persistence. Business rules are implemented as pure functions or focused value types wherever possible, which keeps calculations independent of UI and makes them straightforward to test. Platform side effects are isolated in services.

## Data model

`Refund` is a SwiftData `@Model` containing merchant identity, amount and ISO currency code, shipment and refund dates, lifecycle status, timestamps, optional supporting details, and a cascade relationship to attachment metadata. The persistence model can represent a full refund lifecycle, while the primary capture experience deliberately asks for only the four essentials above. New records use a neutral internal item label rather than asking the user for one.

`RefundAttachment` stores metadata and an app-generated stored filename, not the file bytes. File contents live together under `Application Support/RefundTracker/Attachments` instead of being placed in the database. Photo data is written atomically with file protection, while file-picker selections are copied from their security-scoped URLs into the app-managed directory. Generated filenames prevent collisions. The detail screen shows attachment metadata and offers the native share sheet for opening or exporting the local file; it does not currently include an inline or Quick Look preview.

### Effective status

The stored status represents the user's latest workflow action. The displayed effective status follows this precedence:

1. `Disputed` and `Cancelled` are always preserved.
2. A record with an actual refund date is `Refunded`.
3. Any otherwise-open record past its expected date is `Overdue`.
4. Otherwise the stored workflow status is shown.

This avoids persisting a status that would immediately become stale at midnight while still respecting explicit user decisions.

### Business days

The default expected date is calculated by advancing the configured number of Monday–Friday business days from the shipped date. Public holidays are intentionally not inferred: holiday calendars vary by country and carrier, and adding one without a locale-specific source would create false precision. The default window can be adjusted globally in Settings.

## Features

- Editorial Overview screen leading with the outstanding balance and compact counts
- Merchant-first ruled lists with clear status and date cues
- Four-essential capture flow with validation and automatic expected dates
- Search, practical filters, and sorting
- Focused status actions for shipped, delivered, refunded, disputed, and cancelled returns
- Native photo and file import with local attachment storage
- Swift Charts insights for monthly refunds and retailer turnaround time
- Configurable local reminders before, on, and after expected dates
- CSV export through the system share sheet
- Explicit sample-data controls and a first-run empty experience
- Dynamic Type, VoiceOver labels, dark mode, and reduced-motion-friendly UI

## Notifications

`NotificationPlanner` produces a deterministic reminder plan from a refund and user preferences. `NotificationService` translates that plan to `UNCalendarNotificationTrigger` requests. Pending requests use stable identifiers derived from the refund ID, so every edit first removes obsolete reminders and then schedules the current set. Refunded, disputed, and cancelled records do not schedule follow-ups.

The four available reminders are:

- A configurable number of days before the expected date
- The expected date
- The first overdue day
- A configurable number of days after the refund becomes overdue

## Currency handling

Amounts are stored as decimal values with an ISO 4217 currency code. The app never performs implicit currency conversion. Aggregate charts and headline totals use the selected default currency; balances in other currencies remain visible separately where relevant.

## CSV export

Export is performed locally. Fields are RFC 4180 escaped, dates use a stable ISO-style format, optional values remain empty, and notes containing quotes, commas, or line breaks are preserved correctly.

## Testing

Run all tests with **Command-U**, or from Terminal:

```sh
xcodebuild test \
  -project RefundTracker.xcodeproj \
  -scheme RefundTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The unit suite covers status precedence and overdue behavior, business-day/default-date calculations, dashboard totals, list filters and sorting, CSV escaping, and notification planning. UI tests cover lightweight capture, editing, completing, overdue filtering, and deletion.

UI tests pass `--ui-testing`, which gives the app a fresh in-memory SwiftData store and bypasses onboarding. `--ui-testing-seed` adds deterministic records for filter scenarios. These arguments are ignored during normal use.

## Privacy and production notes

- There are no third-party dependencies.
- No user data leaves the device unless the user explicitly invokes the share sheet.
- Sample records are only inserted from Settings or the UI-testing launch mode.
- Notification permission and scheduling errors are surfaced without blocking record persistence.
- Attachment deletion removes both metadata and its locally stored file.
