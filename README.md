# SecureCampus — Smart Campus Security & Management System

A Final Year Project: a Flutter app with five role-based portals (Admin,
Student, Security, Librarian, Driver), a Firebase backend, a small Python
service for account management, a Python bus-ETA service, and a scheduled
job for overdue-library notifications.

**This branch (`main`) is Phase 1.** Phase 2 (iris recognition for class
attendance and gate entry, with the camera, Admin camera control, gate and
security alerts, and student attendance) is on the **`phase-2`** branch and is
not included here. In the app, Phase 2 items appear only as locked "Under
development" menu entries and greyed cards, with no data and no code behind
them.

**Live demo (web version):** https://securecampus-seven.vercel.app

**Read `docs/LIMITATIONS.md` first.** It states plainly what has been built and
tested vs. what still needs a real device or a real trip to prove. This
project follows a strict no-fake-data policy (no mock AI, no fake GPS, no
hardcoded stats).

## What Phase 1 contains

| Portal | What it does |
|---|---|
| Admin | Creates and manages students, courses, books and staff accounts. Builds the bus route on a map: chooses each stop and the campus by tapping the map (or using the phone's location), edits, reorders or deletes stops, sees the route drawn along the real roads. Watches the bus live and assigns students to stops. |
| Student | Own courses, library loans, found-card report, bus assignment and alerts. Never sees the live bus map. |
| Librarian | Issues and returns books by QR; books and students can also be found by typing part of the title, code or name. |
| Security | Reads the found-card reports (read only). |
| Driver | Starts and ends a trip; the phone sends its GPS every 10 s (foreground service, so it continues with the screen off). The server ends the trip if the phone goes offline. |

Server-side jobs: `bus_eta` sends one alert per student per trip about
10 minutes before their own stop (also at once if the trip starts when the stop
is already inside 10 minutes); `overdue_checker` sends overdue and due-soon
notices.

**Not built yet:** the afternoon trip *from* the campus (the campus is shown as
its first stop, but there is no separate trip or alert logic for that
direction), and everything in Phase 2.

## Setup after cloning (secrets are not in git)

These files are git-ignored and must be created locally. Ask the project owner or create your own:

| File | How to get it |
|---|---|
| `.env` | Copy `.env.example`, fill in Firebase, camera, Supabase values |
| `secrets/serviceAccountKey.json` | Firebase console → Project settings → Service accounts → Generate new private key |
| `mobile/android/app/google-services.json` | Firebase console → Project settings → your Android app → download |
| `CREDENTIALS.md` | Not needed; only a private note of seeded account passwords |

Then follow section 4 below. Never commit these files.

## 1. Version requirements (current stable, verified Sept 2026)

See `docs/VERSION_AUDIT.md` for the full methodology and sourcing —
summary:

| Component | Target | How this was verified |
|---|---|---|
| Flutter | 3.47.x (stable channel) | Built and tested with Flutter 3.47.7 |
| Dart | 3.13.x (ships with Flutter 3.47) | Dart 3.13.5 |
| Firebase Flutter plugins | Floors from BoM 4.11.0 (2026-03-23), `^` constraints so `flutter pub get` resolves newer | firebase.google.com/support/release-notes/flutter (official, dated) |
| Android | Native project is in `mobile/android` (generated and built) | Run `flutter doctor` for the toolchain the project needs |
| Python (iris_ai / bus_eta / overdue_checker) | 3.12+ | **Actually installed and tested** — this repo's Python code was verified end-to-end on Python 3.12.3 |
| FastAPI / OpenCV / NumPy / firebase-admin / etc. | Latest PyPI as of Sept 2026 | **Actually queried live from PyPI and installed** — not guessed (see `docs/VERSION_AUDIT.md`) |

Run `flutter --version`, `dart --version`, and `python --version`
yourself once you have the toolchain installed — if any report older
than the floors above, upgrade before proceeding.

## 2. Project overview

Admin creates students, courses, books and staff accounts, and builds the bus
route: the stops and the campus are chosen on a map (the campus is the last
stop of the morning route). Students see only their own data (courses,
library, bus assignment, alerts — never the live bus map); Security sees the
found-card reports (read only); the Librarian issues/returns books via QR; the
one Driver shares live GPS while a trip is active. Overdue-book notifications
and the bus 10-minute alert run as real server-side jobs, not client-side
checks.

## 3. Architecture

See `docs/ARCHITECTURE.md` for the full data-flow diagram. Four
backend pieces, three languages by design:
- **`iris_ai/`** (Python/FastAPI) — in Phase 1 this is the account service
  (admin account creation). The camera and iris recognition code is on the
  `phase-2` branch; the folder keeps its name so scripts and Docker still work.
- **`bus_eta/`** (Python) — continuous GPS-to-ETA polling loop; sends the
  one 10-minute bus alert per student per trip.
- **`overdue_checker/`** (Python) — the periodic overdue-book and due-soon
  check. It is a plain Python loop (not a Firebase Cloud Function, which
  needs the paid Blaze plan), so the whole backend stays free-tier.
- **Flutter app** (`mobile/`) — talks to Firestore/RTDB/Storage
  directly for everything permitted by security rules, and to
  `iris_ai`'s REST API only for the thing a client fundamentally
  can't do itself: creating Firebase Auth accounts.

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
firebase deploy --only firestore:rules,firestore:indexes,database
```

`firebase.json` (repo root) already wires the rule files.

### 4.2 Python services (`iris_ai`, `bus_eta`)

```
./setup.sh      # or setup.bat on Windows — creates both venvs, generates QR codes
# fill in .env (copy from .env.example) and put your service account JSON
# at ./secrets/serviceAccountKey.json
./run.sh        # or run.bat — starts bus_eta in the background, iris_ai in the foreground
```

Or via Docker: `docker compose up --build` (starts all three services).

Verify `iris_ai` is up: `curl http://localhost:8000/health`.

### 4.3 Seed the initial dataset

```
python scripts/seed_firebase.py
```

Creates the 10 students, 5 books, 1 bus, 1 driver, courses, and stops
as real, Admin-editable Firestore/Auth records (spec §47) — reuses the
same account-creation path (`iris_ai/app/firebase_client.py::create_account`)
the Admin portal uses, including the race-safe registration-number
uniqueness check.

### 4.4 Iris and camera (Phase 2)

The RTSP camera setup and iris enrollment are Phase 2 and are on the
`phase-2` branch, not in this branch.

### 4.6 Flutter app

The native folders are already in the repo (`mobile/android`, `mobile/web`), so
there is no `flutter create` step.

```
cd mobile
flutter pub get
flutterfire configure     # only if lib/firebase_options.dart is missing for your project
flutter analyze
flutter test              # 211 tests
flutter run               # on a connected phone or emulator
```

Pass your account service's address at run/build time (defaults to
`localhost`, which only works for an emulator on the same machine):

