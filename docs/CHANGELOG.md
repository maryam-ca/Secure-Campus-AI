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
