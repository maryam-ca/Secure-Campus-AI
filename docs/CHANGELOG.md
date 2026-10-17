# SecureCampus — Change Log

Every change to this project gets an entry here, **newest first**. This is the
file to open when someone asks "what did you do and when?".

## How to add an entry (30 seconds)

Copy the template, fill it in, paste it directly under the line `<!-- NEW ENTRIES GO BELOW THIS LINE -->`.

```
### YYYY-MM-DD — short title
- **Type:** feature | fix | refactor | docs | config | test | infra
- **Areas:** iris_ai / bus_eta / overdue_checker / mobile / firebase / scripts / docs
- **What changed:** one or two lines
- **Files:** path/one, path/two
- **Issue:** I-xx (if it closes or touches one — also update ISSUES.md)
- **Verified by:** test run / flutter analyze / tried on device / not verified
- **Notes:** anything surprising, follow-ups
```

Rules: record what you **verified**, not what you hope works. If you change
behaviour, update the matching doc too. If you fix an issue, set its row in
[ISSUES.md](ISSUES.md) to `Fixed` with the date.

Related: [PROJECT_STATUS.md](PROJECT_STATUS.md) (baseline analysis) · [ISSUES.md](ISSUES.md) (open problems).

---

<!-- NEW ENTRIES GO BELOW THIS LINE -->

### 2026-10-18 — Admin Library: removed the duplicate Catalog / Reports tabs
- **Type:** fix
- **Areas:** mobile
- **What changed:** Library > Catalog and Library > Reports are separate pages with Catalog / Reports chips in the header bar, but each page also drew its own Catalog / Reports tab bar, so the choice appeared twice. The page's own tab bar is removed; the header chips switch pages. The "new reports" count badge that sat on that tab is gone (the dashboard's "new student reports" row still shows it).
- **Files:** mobile/lib/features/admin/admin_library_screen.dart, mobile/test/admin_library_test.dart
- **Verified by:** flutter analyze, flutter test (174 passed).

### 2026-10-18 — Removed the pre-filled "Demo accounts" from the login page
- **Type:** refactor
- **Areas:** mobile, scripts, docs
- **What changed:** The login page no longer has a "Demo accounts" button or any pre-filled credentials. Removed `config/demo_accounts.dart`, `features/auth/demo_accounts_sheet.dart`, `test/demo_accounts_test.dart`, `scripts/make_demo_defines.py`, and the demo-accounts step in `run_app.bat`. The forced "change your temporary password at first login" rule now applies to every build (before, it was switched off in debug builds with demo accounts).
- **Files:** mobile/lib/features/auth/login_screen.dart, core/router/password_gate.dart, run_app.bat, docs/DEPLOY_WEB.md, README.md
- **Verified by:** see the test run for this change.
- **Notes:** An account created by Admin or the seed script with a temporary password must now be given a new password at its first sign-in. A local `mobile/demo_accounts.json` (git-ignored) is no longer read by anything and can be deleted. Builds made earlier (the APK, the Vercel site) still contain the old login page until rebuilt.

### 2026-10-18 — Bus ETA now uses real road distance (free OpenStreetMap routing)
- **Type:** feature
- **Areas:** bus_eta, docs
- **What changed:** The ETA to a student's stop is now the real road distance from OSRM (OpenStreetMap routing, no key) divided by the assumed bus speed, instead of the straight-line distance. Order: Google (if `MAP_API_KEY` is set) → OSRM → straight line. If OSRM fails it falls back to straight line and pauses OSRM for 60 s. One routing call per stop per cycle. New settings `ROUTING_PROVIDER` (`osrm` | `straight`) and `OSRM_BASE_URL`. README demo positions changed to points on the GT Road.
- **Files:** bus_eta/app/geo.py, config.py, service.py, tests/test_geo.py, tests/test_service.py, .env.example, README.md
- **Verified by:** bus_eta pytest (38 passed); a live call to the public OSRM server for the demo positions (8.4 min to the target stop, road distance 3.5 km).
- **Notes:** No traffic information; the public OSRM server is for light use. Not tried on a real trip. The `bus_eta` service must be restarted.

### 2026-10-18 — Phase 2 code moved to branch `phase-2`; `main` is Phase 1 only
- **Type:** refactor
- **Areas:** mobile, iris_ai, bus_eta, firebase, docs
- **What changed:** The full code was saved on the `phase-2` branch (commit df14b9f). On `main` the iris and camera code, Admin camera control and Gate & Security screens, student attendance, Security gate screens, iris data on the student pages, per-course attendance, course camera ID, and the attendance/gate/iris/alert Firestore rules were removed. Phase 2 remains only as locked "Under development" menu entries and greyed cards. `iris_ai/` is now just the account service. `docs/IRIS_MODEL.md` and the camera/iris sections of the README were removed. bus_eta now resolves a relative `GOOGLE_APPLICATION_CREDENTIALS` against the repo root. See `docs/PHASE_SPLIT.md`.
- **Files:** see `git show --stat` for the commit. Notable: mobile/lib (security, student, admin screens, models, providers, repositories), iris_ai/app, firebase/firestore.rules and its tests, README.md, .env.example, docs/PHASE_SPLIT.md.
- **Verified by:** flutter analyze (no errors or warnings), flutter test (180 passed), Firestore rules tests in the emulator (20 passed), iris_ai pytest (7 passed), bus_eta pytest (31 passed).
- **Notes:** Firestore rules need publishing for the new rule set. Other docs (ARCHITECTURE, PROJECT_STATUS, etc.) still describe Phase 2 in places; they were not rewritten.

### 2026-10-17 — Bus: seat count removed (not part of the FYP); campus location only
- **Type:** refactor
- **Areas:** mobile
- **What changed:** Removed the seating-capacity feature: the "Set seats" tile and dialog, the "bus is full" block when assigning a student, `BusInfo` / `busInfoProvider` / `setBusCapacity` / `watchBus`, and the seat arithmetic. Admin > Transport > Buses now has a "Campus Location" card only. The campus dialog and the assign dialog show a plain message when a save is refused. `core/utils/bus_capacity.dart` became `bus_route.dart` (route order only).
- **Files:** mobile/lib/features/admin/admin_bus_screen.dart, admin_nav.dart, admin_stops_screen.dart, repositories/admin_repository.dart, providers/admin_providers.dart, models/transport_models.dart, core/utils/bus_route.dart, test/admin_bus_test.dart, test/bus_route_test.dart
- **Verified by:** flutter analyze (no errors or warnings), flutter test (178 passed). Not tried against live Firebase.
- **Notes:** Any `capacity` value already stored in Firestore `bus/{busId}` is simply ignored. The `bus` rules stay because the driver lookup still reads that collection. Supersedes the 2026-10-15 seat-count entry.

### 2026-10-17 — Bus: back to ONE alert, 10 minutes before (20-minute alert removed)
- **Type:** fix
- **Areas:** bus_eta, mobile
- **What changed:** Students now get a single "Bus Arriving Soon" alert when the bus is about 10 minutes from their stop, once per trip, as in the approved proposal. The 20-minute "Get Ready" alert and its setting `ALERT_FIRST_MINUTES` are removed. The student app no longer shows a 20-minute "get ready" status; the driver and admin dialogs say "10-minute alert". Supersedes the 2026-10-13 two-reminder entry.
- **Files:** bus_eta/app/config.py, service.py, firebase_client.py, tests/test_service.py; mobile/lib/models/dashboard_models.dart, features/student/widgets/bus_assignment_section.dart, student_home_section.dart, features/driver/driver_dashboard_screen.dart, features/admin/admin_bus_screen.dart, test/student_home_test.dart
- **Verified by:** unit tests only (see the test runs for this change). Not verified with a real driver GPS trip or push delivery.
- **Notes:** Old `BUS_20_MIN` notifications already stored keep their bus icon in the Alerts list. The `bus_eta` service must be restarted to stop sending the 20-minute alert.

### 2026-10-17 — Security: live alert badges; Security can no longer resolve alerts
- **Type:** fix
- **Areas:** mobile, firebase
- **What changed:** The Security sidebar now shows live counts (new unknown-person alerts, open found-card reports), so an alert is visible in the app even if a phone push never arrives. The Resolve / Mark as new button is removed from Security's alert cards (status is shown only). firestore.rules: only Admin may update a securityAlerts status.
- **Files:** mobile/lib/features/security/security_dashboard_screen.dart, firebase/firestore.rules, mobile/test/security_portal_test.dart
- **Verified by:** flutter analyze, flutter test, iris_ai tests/test_alert_upload.py (alert creation calls notify_role for security). Not verified end to end: no camera, so no real unknown-person alert has been generated here. firestore.rules not deployed.
- **Notes:** Admin's alert-resolving screen (Gate & Security) is locked under Phase 2 in the sidebar, so alerts cannot be resolved in the app until it is unlocked.

### 2026-10-17 — Found-card reports: required, checked against student records, Admin-only resolve, Security view
- **Type:** feature
- **Areas:** mobile, firebase
- **What changed:** The finder form now requires the name and registration number as printed on the card. Admin sees each report checked against the real student record (verified / name mismatch / no such student) and can notify the student only when both match. Only Admin can notify the student and resolve a report. Security has a read-only Lost Cards page: open reports, and resolved ones marked Resolved for 24 hours, then they disappear. Admin dashboard shows a "found-card reports to review" row. Student Courses page added; student Attendance moved under locked Phase 2.
- **Files:** firebase/firestore.rules, mobile/lib/core/utils/lost_card_match.dart, models/admin_models.dart, repositories/admin_repository.dart, providers/admin_providers.dart, features/common/found_card_report_screen.dart, features/admin/admin_lost_cards_screen.dart, features/admin/admin_dashboard_screen.dart, features/security/security_dashboard_screen.dart, test/lost_card_test.dart
- **Verified by:** flutter analyze (no errors or warnings), flutter test. firestore.rules changed but NOT deployed or tested against a real project.
- **Notes:** The finder is anonymous and cannot read student records, so the check is done on the Admin side, not at submit time. Deploy with `firebase deploy --only firestore:rules` or Security cannot read the reports.