```
flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8000
```

The Admin portal is the natural starting point once the app runs: add
courses (with a weekly schedule), then **Transport → Stops**: add the stops and
the campus by choosing them on the map, and create the Security, Librarian and
Driver accounts (each returns a one-time temporary password to relay to them).

## 5. Normal run (after first-time setup above)

```
./run.sh                    # iris_ai + bus_eta
# the app - from the project root (Windows; note the leading .\):
.\run_app.bat                  # flutter run on the connected phone
.\install_app.bat              # build + install + launch, no hot-reload session
# or: cd mobile  and then  flutter run
# Do NOT run plain `flutter run` in the project root: the Flutter app is in
# mobile/, and from the root Flutter walks up to an unrelated project in your
# user folder and builds that one instead.
```

### 5.1 Updating the live web version

Vercel cannot build Flutter, so the web version is built here and uploaded:

```
vercel whoami          # must show maryamfatima454
.\deploy_web.bat        # builds from the current code and deploys to Vercel
```

Then press Ctrl+F5 on the site (the browser caches the old app). Details:
`docs/DEPLOY_WEB.md`.

## 6. Testing

```
cd mobile       && flutter test                          # 211 tests: screens, route/stop logic, road route, driver, library
cd iris_ai      && PYTHONPATH=. pytest tests/ -v         # 7 tests: account endpoints and password rules
cd bus_eta      && PYTHONPATH=. pytest tests/ -v         # 39 tests: ETA math, the single 10-minute alert, one alert per student per trip, own-stop only
cd overdue_checker && PYTHONPATH=. pytest tests/ -v      # 10 tests: overdue and due-soon rules
firebase emulators:exec --only firestore --project demo-securecampus "npm --prefix rules-tests test"   # 25 security-rule tests (run from firebase/)
python scripts/check_live_rules.py                       # read-only probe of the live project's rules
python scripts/generate_qr_codes.py                      # regenerates + re-verifies all 5 QR codes
```

