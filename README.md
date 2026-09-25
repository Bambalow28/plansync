<p align="center">
  <img src="docs/icon.png" width="128" alt="PlanSync app icon">
</p>

<h1 align="center">PlanSync</h1>

<p align="center">Every part of a trip in one place: day-by-day plans, places, money and documents.</p>

<p align="center"><sub>iOS · Flutter · Firebase</sub></p>

## What it does

- **Trips & itineraries.** Plan a trip day by day, or have AI draft one for you.
- **Places.** Search and pin locations to any plan item.
- **Expenses.** Track spending by category.
- **Attachments.** Tickets, bookings and PDFs, stored with the trip.
- **Flight lookup.** Pull in flight details automatically.
- **Live Activity.** Trip status on the Lock Screen and Dynamic Island.
- **Share & export.** Share an itinerary or export it as a PDF.
- **Travel advisors.** Browse advisors, request a custom plan, or apply to become one.
- Offline aware, with local notifications.

## Stack

- **Flutter**, iOS first.
- **Firebase** (Auth, Firestore) for accounts and advisor data.

| Path | What |
|---|---|
| `lib/ui/` | Home, trip, advisor, auth, onboarding |
| `lib/models/`, `lib/controllers/`, `lib/services/` | Data, state and integrations |

## Develop

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Release

Every push to `main` builds a signed IPA on a self-hosted macOS runner and uploads it to TestFlight
(`.github/workflows/testflight.yml`).
