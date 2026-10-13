# SecureCampus — Smart Campus Security & Management System

A Final Year Project: a Flutter app with five role-based portals (Admin,
Student, Security, Librarian, Driver), a Firebase backend, a standalone
Python computer-vision service that does real iris recognition for
classroom attendance and gate entry, a Python bus-ETA service, and a
scheduled Cloud Function for overdue-library notifications.

**Read `docs/LIMITATIONS.md` and `docs/AUDIT_REPORT.md` first.** They
state plainly what has been built, tested, and fixed in this
development environment vs. what requires your own Firebase project, a
physical iPhone 13, and a real Android/iOS device to actually run and
demo — this project follows a strict no-fake-data policy (no mock AI,
no fake GPS, no hardcoded stats), which means some things genuinely
cannot be proven working until you attach that hardware.

## 1. Version requirements (current stable, verified Sept 2026)

See `docs/VERSION_AUDIT.md` for the full methodology and sourcing —
summary:

| Component | Target | How this was verified |
|---|---|---|
| Flutter | 3.47.x (stable channel) | Web search against docs.flutter.dev release notes (no Flutter SDK available in this build env to run `flutter --version` directly) |
| Dart | 3.13.x (ships with Flutter 3.47) | Same |
| Firebase Flutter plugins | Floors from BoM 4.11.0 (2026-03-23), `^` constraints so `flutter pub get` resolves newer | firebase.google.com/support/release-notes/flutter (official, dated) |
| Android | AGP ~9.2, Gradle ~9.5, Kotlin ~2.2, compileSdk 36, JDK 17 | Web search against developer.android.com — **not applied to a generated project**, since none exists here; verify against what `flutter create` actually produces |
| Python (iris_ai / bus_eta / functions) | 3.12+ | **Actually installed and tested** — this repo's Python code was verified end-to-end on Python 3.12.3 |
| FastAPI / OpenCV / NumPy / firebase-admin / etc. | Latest PyPI as of Sept 2026 | **Actually queried live from PyPI and installed** — not guessed (see `docs/VERSION_AUDIT.md`) |

Run `flutter --version`, `dart --version`, and `python --version`
yourself once you have the toolchain installed — if any report older
than the floors above, upgrade before proceeding.

## 2. Project overview

Admin creates students/courses/books/the bus and controls the live
recognition camera; students see only their own data (attendance,
library, bus assignment — never gate history or the live bus map);
Security sees gate entries and unknown-person alerts; Librarian
issues/returns books via QR; the one Driver shares live GPS while a
trip is active; overdue-book notifications and the bus 10-minute alert
run as real server-side jobs, not client-side checks.

## 3. Architecture

See `docs/ARCHITECTURE.md` for the full data-flow diagram. Four
backend pieces, three languages by design:
- **`iris_ai/`** (Python/FastAPI) — camera, iris recognition, admin
  account creation, camera controls.
- **`bus_eta/`** (Python) — continuous GPS-to-ETA polling loop; a
  continuous loop doesn't fit Cloud Functions' execution model, hence
  a standalone service like `iris_ai`.
- **`functions/`** (Python Cloud Functions, 2nd gen) — the overdue-book
  scheduled check; a genuinely periodic job is exactly what Cloud
  Functions' `onSchedule` is for, and keeping it in Python (not
  Node.js) keeps the whole backend in one language.
- **Flutter app** (`mobile/`) — talks to Firestore/RTDB/Storage
  directly for everything permitted by security rules, and to
  `iris_ai`'s REST API only for the two things a client fundamentally
  can't do itself: creating Firebase Auth accounts and controlling the
  live recognition loop.

## 4. Setup — first time

### 4.1 Firebase project

```
npm install -g firebase-tools     # if not already installed
firebase login
```

Then follow `firebase/README.md` in full: create the project, enable
Auth/Firestore/RTDB/Storage, generate a service-account key, and:

```
firebase use --add                 # links this repo to your project (writes .firebaserc)
firebase deploy --only firestore:rules,firestore:indexes,storage:rules,database
firebase deploy --only functions   # deploys the overdue-book scheduled Cloud Function
```

`firebase.json` (repo root) already wires all four rule files and the
`functions/` source — this file did not exist in an earlier build of
this project, which meant `firebase deploy` could not have worked at
all; it's included now.

