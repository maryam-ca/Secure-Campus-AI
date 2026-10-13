# SecureCampus — Strict Requirements Audit

Performed by direct code inspection (grep/view/execution against the actual
files in the ZIP), not by recollection. Every claim below is either backed by
a quoted file/line or a command that was actually run. Where something could
not be verified without hardware/a live Firebase project, that is stated
explicitly rather than assumed.

---

## 1. Roles

**Verified clean.** `mobile/lib/core/constants/roles.dart`:
```dart
enum UserRole { admin, student, security, librarian, driver }
```
Project-wide search for "teacher" returns zero hits except one code comment
that explicitly states there is no Teacher role. Router (`app_router.dart`)
defines exactly 5 portal routes (`/admin`, `/student`, `/security`,
`/librarian`, `/driver`) plus `/login`, `/splash`, `/account-error`,
`/report-lost-card`. No teacher portal, no 6th role, no generic/unknown role
fallback.

## 2. Student System

| Requirement | Status | Evidence |
|---|---|---|
| Admin creates students | ✅ | `iris_ai/app/admin_api.py` `POST /admin/accounts` → `firebase_client.create_account()`, called from `admin_students_screen.dart` |
| Registration number unique | ⚠️ **Not enforced** | No uniqueness check exists anywhere — not in `create_account()`, not in the Flutter form, not a Firestore constraint (Firestore has no native unique-field constraints). It's a naming *convention*, not an enforced rule. |
| Firebase Authentication | ✅ | `firebase_admin.auth.create_user()` server-side; `FirebaseAuth.signInWithEmailAndPassword` client-side |
| Own-data-only isolation | ✅ | Enforced twice: router (`_pathForRole`) + `firestore.rules` (`resource.data.studentId == request.auth.uid`) |
| Profile / courses / attendance / bus / stop / library / notifications | ✅ | All present in `student_dashboard_screen.dart` + widgets, all backed by live Firestore queries in `student_repository.dart` |
| Cannot see other students / gate history / security / admin / driver / librarian functions | ✅ | Confirmed: `grep` across `features/student/` and `student_repository.dart` for `gateEntries`/`securityAlerts` → zero matches. Router forces students onto `/student` only; `firestore.rules` blocks `gateEntries`/`securityAlerts` reads for the student role entirely. |

## 3. AI Iris Recognition — direct answers to your 10 questions

1. **Which exact model/pipeline?** A classical Daugman/Masek-style pipeline implemented from scratch: Hough-circle-based pupil/iris segmentation → Daugman rubber-sheet normalization → 1-D Log-Gabor phase encoding → Hamming-distance matching. Not a pretrained deep-learning model (see docs/IRIS_MODEL.md §1 for why: no reachable weight repository in the build sandbox, and this avoids an undocumented-license/missing-weights risk).
2. **Implementation location:** `iris_ai/app/recognition/segmentation.py`, `normalization.py`, `encoding.py`, `matcher.py`, orchestrated by `app/pipeline.py`.
3. **Model weights:** None required — it's a deterministic algorithm, not a trained network. Nothing to download, nothing that can silently be missing.
4. **Embedding generation:** `encoding.py::encode_iris()` — row-wise 1-D Log-Gabor filter (FFT-based) on the normalized iris image, phase-quantized into a 2-bit Gray code per sample → a binary array (`IrisTemplate.code`) plus a validity mask (`IrisTemplate.mask`) is the embedding.
5. **Matching:** `matcher.py::compare_templates()` — fractional Hamming distance between two binary codes, restricted to bits both masks mark valid, minimized over a small range of angular shifts for rotation tolerance.
6. **Similarity metric:** Hamming distance, range [0.0, 0.5] (0 = identical, ~0.5 = statistically unrelated).
7. **Threshold location:** `app/config.py` line 28: `IRIS_MATCH_THRESHOLD: float = 0.32`.
8. **Configurable?** Yes — via `.env` (`IRIS_MATCH_THRESHOLD=0.32`), read by `pydantic_settings`.
9. **Unknown-person detection:** `pipeline.py::recognize_against_enrolled()` — if the best Hamming distance across all enrolled templates exceeds the threshold (or no reliable comparison exists), `is_known=False` is returned; `main.py` then routes to `create_unknown_alert()`.
10. **Actually executable?** Yes — verified by running it, not just reading it: `PYTHONPATH=. pytest tests/ -v` → **7/7 pass**, including a real bug found and fixed mid-build (the initial pupil detector was latching onto the whole iris instead of the pupil; a two-stage segmentation fix was required — see `docs/IRIS_MODEL.md` §5 for the full story). The FastAPI service was also booted and hit live over HTTP (`curl /health`, `/camera/status`, `/recognize/once`) with real, non-fabricated responses.