Not covered by automatic tests: the driver's phone behaviour on a real device
(foreground service, losing the connection) and a real bus trip. These need
the phone and the road — see `docs/LIMITATIONS.md`.

### 6.1 Demonstrating the 10-minute bus alert (assessment)

Each student gets **one** alert per trip, about 10 minutes before the bus
reaches **their own stop** (`bus_eta/app/service.py`). The ETA is the **real
road distance** from the bus to that stop (free OpenStreetMap routing, OSRM, no
key) divided by `AVG_BUS_SPEED_KMH` (25 km/h). It does not know about traffic.
If the routing server cannot be reached, it falls back to the straight-line
distance, and the service log says which was used (`osrm_road_distance` or
`haversine_fallback`). `ROUTING_PROVIDER=straight` turns routing off. A
`MAP_API_KEY` (Google Distance Matrix, paid) takes priority and adds live traffic.

**How the demo works.** The driver app, the Firebase writes, the `bus_eta`
service, the ETA calculation and the student notification are all real. Only
the GPS input is overridden: the browser's DevTools sends a test position
instead of a real GPS fix. No fake data is written to the database. On a phone
the same screen sends the real GPS. Say this plainly to the assessors.

**Before you start**
- Firestore rules published from `firebase/firestore.rules` (the campus,
  stops and Security pages need them).
- The campus and the stops are saved (Admin, Transport, Stops), and at least one
  student is assigned to each stop you will test (Admin, Transport, Buses).
- A driver account assigned to `BUS-001`, and a student login for a student
  at the stop you will test.
- `bus_eta` running. `GOOGLE_APPLICATION_CREDENTIALS` in `.env` is relative to
  the project root, so when starting from `bus_eta/` give the full path:

```
cd bus_eta
.venv\Scripts\activate
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\full\path\to\secrets\serviceAccountKey.json"   # PowerShell
python -m app.main
```

**Steps**
1. Open three windows side by side: the driver (Chrome), the student (another
   browser profile, on the Bus page), and the `bus_eta` terminal.
2. In the driver's Chrome press F12 → the three-dot menu → More tools →
   **Sensors** → Location → Other, and enter a test position (table below).
3. Sign in as the driver and press **Start Trip**. Allow location if asked.
4. Within about 30 seconds (the service polls every 20 s) the log shows
   `final alert to student ... for stop <name>`. The student's Bus page changes
   to "About N min from your stop - head to your pickup point now.", and the
   Alerts page shows a "Bus Arriving Soon" notification.
5. Students at other stops get nothing, because their stops are more than
   10 minutes away.

**Test positions** (on the GT Road, 3.5 km of road before the stop, so the
ETA is about 8.4 min and inside the 10-minute window)

