# SecureCampus: Smart Campus Security & Management

**Status:** Final-year project, Phase 1 on `main`, Phase 2 on `phase-2` branch (Current) · **Type:** Campus management mobile app
**Stack:** Flutter app, Firebase (Firestore, auth), Python services (FastAPI account service, bus ETA, overdue checker), Docker

## What it is
One app with five role-based portals: Admin, Student, Security, Librarian and Driver.

## Phase 1 features (this branch)
- **Admin:** creates students, courses, books, bus stops and the campus location
- **Student:** sees only their own courses, library items, bus assignment and alerts
- **Security:** read-only found-card reports
- **Librarian:** issues and returns books by QR code
- **Driver:** shares live GPS during a trip
- **Server-side jobs:** overdue-book notifications and a bus 10-minute-away alert
- Strict no-fake-data policy: no mock AI, fake GPS or hardcoded stats

## Phase 2 (not in `main`)
- Iris recognition for class attendance and gate entry, camera control, gate and security alerts. Shown in the app only as locked "Under development" entries.

## Limits / notes
- Needs your own Firebase project, a real Android/iOS device and (for Phase 2) camera hardware before it can be demoed end to end.
- Secrets (`.env`, service account key, `google-services.json`) are git-ignored and must be created locally.

## Docs
`README.md`, `docs/LIMITATIONS.md`, `docs/AUDIT_REPORT.md`, `docs/ARCHITECTURE.md`