**No random prediction, no hardcoded identity, no "image exists = match" logic, no mock API response** — confirmed by a project-wide grep for `random|mock|fake|hardcod` in `iris_ai/app/`: every hit is a comment *disclaiming* that pattern, not code implementing it.

**Honest caveat (already documented, repeating here since you asked directly):** this pipeline was designed around near-infrared imaging; the iPhone 13 is an RGB camera. The same real algorithm runs on RGB frames, but accuracy is unvalidated against real people — `docs/IRIS_MODEL.md` §6 explicitly marks FAR/FRR/accuracy as **"not yet evaluated"** rather than inventing numbers. This is not a case of "IRIS AI NOT COMPLETE" — the pipeline is real, complete, and tested at the mechanics level; what's unverified is *accuracy against real students*, which requires real enrollment photos you haven't captured yet.

## 4. FastAPI / AI Service

**Present and real.** `iris_ai/app/main.py`. Registered routes (verified by importing the app and listing `app.routes`):
```
/health  /camera/status  /iris/enroll  /recognize/once
/stream/start  /stream/stop  /stream/status
/admin/accounts  /admin/accounts/deactivate
```
CORS middleware present (`allow_origins=["*"]` — fine for local dev, **should be tightened before any production deployment**, noted under Security Issues). Request/response schemas in `app/models/schemas.py` (Pydantic). Error handling: camera-offline, no-iris-detected, Firebase-not-configured, and Firestore query failures all raise/return explicit, non-fabricated error states — verified this directly (a curl against `/camera/status` with no RTSP configured returns `NOT_CONFIGURED`, not a faked `ONLINE`). `Dockerfile` present and complete.

**Is Flutter actually connected?** Partially, and precisely:
- ✅ `/admin/accounts`, `/admin/accounts/deactivate`, `/iris/enroll` — genuinely called from `backend_api_service.dart`, wired to real buttons in `admin_students_screen.dart` and `admin_accounts_screen.dart`.
- ❌ `/recognize/once`, `/stream/start`, `/stream/stop`, `/stream/status`, `/camera/status` — **never called from Flutter, anywhere.** These are meant to be operated by whoever runs the camera station (e.g. via curl or the `/docs` Swagger UI), not from the mobile app. This is architecturally defensible — attendance/gate recognition is meant to run as an autonomous camera loop, not a per-tap mobile action — **but there is currently no Admin-portal button to start/stop that camera recognition loop.** That's a genuine gap: today, the loop must be started manually via `curl -X POST http://<host>:8000/stream/start?mode=attendance`.

## 5. iPhone 13 Camera

RTSP integration is real (`iris_ai/app/camera/rtsp_stream.py`, `cv2.VideoCapture` with `CAP_FFMPEG`, connect/backoff/reconnect logic, explicit `ONLINE`/`OFFLINE`/`NOT_CONFIGURED`/`ERROR` states). `CAMERA_RTSP_URL` is read from `.env` (`app/config.py`), **not hardcoded** — confirmed by a project-wide IP-address grep, which found zero hardcoded non-local IPs (the only IP-looking string anywhere is inside a doc comment example). **Never tested against a real iPhone stream** — no phone/network available in this build environment.

The IR-camera claim is handled correctly: `docs/IRIS_MODEL.md` §5 explicitly and repeatedly states the iPhone 13 is an **RGB, not NIR/infrared** sensor, explains why that matters for accuracy, and documents the swap-in path for a real NIR camera later. No file anywhere claims the iPhone is an infrared camera.

## 6. Classroom Attendance