### 2026-10-17 — Transport split into Buses and Stops pages
- **Type:** refactor
- **Areas:** mobile
- **What changed:** Admin > Transport now has Buses (live map, status, seats, campus, student assignments) and Stops (route shown in visit order with arrows between stops, reorder, add). Accordion sidebar: opening one module closes the other. Security portal: Book Reports removed; Recent Entries and Unknown-Person Alerts moved under a locked Phase 2 group.
- **Files:** mobile/lib/features/admin/admin_stops_screen.dart, admin_bus_screen.dart, admin_nav.dart, core/widgets/portal_sidebar.dart, features/security/security_dashboard_screen.dart, tests
- **Verified by:** flutter analyze (no errors or warnings), flutter test (172 passed). Not yet run on a device.

### 2026-10-17 — One shared layout for every role; logo returns Home; matching top bar
- **Type:** refactor
- **Areas:** mobile
- **What changed:** The Admin shell moved to shared widgets (`core/widgets/portal_shell.dart`, `portal_sidebar.dart`, `portal_nav.dart`, `portal_module_page.dart`). Student, Librarian, Security and Driver now use the same sidebar, header bar, Home button and theme; each defines only its own menu. Bottom navigation bars and the Security top tabs are replaced by sidebar pages. Tapping the logo or "SecureCampus" in the sidebar returns to Home. The top bar and the sidebar header are the same solid blue (app-wide `appBarTheme`).
- **Files:** mobile/lib/core/widgets/portal_*.dart, core/theme/app_theme.dart, features/admin/admin_nav.dart, admin_home_shell.dart, student/student_dashboard_screen.dart, librarian/librarian_home_screen.dart, security/security_dashboard_screen.dart, driver/driver_dashboard_screen.dart, plus tests
- **Verified by:** flutter analyze (no errors or warnings), flutter test (168 passed). Not yet run on a device.
- **Notes:** On a phone, the sidebar opens from the menu button. All role features are unchanged; only the navigation frame changed.

### 2026-10-17 — Admin module first pages, header bar, Home button, per-role staff pages
- **Type:** feature
- **Areas:** mobile
- **What changed:** Clicking a main module in the sidebar opens its first page (cards for its sub-modules) and expands it; the arrow only expands or collapses. Every Admin page except the dashboard has a header bar (Home > Module > Page, clickable, plus sub-module chips) and a Home button in the app bar. Staff Accounts split into Security Staff, Librarians and Drivers pages. Settings listed under Phase 2 (locked).
- **Files:** mobile/lib/features/admin/admin_module_page.dart, admin_nav.dart, admin_sidebar.dart, admin_home_shell.dart, admin_accounts_screen.dart, providers/admin_navigation_provider.dart, test/admin_shell_test.dart, test/admin_sidebar_test.dart
- **Verified by:** flutter analyze (no errors or warnings), flutter test (167 passed). Not yet run on a device.

### 2026-10-17 — Admin sidebar regrouped by phase (expand/collapse modules)
- **Type:** refactor
- **Areas:** mobile
- **What changed:** Admin sidebar is now grouped main modules with expandable sub-modules (User Management, Academics, Library, Transport, Lost & Found). Camera, attendance and gate are under a greyed, non-clickable "Phase 2 - Under development" group. Every Admin page shares one title strip (breadcrumb + description). Dashboard shows Phase 1 numbers and greyed Phase 2 cards with no figures. The menu is data in `admin_nav.dart`; page ids are strings (`AdminSection`), `adminLibraryTabProvider` removed (Library > Reports is its own id).
- **Files:** mobile/lib/features/admin/admin_nav.dart, admin_sidebar.dart, admin_home_shell.dart, admin_dashboard_screen.dart, admin_library_screen.dart, providers/admin_navigation_provider.dart, core/widgets/dashboard_widgets.dart, test/admin_sidebar_test.dart, test/admin_dashboard_test.dart
- **Verified by:** flutter analyze (no errors or warnings), flutter test (162 passed). Not yet run on a device.
- **Notes:** Camera/Gate screens still exist in code, just not in the menu. Other roles untouched. To enable a Phase 2 module: give its item a `screen` in `admin_nav.dart`.

### 2026-10-15 — One logo everywhere: Admin sidebar, splash, Android launch screen and app icon
- **Problem:** the Admin sidebar and the in-app splash screen showed a plain stock shield icon, the Android launch screen was empty white, and the launcher icon was not the SecureCampus mark; the dashboard card and login used the real logo.
- **Fix:** sidebar and splash now use the real logo (`AnimatedShieldLogo`). The logo was rendered to PNG and used for: the Android native launch screen (`drawable/splash_logo.png` centred on white, both `launch_background.xml`), the Android launcher icons (all five densities) and the web icons/favicon.
- **Also fixed:** `student_home_test` used a fixed date, so it started failing once the real calendar passed it (`LibraryIssueModel.status` uses the real clock). It now uses the real current time. Not a product bug.
- **Verified by:** `flutter test` **156/156**, `flutter analyze` 0 errors, debug APK builds with the new resources.
- **Not verified:** how the launch screen and icon look on the phone (reinstall the app to see them; Android may cache the old launcher icon until reinstalled).