### 4.2 Python services (`iris_ai`, `bus_eta`)

```
./setup.sh      # or setup.bat on Windows — creates both venvs, generates QR codes
# fill in .env (copy from .env.example) and put your service account JSON
# at ./secrets/serviceAccountKey.json
./run.sh        # or run.bat — starts bus_eta in the background, iris_ai in the foreground
```

Or via Docker: `docker compose up --build` (starts both services;
`functions/` is deployed separately via the Firebase CLI above, not
run locally the same way).

Verify `iris_ai` is up: `curl http://localhost:8000/health` and
`curl http://localhost:8000/camera/status`.

### 4.3 Seed the initial dataset

```
python scripts/seed_firebase.py
```

Creates the 10 students, 5 books, 1 bus, 1 driver, courses, and stops
as real, Admin-editable Firestore/Auth records (spec §47) — reuses the
same account-creation path (`iris_ai/app/firebase_client.py::create_account`)
the Admin portal uses, including the race-safe registration-number
uniqueness check.

### 4.4 iPhone 13 RTSP camera

1. Install **RTSP & RTMP Cam — OctoStream** from the App Store.
2. Connect the iPhone and the machine running `iris_ai` to the **same
   Wi-Fi network**.
3. Open the app, enable the camera, start the RTSP server.
4. Copy the RTSP URL it shows you.
5. Put it in `.env` as `CAMERA_RTSP_URL` (never hardcode it — it changes
   with your network).
6. Restart `iris_ai` and check `/camera/status` reports `ONLINE`.
7. Position the phone at the classroom entrance (attendance) or the
   gate (entry verification), with good, even, direct lighting — see
   `docs/IRIS_MODEL.md` §5 for why lighting matters more on this RGB
   camera than it would on a dedicated NIR iris sensor.

### 4.5 Iris enrollment

From the Admin portal (Students → tap a student → "Enroll Iris",
camera capture via `image_picker`) once the app is running, or
directly:

```
curl -X POST http://localhost:8000/iris/enroll \
  -F "student_id=<firebase-uid>" \
  -F "image=@/path/to/eye_photo.jpg"
```

### 4.6 Flutter app

```
cd mobile
flutter create --platforms=android,ios .   # generates native folders - see docs/MOBILE_PLATFORM_SETUP.md
# then add the camera/location/notification/Maps permissions listed there
flutter pub get
flutter pub outdated                        # see what's newer than this repo's floors - update freely
flutterfire configure                       # generates lib/firebase_options.dart against your project
flutter analyze                             # first real compile-check of this codebase - fix anything it flags
flutter test                                # if you add widget/unit tests
flutter build apk --debug                   # first real build
flutter run                                 # on a real device/emulator
```

Pass your `iris_ai` service's address at run/build time (defaults to
`localhost`, which only works for an emulator on the same machine):

```
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8000
```

The Admin portal is the natural starting point once the app runs: add
courses (with camera ID + schedule), add bus stops, create
Security/Librarian/Driver accounts (each returns a one-time temporary
password to relay to them), and use the new Camera section to start
the live recognition loop instead of a manual curl call.

## 5. Normal run (after first-time setup above)

```
./run.sh                    # iris_ai + bus_eta
cd mobile && flutter run    # the app
```

`functions/` runs on Firebase's infrastructure once deployed — nothing
to start locally for it day-to-day; redeploy with
`firebase deploy --only functions` after changing `functions/main.py`.

## 6. Testing what's been verified in this build environment

```
cd iris_ai   && PYTHONPATH=. pytest tests/ -v   # 7 tests, pipeline mechanics on synthetic images
cd ../bus_eta && PYTHONPATH=. pytest tests/ -v  # 5 tests, real haversine/ETA math incl. a known real-world distance
cd .. && python scripts/generate_qr_codes.py    # regenerates + re-verifies all 5 QR codes
cd functions && pip install -r requirements.txt --break-system-packages && python -c "import main"  # Cloud Function import-verifies
```

Everything else (Firebase-dependent calls against a live project, RTSP
against the real phone, Flutter build/run, GPS, the Cloud Function
actually firing on schedule) needs to be run and tested by you against
your own project/hardware — see `docs/AUDIT_REPORT.md` "Device/Project-
Dependent Items" for the exact list.

## 7. Environment variables