| Stop | Latitude | Longitude | Expected |
|---|---|---|---|
| Hassan Abdal | 33.796714 | 72.714719 | ETA about 8.4 min, alert to the Hassan Abdal students only (Wah Cantt is 12.6 min away) |
| Attock City Junction | 33.771699 | 72.378932 | ETA about 8.4 min, alert to the Attock students only |

Use a position **on the road**: the ETA follows the road, so a point that is
close on the map but needs a long detour is not "10 minutes away". To make a
test point for another stop, take a point on the same road about 3.5 km of
road before the stop (a point from the OpenStreetMap route works). A stop
within 10 minutes of that point also alerts, which is correct.

**Repeat the demo.** The alert fires once per trip. Press **End Trip**, then
**Start Trip** again (a new trip). When finished, press **End Trip** and set the
DevTools Location back to "No override".

**Optional: a real walk.** At 25 km/h a walker is "10 minutes away" only about
4 km (of road) from the stop. For a walking demo set `AVG_BUS_SPEED_KMH=5` in
`.env` (about 0.8 km) and restart `bus_eta`, say that you did, and set it back after.

**Backup.** Record the demo once beforehand and keep a screenshot of the log
line. The unit tests also prove the rule (`cd bus_eta && pytest tests/`).

**Limits to state honestly.** The ETA uses the real road distance but a fixed
assumed speed, so it ignores traffic and stops on the way (Google routing with
`MAP_API_KEY` adds traffic), and it does not know which stops the bus has already
passed. The public OSRM server is meant for light use. It has not been tried on
a real bus trip.

## 7. Environment variables

See `.env.example` — every configurable value (Firebase project, RTDB
URL, bus ETA polling/threshold/speed, map API key) with comments. Never
commit a filled-in `.env`. The maps in the app (live bus map, route map, map
picker) use OpenStreetMap tiles and OSRM road routing, so they need no map key.

## 8. Troubleshooting

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
- **Route map shows straight lines** — the free OSRM road service could not be
  reached (no internet or busy); the note under the map says so. Try again later.
- **The live site shows the old app after a deploy** — press Ctrl+F5 (browser
  cache), and check that `vercel whoami` said maryamfatima454 before deploying.

## 9. Security considerations

- Registration-number reservations (`registrationNumbers`) are unreadable by
  every client role, including Admin — only the trusted Admin-SDK-backed
  backend service touches them.
- The live bus map is never exposed to students, enforced independently in
  the Flutter router and the Realtime Database rules.
- The campus location (`config/transport`) can be read by any signed-in user
  and written only by the Admin; checked in the rules tests and against the
  live project.
- Registration numbers are uniqueness-enforced via a race-safe Firestore
  transaction, not just client-side validation (fixed after audit).
- `driverLocation` RTDB writes are field-whitelisted; unexpected keys
  are rejected (fixed after audit).
- No online payment of any kind exists anywhere in this codebase (lost
  card / overdue fines are informational only, per spec).
- CORS on `iris_ai` is wide open (`allow_origins=["*"]`) — fine for
  local dev, tighten before any real deployment.

## 10. Known limitations

See `docs/LIMITATIONS.md` for the full, itemized list. The main ones:

- The Driver GPS, the bus ETA job and the road-distance alert are tested with
  unit tests and a simulated position, **not yet on a real bus trip**.
- ETA = road distance / a fixed 25 km/h: no traffic, and it does not know which
  stops were already passed. The public OSRM server is meant for light use.
- Only the morning direction (towards the campus) is built; there is no
  separate afternoon trip or alert from the campus.
- The Firebase rules must be published to the live project whenever
  `firebase/firestore.rules` changes.
- The web demo needs the Python services running on a machine that is on for
  account creation and live alerts.

## 11. Next steps

1. Try the Driver portal and the bus alert on a real bus trip and a real phone.
2. Afternoon direction: a trip that starts at the campus, with its own alerts.
3. Phase 2 (branch `phase-2`): iris enrollment, camera, attendance and gate
   entry, once the camera hardware is available.
