# SecureCampus — Project Status & Deep Analysis

**Baseline snapshot: 2026-10-13.** This is a point-in-time analysis. Do not edit
it to record later work — record that in [CHANGELOG.md](CHANGELOG.md) and
[ISSUES.md](ISSUES.md). Update this file only when you re-run a full review
(add a new dated section at the top and keep the old one below it).

Method: every source file outside `.venv`/`build` was read or searched; the two
Python test suites were executed; `flutter analyze` was attempted (see §6).
Nothing here is copied from the older reports without being checked against the
code.

---

## 1. What the project is

A Final Year Project: a Flutter app with five role portals (Admin, Student,
Security, Librarian, Driver) on a Firebase backend, plus Python services:
iris recognition for attendance/gate entry, bus ETA alerts, and overdue-book
notifications.

## 2. Components and their real state

| Component | Path | Size | State |
|---|---|---|---|
| Flutter app | `mobile/` | ~50 Dart files, ~9.5k lines | **Builds.** `android/` + `ios/` exist, `firebase_options.dart` and `google-services.json` are in place, a debug APK was built 2026-09-18. Never confirmed running end-to-end in these docs. |
| Iris AI service | `iris_ai/` (FastAPI) | ~1.5k lines | Code complete. **7/7 tests pass** (re-run 2026-10-13). Accuracy on real eyes unmeasured. |
| Bus ETA job | `bus_eta/` | ~330 lines | **5/5 tests pass** (re-run 2026-10-13). Never run against a real driver GPS. |
| Overdue checker | `overdue_checker/` | ~180 lines | New standalone loop replacing the Cloud Function. **No tests, not documented anywhere.** |
| Cloud Function | `functions/main.py` | 112 lines | Now redundant with `overdue_checker/` (identical logic). Needs Blaze plan, so effectively abandoned. |
| Firebase rules | `firebase/` | — | Firestore + RTDB rules are current. **Storage rules are stale** (see I-07). |
| Scripts | `scripts/` | — | Seed, RTDB-role backfill, QR generation. |
| Docs | `docs/` | 7 files | **Mostly out of date** — they describe the project as of ~2026-09-11 (see §5). |

## 3. Architecture as it actually is today

```
iPhone RTSP ─► iris_ai (FastAPI) ──► Firestore  (attendance, gateEntries, alerts, notifications)
                    │          └───► Supabase Storage (unknown-person JPEGs)   ← changed from docs
                    └── signed-URL endpoint ◄── Flutter app (Admin/Security)

Driver phone GPS ─► RTDB driverLocation ─► bus_eta loop ─► Firestore notifications + FCM
overdue_checker loop ─► Firestore libraryIssues ─► notifications + FCM          ← replaces Cloud Function
Flutter app ─► Firestore / RTDB directly (rules-enforced) ; iris_ai REST for account creation + camera control
```

Key decisions that diverged from the written docs:
1. **Alert images moved to Supabase Storage** to avoid the Firebase Blaze plan.
   Backend + `backend_api_service.dart` were updated; the Flutter image widget was not (I-01).
