# Firebase Setup

## 1. Create the project

1. https://console.firebase.google.com → Add project.
2. **Upgrade to the Blaze (pay-as-you-go) plan.** This is required for
   the overdue-book scheduled Cloud Function in `functions/` — Cloud
   Functions (including the free-tier-eligible ones) require Blaze,
   and scheduled functions additionally need the Cloud Scheduler API
   enabled (usually on by default for Blaze projects; each schedule
   costs $0.10/month with 3 free per Google account). If you'd rather
   not enable billing, skip deploying `functions/` — everything else in
   this project works without it, you'll just be back to the "detection
   only, no notification" state for overdue books documented in
   `docs/AUDIT_REPORT.md`.
3. Enable **Authentication** → Sign-in method → Email/Password, and
   Anonymous (needed for the public "report a found card" flow).
4. Enable **Cloud Firestore** (production mode).
5. Enable **Realtime Database** (used only for live driver GPS).
6. Enable **Storage**.
7. Enable **Cloud Messaging** (FCM) — no separate "enable" step beyond
   the project existing; you'll need a Web/Android/iOS FCM
   configuration depending on target platform, done via FlutterFire.

## 2. Service account (for iris_ai, bus_eta, and the seed script)

Project settings → Service accounts → Generate new private key. Save it
as `../secrets/serviceAccountKey.json` (already gitignored) and point
`GOOGLE_APPLICATION_CREDENTIALS` in `.env` at it.

## 3. Deploy rules and the scheduled function

**Run these from the repo root** (where `firebase.json` lives — not
from inside this `firebase/` directory; `firebase.json` references
these rule files by their `firebase/...` relative path already):

```
firebase login
firebase use --add                 # pick your project - writes .firebaserc (see .firebaserc.example)
firebase deploy --only firestore:rules,firestore:indexes,storage:rules,database
firebase deploy --only functions   # the overdue-book check - needs Blaze, see step 1.2 above
```

`firebase.json` did not exist in an earlier build of this project,
which meant none of the above could have worked at all — it's included
now at the repo root.

## 4. Seed the initial dataset

From the repo root, with `.env` filled in:

```
python scripts/seed_firebase.py
```

This creates (as real, Admin-editable Firestore/Auth/RTDB records, per
spec §47 — nothing hardcoded into the app), reusing the same
`create_account()` path (with its race-safe registration-number
uniqueness reservation) that the Admin portal itself uses:
- 10 student accounts (Firebase Auth + `students` + `users` docs)
- 1 librarian account, 1 security account, 1 driver account
- 6 course documents
- 5 book documents
- 3 bus stops
- 1 bus (`BUS-001`) assigned to the seeded driver
- `roles/{uid}` and `driverAssignments/{uid}` mirrors in Realtime
  Database (needed because RTDB rules can't query Firestore directly)

It prints each account's temporary password once — capture it, students
should be told to have Admin reset their password on first login (spec
§46: no self-service password reset flow; contact Admin).

**Iris enrollment is a separate step** — it needs a real captured eye
image per student, sent to `POST /iris/enroll` on the running iris_ai
service (or via the Admin portal's Students → Enroll Iris button once
the app runs). See `docs/IRIS_MODEL.md`.

## 5. FlutterFire configuration

From `mobile/` (after `flutter create --platforms=android,ios .` — see
`docs/MOBILE_PLATFORM_SETUP.md`):

```
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `mobile/lib/firebase_options.dart` against your actual
project — intentionally not included in this repo (a placeholder file
would either fail to compile or point at a project that doesn't exist).

## 6. Google Maps API key (separate from the above)

The Admin portal's live bus map needs its own native Maps SDK key —
this is not part of `flutterfire configure`. See
`docs/MOBILE_PLATFORM_SETUP.md` §4 for the exact Android/iOS steps.