See `.env.example` — every configurable value (Firebase project, RTDB
URL, camera URL/name/location, iris threshold, cooldown/dedupe windows,
bus ETA polling/threshold/speed, map API key) with comments. Never
commit a filled-in `.env`. Note: the Admin live bus map needs a
*separate* native Google Maps API key (not in `.env` — see
`docs/MOBILE_PLATFORM_SETUP.md` §4).

## 8. Troubleshooting

- **`/camera/status` says `NOT_CONFIGURED`** — `CAMERA_RTSP_URL` is
  empty in `.env`. Fill it in from the OctoStream app.
- **`/camera/status` says `OFFLINE`** — URL is set but unreachable;
  confirm phone + machine are on the same Wi-Fi and OctoStream's
  server is actually running.
- **Firebase calls raise `FirebaseNotConfiguredError`** —
  `GOOGLE_APPLICATION_CREDENTIALS` isn't set or the file doesn't exist.
- **`/admin/accounts` or `/stream/start` returns 401/403** — these now
  require a real Firebase ID token for an active Admin account (fixed
  after audit); pass `Authorization: Bearer <token>`, or use the Admin
  portal UI which does this for you.
- **`flutter pub get` fails on Firebase packages** — run
  `flutterfire configure` first so `firebase_options.dart` exists.
- **Recognition rejects a real enrolled student** — see
  `docs/IRIS_MODEL.md` §5–6; recalibrate `IRIS_MATCH_THRESHOLD` against
  a few real genuine/impostor comparisons first.
- **`firebase deploy` fails with "no project active"** — run
  `firebase use --add` first (writes `.firebaserc` — see
  `.firebaserc.example` for the shape).
- **Admin's live map shows a grey/blank tile area** — the native Google
  Maps API key isn't configured yet; see `docs/MOBILE_PLATFORM_SETUP.md` §4.

## 9. Security considerations

- Biometric templates (`irisProfiles`) and registration-number
  reservations (`registrationNumbers`) are unreadable by every client
  role, including Admin — only the trusted Admin-SDK-backed `iris_ai`
  service touches them.
- Unknown-person images are **not public** (fixed after audit — see
  `docs/AUDIT_REPORT.md` "Security Issues" #1): only a private Storage
  path is stored; the app resolves a viewing URL live via
  `getDownloadURL()`, itself gated by `storage.rules` to Admin/Security.
- Gate entries and the live bus map are never exposed to students,
  enforced independently in the Flutter router and Firestore/RTDB rules.
- Registration numbers are uniqueness-enforced via a race-safe Firestore
  transaction, not just client-side validation (fixed after audit).
- `driverLocation` RTDB writes are field-whitelisted; unexpected keys
  are rejected (fixed after audit).
- No online payment of any kind exists anywhere in this codebase (lost
  card / overdue fines are informational only, per spec).
- CORS on `iris_ai` is wide open (`allow_origins=["*"]`) — fine for
  local dev, tighten before any real deployment.

## 10. Known limitations

See `docs/LIMITATIONS.md` and `docs/AUDIT_REPORT.md` for the full,
itemized list — most fundamentally: this environment has no Flutter
SDK and no network path to `pub.dev`/`dl.google.com`/
`storage.googleapis.com`, so **the Flutter/Dart code has never been
compiled**. A static consistency sweep (every import resolves, every
referenced class exists, every package is declared, brace/paren
balance across all 50 files) was run instead and caught two real bugs
before delivery (a Kotlin-style `.let()` call that isn't valid Dart,
and a missing relative-import path) — but it cannot catch type errors
or Flutter API misuse. Run `flutter analyze` yourself as the first
real check.

## 11. Next steps

1. `flutter analyze` / `flutter pub get` / `flutter build apk --debug`
   — first real compile check; fix whatever it flags.
2. Deploy Firebase rules + the Cloud Function, run the seed script,
   generate `firebase_options.dart`.
3. Configure the native Google Maps API key.
4. Iris-enroll the 10 real students and calibrate
   `IRIS_MATCH_THRESHOLD` (`docs/IRIS_MODEL.md` §6).
5. Connect the real iPhone RTSP stream; test attendance/gate capture
   via the Admin portal's new Camera controls.
6. Test the Driver portal's GPS, the bus ETA job, and the overdue-book
   Cloud Function against real data and a real schedule.