2. **Overdue notifications moved to a local Python loop** (`overdue_checker/`) for the same reason.
3. **Firebase project in use:** a real one is configured (the app's own comment names it).

## 4. Role / data-access model (verified)

- Roles: `admin, student, security, librarian, driver` — enforced in the router
  (`app_router.dart`), Firestore rules, and RTDB rules.
- `irisProfiles` and `registrationNumbers` are unreadable by every client role.
- Students cannot read `gateEntries`, `securityAlerts`, or the live bus location.
- Registration-number uniqueness is a server-side transaction.
- RTDB `driverLocation` writes are field-whitelisted and tied to `driverAssignments`.

This part of the design is sound and matches the code.

## 5. Documentation accuracy

| Doc | Verdict |
|---|---|
| `README.md` | Stale: says no android/ios folders, Cloud Function for overdue, Firebase Storage for images; omits `overdue_checker` and Supabase. |
| `docs/LIMITATIONS.md`, `FINAL_VERIFICATION_REPORT.md`, `AUDIT_REPORT.md` | Written when the Flutter code had never been compiled. That is no longer true. Treat as history. |
| `docs/ARCHITECTURE.md` | Still shows Firebase Storage, no Supabase, no overdue checker. |
| `docs/SUPABASE_STORAGE_SETUP.md` | **Referenced by code and `config.py` but does not exist.** |
| `.env.example` | Missing `SUPABASE_*` and `OVERDUE_CHECK_INTERVAL_SECONDS` (the real `.env` has them). |
| `mobile/README.md` | Default Flutter template text. |
| `IRIS_MODEL.md`, `MOBILE_PLATFORM_SETUP.md`, `VERSION_AUDIT.md` | Not re-audited in detail; likely still broadly valid. |

## 6. Verification results (2026-10-13)

| Check | Result |
|---|---|
| `iris_ai` pytest (system Python 3.11, OpenCV 4.13, NumPy 2.4) | **7 passed** |
| `bus_eta` pytest | **5 passed** |
| `iris_ai/.venv` and `overdue_checker/.venv` | **Unusable here** — they point at `C:\Users\hp\...\Python310`, i.e. copied from another PC. Recreate them (I-12). |
| `flutter analyze` | **Not conclusive.** `.dart_tool` is missing, so analyze reports ~3,300 false "package not found" errors. `flutter pub get --offline` failed (no cached `flutter_lints`). Needs `flutter pub get` with internet, then re-run. |
| Flutter widget test | `mobile/test/widget_test.dart` is the untouched Flutter "counter" template; it does not match this app and will fail (I-08). |
| Test coverage | Python: pipeline + geo math only. No tests for Firebase client, admin API auth, overdue checker, rules, or any Flutter code. |

Version note: `requirements.txt` pins `numpy==2.2.6` / `opencv-python-headless==5.0.0.93`, but the machine running tests has different versions. The tests pass on both, but the pinned set was not re-installed and tested today.

## 7. Findings, in priority order

Full tracking with IDs/status is in [ISSUES.md](ISSUES.md). Summary:

**Security**
- `POST /iris/enroll` has **no authentication** — anyone who can reach port 8000 can overwrite a student's iris template (and the Flutter call sends no token). `POST /recognize/once` is also open and can write attendance/gate records. (I-02)
- `CREDENTIALS.md` holds the seeded admin + 10 student passwords in plaintext, and `.env`/`secrets/serviceAccountKey.json` hold live keys. They are git-ignored, but **this project is not under its own version control** (see below), and the passwords are the same ones used for demo accounts. Rotate before any demo outside your machine. (I-03)
- CORS is `*` and no rate limiting (known, documented). (I-10)
- A deactivated account is only flagged in Firestore; its Firebase Auth user stays enabled. Rules/router block it, but the token is still valid for services that don't check `active`. (I-11)

**Functional breakage**
- Security/Admin alert images will show an error: `SecureStorageImage` still calls Firebase Storage, but images are now in Supabase. The signed-URL endpoint exists but nothing calls it. (I-01)
- `iris_ai/requirements.txt` does not list `supabase`, yet `firebase_client.py` imports it at module load → a clean install or Docker build crashes on start. (I-04)
- Android manifest has no Google Maps API key and no `POST_NOTIFICATIONS` permission → Admin live map is blank; push notifications won't show on Android 13+. (I-05, I-06)
- `docker-compose.yml`, `run.bat/.sh`, `setup.bat/.sh` do not know about `overdue_checker`. (I-09)

**Process**
- **No version control for this project.** The git repo is at `C:\Users\Maryam` (home folder); the last commits there belong to a different project (an ERP app) and this folder shows as untracked. There is no history, no backup, no way to diff what changed. (I-13)
- A stray `studnet 1.jpeg` sits in the project root. (I-14)

**AI / accuracy (unchanged, still the biggest academic risk)**
- Classical Daugman pipeline on an RGB iPhone camera, `IRIS_MATCH_THRESHOLD=0.32` never calibrated, no FAR/FRR numbers. Segmentation uses Hough circles, which is fragile on visible-light eye images. Needs real enrollment data and an evaluation table for the thesis. (I-15)
- One camera name/location per service instance, and "attendance" vs "gate" is a global mode — you can't run both at once without two instances. (I-16)

## 8. What is genuinely finished vs. not proven

Finished and tested in code: iris pipeline mechanics, ETA math, rules design,
role routing, account management, library/QR flow, bus map code, notification
plumbing.

Not proven on real hardware/accounts: iPhone RTSP capture, iris accuracy,
driver GPS → ETA alert, FCM delivery, Maps rendering, overdue checker firing,
Supabase upload/signed URL, and a clean `flutter analyze`.

## 9. Recommended next steps (ordered)

1. Put the project under its own git repo with a proper `.gitignore` (I-13) — do this first so everything below is tracked.
2. Fix I-01 (alert image widget), I-04 (supabase dependency), I-02 (auth on enroll).
3. `flutter pub get` + `flutter analyze` + replace the template widget test.
4. Add Maps key + notification permission (I-05/I-06).
5. Recreate the Python venvs; wire `overdue_checker` into setup/run/docker (I-09, I-12).
6. Refresh README/ARCHITECTURE/`.env.example`, write the missing Supabase doc (I-07, I-17).
7. Collect real eye images, calibrate the threshold, record FAR/FRR (I-15).
8. Run each portal end-to-end on a phone and log the result in the CHANGELOG.