Real, not manual-insert. Flow verified end-to-end in `firebase_client.py::record_attendance()`:
- Course lookup: `find_active_course_for_camera()` matches the camera ID against a course's Admin-configured weekly `schedule` (day/start/end) — attendance is only recorded if a real scheduled session is active right now.
- `_ensure_class_session()` creates/reuses a `classSessions/{courseId}_{date}` doc — this is the actual "a class happened" record (needed as the denominator for the student's attendance %).
- Duplicate prevention: queries existing `attendance` docs for `studentId+courseId` within `ATTENDANCE_DEDUPE_MINUTES` before writing — confirmed in code, not asserted.
- Record contains studentId, registrationNumber, courseId, date, time, recognitionScore, cameraId/location, serverTimestamp — matches spec exactly.

This is only reachable through the real recognition pipeline (`process_image` → `recognize_against_enrolled` → `record_attendance`) — there is no separate "manually insert attendance" code path anywhere in the app or backend.

## 7. Student Attendance Display

`mobile/lib/models/course_model.dart::CourseAttendanceSummary` — `percentage` is a **getter**, computed as `present / totalSessions * 100` at read time, never stored. `student_repository.dart` populates `totalSessions` from real `classSessions` docs and `present` from real `attendance` docs for that student+course. No hardcoded percentage, no fake chart data anywhere in `features/student/widgets/course_attendance_card.dart`.

## 8. Campus Gate

Entry-only, confirmed by an explicit project-wide search for exit-scanning logic (`grep -in "exit.*scan\|exitEntry\|exit_verification"`) → **zero matches anywhere.** `record_gate_entry()` writes `status: "VERIFIED_ENTRY"` with studentId, registrationNumber, name, recognitionScore, cameraId/location, serverTimestamp. `firestore.rules`: `gateEntries` readable only by `isAdmin() || isSecurity()` — confirmed no student-role path can read this collection, and confirmed (§2 above) student-side Dart code never even references the collection name.

## 9. Unknown Person Alert

Real, with one important caveat found during this audit.

- **Frame capture:** the actual current frame is JPEG-encoded (`cv2.imencode`) in `main.py`'s recognition cycle — not a placeholder image.
- **Storage:** `firebase_client.py::create_unknown_alert()` uploads to Firebase Storage at `security_alerts/{cameraId}/{timestamp}.jpg`.
- **Firestore collection:** `securityAlerts` — `type`, `cameraId/location`, `imageUrl`, `bestMatchScore`, `status: "NEW"`, `createdAt`.
- **Notification:** `notify_role("security", ...)` — writes a real `notifications` doc for every active Security user **and** sends a real FCM push via `messaging.send()` — this is genuine FCM, not an in-app-only fake (see §19).
- **Duplicate prevention:** a per-camera cooldown (`UNKNOWN_ALERT_COOLDOWN_SECONDS`) queries recent alerts before creating a new one — confirmed in code.

**⚠️ Security finding:** immediately after upload, the code calls `blob.make_public()`. This sets the object's ACL to public at the Google Cloud Storage level, which **bypasses `storage.rules` entirely** (rules restrict reads to admin/security, but `make_public()` operates below the rules layer). In its current form, **anyone with the image URL — no login required — can view captured unknown-person photos.** This was flagged with a code comment at write-time but is a real inconsistency between the stated access policy and the actual implementation. See Security Issues.

## 10. Security Portal

`security_dashboard_screen.dart` — real: tabs for recent verified entries (`gateEntries` stream) and unknown-person alerts (`securityAlerts` stream, showing the actual `imageUrl`, timestamp, and a mark-resolved button that writes `status` via `firestore.rules`' restricted `isSecurity()` update path, which only permits changing the `status` field — confirmed by reading the rule). No Admin-only functions are reachable: the router hard-locks a `security` role account to `/security`; there is no navigation path to `/admin` anywhere in the security screen's code.

## 11. Lost Student Card

Full flow present and real, including a piece the original chat build initially lacked: a **public entry point** for a finder who isn't a SecureCampus account holder. `features/common/found_card_report_screen.dart` — reached via an anonymous Firebase Auth session (`AuthService.signInAnonymously()`), which satisfies `firestore.rules`' `allow create: if isSignedIn()` on `lostCardReports` without needing a real account. Form fields match spec exactly (name/regNo/location/description + found date). Admin sees the queue (`admin_lost_cards_screen.dart`) and can notify by registration number (`admin_repository.dart::notifyStudentCardFound()`), which looks up the student, writes a `notifications` doc with the Rs. 100 fine text, and sets `notified: true`.

**No payment code exists anywhere** — confirmed by a project-wide search for "payment", "transaction", "gateway", "stripe", "checkout" → zero hits.

## 12. Library

`scripts/seed_firebase.py` defines exactly 5 books, IDs `BOOK-001`–`BOOK-005`, each with title/author/category. `scripts/generate_qr_codes.py` was **run during this audit** — regenerated all 5 PNGs and independently decoded each one back with OpenCV's `QRCodeDetector` to confirm it reads back the exact book ID:
```
BOOK-001.png -> decodes to 'BOOK-001' [OK]   (...through BOOK-005, all OK)
```
This is a real, verified round-trip, not an assumed one. The Librarian scanner (`librarian_scan_screen.dart`, `mobile_scanner` package) reads the raw QR payload (the book ID string) and looks it up via `fetchBookById()` against the real `books` collection.

## 13. Librarian

`librarian_scan_screen.dart` (scan → identify → issue form with manual registration-number entry, auto-lookup of the matching student for linkage, issue/expiry date pickers) → `librarian_repository.dart::issueBook()` writes `libraryIssues` **and** flips `books/{id}.available = false` in one batched write. `librarian_issued_books_screen.dart` lists active issues with an overdue badge and a return button (`returnBook()`, batched: `returned: true` + `available: true`). The resulting doc includes `studentId`, so it correctly appears on that student's own portal (`libraryIssues` rule: `isStudent() && resource.data.studentId == request.auth.uid`).

## 14. Library Overdue

**Detection: real. Notification: not implemented — this is a genuine gap.**

`LibraryIssueModel.status` (`dashboard_models.dart`) computes `overdue` live via `DateTime.now().isAfter(expiryDate)` — never a stored, staleable flag. Both the Librarian's and the Student's screens display this correctly. **However**, a project-wide search confirms `'LIBRARY_OVERDUE'` appears **only once**, as a UI icon-mapping `case` in `notifications_section.dart` — there is no script, job, or Cloud Function anywhere that scans `libraryIssues` for newly-overdue books and actually creates that notification. A student will see the OVERDUE badge if they open the app, but will never receive a notification telling them a book has become overdue.

## 15. Bus

Single bus, single driver — confirmed. `seed_firebase.py` creates exactly one `bus/BUS-001` doc and one driver account. `bus_eta/app/config.py` defaults `BUS_ID: str = "BUS-001"`. No multi-bus data model, no bus-selection UI anywhere (Admin's bus screen hardcodes the single `_busId = 'BUS-001'` constant). Admin can assign/remove student↔stop assignments (`assignStudentToBus()`/`removeBusAssignment()`) and manage stops (`upsertBusStop()`). Student sees Assigned/Not-Assigned + stop name only — confirmed no map widget is reachable from the student portal (`grep` for `GoogleMap`/`google_maps_flutter` inside `features/student/` → zero hits).

## 16. Driver Portal

`driver_dashboard_screen.dart` — real `geolocator` integration: checks `Geolocator.isLocationServiceEnabled()` and permission status explicitly, shows a real error message and **does not proceed** if either fails (no fallback to fake coordinates — confirmed, the "current location" field only ever shows real `Position` data or the literal string `"GPS UNAVAILABLE"`). Start Trip generates a real `tripId`, subscribes to `Geolocator.getPositionStream()`, and pushes each real fix to Realtime Database. Stop Trip cancels the subscription and writes `tripActive: false`. **Never run on a real device** — no hardware available in this environment.

## 17. Admin Bus Map

**❌ Not implemented as a map.** This is a confirmed, direct spec miss, not a matter of interpretation.

`google_maps_flutter` is declared in `pubspec.yaml` but a project-wide search (`grep -rn "GoogleMap"`) returns **zero usages anywhere in the codebase.** `admin_bus_screen.dart` only calls `fetchBusStatus()`, which returns one of three plain strings: `"Trip Active"`, `"Idle (last known location on file)"`, or `"GPS UNAVAILABLE"` — Admin never sees the driver's actual latitude/longitude, on a map or otherwise (confirmed: the only `lat`/`lng` references in `admin_bus_screen.dart` are for configuring static **bus stops**, not reading the live driver position). "Last update time" is also not surfaced to Admin despite being stored (`updatedAt` field exists in RTDB but is never read/displayed in the Flutter admin UI).

## 18. Bus 10-Minute Notification

Real math, real dedup, genuinely tested. `bus_eta/app/geo.py`:
- `haversine_km()` — real great-circle distance. **Tested against a known real-world value**: Islamabad→Lahore computed at 260–290km (actual ~275km) — this test was re-run during this audit and passed.
- `fetch_routing_eta_minutes()` — optional real Google Distance Matrix API call when `MAP_API_KEY` is set; falls back to `haversine + AVG_BUS_SPEED_KMH` otherwise, and the fallback is explicitly labeled (`method: "haversine_fallback"`) rather than silently presented as routing-accurate.
- `service.py::run_once()` — reads live `driverLocation` from RTDB (Admin SDK), computes ETA to every assigned student's real registered stop, and calls `notify_student_bus_arriving()` only when ETA ≤ `ALERT_THRESHOLD_MINUTES` (default 10) **and** `busAssignments/{id}.lastAlertTripId != current tripId` — this is the per-trip dedup mechanism (a new `tripId` is generated each time the driver starts a trip, so one alert fires per student per trip, not one per polling cycle).
- Verified by execution: `PYTHONPATH=. pytest tests/ -v` → **5/5 pass**, re-run during this audit.
- Students confirmed not shown a live map (§17/§15 above).

## 19. Notifications

**Real FCM infrastructure, with one real display gap.**

- Backend: `messaging.send(messaging.Message(...))` — actual FCM calls in both `iris_ai/app/firebase_client.py` and `bus_eta/app/firebase_client.py`, reading the recipient's `users/{uid}.fcmToken`.
- Client token registration: `push_notification_service.dart` — `requestPermission()`, `getToken()`, `onTokenRefresh` listener, all writing to Firestore. Wired into app startup via a Riverpod listener (`auth_provider.dart::_pushRegistrationProvider`) that fires as soon as a user signs in — confirmed this is actually reachable from `main.dart`'s provider graph, not dead code.
- Persistence: every notification is also a `notifications` Firestore doc with `isRead`, confirmed read/unread toggle exists and is rules-restricted to the recipient updating only their own `isRead` field.
- The only SnackBar in the entire notification-adjacent code is a one-off UI confirmation ("student notified") after an Admin action — **not** a substitute for the actual push mechanism; confirmed by checking every `SnackBar` usage project-wide.
- **Gap found:** there is no `FirebaseMessaging.onMessage` (foreground) or `onBackgroundMessage` handler registered anywhere. Background/terminated-app notifications will likely display via the OS's default FCM handling (since the backend sends a `notification` payload with title/body), but **while the app is open, nothing will visibly pop up** without this handler — the notification still lands in Firestore/the in-app Notification section, just not as a system banner while the app is in the foreground.
- **Never tested end-to-end** against a real device — no hardware available here.

## 20. Firebase Security

Reviewed `firestore.rules`, `database.rules.json`, `storage.rules` directly, line by line. Role source of truth is `users/{uid}.role` + `.active`, checked via a `hasRole()` helper reused consistently. No collection is unconditionally publicly readable or writable in the rules text itself. Two real issues found (both already noted above, consolidated here):

1. **Storage: `make_public()` bypasses `storage.rules`** on unknown-person images — the rules say admin/security-only, the actual upload code makes the object public at the GCS ACL layer. This is the most important finding in this entire audit.
2. **RTDB: `driverLocation/{busId}` has no field whitelist.** `.validate` rules exist for `lat`/`lng`/`updatedAt`/`tripActive`, but not for `tripId` (which the app does write) or any other key — Realtime Database rules allow undeclared fields by default, so a compromised driver client could write arbitrary extra data to that path. Not a cross-role read/write hole (the driver-identity check `driverAssignments/{uid} === $busId` is sound), but a data-integrity gap.

No other unconditional `allow read/write: if true` was found anywhere in any of the three rules files.

## 21. UI/UX

Consistent white+blue Material 3 theme (`core/theme/app_theme.dart`) applied uniformly — confirmed no screen defines its own colors outside `AppColors`. Loading/error/empty states are present via `AsyncValue.when()` patterns across every data-driven screen (confirmed by spot-checking `admin_dashboard_screen.dart`, `student_dashboard_screen.dart`, `security_dashboard_screen.dart`, `librarian_issued_books_screen.dart`). Responsive layout: `AdminHomeShell` switches between a drawer and a permanent side rail based on width; `GridView.count` on the dashboard adapts column count to width.

**Gaps found:**
- **No search or filter UI anywhere** — confirmed by project-wide search for search-related widgets. Spec explicitly asked for "Search, Filters where needed."
- **No confirmation dialogs before destructive actions** — deactivating an account, removing a bus assignment, etc. all fire immediately on tap with no "Are you sure?" step.
- `portal_coming_soon_screen.dart` still exists in the codebase but is now **dead code** — confirmed unreferenced by any import — a leftover from before the real Admin/Security/Librarian/Driver screens were built; harmless but should be deleted for cleanliness.

## 22. Database

| Collection | Purpose | Actually Used? | Real Data? |
|---|---|---|---|
| `users` | role/active/fcmToken | ✅ Both sides | ✅ |
| `students` | student profile fields | ✅ Both sides | ✅ |
| `courses` | course + camera + schedule | ✅ Both sides | ✅ |
| `enrollments` | *(originally planned student↔course join)* | ❌ **Unused** — declared in `firestore.rules` only; course membership is actually stored as an array field on `students` instead. Orphaned rule block. | — |
| `irisProfiles` | biometric templates | ✅ Backend only (by design — rules deny all client access) | ✅ |
| `attendance` | per-session records | ✅ Both sides | ✅ |
| `classSessions` | "a class happened" denominator | ✅ Both sides | ✅ |
| `gateEntries` | entry-only log | ✅ Both sides | ✅ |
| `securityAlerts` | unknown-person events | ✅ Both sides | ✅ |
| `lostCardReports` | finder submissions | ✅ Flutter only (no backend need) | ✅ |
| `books` | library catalog | ✅ Both sides | ✅ |
| `libraryIssues` | issue/return records | ✅ Flutter only (no backend need) | ✅ |
| `bus` | the one bus doc | ✅ Both sides | ✅ |
| `busStops` | stop config | ✅ Both sides | ✅ |
| `busAssignments` | student↔stop, `lastAlertTripId` dedup | ✅ Both sides | ✅ |
| `notifications` | in-app + push trigger record | ✅ Both sides | ✅ |
| RTDB `driverLocation/{busId}` | live GPS | ✅ Both sides | ✅ |
| RTDB `roles/{uid}`, `driverAssignments/{uid}` | RTDB-side role mirror | ✅ Backend writes, rules read | ✅ |

No duplicated data found beyond intentional, documented denormalization (e.g. `stopName` copied onto `busAssignments` for read efficiency — a normal, deliberate tradeoff, not an error). No collection found with obviously missing required fields in the writer code. The one real issue is `enrollments` being entirely orphaned.

## 23. Dummy/Mock Audit

Full project-wide, case-insensitive search for `mock|dummy|fake|placeholder|TODO|hardcod|sample|random|simulat`, run fresh during this audit. **Zero occurrences of actual fake/mock/hardcoded logic.** Every hit (~30 total) is one of:
- A comment explicitly *disclaiming* that pattern ("no mocked fallback", "not a placeholder", "no random assignment") — self-documentation, not implementation.
- Legitimate technical use of "sample" (signal-processing sampling in `normalization.py`/`matcher.py`).
- Legitimate `random`/`secrets` use for generating real temporary account passwords (`seed_firebase.py`) — appropriate randomness, unrelated to AI/recognition logic.
- `?? 0.0` / `?? ''` null-safety fallback defaults on Firestore field parsing — standard defensive coding, not fabricated data.
- `portal_coming_soon_screen.dart`'s own docstring, which explicitly describes itself as "a deliberately honest placeholder" — and which, per §21, is now unreferenced dead code anyway.

**Zero `TODO` comments exist in the entire codebase.**

## 24. Runnability

**Python side: verified working by execution**, re-run fresh during this audit:
```
iris_ai:  PYTHONPATH=. pytest tests/ -q  →  7 passed
bus_eta:  PYTHONPATH=. pytest tests/ -q  →  5 passed
python3 scripts/generate_qr_codes.py     →  5/5 QR codes generated + decode-verified
python3 -m py_compile <every .py file>   →  no syntax errors
```
`requirements.txt` present and installable for both services (confirmed by installing them). `Dockerfile`/`docker-compose.yml` present for both services.

**Flutter side: cannot be verified in this environment**, and this is the single largest open risk:
- No Flutter SDK is available in the build sandbox, so `flutter pub get` / `flutter analyze` / `flutter build` were **never run**. A static consistency sweep was performed instead (every relative import resolves to a real file; every referenced class exists under the exact name used; every imported `package:` is declared in `pubspec.yaml`; brace/parenthesis balance across all 48 files) — this caught one real bug (a Kotlin-style `.let()` call, invalid Dart, found and fixed) but **cannot catch type errors, null-safety violations, or Flutter/package API misuse.** Treat the Dart code as "believed correct, not compiler-verified."
- **`android/` and `ios/` native platform folders do not exist** in `mobile/` — confirmed by directory listing. `flutter run`/`flutter build` cannot work at all until `flutter create --platforms=android,ios .` is run inside `mobile/` (documented in `docs/MOBILE_PLATFORM_SETUP.md`, including the exact camera/location/notification permission entries needed afterward — but this step has never actually been executed).
- `lib/firebase_options.dart` does not exist (by design — no real Firebase project was available to generate it against).

**Exact commands required, in order:**
```
# Backend (verified working)
./setup.sh && ./run.sh

# Flutter (never executed in this environment)
cd mobile
flutter create --platforms=android,ios .
# then edit AndroidManifest.xml / Info.plist per docs/MOBILE_PLATFORM_SETUP.md
flutter pub get
flutterfire configure
flutter analyze     # first real compile check — expect to fix issues here
flutter run
```

## 25. One-Command Requirement

`setup.sh`/`setup.bat` and `run.sh`/`run.bat` exist and were exercised (setup installs both Python venvs and generates QR codes; run starts `bus_eta` in the background and `iris_ai` in the foreground). **This is honestly one-command only for the backend.** It is **not** one-command for the whole system, and I will not claim otherwise:
- `setup.sh` does call `flutter pub get` *if* a Flutter SDK happens to be on the developer's PATH, but it does **not** run `flutter create` even when Flutter is available — a real gap, since without native folders `pub get` alone doesn't make the app runnable.
- Firebase project creation, rules deployment, and `flutterfire configure` are manual, unavoidable, one-time steps (documented in `firebase/README.md`) — no script can create your Firebase project or your device's platform folders for you.
- `flutter run` is inherently interactive (device/emulator selection) and cannot be scripted into a background command.

## 26. Final Audit Report

### COMPLETE FEATURES
- 5-role system, no Teacher role, enforced in router + rules
- Firebase Auth-based login/session/redirect for all 5 roles
- Real iris recognition pipeline (segmentation/normalization/encoding/matching), tested, threshold-configurable
- FastAPI service (camera status, enroll, recognize, stream loop, admin account creation) — booted and hit live
- RTSP camera integration code (connect/reconnect/offline handling) — untested against real hardware
- Classroom attendance: course-schedule-gated, deduplicated, real Firebase writes, real client-computed percentage
- Gate entry (entry-only, no exit path exists), Admin/Security-only visibility
- Unknown-person alert: real capture → Storage → Firestore → FCM, cooldown-deduplicated
- Security portal: real entries/alerts, resolve action
- Lost card: full flow including a public (anonymous-auth) finder entry point, no payment code anywhere
- Library: 5 real seeded books, real generated+verified QR codes, real scan→issue→return flow, real batched availability updates
- Single bus/single driver enforced everywhere, no multi-bus code
- Driver portal: real GPS via geolocator, explicit permission/service-disabled handling, no fake coordinates
- Bus ETA job: real haversine math (verified against a known real-world distance) + optional real routing API, per-trip dedup
- FCM token registration + real backend push-send calls
- Firestore/RTDB/Storage rules covering every collection, role-consistent (with 2 exceptions below)
- Zero fake/mock/hardcoded logic found anywhere in a full project sweep

### PARTIALLY COMPLETE
- FastAPI↔Flutter integration: account creation & iris enrollment are wired; the recognition/camera-loop endpoints are not called from the app at all (no Admin UI to start/stop live recognition)
- Notifications: infrastructure is real and complete, but no foreground FCM display handler exists, and it's never been exercised against a real device
- Library overdue: detection is real and live; the notification that's supposed to fire when a book goes overdue is **never actually sent** (no job creates it)
- Admin bus visibility: status only ("Trip Active"/"Idle"/"GPS UNAVAILABLE"); real coordinates and last-update time are never surfaced despite being stored
- One-command startup: true for the backend only; Flutter requires several manual, undocumented-in-scripts steps

### NOT IMPLEMENTED
- **Admin live bus map** (spec §17/§34 explicitly asked for one) — `google_maps_flutter` is a declared dependency with zero actual usage anywhere
- Registration-number uniqueness enforcement
- Search/filter UI anywhere in the app
- Confirmation dialogs before destructive actions
- Overdue-book notification job
- Native Android/iOS platform folders (`flutter create` was never run)

### FAKE/MOCK FUNCTIONALITY FOUND
**None.** This was checked explicitly and thoroughly (§23) — no fake AI, no fake GPS, no hardcoded attendance/stats, no placeholder images used as real captures, no simulated camera feed. The one file that describes itself as a "placeholder" (`portal_coming_soon_screen.dart`) is dead code, not something a user can reach.

### TECHNICAL ERRORS
- Flutter/Dart code has **never been compiled** — only structurally sanity-checked. Real compile errors are possible and should be expected on first `flutter analyze`.
- `android/`/`ios/` folders missing entirely — `flutter run` cannot work until generated.
- `mobile/lib/firebase_options.dart` does not exist — must be generated via `flutterfire configure`.
- `enrollments` Firestore rule block is dead/orphaned.

### SECURITY ISSUES
1. **Unknown-person images are made public at the Storage ACL layer** (`blob.make_public()`), bypassing `storage.rules`' admin/security-only read restriction. Anyone with the URL can view a captured photo without authentication. **This should be fixed before any real deployment** — remove `make_public()` and serve images via signed URLs or authenticated Storage reads instead.
2. **RTDB `driverLocation` write path has no field whitelist** — `tripId` and any other extra key can be written without validation (though the driver-identity check itself is sound).
3. CORS on the FastAPI service is wide open (`allow_origins=["*"]`) — acceptable for local dev, not for a public deployment.
4. Registration numbers are not uniqueness-enforced, which could let Admin (accidentally or maliciously) create two accounts that collide in downstream lookups (e.g. the Librarian's registration-number search would return an arbitrary one of the two).

### AI/ML STATUS
- **Model:** Classical Daugman/Masek algorithmic pipeline (not a pretrained deep network)
- **Model weights:** None required
- **Preprocessing:** Grayscale conversion + Gaussian/median blur inside segmentation
- **Segmentation:** Two-stage Otsu + percentile-sweep pupil detection, Hough-circle iris boundary — real, tested, one real bug found and fixed during development
- **Normalization:** Daugman rubber-sheet model, 64×512 fixed output, heuristic eyelid-occlusion masking
- **Embedding:** 1-D Log-Gabor phase-quantized binary code + mask
- **Matching:** Fractional Hamming distance, rotation-tolerant shift search
- **Threshold:** `IRIS_MATCH_THRESHOLD=0.32`, env-configurable, **not yet calibrated against real students**
- **Unknown detection:** Best-match distance above threshold (or no reliable comparison) → `is_known=False` → real alert path
- **FastAPI:** Real, booted, live-tested
- **RTSP:** Real code, untested against real hardware
- **Actual end-to-end integration:** Camera → recognition → Firebase write path is real and wired; Flutter app integration is limited to enrollment and account creation, not live-recognition control

### FINAL SCORE: **63 / 100**

Breakdown of where points were lost, strictly against your requirements (not UI polish):
- **-10** Flutter app has never been compiled; native platform folders don't exist — the primary demo artifact's runnability is unverified
- **-8** Admin live bus map explicitly required and not implemented at all
- **-6** Overdue-book notification never fires (detection works, the notification doesn't)
- **-5** Public Storage ACL bypass on unknown-person images — a real security inconsistency
- **-4** No Admin UI to control the live recognition camera loop
- **-3** Registration-number uniqueness not enforced
- **-3** No search/filter UI, no destructive-action confirmations
- **-2** No foreground push-display handler; push never tested end-to-end
- The remaining ~63 points reflect that the hardest, most-scrutinized requirement — real, non-fake, tested iris recognition with a real FastAPI service, real RTSP architecture, real Firebase data model and rules, real GPS, real QR, and a genuinely clean dummy/mock audit — is legitimately done, not faked, and not hidden behind a nice UI.

---

# Can I practically demonstrate this FYP right now?

## NO — exact blockers, in the order you'd hit them:

1. **`mobile/` has no native Android/iOS project.** `flutter run` will not work at all until you run `flutter create --platforms=android,ios .` inside `mobile/` and add the permissions listed in `docs/MOBILE_PLATFORM_SETUP.md`.
2. **The Flutter/Dart code has never been compiled.** The first `flutter analyze` after step 1 may surface real errors that need fixing — treat this as expected, not optional.
3. **No Firebase project is wired up yet from the app's side** — `lib/firebase_options.dart` doesn't exist until you run `flutterfire configure` against your real project, and `firestore.rules`/`database.rules.json`/`storage.rules` need to actually be deployed (`firebase deploy --only firestore:rules,firestore:indexes,storage:rules`, plus publishing the RTDB rules).
4. **No data exists yet** — run `python scripts/seed_firebase.py` to create the 10 students/books/bus/driver/courses/stops as real records.
5. **No student has an enrolled iris** — enrollment requires a real captured eye photo per student via `POST /iris/enroll` (or the Admin portal's enroll button once the app runs), and `IRIS_MATCH_THRESHOLD` should be sanity-checked against a few real comparisons before you trust it in front of an audience.
6. **No RTSP stream is connected** — needs the physical iPhone 13 running OctoStream on the same Wi-Fi as whatever machine runs `iris_ai`.
7. **No admin UI exists to start the live recognition loop** — until built, you'll need to trigger `/stream/start` manually (curl or the `/docs` page) during the demo.

None of these are fake-work-required-to-fix — they're the real, expected remaining steps for a system built with a strict no-fake-data policy, exactly as `docs/LIMITATIONS.md` said from the start. But as of right now, today, you cannot walk into a room and demo this system — steps 1–3 alone are non-negotiable prerequisites.