### 2026-10-15 — Web (Chrome) blank page: guard the push background handler (UNVERIFIED fix)
- **Symptom:** running the app in Chrome (to watch the driver as Admin on the PC) showed a blank page. Console showed all Firebase plugins initialising and then nothing; no error text.
- **Likely cause:** `FirebaseMessaging.onBackgroundMessage(...)` is registered in `main()` before `runApp()`. A browser has no Dart background isolate (it needs a JavaScript service worker), so this can fail and abort `main()`, which gives a blank page.
- **Change:** `mobile/lib/main.dart` registers it only when not on web and never lets a failure stop the app. Android/iOS behaviour is unchanged.
- **Verified:** `flutter analyze` clean; the web build compiles.
- **Not verified:** that Chrome now shows the login page (headless screenshots here cannot render Flutter's canvas, so I could not see it). If it is still blank, open Chrome DevTools (F12) > Console and send the first red error.
- **Note:** a pasted `ERR_CONNECTION_REFUSED ... localhost:15213` console log was from a dev session I had stopped, not the original cause.

### 2026-10-15 — Driver/bus module, step 1: a driver trip that keeps working and cannot lie
- **Keeps sharing with the screen off:** on Android the trip runs as a foreground service (a "SecureCampus trip is live" notification), with a GPS fix about every 10 seconds even when the bus stands still (before: only every 15 m of movement, no background protection). Manifest gained `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`.
- **Cannot show a dead trip as live:**
  - The database server is told to mark the trip ended if the phone drops off (`onDisconnect`: app killed, phone off, no signal), and the location timestamp is now the server's clock (`ServerValue.timestamp`), so a wrong phone clock cannot fake freshness. Together with the 180 s server-side staleness check in `bus_eta` this closes the "dead phone looks live" gap.
  - If the app was closed during a trip, the next start ends the leftover trip and tells the driver.
  - Signing out ends a live trip first (new `onBeforeSignOut` in `PortalScaffold`).
  - A GPS fix that arrives after the trip ended can no longer re-mark it live.
- **Driver screen:** trip timer, "last GPS update" (Just now / 12 s ago / 3 min ago) with a red warning after 45 s without a fix, plain-language errors instead of raw exception text (GPS off, permission blocked, no internet, server refused), stop dialog now says "20- and 10-minute bus alerts". A temporary error no longer ends the trip. Status rows no longer overflow on narrow phones.
- **Bug fixed on the way:** the screen read the signed-in user once, so if it opened before the auth stream emitted it would sit on a spinner forever; it now waits for the user.
- **Files:** mobile/lib/features/driver/driver_dashboard_screen.dart, mobile/lib/repositories/driver_repository.dart, mobile/lib/core/utils/driver_status.dart, mobile/lib/core/widgets/portal_scaffold.dart, mobile/android/app/src/main/AndroidManifest.xml, mobile/test/{driver_status_test,driver_dashboard_test}.dart
- **Verified by:** `flutter test` **156/156** (13 new: freshness/timer/error wording, no-bus, leftover trip ended, GPS-off message, start arms auto-end and sends fixes, End Trip, stuck-GPS warning, friendly write error, sign-out ends trip); `flutter analyze` 0 errors; debug APK builds with the foreground-service settings.
- **Not verified (needs the real phone):** the foreground notification and background/screen-off location, `onDisconnect` actually firing when the phone loses signal, and the Realtime Database rules accepting the server-timestamp writes (RTDB rules have no emulator test yet). Test: start a trip, lock the screen for 2 minutes, watch the Admin map move; then switch the phone to airplane mode and confirm the trip shows ended.

### 2026-10-15 — Library: manual book entry accepts part of any ID format (issue and return)
- **Problem:** typing a book ID by hand only worked if the full ID was typed exactly (and the hint said `BOOK-001`, the old format). Typing a few letters/digits of the ID found nothing, unlike the student search.
- **Fix:** on the librarian Issue/Return screen, typing part of the Book ID, title or author (2+ characters, case/dashes/spaces ignored, any ID format) lists the matching books with their full ID and status (Available / Issued / Locked); the librarian taps the right one. A full code typed or scanned is matched ignoring case/dashes/spaces ("book-001" finds "BOOK-001") before falling back to an exact lookup. The return-verification "Enter the book ID" dialog has the same pick-from-list; the picked ID must still equal the loan's book, otherwise "Wrong book".
- **Safety:** a partial code never picks a book automatically, and two IDs that differ only by punctuation match nothing rather than the wrong book.
- **Files:** mobile/lib/core/utils/catalog_logic.dart (`searchBooks`, `bookForCode`), mobile/lib/features/librarian/{librarian_scan_screen,return_verify_screen}.dart, mobile/test/book_search_test.dart
- **Note:** `dart format` was run on the two screens, so their diff is larger than the real change.
- **Verified by:** `flutter test` **143/143** (8 new); `flutter analyze` 0 errors.
- **Not verified:** on the phone; the exact IDs you see in the app were not checked against Firestore (search works with any format).

### 2026-10-15 — Driver/bus module, step 2: Admin sets seats, campus and route order; a full bus blocks assignment
- **Admin > Bus now has a "Seats & Campus" card:** set the bus seat count (1-200; shows "Seats 40 · Assigned 24 · Free 16", or "seat count not set" until entered) and the campus name/latitude/longitude (stored in `config/transport`; needed for to-campus / from-campus trips).
- **Route order:** every stop is numbered and has up/down arrows; the new order is written in one batch and old gaps/duplicates are renumbered 1..n.
- **Over-capacity is blocked:** assigning a student to a full bus is refused with a plain message ("This bus is full: all N seats are already assigned...") and the dialog stays open. The check is in the repository using fresh data (not only in the screen). Moving a student who already has a seat does not need a free seat. If no seat count is set yet there is no limit.
- **Wording:** the remove-assignment dialog now says "20- and 10-minute arrival alerts".
- **Rules:** new `config/{doc}` rule (signed-in read, Admin write). **Owner must publish the updated `firebase/firestore.rules`.**
- **Files:** mobile/lib/repositories/admin_repository.dart, mobile/lib/providers/admin_providers.dart, mobile/lib/features/admin/admin_bus_screen.dart, firebase/firestore.rules, mobile/test/admin_bus_test.dart, firebase/rules-tests/firestore.rules.test.mjs
- **Verified by:** `flutter test` **135/135** (6 new screen tests: seats/campus display, seat-count save and rejection, reorder arrows and end-stop limits, full-bus message); Firestore rules **15/15**; `flutter analyze` 0 errors.
- **Not verified:** on a phone; the repository's full-bus check against real Firestore (only the screen with a fake repository and the pure logic are tested).

### 2026-10-14 — Driver/bus module, step 1a + 2a: lost-GPS protection and seat/route rules (pure logic)
- **Flaw found in my own earlier work:** `bus_eta` did not look at how old the driver's location was, so a driver phone that died or lost GPS mid-trip still looked "live" and students kept seeing a stale status.
- **Fix:** locations older than `LOCATION_STALE_SECONDS` (180 s) are ignored: no alerts, and student statuses are cleared once (`is_stale()` in `bus_eta/app/service.py`).
- **Added (not yet wired into screens):** `mobile/lib/core/utils/bus_capacity.dart` (block assigning a student when the bus is full; seat summary; stop reordering; stop order for to-campus vs from-campus trips) and `mobile/lib/models/transport_models.dart` (`BusInfo`, `CampusLocation`, `TripDirection`).
- **Verified by:** `bus_eta` pytest 32 passed; new `bus_capacity_test.dart` 14 passed.
- **Not verified:** on a phone; the screens that use the new logic come in the next steps.

### 2026-10-14 — Students module, part 4: bulk import of students from a CSV file (proposal: "Admin can upload student data")
- **Where:** Admin > Students, the upload button next to the search box opens **Import students**.
- **Flow (nothing is created until the Admin confirms):**
  1. **Choose** a CSV file (file picker) or paste its text; **Copy template** gives the header and an example row (also `docs/students_import_template.csv`).
  2. **Check:** the whole file is read first. Columns: `name, email, registration_number, program, semester, courses` (any order, common header names accepted; courses are IDs separated by `;` or `|`; empty program/semester default to BSE/1). Every problem is shown by line in plain words: empty name, invalid email, bad registration number, semester not 1-12, unknown course, a duplicate **inside the file**, or a registration number/email that **already exists** in the system. Bad rows are skipped; the Admin sees "N ready to import, M with problems".
  3. **Import:** accounts are created one by one through the same server call as "Add Student" (random temporary password, student must choose their own at first sign-in). A row the server refuses is recorded and the rest continue; if the server cannot be reached the import **stops** and the remaining rows are marked "not attempted" instead of producing a wall of errors.
  4. **Results:** created / not created with reasons, and **Copy accounts and passwords** (name, email, registration number, temporary password) so the Admin can hand them out; a warning says the passwords are shown only now.
- **Real flaw found and fixed while testing:** the first version read the existing-students list without waiting for it or keeping it loaded, so duplicates of existing students were not caught at the check step (only the server would later refuse them). It now waits for the list. Also the "Check file" button is pinned at the bottom so it cannot scroll out of view.
- **Files:** mobile/lib/core/utils/{student_csv,student_import}.dart, mobile/lib/features/admin/{admin_students_import_screen,admin_students_screen}.dart, mobile/pubspec.yaml (+ `file_picker` 13.1.0), docs/students_import_template.csv, mobile/test/{student_csv_test,student_import_test,admin_students_import_test}.dart
- **Verified by:** `flutter test` **115/115** (22 new: CSV parsing incl. quotes/CRLF/BOM; each validation rule; the import runner's refuse-and-continue vs stop-when-unreachable; the screen end to end with a fake server: empty/invalid file, review with problem lines, only valid rows sent with the right fields and no password, partial failure, unreachable server, Back); `flutter analyze` 0 errors; debug APK built with the new plugin (206 MB).
- **Not verified:** on the phone (it was disconnected, so the APK was built but not installed: run `.\install_app.bat`); the real file picker; a real import. **Importing needs the SecureCampus server reachable from the phone**: the app is built with `BACKEND_BASE_URL` pointing at `localhost`, so build with `--dart-define=BACKEND_BASE_URL=http://<PC-IP>:8000` and run `iris_ai` on the same Wi-Fi.

### 2026-10-14 — Students module: summary of what changed today
1. **Passwords:** no more registration-number passwords; random temporary password; forced first-login change; Change password in every portal; rules let a user clear only their own flag.
2. **Student Home:** one-screen summary, bus status text with 20/10-minute wording and stale detection, unread-alerts badge, returned-books history.
3. **Admin Students:** ID/name search and filters with counts, full student overview, working Reactivate.
4. **Bulk CSV import.**
- **Totals after this work:** `flutter test` 115, `iris_ai` 25, `bus_eta` 28, `overdue_checker` 10, Firestore rules 14: all passing.
- **Owner must publish the updated `firebase/firestore.rules`** (first-login flag rule) for the password flow to clear its flag.

### 2026-10-14 — Students module, part 3: Admin student list filters, full student overview, working Reactivate
- **Admin > Students list:**
  - Search now finds a student by any part of the name, program, email or **ID** (`007`, `bse-00`, `FA23BSE001`).
  - Filter chips with counts: **All (n) / Iris enrolled (n) / Not enrolled (n)**, plus a **Semester** filter (only the semesters that exist). A line shows "N of M students". The chips wrap onto two lines instead of running off the screen.
- **Bug fixed:** the student sheet offered only **Deactivate**, while its own message said "you can reactivate them later from this same screen" - there was no Reactivate button. The sheet now shows the account status (active / deactivated) and a **Reactivate** button when the account is off.
- **New: Full details** (button in the student sheet) opens a read-only overview: profile and status chips, **courses with attendance** (e.g. "6/10 - 60%", red under 75%, "no classes yet"), **library** (current books with due dates and OVERDUE, how many returned earlier) and the **bus** stop.
- **Files:** mobile/lib/core/utils/student_filter.dart, mobile/lib/features/admin/{admin_students_screen,admin_student_overview_screen}.dart, mobile/lib/providers/admin_student_providers.dart, mobile/test/{student_filter_test,admin_students_test}.dart
- **Verified by:** `flutter test` **93/93** (12 new: filter logic for text/ID/iris/semester/combined, counts; list shows chips with counts and narrows with each; search by ID part and name; semester filter; sheet shows Deactivate for an active account and **Reactivate** for a deactivated one; overview shows courses with attendance, overdue loan, returned count and bus stop); `flutter analyze` 0 errors. Writing the tests exposed two layout problems in my own first version (filter chips ran off a phone-width screen; the sheet's status line could overflow); both fixed with wrapping/shrinking layouts.
- **Not verified:** on the phone; the actual Reactivate write (it only changes `users.active`, which admin rules already allow; the Firebase login itself is not re-enabled/disabled by this button, access is blocked by the app and the rules).

### 2026-10-14 — Students module, part 2: student Home screen, bus status text, unread badge, loan history (A3.4)
- **Student dashboard** is now five tabs: **Home, Attendance, Bus, Library, Alerts**. The old blue profile header is gone; Home is the one-screen summary.
  - **Home:** white header card with the real logo, the student's name, registration number, program and semester; a **Needs attention** list (overdue books, books due within 2 days, the bus being within 20 minutes, unread alerts; otherwise "All clear"); tiles for **Attendance** (overall %, "8 of 10 classes"), **Books issued** (next due date or "N overdue"), **Unread alerts**, **Courses**; and a wide **Campus Bus** line with the stop and the live status sentence. Every item opens its tab. A test at 360 x 740 checks it needs no scrolling even with all four attention rows.
  - **Alerts tab** shows a badge with the number of unread alerts.
  - **Library tab** now also has a collapsed **Returned books (N)** history with issue and return dates.
- **Bus status text (A3.4):** students cannot read the driver's live location (by design), so the `bus_eta` service now writes a text-only status onto each student's own assignment: `tripActive`, `etaMinutes`, `statusUpdatedAt`. The Bus tab and Home show it in words: "On its way - about 35 min from your stop." / "About 15 min from your stop - get ready." / "About 8 min from your stop - head to your pickup point now." / "Your bus is arriving now." / "No trip in progress right now." A status older than 3 minutes counts as stale and shows "No trip in progress", so a stopped service never claims the bus is on its way; the banner rechecks every 30 seconds.
  - **Free-tier safe:** the status is written only when the minutes change, or at most every 2 minutes to stay fresh (20,000 writes/day limit); statuses are cleared once when a trip ends; the idle loop makes no extra reads. After both reminders were sent the status still keeps updating.
- **Shared look:** header card, attention list, stat tile and wide status tile moved into `core/widgets/dashboard_widgets.dart` and are used by both the Admin and Student homes (no duplicated code).
- **Files:** bus_eta/app/{service,firebase_client}.py, bus_eta/tests/test_service.py, mobile/lib/core/widgets/dashboard_widgets.dart, mobile/lib/features/student/{student_dashboard_screen}.dart, features/student/widgets/{student_home_section,bus_assignment_section,library_section}.dart, features/admin/admin_dashboard_screen.dart, models/dashboard_models.dart, providers/student_providers.dart, mobile/test/student_home_test.dart
- **Verified by:** `bus_eta` pytest **28/28** (9 new: when to write a status, not rewritten when unchanged and fresh, keeps updating after both reminders, cleared once when the trip ends); `flutter test` **81/81** (15 new for the student side); `flutter analyze` 0 errors. A test run also corrected my own wrong expectation (12 min away is "get ready") and showed an always-present hidden Badge widget; both were test mistakes, not app bugs.
- **Not verified:** on the phone, and the status end to end with a real trip (needs the driver app sharing GPS and `bus_eta` running). The bus thresholds (20/10) are repeated in the app (`BusAssignmentModel`) and `bus_eta` settings; change both together.

### 2026-10-14 — Students module, part 1: no guessable passwords; forced first-login password change; Change password
- **Problem:** when an admin created a student the password was their **registration number** (the backend default, and the Admin app also sent it explicitly). The backend flagged `mustResetPassword`, but the app never read it, and nobody could change their own password.
- **Backend:** `create_account` now always generates a random temporary password (no registration-number default). Admin dialog text now says "Temporary password" and that the student will choose their own at first login; the app no longer sends a password.
- **App:**
  - **First login:** an account flagged `mustResetPassword` is sent to a "Choose your password" screen from anywhere and cannot leave it (no back; Sign out only). Rules: at least 8 characters with a letter and a number, different from the temporary one, and not the registration number or the email name.
  - **Voluntary:** a "Change password" button in the app bar of every portal (Student, Librarian, Security, Driver) and in the Admin drawer; asks for the current password first.
  - Debug builds that carry the demo-accounts list do **not** force the change (so the one-tap demo logins keep working); release builds always do.
  - After a successful change the flag is cleared in Firestore; if that is refused, the screen still will not return this session.
- **Firestore rules:** a user may now clear **only their own** `mustResetPassword` flag, and only to `false`; role/active/anyone else's account remain admin-only.
- **Files:** iris_ai/app/firebase_client.py, iris_ai/tests/test_account_password.py, firebase/firestore.rules, firebase/rules-tests/firestore.rules.test.mjs, mobile/lib/{core/utils/password_policy,core/router/{password_gate,role_paths,app_router},core/widgets/portal_scaffold,features/auth/change_password_screen,features/admin/{admin_home_shell,admin_students_screen},services/auth_service,repositories/user_repository,providers/auth_provider}.dart, mobile/test/password_test.dart
- **Verified by:** `iris_ai` pytest 25/25 (4 new: random password not the registration number, different each time, flagged to change, explicit password still honoured/too-short refused); `flutter test` 66/66 (13 new: password rules, the redirect rule, the screen in first-login and voluntary modes, weak password never sent, good password sent with the right values, wrong-password message); rules emulator **14/14** (3 new, incl. a user cannot change role/active/another user, cannot set the flag to true). `flutter analyze` 0 errors. A test caught a real bug (the screen read the user only once, before it loaded) and it was fixed.
- **Needs from the project owner:** **publish the updated `firebase/firestore.rules`** (the new users rule). Until then the flag cannot be cleared after a change (the session guard stops looping; the screen returns at the next sign-in).
- **Not verified on the phone / real Firebase:** the real password change (needs a non-demo build and an account with the flag set).
- **Note:** existing seeded accounts still carry `mustResetPassword = true`, so a release build will ask each of them to choose a password at first sign-in.

### 2026-10-14 — Admin dashboard simplified to one screen; plain header card with the real app logo
- **Feedback:** the dashboard was too crowded and scrolled; remove duplicated or unnecessary data; remove the blue header card and show the proper app logo.
- **Removed (duplicates / clutter):** the Quick actions row (repeated the side menu), the section headings (Campus today / Library / Transport), the separate Unknown Alerts, Issued Books, Overdue Books and Locked Books cards (the same numbers already appear in "Needs attention", and issued/locked are now a single note on the Library card).
- **Now:** a header card (white, no blue) with the **real SecureCampus shield logo** (the same mark as the login screen, drawn still), the "SecureCampus" name, the greeting with the admin's name and today's date; a **Needs attention** list only when something needs action (open alerts, overdue books, new student reports; otherwise a green All clear); five cards: Total Students, Attendance (today), Gate Entries (today), Library Books (with "N issued · N locked"), and Bus Status. Everything is tappable. Labels shortened so none are cut off ("Today's Attenda..." is now "Attendance" with "today" underneath).
- **Fits one screen:** a test at phone size (360 x 740) checks the page needs no scrolling even in the worst case (three attention rows) and ends above the bottom of the real page area. On the SM-A305F the earlier version already left about a third of the screen empty; the cards were made roomier to use the space.
- **Logo widget:** `AnimatedShieldLogo` gained `animate` (default true, so login and library screens are unchanged); the dashboard passes `animate: false` so a data screen has no moving logo.
- **Files:** mobile/lib/features/admin/admin_dashboard_screen.dart, mobile/lib/core/widgets/animated_shield_logo.dart, mobile/test/admin_dashboard_test.dart
- **Verified by:** `flutter test` 53/53 (includes: the shield logo and "SecureCampus" present; the removed items absent; no scrolling needed; all cards and attention rows navigate); `flutter analyze` 0 errors. A phone screenshot of the previous simplified layout showed it fits with space to spare and no overflow.
- **Not verified on the phone:** the final version (white header with logo, shortened labels, roomier cards): the phone was locked after install.

### 2026-10-14 — Admin dashboard redesigned (professional look) + Library page opens on Reports from the dashboard
- **Type:** UI redesign
- **Areas:** mobile (admin)
- **Problems found on the phone (screenshot of the old dashboard):** a red "BOTTOM OVERFLOWED BY 15 PIXELS" error on the Unknown Alerts card; the bus status cut off as "Idle (last known ..."; a lone card in the last row and an empty lower half; plain white boxes with no hierarchy and nothing to say what needs action.
- **New dashboard:**
  - **Greeting banner** (navy to blue gradient): time-of-day greeting, the signed-in admin's name, today's date.
  - **Needs attention** panel: open unknown-person alerts, overdue books, new student reports; each is tappable (alerts go to Gate & Security, overdue to Library, reports to **Library > Reports**). When there is nothing to do it shows a green "All clear".
  - **Quick actions:** Students, Library, Security, Camera.
  - **Grouped stat cards:** Campus today (attendance, gate entries, total students, unknown alerts), Library (books, issued, **overdue, locked** - new), Transport (bus status shown in full). Cards are fixed height with a tinted icon, large number and label, so text cannot overflow; all are tappable.
  - A failed load now shows a plain message with Retry instead of raw error text. Optional data (library counts, reports, user name) never blocks the page if it fails to load.
- **Drawer:** branded header (logo, SecureCampus, admin name, email, "Administrator").
- **Navigation:** new `adminLibraryTabProvider` lets the dashboard open Library on its Reports tab; the Library page reads it once and resets it.
- **Files:** mobile/lib/features/admin/{admin_dashboard_screen,admin_home_shell,admin_library_screen}.dart, mobile/lib/providers/admin_navigation_provider.dart, mobile/test/admin_dashboard_test.dart
- **Verified by:**
  - `flutter test` **53/53**. The rewritten dashboard tests run at phone size (360 x 780) and cover: all labels and groups present; no overflow with a long bus status and the full status shown; Needs attention items with correct wording; All clear state; attention items and every stat card open the right section; "new student reports" opens the Reports tab; quick actions; the plain error message with Retry.
  - `flutter analyze` 0 errors.
  - **On the phone (SM-A305F, screenshot):** banner, Needs attention (picked up a real student report and the 2 open alerts), quick actions and the Campus today cards render correctly with no overflow.
- **Not verified on the phone:** the Library and Transport sections lower on the page and the new drawer header (the screen turned off before they were scrolled into view); covered by the tests above.

### 2026-10-14 — Locking confirmed working; Admin > Library gets a Reports tab
- **Rules published:** the new Firestore rules were published by the project owner. `python scripts/check_live_rules.py` now returns HTTP 200 for `issueReports` and `lockHistory` ("The new rules are PUBLISHED"). Locking and unlocking a book work on the phone (confirmed by the user).
- **Change:** the Admin dashboard's **Library** page now has two tabs, **Catalog** (the existing book list, add book, Locked filter, lock/unlock) and **Reports** (the same view the librarian sees: Issued now / Overdue / Locked / New reports summary, and the students' "I did not borrow this book" reports, which the admin can mark resolved or reopen). The Reports tab shows a badge with the number of new reports.
- **Files:** mobile/lib/features/admin/admin_library_screen.dart (existing page became the Catalog tab; new `AdminLibraryScreen` wrapper with the tabs), mobile/test/admin_library_test.dart
- **Verified by:** `flutter test` 46/46 (new: both tabs present with Catalog first; Reports tab shows summary and a student report with its resolve button; badge shows the count of new reports only; no badge when none); `flutter analyze` 0 errors; APK built and installed on the SM-A305F (22:26).
- **Not verified:** on the phone, and the admin resolving a real report end to end (the rules allow admin updates, covered by the emulator tests).
- **Notes:** `dart format` was run on the file, so the diff is larger than the change.

### 2026-10-14 — Locking / reports still denied: live rules confirmed OLD; clearer errors and colours
- **Reported:** locking a book still gives a permission error; Reports tab shows "could not load reports" under "Student reports", with the summary showing Issued 3, Overdue 0, Locked 0, New reports 0; tile colours need fixing.
- **Diagnosis (definitive):** a read-only check of the LIVE project (`campus-a4087`), signing in as the demo librarian exactly like the app: `books` and `libraryIssues` return 200, but `issueReports` and `books/BOOK-001/lockHistory` return **403 PERMISSION_DENIED**. The librarian's profile is correct (role `librarian`, active). So the app is fine and the published Firestore rules are still the old ones; the new rules (`firebase/firestore.rules`) are **not published**. They cannot be deployed from this PC: the Firebase CLI account `codecortexpk@gmail.com` gets 403 on project `campus-a4087` (no permission). The phone's log agrees (the `issueReports` listener kept failing with PERMISSION_DENIED).
- **Needed from the project owner:** Firebase console, project `campus-a4087` -> Firestore Database -> Rules -> replace everything with `firebase/firestore.rules` -> Publish. Then run `python scripts/check_live_rules.py` (new, read-only, prints 200/403 per rule).
- **Changed in the app:**
  - Reports list error is now plain language with a Retry button: "Student reports are not available yet. The database rules for reports have not been published..." for permission errors, "Could not load reports. Check your connection and try again." otherwise (no raw exception text).
  - Lock/unlock failures with permission denied now say the lock rules are not published and to ask the administrator, instead of the raw error.
  - Colours: Locked is now its own purple (`AppColors.locked`), no longer the same red as Overdue. Reports tiles are Issued now = blue, Overdue = red, Locked = purple, New reports = orange. The Locked sub-tab, locked cards, LOCKED badge, lock history icons and the locked-book sheet use the purple.
- **Files:** mobile/lib/core/theme/app_theme.dart, features/common/issue_reports_screen.dart, features/library/book_lock_ui.dart, features/librarian/{librarian_catalog_screen,librarian_reports_screen,librarian_scan_screen}.dart, mobile/test/librarian_error_resilience_test.dart, scripts/check_live_rules.py
- **Verified by:** `flutter test` 42/42 (2 new: denied reports show the plain message + Retry and no raw text; other errors say check the connection); `flutter analyze` 0 errors; APK built and installed on the SM-A305F; `scripts/check_live_rules.py` run against the live project -> exit 2 (new rules NOT published).
- **Not verified:** the new screens and colours on the phone; locking itself (blocked until the rules are published).

### 2026-10-14 — Fix: scanner camera no longer keeps running behind the book sheet
- **Type:** fix (battery / behaviour)
- **Areas:** mobile (librarian Home scan)
- **Problem:** after a QR code was read and the book sheet opened, the camera preview kept running behind the sheet. A flag ignored further codes, so nothing was scanned twice, but the camera and decoder stayed on until the sheet was closed.
- **Fix:** the camera is stopped as soon as a code is read (also when the ID is typed instead). If the code is not one of our books, the camera restarts so another code can be scanned. When the sheet closes the camera view goes away as before, and the next tap on Scan starts the camera fresh. The package's own lifecycle restart does not apply here because the screen uses its own scanner controller.
- **Files:** mobile/lib/features/librarian/librarian_scan_screen.dart
- **Verified by:** `flutter test` 40/40 and `flutter analyze` 0 errors (no tests can drive the camera); APK built and installed on the SM-A305F.
- **Not verified:** on the phone: that the preview freezes/stops behind the sheet, that an unknown code restarts scanning, and that a second scan after closing the sheet works. Please try each once.

### 2026-10-14 — Fix: red error screen in the librarian portal when a Firestore query is denied
- **Type:** fix (crash)
- **Areas:** mobile (librarian, student library, lock actor)
- **Symptom:** the phone showed Flutter's full red error screen after logging in as the librarian.
- **Cause:** the new Home, Catalog and Reports screens read stream providers with `.value`. In Riverpod 2.6, `.value` rethrows when the stream has failed, so a failed query threw while the screen was building. The query that fails today is the students' reports (`issueReports`) because the new Firestore rules have not been deployed to the live project, so Firestore answers `permission-denied`. Reproduced with a test: against the old code both new tests fail with the `permission-denied` exception.
- **Fix:** those reads now use `.valueOrNull` (a failed or loading stream just shows zero or empty), in `librarian_home_screen`, `librarian_catalog_screen`, `librarian_reports_screen`, `library_section` (student report button) and `book_lock_providers`. Existing pre-A2 code that still uses `.value` (auth and student providers) was left alone.
- **Files:** mobile/lib/features/librarian/{librarian_home_screen,librarian_catalog_screen,librarian_reports_screen}.dart, mobile/lib/features/student/widgets/library_section.dart, mobile/lib/providers/book_lock_providers.dart, mobile/test/librarian_error_resilience_test.dart
- **Verified by:** `flutter test` 40/40 (2 new regression tests: Reports tab and Catalog stay usable when the reports/loans streams fail); `flutter analyze` 0 errors; APK built and installed on the SM-A305F (update in place).
- **Not verified:** on the phone (screen locked, UI not seen).
- **Still needed:** deploy the rules (`firebase deploy --only firestore:rules`). Without them the Reports tab shows zeros and student reports / book locks are denied; the app no longer crashes, but those features do not work until the rules are live.

### 2026-10-14 — Fix: running the app from the project root (run_app.bat, install_app.bat)
- **Type:** fix (tooling)
- **Problem:** `flutter run` in the project root built a different app (`safekid_transport_assistant`, from `C:\Users\Maryam`) and failed with its errors. The SecureCampus Flutter app lives in `mobile/`; the root has no `pubspec.yaml`, so Flutter walks up to the first one it finds (the stray `C:\Users\Maryam\pubspec.yaml`).
- **Checked on the phone (SM-A305F):** the installed SecureCampus starts normally (Firebase initialises, no crash in the log); `flutter run` from `mobile/` builds, installs and attaches without errors; the new `run_app.bat` run from the root does the same.
- **Fix:** added `run_app.bat` (runs `flutter run` inside `mobile/`, adds the demo-accounts define if `demo_accounts.json` exists or can be created) and `install_app.bat` (build, `adb install -r`, falls back to `flutter install` on a signature mismatch, then launches). README updated. Local VS Code launch entry added in `.vscode/launch.json` (that folder is git-ignored).
- **Use (PowerShell/cmd, from the project root):** `.\run_app.bat` or `.\install_app.bat`. The `.\` is required on this PC: `NoDefaultCurrentDirectoryInExePath=1` stops Windows running scripts from the current folder without it.
- **Files:** run_app.bat, install_app.bat, README.md
- **Not verified:** `install_app.bat` itself (its steps were run separately earlier); the phone screen was locked, so the UI was not looked at.
- **Notes:** The unrelated project in `C:\Users\Maryam` (pubspec.yaml, android/, lib/) will keep confusing Flutter in any folder that has no pubspec of its own. Moving it into its own folder would remove the problem for good; not touched.

### 2026-10-14 — Librarian portal reorganised (Home / Catalog / Reports) and "Locked" books with full history
- **Type:** feature + safety
- **Areas:** mobile (librarian, admin), Firestore rules, new rules tests
- **Tabs:** Librarian now has **Home | Catalog | Reports** (was Scan & Issue | Issued | Catalog | Reports). The duplicate Issued tab is gone.
  - **Home:** "Issue or Return a book". One scan: an available book opens the issue sheet, an issued book opens the return sheet, a locked book opens a locked notice (reason, who locked it, when, Unlock and History buttons).
  - **Catalog sub-tabs with the quantity written under each:** All, Available, Issued, Overdue, Locked. Issued and Overdue list the loans (student, due date, Return with the scan check, search by book or student). Overdue is also counted under Issued (stated on screen). Search covers title, ID, author (books) or book/student (loans).
  - **Reports:** a short summary (Issued now, Overdue, Locked, New reports) above the students' "I did not borrow this" reports; the tab shows a badge with the number of new reports. No tiles on Home.
- **Locked books (new category):**
  - A book can be locked only when it has been received. An issued book must be returned first, then locked (it is then physically in the safe). Enforced in a Firestore transaction.
  - The reason is free text and **required** for locking and for unlocking.
  - Librarian **and Admin** can lock and unlock (Admin from the Admin Library screen, which also got a Locked filter).
  - Every lock/unlock is appended to `books/{id}/lockHistory` with action, reason, who (uid, name, role) and when; the history is append-only and shown via "Lock history".
  - A locked book cannot be issued: checked in the app, inside the issue transaction, and by a Firestore rule that rejects a new loan for a locked book even from a modified client. Issuing also now re-reads the book in a transaction, so a book issued or locked a moment ago by someone else is refused.
- **Files (new):** mobile/lib/core/utils/catalog_logic.dart, features/library/book_lock_ui.dart, features/librarian/{issued_loan_card,librarian_reports_screen}.dart, repositories/book_lock_repository.dart, providers/book_lock_providers.dart, mobile/test/catalog_test.dart, firebase/rules-tests/*. **Changed:** admin_models.dart (BookModel lock fields, BookLockEvent), librarian_{home,catalog,scan}_screen.dart, admin_library_screen.dart, librarian_repository.dart, firebase/firestore.rules, .gitignore. **Removed:** librarian_issued_books_screen.dart (its loan card lives on in the Catalog).
- **Verified by:**
  - `flutter test` **38/38** (new: book states and counts, filters, loan search, older books without lock fields, Catalog screen shows 5/2/2/1/1 under the tabs, Locked tab shows reason + Unlock, Overdue tab shows only the overdue loan, Available tab hides issued/locked).
  - `flutter analyze` 0 errors.
  - **Firestore rules tested against the real emulator: 11/11 pass** (lock history: own uid only, reason required, extra fields refused, append-only, hidden from students/security; locked book cannot be issued by librarian or admin; students cannot issue or edit books; students read only their own loans; no student access to gate entries or iris data; report creation only for the student's own loan and with the right shape; staff change only the status). Run: `cd firebase/rules-tests && npm install`, then from the repo root `firebase emulators:exec --only firestore --project demo-securecampus "npm --prefix firebase/rules-tests test"`.
  - APK built and installed on the SM-A305F.
- **NOT verified:** the new screens on the phone; the Dart lock/unlock transaction against a real Firestore (rules are tested, the Dart repository code itself has no automated test); catalog behaviour with real data.
- **MUST DO before locking works on the phone:** deploy the rules with `firebase deploy --only firestore:rules`. Until then the new `lockHistory` writes are denied (no rule yet) and a lock attempt shows an error.
- **Notes:** The earlier `flutter analyze` hint count is unchanged (style infos only). The Admin screen can lock/unlock but has no loan view. Closes the A2.6 library rules test and starts A4.7.

### 2026-10-14 — Library: search on the Issued list, verified returns (scan or typed ID), return from the Scan tab
- **Type:** feature / safety fix (A2.1, A2.5 part)
- **Areas:** mobile (librarian), Firestore data
- **What was wrong:** The Issued list had no search, and the Return button returned the loan immediately without checking that the physical book matched. A mis-tap or the wrong book in hand silently returned the wrong loan.
- **What changed:**
  1. **Search bar** on the Issued list: matches book title, book ID, student name or student ID (any part, case-insensitive; IDs ignore dashes/spaces), from 2 characters. **All / Overdue** filter chips with counts and a "N shown" counter.
  2. **Return now needs the book in hand:** tapping Return opens a camera screen. The scanned QR must match that loan's book. A wrong book is refused with a message naming the book that was scanned ("Wrong book. You scanned "X" (BOOK-002), but this return is for "Y" (BOOK-001)"); nothing changes.
  3. **"Can't scan? Enter the book ID":** typing the matching ID, then a confirmation dialog (book, student, ID) returns it, recorded as manual.
  4. **Return from the Scan tab:** scanning a book that is already issued now shows who has it, the due date, an OVERDUE tag, and a "Return this book" button (the scan is the proof).
  5. **Audit trail:** each return stores `returnedAt`, `returnedBy` (librarian uid) and `returnMethod` (`scan` or `manual`) on the `libraryIssues` document, in addition to `returned: true`.
- **Files:** mobile/lib/core/utils/issue_search.dart, mobile/lib/features/librarian/{return_verify_screen,librarian_issued_books_screen,librarian_scan_screen}.dart, mobile/lib/repositories/librarian_repository.dart, mobile/test/issue_search_test.dart
- **Verified by:** `flutter test` 29/29 (new: issue search by title/ID/student, short query shows all, no match, book-code matching right/wrong/partial/empty); `flutter analyze` 0 errors; APK built and installed on the SM-A305F (update in place).
- **Not verified:** the camera screens on the phone (scanner cannot run in unit tests); a real return end to end; the manual-ID path; the wrong-book message. Test with printed QR codes from `qr_codes/`.
- **Notes:** No Firestore rule change was needed (librarians already write `libraryIssues` and `books`). Old returns made before today have no `returnedAt` / `returnMethod`. `returnMethod` is ready for the activity log (A4.4).

### 2026-10-14 — Librarian student search: by any part of ID or name, librarian picks (replaces the last-3-digits rule)
- **Type:** change (UX), requested by the team
- **Areas:** mobile (librarian)
- **What changed:** The issue sheet field is now "Student ID or name". From **2 characters** it lists every student whose registration number **contains** the text (`00` lists all IDs with 00) or whose **name contains** it (`ayesh` lists every name with those letters); case, dashes and spaces are ignored for IDs, case for names. The list shows name plus the complete ID, program and semester, with a "N students found - check the name and ID, then tap one" line. **Nothing is selected automatically**, even for a single match; the librarian taps the correct student, and editing the text clears the selection. Replaces the "ends with last 3 digits" behaviour added earlier today (function renamed `searchStudents`).
- **Files:** mobile/lib/core/utils/student_search.dart, mobile/lib/features/librarian/librarian_scan_screen.dart, mobile/test/student_search_test.dart
- **Verified by:** `flutter test` 22/22 (search tests: 00 across IDs, ID formats, name parts and case, single match still a list, under 2 characters, no match); `flutter analyze` 0 errors; installed on the SM-A305F with `adb install -r` (update in place).
- **Not verified:** the sheet on the phone (needs a librarian login and a scanned book).
- **Notes:** A 3-letter text such as `BSE` matches every ID (all contain it) and lists everyone; the list scrolls. The full student list is fetched when the sheet opens.

### 2026-10-14 — Librarian: find the student by the last 3 digits (A2.1 fix)
- **Type:** fix / UX
- **Areas:** mobile (librarian)
- **What was wrong:** In the issue sheet the student lookup was an exact Firestore query (`registrationNumber == typed text`). The librarian had to type the whole number (for example FA23-BSE-007) with the right case and dashes, then tap the search icon; it returned at most one student.
- **What changed:** Typing the last 3 or more characters now searches live. The match ignores case, dashes and spaces and compares the END of the registration number. One match is selected automatically; several matches (the same digits in two intakes, such as FA22-BSE-007 and FA23-BSE-007) are shown as a list to tap. A selected student shows name, registration number, program and semester. Students load once when the sheet opens (the librarian role may already read `students`, so there are no rule changes).
- **Files:** mobile/lib/core/utils/student_search.dart, mobile/lib/repositories/librarian_repository.dart, mobile/lib/features/librarian/librarian_scan_screen.dart, mobile/test/student_search_test.dart
- **Verified by:** `flutter test` 21/21 (6 new search tests: last 3 digits, two intakes, long forms in any case, under 3 characters, end-not-middle); `flutter analyze` 0 errors; APK built and installed on the SM-A305F.
- **Not verified:** the new sheet itself on the phone (needs a librarian login and a scanned book).
- **Notes:** The whole student list is fetched per issue; fine for hundreds of students, revisit if it grows to thousands. The debug signing key on this PC was recreated at 19:59 today (cause not found), so the copy on the phone had to be replaced; `flutter install` does this. If the key is recreated again, expect the same.

### 2026-10-14 — Login screen: "Demo accounts" list, tap to sign in (testing aid)
- **Type:** feature (testing)
- **Areas:** mobile, scripts
- **What changed:** The login screen shows a **Demo accounts** button (debug builds only). It opens a list of every seeded account grouped by role (admin, librarian, security, driver, students); tapping one signs in. The accounts are NOT in source code: `scripts/make_demo_defines.py` converts `CREDENTIALS.md` into `mobile/demo_accounts.json` (git-ignored), which is passed at build time with `--dart-define-from-file`. A normal build, or any release build, shows no button and contains no accounts.
- **Build command:** `python scripts/make_demo_defines.py` then in `mobile/`: `flutter build apk --debug --dart-define-from-file=demo_accounts.json`
- **Files:** scripts/make_demo_defines.py, mobile/lib/config/demo_accounts.dart, mobile/lib/features/auth/{login_screen,demo_accounts_sheet}.dart, mobile/test/demo_accounts_test.dart, .gitignore
- **Verified by:** `flutter test` 15/15 (parsing, no button when empty, tapping a demo account calls sign-in with its email and password); `flutter analyze` 0 errors; script parsed 14 accounts (1 admin, 10 students, librarian, security, driver); debug APK built with the file.
- **Not verified:** on the phone (install blocked by a signature mismatch with the copy already installed; needs an uninstall).
- **Notes:** Remove the demo build before showing the app to anyone outside the team: anyone holding that APK can read the passwords from it. Passwords are the seeded ones in CREDENTIALS.md; rotating them (A1.7) means re-running the script and rebuilding.

### 2026-10-14 — Admin dashboard cards are tappable
- **Type:** feature (UX)
- **Areas:** mobile
- **What changed:** Each Admin dashboard stat card now opens its section: Total Students to Students; Library Books and Issued Books to Library; Bus Status to Bus and Stops; Today's Attendance, Today's Gate Entries and Unknown Alerts to Gate and Security. The selected Admin section moved from local state into a shared provider so cards can switch it.
- **Files:** mobile/lib/providers/admin_navigation_provider.dart, mobile/lib/features/admin/admin_dashboard_screen.dart, mobile/lib/features/admin/admin_home_shell.dart, mobile/test/admin_dashboard_test.dart
- **Verified by:** `flutter test` 11/11 (new test taps all seven cards and checks the section); `flutter analyze` 0 errors; debug APK builds.
- **Not verified:** on the phone. Installing the new APK failed with INSTALL_FAILED_UPDATE_INCOMPATIBLE (signature differs from the copy already on the phone); an uninstall is needed first.
- **Notes:** Other portals (Student, Security, Librarian, Driver) were not changed; tell me which other items should be tappable.

### 2026-10-13 — Flutter SDK switched to 3.47.7; Android debug APK builds again (A1.13, I-32)
- **Type:** infra / fix
- **Areas:** build environment (outside the repo), mobile
- **What changed:** The Flutter SDK folder `C:/flutter` (git branch `stable`, clean) moved from 3.38.7 to **3.47.7** (Dart 3.13.5) with `git reset --hard 3.47.7`. Rollback: `cd C:/flutter` then `git reset --hard 3.38.7`. After that the Gradle script error was gone, but a second failure appeared: caches in `mobile/build`, `mobile/android/.gradle` and `mobile/android/.kotlin` still pointed at `C:/Users/hp/...` (a folder copied from another PC). Ran `flutter clean`, deleted those generated folders (none are tracked in git), ran `flutter pub get` and rebuilt. `pubspec.lock` was regenerated by the newer SDK.
- **Files:** mobile/pubspec.lock (generated); nothing else in the repo
- **Issue:** I-32 (Fixed)
- **Verified by:** `flutter build apk --debug` produced `app-debug.apk` (179 MB, 2026-10-13 22:44); `flutter analyze` 0 errors; `flutter test` 10/10.
- **Not verified:** the APK has not been installed or run on a phone yet. Other Flutter projects on this PC now use 3.47.7 too.

### 2026-10-13 — Bus: two reminders per trip, 20 min then 10 min (A3.3, user addition)
- **Type:** feature
- **Areas:** bus_eta, mobile, config
- **What changed:** `bus_eta` now sends **"Get Ready - Bus Coming" at ~20 min** and **"Bus Arriving Soon - head to your stop" at ~10 min**, each once per student per trip (`alertFirstTripId`, `alertFinalTripId` on `busAssignments`; legacy `lastAlertTripId` still blocks repeats). If the first reading is already inside 10 min (late trip start) only the final alert is sent. New setting `ALERT_FIRST_MINUTES=20` (`ALERT_THRESHOLD_MINUTES=10` unchanged). Notification type `BUS_20_MIN` shows the bus icon in the student Alerts list.
- **Files:** bus_eta/app/{service,firebase_client,config,main}.py, bus_eta/tests/test_service.py, mobile/lib/features/student/widgets/notifications_section.dart, .env.example, docs/TODO.md
- **Issue:** I-20 (partly: logic tested, not the live trip)
- **Verified by:** `bus_eta` pytest 19/19 (5 old + 14 new: decision table, first→final sequence, no repeat, legacy field, new trip re-alerts, no active trip); `flutter analyze` 0 errors.
- **Not verified:** a real driver GPS trip and push delivery. The proposal says one 10-minute alert; the 20-minute reminder is an addition requested by the team and should be mentioned to the supervisor.

### 2026-10-13 — Library: "due soon" notice and "report unauthorized issue" (A2.2–A2.4)
- **Type:** feature
- **Areas:** overdue_checker, mobile, firebase rules
- **What changed:**
  - `overdue_checker` now sends a one-time **due-soon** notice (return date within `DUE_SOON_HOURS`, default 48) as well as the overdue notice, and notifies every active librarian + security user once per new student report. Code refactored into `notify_due_soon`, `notify_overdue`, `notify_new_reports`.
  - Student Library tab: **"I did not borrow this"** button on each issued book → dialog with optional note → `issueReports` document.
  - Librarian portal: new **Reports** tab. Security portal: new **Book Reports** tab. Both list reports in real time and can mark them resolved/reopen.
  - `firestore.rules`: new `issueReports` rules (student can create only for their own loan, fixed field set, note ≤ 200 chars; staff read; staff update `status` only; admin delete). `LibraryIssueModel` now carries the document id.
- **Files:** overdue_checker/app/{service,config}.py, overdue_checker/tests/test_service.py, mobile/lib/{models/issue_report_model.dart, repositories/issue_report_repository.dart, providers/issue_report_providers.dart, features/common/issue_reports_screen.dart, features/student/widgets/library_section.dart, features/librarian/librarian_home_screen.dart, features/security/security_dashboard_screen.dart, models/dashboard_models.dart}, mobile/test/issue_report_model_test.dart, firebase/firestore.rules, .env.example
- **Issue:** I-23, I-24 (Fixed in code)
- **Verified by:** `overdue_checker` pytest 10/10 (due-soon once + dedupe, overdue once, no-student skip, push failure, report fan-out + dedupe); `flutter test` 10/10; `flutter analyze` 0 errors/0 warnings; `iris_ai` 21/21 and `bus_eta` 5/5 still pass.
- **Not verified:** nothing ran on a phone (APK build blocked by I-32); the new Firestore rules were not run in the emulator and are **not deployed** (`firebase deploy --only firestore:rules` needed); the notifications for staff arrive up to 60 s late (checker interval) and Librarian/Security have no in-app notification list, only push + the reports tab.
- **Notes:** `DUE_SOON_HOURS` added to `.env.example`. A librarian/security user without an FCM token only sees the report in the tab.

### 2026-10-13 — Admin map on OpenStreetMap; notification permission (A1.11, A1.12) — APK build blocked (I-32)
- **Type:** feature / config
- **Areas:** mobile
- **What changed:** Replaced `google_maps_flutter` with `flutter_map` 8.3.2 + `latlong2` (OSM tiles, attribution shown, no API key/billing). Bus and stop markers kept. Added `POST_NOTIFICATIONS` to the Android manifest. `pubspec.lock` regenerated.
- **Files:** mobile/pubspec.yaml, mobile/pubspec.lock, mobile/lib/features/admin/admin_bus_screen.dart, mobile/android/app/src/main/AndroidManifest.xml
- **Issue:** I-05, I-06 (Fixed in code); I-32 (new, open)
- **Verified by:** `flutter analyze` 0 errors / 0 warnings; `flutter test` 8/8. **`flutter build apk --debug` FAILS** (Gradle script compile errors) — I stashed my changes and rebuilt the original commit: it fails identically, so this is not caused by the map change. Cause found: project made with Flutter 3.47.2, installed SDK is 3.38.7 (`C:lutter`).
- **Notes:** The map has not been seen running (no APK, no device). OSM public tiles are for light use only. Fix for I-32 needs switching the global Flutter SDK, which may affect your other projects, so it is left to you (task A1.13).

### 2026-10-13 — Flutter tests, unused import, functions/ deprecated (A1.4, A1.9, A1.10)
- **Type:** test / config
- **Areas:** mobile, functions, firebase.json
- **What changed:** Deleted the counter-template `widget_test.dart`. Added `test/models_test.dart` (roles = exactly five, no Teacher; library status issued/overdue/returned; bus assignment parsing) and `test/login_screen_test.dart` (screen renders; empty submit never reaches Firebase). Removed the unused import in `admin_dashboard_screen.dart`. Removed the `functions` block from `firebase.json` and added `functions/DEPRECATED.md` (Cloud Functions need Blaze).
- **Files:** mobile/test/*, mobile/lib/features/admin/admin_dashboard_screen.dart, firebase.json, functions/DEPRECATED.md
- **Issue:** I-08, I-18 (Fixed)
- **Verified by:** `flutter test` 8/8 pass; `flutter analyze` 0 errors, 0 warnings (style infos only).
- **Notes:** Router redirect-by-role is private and needs Firebase; it is not covered yet (A5.2, will need fakes). `firebase deploy` no longer touches functions.

### 2026-10-13 — Security fixes: admin auth on enroll/recognize, real account deactivation (A1.5, A1.6)
- **Type:** fix (security)
- **Areas:** iris_ai, mobile
- **What changed:** `POST /iris/enroll` and `POST /recognize/once` now require an admin Firebase ID token (401 without, 403 for non-admin). The Flutter `enrollIris` call sends the Bearer token. `deactivate_account` now also disables the Firebase Auth user and revokes refresh tokens. Added `httpx` to requirements (test client).
- **Files:** iris_ai/app/main.py, iris_ai/app/firebase_client.py, iris_ai/tests/test_endpoint_auth.py, iris_ai/requirements.txt, mobile/lib/services/backend_api_service.dart
- **Issue:** I-02, I-11 (Fixed)
- **Verified by:** `iris_ai` pytest 21/21 (12 new: 401/403 for all five admin endpoints, admin reaches handler, deactivation calls disable + revoke); `flutter analyze` 0 errors.
- **Notes:** Not verified against real Firebase tokens or on a device (enrolling from the Admin screen should be re-tested). There is no "reactivate" feature in the app; re-enabling a user needs `disabled=False` in the console. `/stream/status`, `/camera/status`, `/health` stay public (read-only status).

### 2026-10-13 — Alert images moved to Firebase Storage; Supabase removed (A1.8)
- **Type:** refactor / decision (D-4)
- **Areas:** iris_ai, mobile, config, docs
- **What changed:** `create_unknown_alert` uploads to Firebase Storage (`security_alerts/{camera}/{ts}.jpg`); if the upload fails the alert is still saved with an empty `imagePath`. Deleted `supabase_client.py`, the `/admin/security-alert-image-url` endpoint, `SUPABASE_*` settings, the `supabase` dependency and the unused Flutter `fetchSecurityAlertImageUrl`. Local `.env` now has the real project id and bucket `campus-a4087.firebasestorage.app` (git-ignored).
- **Files:** iris_ai/app/firebase_client.py, admin_api.py, config.py, requirements.txt, tests/test_alert_upload.py, mobile/lib/services/backend_api_service.dart, .env.example, docs/*
- **Issue:** I-01, I-04 (moot), I-07, I-31
- **Verified by:** `iris_ai` pytest 9/9 (2 new, mocked Storage); `import app.main` OK; `flutter analyze` 0 errors (29 issues, all warnings/infos as before).
- **Notes:** **Not verified against real Firebase:** the bucket `campus-a4087.firebasestorage.app` does not exist yet (checked read-only with the service account: 404). Create it via console → Storage → Get started (A1.8b); this may require the Blaze plan. Old alerts holding Supabase paths will show a placeholder. `README`/`ARCHITECTURE` still mention Supabase in places (I-17).

### 2026-10-13 — Environment fixes: venvs, supabase dependency, overdue_checker wired in (A1.1–A1.3)
- **Type:** fix / config
- **Areas:** iris_ai, bus_eta, overdue_checker, repo root
- **What changed:** Deleted the unusable `.venv` folders and recreated them for `iris_ai`, `bus_eta`, `overdue_checker` from pinned requirements (Python 3.11.9). Added `supabase==2.32.0` to `iris_ai/requirements.txt`. Added `overdue_checker` to `setup.bat/.sh`, `run.bat/.sh`, `docker-compose.yml`, plus a new `overdue_checker/Dockerfile`. Added `SUPABASE_*` and `OVERDUE_CHECK_INTERVAL_SECONDS` to `.env.example`.
- **Files:** iris_ai/requirements.txt, setup.bat, setup.sh, run.bat, run.sh, docker-compose.yml, overdue_checker/Dockerfile, .env.example
- **Issue:** I-04, I-09, I-12, I-21 (Fixed); I-17 (in progress)
- **Verified by:** on the pinned set (numpy 2.2.6, OpenCV 5.0.0): `iris_ai` pytest 7/7, `bus_eta` pytest 5/5; `import app.firebase_client, app.main` OK in iris_ai; `import app.service` OK in overdue_checker.
- **Notes:** Not tested: `docker compose build`, `setup.sh`/`run.sh` (no Docker/bash target here), running `run.bat` against live Firebase. The pinned versions need Python 3.11+ (Docker images use 3.12).

### 2026-10-13 — Free-first rule (D-7): Supabase kept, OpenStreetMap for maps
- **Type:** docs / decision
- **Areas:** docs
- **What changed:** Added D-7 (Spark only, no billing). Amended D-4: alert images stay on Supabase unless Firebase Storage proves free. A1.8 now fixes the image widget + Supabase deps; A1.11 now swaps Google Maps for `flutter_map` + OpenStreetMap; A3.6 keeps the free straight-line ETA. I-31 deferred.
- **Files:** docs/TODO.md, docs/ISSUES.md, docs/CHANGELOG.md
- **Verified by:** Firebase pricing-plans page (updated 2026-10-06): using Google Maps APIs in the project auto-upgrades it to Blaze; Cloud Functions need Blaze; Spark quota overage shuts the product off for the month.
- **Notes:** Storage-on-Spark still unconfirmed for this project (check console Build → Storage).

### 2026-10-13 — To-do split into Part A (before mid) and Part B (after mid)
- **Type:** docs
- **Areas:** docs
- **What changed:** Rewrote TODO.md. Part A (before mid): library, bus tracking, admin/roles, notifications, tests, docs, mid regression check. Part B (after mid): lost-card recovery with OCR, iris/eye recognition, final report. Added decision D-6.
- **Files:** docs/TODO.md, docs/CHANGELOG.md
- **Verified by:** task counts recomputed from the file.
- **Notes:** Eye-recognition and card code stays in the repo during Part A; A5.3 is the check that nothing broke.

### 2026-10-13 — Supervisor decisions recorded; Flutter health check
- **Type:** docs / test
- **Areas:** docs, mobile
- **What changed:** Recorded D-1…D-5 in TODO.md; opened I-31 (switch to Firebase Storage); I-19 closed; I-25/I-28 updated. Committee email "Partially Accepted with changes" noted.
- **Files:** docs/TODO.md, docs/ISSUES.md, docs/CHANGELOG.md
- **Verified by:** `flutter pub get` OK; `flutter analyze`: 0 errors, 1 warning, 28 infos; `flutter test`: **fails** (default counter test, I-08). `pub get` rewrote `pubspec.lock` (older versions); reverted with git checkout so the tracked lockfile is unchanged. `iris_ai` 7/7 and `bus_eta` 5/5 passed earlier today.
- **Notes:** Existing code compiles; nothing found broken beyond the already-listed issues.

### 2026-10-13 — Project put under git and force-pushed to GitHub
- **Type:** infra
- **Areas:** repo root, docs
- **What changed:** `git init` inside `securecampus/`; extended `.gitignore` (all `.venv/`, `scripts/.env`, `google-services.json`, `local.properties`, APKs, `.vscode/`, stray jpeg); one commit of 210 files; **force-pushed** to `maryam-ca/Secure-Campus-AI` `main` (old head `c7d2952` replaced by `c8b7967`). Added "Setup after cloning" to README.
- **Files:** .gitignore, README.md, docs/ISSUES.md, docs/CHANGELOG.md
- **Issue:** I-13 (Fixed)
- **Verified by:** `git check-ignore` confirms `.env`, `secrets/`, `CREDENTIALS.md`, `scripts/.env`, `google-services.json` are ignored; push output shows forced update.
- **Notes:** Old remote history only reachable via `c7d2952` until GitHub garbage-collects it. `firebase_options.dart` (Firebase API keys) is committed because the app needs it.

### 2026-10-13 — Proposal traceability and master to-do added
- **Type:** docs
- **Areas:** docs
- **What changed:** Compared the supervisor-approved proposal with the code; added `PROPOSAL_TRACEABILITY.md` and `TODO.md` (59 ordered tasks, 7 phases); opened issues I-22 to I-30 for missing proposal features. No source code modified.
- **Files:** docs/PROPOSAL_TRACEABILITY.md, docs/TODO.md, docs/ISSUES.md
- **Verified by:** grep of `mobile/lib` and `iris_ai/app` for each proposal feature.
- **Notes:** Open decisions D-1 to D-5 listed at the end of TODO.md.

### 2026-10-13 — Baseline analysis and tracking documents added
- **Type:** docs
- **Areas:** docs
- **What changed:** Full review of the project; added `PROJECT_STATUS.md`, `ISSUES.md` (21 issues opened) and this changelog. No source code was modified.
- **Files:** docs/PROJECT_STATUS.md, docs/ISSUES.md, docs/CHANGELOG.md
- **Verified by:** `iris_ai` pytest 7/7 pass; `bus_eta` pytest 5/5 pass; `flutter analyze` inconclusive (dependencies not resolved — I-19).
- **Notes:** Docs from 2026-09-11 (README, LIMITATIONS, AUDIT/FINAL reports) are outdated; see I-17.

---

## History before tracking began (reconstructed from file dates and code comments)

Dates are approximate. There was no git history for this project to rebuild an exact log from.

### 2026-09-11 — Initial delivery
- Complete first build of all components: Flutter source (no native folders), `iris_ai`, `bus_eta`, `functions/` Cloud Function, Firebase rules/indexes, scripts, QR codes, and the docs set (README, ARCHITECTURE, AUDIT_REPORT, FINAL_VERIFICATION_REPORT, IRIS_MODEL, LIMITATIONS, MOBILE_PLATFORM_SETUP, VERSION_AUDIT). Python tests 7/7 and 5/5 passed; Flutter was not yet compiled.

### 2026-09-11 → 2026-09-14 — Real Firebase project connected
- `.firebaserc` created, `.env` filled in, service-account key placed in `secrets/`, project seeded (admin + 10 students — see `CREDENTIALS.md`, kept private).

### 2026-09-12 → 2026-09-13 — Flutter project generated and debugged on a device
- `android/` and `ios/` generated, `firebase_options.dart` and `google-services.json` added. Fixed the `[core/duplicate-app]` startup crash in `main.dart` (app stuck on native splash).
- Firestore rules fixes: users can write their own `fcmToken`; librarian can read `students`; users can delete their own notifications.
- Admin features added: edit account name / reset password (`/admin/accounts/update`); UI work (animated logo, hero headers, campus image).
- `config.py` (all services) made independent of the launch directory for `.env` and credentials paths.

### 2026-09-14 → 2026-09-18 — Free-tier workarounds, first APK
- Unknown-person images moved from Firebase Storage to **Supabase Storage** (new `supabase_client.py`, `/admin/security-alert-image-url`, `imagePath` field). Flutter image widget not updated (→ I-01).
- Cloud Function replaced by the standalone **`overdue_checker/`** loop (no Blaze plan needed).
- `scripts/backfill_rtdb_roles.py` added to repair RTDB role mirrors.
- Debug APK built (2026-09-18).

### 2026-10-03 — `CREDENTIALS.md` last edited
- Seeded-account credential list updated.
