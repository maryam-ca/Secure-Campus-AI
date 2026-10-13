# SecureCampus — Issue Tracker

One row per problem. Never delete a row: change its **Status** and fill in
**Resolved** (date + one line on how). Add new issues at the bottom with the
next free ID.

Status values: `Open` · `In progress` · `Fixed` · `Won't fix` · `Needs hardware`
Severity: `High` (breaks a feature or is a security hole) · `Med` · `Low`

Opened from the 2026-10-13 baseline analysis ([PROJECT_STATUS.md](PROJECT_STATUS.md)).

| ID | Sev | Area | Problem | Where | Status | Resolved |
|---|---|---|---|---|---|---|
| I-01 | High | Flutter / Storage | Alert images can't load: `SecureStorageImage` reads Firebase Storage, but images are uploaded to Supabase. Replace with a widget that calls `BackendApiService.fetchSecurityAlertImageUrl(path)` and shows the signed URL. | `mobile/lib/core/widgets/secure_storage_image.dart`, used by `admin_gate_security_screen.dart:106`, `security_dashboard_screen.dart:145` | Open | |
| I-31 | Med | Storage | D-4: use Firebase Storage instead of Supabase. Backend upload + Flutter widget (I-01) must be switched together; Firebase Storage needs the Blaze plan; update `storage.rules`, remove `supabase_client.py`, `SUPABASE_*` env vars. | `iris_ai/app/firebase_client.py`, `supabase_client.py`, `admin_api.py`, `secure_storage_image.dart` | Deferred | Free-first: stay on Supabase; re-check Firebase Storage on Spark in Part B |
| I-02 | High | Security | `/iris/enroll` has no auth (anyone on the network can overwrite a student's iris template); Flutter's `enrollIris` sends no token. `/recognize/once` is also unauthenticated and writes attendance/gate records. Add `require_admin` to both and send the Bearer token from the app. | `iris_ai/app/main.py:96,188`, `backend_api_service.dart:enrollIris` | Open | |
| I-03 | High | Security | Plaintext passwords (admin + 10 students) in `CREDENTIALS.md`; live keys in `.env` and `secrets/`. Rotate admin password/service-account/Supabase key before sharing or demoing off-machine; never copy the folder to git/cloud as-is. | `CREDENTIALS.md`, `.env`, `secrets/`, `scripts/.env` | Open | |
| I-04 | High | Python deps | `supabase` is imported at startup but missing from `iris_ai/requirements.txt` → fresh install / Docker build fails. | `iris_ai/requirements.txt`, `iris_ai/app/firebase_client.py:28` | Open | |
| I-05 | Med | Android | No Google Maps API key meta-data in the manifest → Admin live bus map shows grey tiles. | `mobile/android/app/src/main/AndroidManifest.xml` | Open | Decision 2026-10-13: use OpenStreetMap (flutter_map), no Google Maps key (avoids forced Blaze upgrade) |
| I-06 | Med | Android | `POST_NOTIFICATIONS` permission missing (needed on Android 13+ for FCM banners). | same | Open | |
| I-07 | Med | Firebase | `storage.rules` still describes `security_alerts/` in Firebase Storage, which is no longer used. Either remove that block or document that Storage rules are unused. | `firebase/storage.rules` | Open | |
| I-08 | Med | Tests | `mobile/test/widget_test.dart` is the Flutter counter template; it fails against this app (and `SecureCampusApp` needs a `ProviderScope`). Replace with a real smoke test (e.g. login screen renders). | `mobile/test/widget_test.dart` | Open | Confirmed 2026-10-13: `flutter test` fails (counter template) |
| I-09 | Med | Ops | `overdue_checker` is missing from `setup.*`, `run.*` and `docker-compose.yml` (and has no Dockerfile). | repo root, `overdue_checker/` | Open | |
| I-10 | Low | Security | CORS `allow_origins=["*"]`, no rate limiting on any endpoint. | `iris_ai/app/main.py:47` | Open | |
| I-11 | Med | Security | `deactivate_account` only sets `users.active=false`; the Firebase Auth user stays enabled. Also call `fb_auth.update_user(uid, disabled=True)` (and re-enable on reactivation). | `iris_ai/app/firebase_client.py:358` | Open | |
| I-12 | Med | Env | `iris_ai/.venv` and `overdue_checker/.venv` reference `C:\Users\hp\...\Python310` (made on another PC) and don't run here. Recreate with `setup.bat`; add both `.venv` folders to `.gitignore` (currently only iris_ai/bus_eta are listed — `overdue_checker/.venv` is not). | `iris_ai/.venv`, `overdue_checker/.venv`, `.gitignore` | Open | |
| I-13 | High | Process | The project has **no version control of its own**. Git root is `C:\Users\Maryam`; this folder is untracked and recent commits there are another project. `git init` inside `securecampus/`, commit with the existing `.gitignore`, and confirm `.env`, `secrets/`, `CREDENTIALS.md`, `google-services.json` policy before the first push. | project root | Fixed | 2026-10-13: git init in project, pushed to github.com/maryam-ca/Secure-Campus-AI (secrets git-ignored) |
| I-14 | Low | Hygiene | Stray `studnet 1.jpeg` in project root (name typo; possibly a student photo/PII). Move it out or into an ignored folder. | repo root | Open | |
| I-15 | High | AI | Iris accuracy never measured: threshold 0.32 uncalibrated, RGB (not NIR) camera, Hough-based segmentation. Collect real genuine/impostor pairs, tune threshold, report FAR/FRR in `docs/IRIS_MODEL.md` §6. | `iris_ai/app/recognition/*`, `.env` | Needs hardware | |
| I-16 | Low | Design | One camera name/location per iris_ai process and a single global attendance/gate mode; can't run both camera roles at once without two instances. Decide whether to document or support multi-camera. | `iris_ai/app/config.py`, `main.py` | Open | |
| I-17 | Med | Docs | README/ARCHITECTURE/LIMITATIONS are stale (Supabase, overdue_checker, android/ios now exist, Flutter now builds); `docs/SUPABASE_STORAGE_SETUP.md` is referenced by code but doesn't exist; `.env.example` lacks `SUPABASE_*` and `OVERDUE_CHECK_INTERVAL_SECONDS`; `mobile/README.md` is template text. | `README.md`, `docs/`, `.env.example` | Open | |
| I-18 | Low | Duplication | `functions/main.py` and `overdue_checker/app/service.py` implement the same job. Decide which one is canonical and remove or mark the other deprecated, so a student isn't notified twice if both are ever run. | `functions/`, `overdue_checker/` | Open | |
| I-19 | Med | Verification | `flutter analyze` has not been run with dependencies resolved (`.dart_tool` missing; offline `pub get` failed). Run `flutter pub get` online, then `flutter analyze`, and record the issue count. | `mobile/` | Fixed | 2026-10-13: `flutter pub get` + `flutter analyze` → 0 errors, 1 warning (unused import admin_dashboard_screen.dart:5), 28 style infos |
| I-20 | Med | Verification | End-to-end device tests never recorded: iPhone RTSP, driver GPS → ETA alert, FCM delivery, Maps tiles, overdue checker, Supabase upload + signed URL, QR scan with a real book. Log each as it passes in CHANGELOG. | — | Needs hardware | |
| I-21 | Low | Deps | Pinned versions (`numpy==2.2.6`, `opencv-python-headless==5.0.0.93`) differ from what's installed on this PC (NumPy 2.4.4, OpenCV 4.13.0). Tests pass on both; re-create venv from `requirements.txt` and re-run tests to confirm the pinned set. | `iris_ai/requirements.txt` | Open | |
| I-22 | High | Proposal | Missing rule "only students verified at the gate can be marked present in class" — `record_attendance` never checks `gateEntries`. | `iris_ai/app/firebase_client.py:132` | Open | |
| I-23 | High | Proposal | Missing "Report unauthorized issue" (student → alerts librarian + security). | mobile, rules | Open | |
| I-24 | Med | Proposal | Only overdue notices exist; proposal requires a notification when the return date is *near*. | `overdue_checker/app/service.py` | Open | |
| I-25 | Low | Proposal | Students can't access bus tracking (map is admin-only); proposal wording says students with a bus can. Needs decision D-2. | `student/widgets/bus_assignment_section.dart` | Decided | D-2: students get text status only, 10 min before pickup. No map for students |
| I-26 | Med | Proposal | No activity-log collection/screen for attendance, library, bus. | backend + mobile | Open | |
| I-27 | Med | Proposal | No report generation/export (attendance, library, security). | mobile admin | Open | |
| I-28 | Low | Proposal | Card recovery has no OCR extraction of name/reg-no (proposal §4.5). Decision D-3. | `found_card_report_screen.dart` | Open | D-3: OCR is required (priority raised to Med) |
| I-29 | Low | Proposal | §8 lists YOLO eye detection and Colab training; neither exists (classical pipeline only). Get supervisor confirmation or remove from report. | — | Open | |
| I-30 | Med | Proposal | Student dashboard lacks "Campus Entry Status (ENTERED / NOT ENTERED + last entry)". | `student_dashboard_screen.dart` | Open | |
