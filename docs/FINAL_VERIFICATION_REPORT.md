# SecureCampus — Final Verification Report (Post-Update)

Everything below reflects the state after: (1) updating to current-stable
2026 toolchain versions, (2) fixing all items from the prior audit
(`docs/AUDIT_REPORT.md`), (3) actually re-running every test that could
be run in this environment. Nothing here is claimed without the
verification method stated alongside it.

## COMPLETED

*(Built, and actually verified by execution in this environment.)*

- **Iris recognition pipeline**, re-verified against true-latest
  OpenCV 5.0.0.93 + NumPy 2.5.2 (both major-version jumps from before) —
  7/7 tests pass.
- **`iris_ai` FastAPI service**, re-verified booted + live HTTP round
  trips against the updated dependency set, including:
  - `/admin/accounts` and `/stream/start`/`/stream/stop` correctly
    reject unauthenticated requests (401), reject invalid tokens
    against an unconfigured Firebase project with an honest 503 (not a
    false success), and correctly validate request bodies (422) before
    auth is even checked — the full auth chain was traced end-to-end.
  - `/camera/status` and `/health` return real, non-fabricated status.
- **`bus_eta` service**, re-verified against true-latest dependencies —
  5/5 tests pass, including the real-world Islamabad–Lahore distance
  sanity check.
- **QR generation**, re-verified against true-latest `qrcode`/`pillow` —
  all 5 books generate and independently decode correctly.
- **Security fix**: `blob.make_public()` removed; unknown-person images
  now use a private Storage path + `getDownloadURL()` resolved live and
  gated by `storage.rules` on every call. Applied consistently in both
  the backend (`imagePath` instead of `imageUrl`) and both Flutter
  screens that display these images (Admin + Security).
- **RTDB field whitelist** on `driverLocation` — unexpected fields are
  now rejected (`$other: {".validate": false}`), matching what
  `driver_repository.dart` actually writes.
- **Registration-number uniqueness**, race-safe: a Firestore
  transaction reserves `registrationNumbers/{regNo}` before the Auth
  account is created, with rollback on failure. `seed_firebase.py`
  refactored to use the same path instead of duplicating logic.
- **`firebase.json` created** — did not exist before, meaning no
  `firebase deploy` command could have worked at all regardless of the
  rules files' own correctness.
- **Overdue-book Cloud Function** (`functions/main.py`) — a real,
  current-mechanism (Python Cloud Functions v2, `onSchedule`) fix for
  the notification that previously never fired. Installed the real
  `firebase-functions` package and import-verified against it.
- **Admin camera controls** — new screen; the backend endpoints it
  calls are now properly admin-auth-gated (previously open to anyone
  who could reach the service).
- **Foreground FCM handling** — was completely absent; now a real
  `onMessage` listener shows an in-app banner, plus a registered
  `onBackgroundMessage` handler.
- **Admin live bus map** — `google_maps_flutter` was a declared
  dependency with zero actual usage before; now a real `GoogleMap`
  widget with a live driver marker (from a real RTDB stream) and stop
  markers, showing "GPS UNAVAILABLE" honestly when there's no location
  on file. Confirmed the student portal still has zero map references.
- **Search/filter UI**: Admin Students (name/reg-no/program),
  Admin Library + Librarian Catalog (search + availability filter),
  Security Alerts (status filter).
- **Confirmation dialogs** before every destructive action that exists
  in the app: deactivate student, deactivate staff account, remove bus
  assignment, stop trip.
- **Dead code removed**: `portal_coming_soon_screen.dart` (confirmed
  zero remaining references).
- **Dependency versions**: real current PyPI versions installed and
  tested for `iris_ai`/`bus_eta`/`functions`; Flutter `pubspec.yaml`
  floors updated to researched-current numbers with `^` constraints so
  `flutter pub get` resolves newer automatically.

## PARTIALLY COMPLETED

- **Flutter/Dart code as a whole**: extensively rewritten and
  cross-checked (imports resolve, referenced classes exist, packages
  declared, brace/paren balance across all 50 files — re-run fresh this
  session, clean) — but **still never compiled**, because this
  environment has no Flutter SDK and no network path to `pub.dev`. This
  static sweep caught two real bugs earlier in this project's build
  (documented in `docs/LIMITATIONS.md`) but cannot catch type errors or
  Flutter API misuse. Treat as "believed correct, not compiler-verified"
  until you run `flutter analyze`.
- **Android/iOS toolchain versions**: researched (AGP ~9.2, Gradle ~9.5,
  Kotlin ~2.2, compileSdk 36, JDK 17) but never applied to an actual
  generated project, since `flutter create` was never run here — no
  `android/`/`ios/` folders exist in this ZIP.
- **Push notifications**: token registration, foreground display, and
  background handler are all real code, but never exercised end-to-end
  against a real device — no hardware available here.

## NOT IMPLEMENTED

- Nothing from the prior audit's "Not Implemented" list remains
  unimplemented in terms of application code — every item (map,
  overdue notification, camera controls, uniqueness, storage security,
  RTDB validation, search/filter, confirm dialogs, dead code) has real
  code now. What's *not* implemented is still the physical/
  infrastructure side that no amount of code can substitute for: a real
  Firebase project with these rules/functions actually deployed, a
  real iPhone RTSP stream connected, real students iris-enrolled, and
  a compiled, running Flutter app on a real device.

## BUILD ERRORS

- **Unknown for Flutter** — cannot be determined without a Flutter SDK.
  Run `flutter pub get && flutter analyze` as the very first step; fix
  whatever it reports.
- **None for Python** — every service (`iris_ai`, `bus_eta`,
  `functions`) was syntax-checked, dependency-installed, and either
  test-suite-verified or import-verified fresh this session, with zero
  outstanding errors.
- One real build-breaking issue *was* found and fixed during this
  session's dependency update (the `email-validator` gap — see
  `docs/VERSION_AUDIT.md` for the full story) — it is fixed, not
  outstanding.

## FIREBASE ERRORS

- None observed *in the rules/config themselves* — `firestore.rules`
  and `storage.rules` brace-balance clean, all `.json` rule/index files
  parse as valid JSON, `firebase.json` is valid and now exists.
- **Cannot rule out deploy-time errors** without a real project to
  deploy against — Firestore composite indexes in particular are only
  fully validated by Firestore itself at query time; `firebase/firestore.indexes.json`
  was hand-maintained to match every compound query in the codebase
  (including the new one the overdue-check Cloud Function needs) but
  this was cross-referenced by inspection, not proven by a live
  `firebase deploy`.
- The overdue Cloud Function additionally requires the Blaze billing
  plan and Cloud Scheduler API enabled — documented in
  `firebase/README.md`, not something any code fix can satisfy for you.

## SECURITY ISSUES

All four items from the prior audit are fixed (see COMPLETED above):
unknown-person image public exposure, RTDB unrestricted fields,
registration-number race condition, and no admin-auth gate on the
camera-control endpoints. Remaining, previously-noted and still
accurate:
- CORS on `iris_ai` remains `allow_origins=["*"]` — fine for local dev,
  tighten before any real deployment (not changed this session since
  it wasn't in the fix list, but still worth flagging again).
- No rate limiting on any FastAPI endpoint — not a project-spec
  requirement, but worth knowing for a real deployment.

## AI/ML STATUS

Unchanged in substance from the original audit, re-verified against
the new dependency versions:
- **Model**: Classical Daugman/Masek algorithmic pipeline (no
  pretrained weights required)
- **Segmentation/Normalization/Encoding/Matching**: all real, all
  re-tested against OpenCV 5.0.0.93 + NumPy 2.5.2 — 7/7 pipeline tests
  still pass after the major-version dependency jump
- **Threshold**: `IRIS_MATCH_THRESHOLD=0.32`, env-configurable, still
  **not calibrated against real students** (needs real enrollment data
  you don't have yet)
- **Unknown detection**: real, unchanged logic
- **FastAPI integration**: real, re-verified this session via actual
  HTTP round trips including the new auth-gating
- **RTSP**: real code, still never tested against the physical iPhone

## DEVICE/PROJECT-DEPENDENT ITEMS

*(Cannot be resolved by any further code change — genuinely require
your own hardware, accounts, or a live deployment.)*

- A real Firebase project, with billing enabled if you want the
  overdue-book Cloud Function.
- Running `flutter create`, `flutter pub get`, `flutter analyze`,
  `flutter build apk --debug` against a real Flutter SDK.
- A Google Maps API key configured natively for the Admin live map.
- The physical iPhone 13 running OctoStream on the same network as
  `iris_ai`.
- Real captured eye photos for the 10 students' iris enrollment, and
  threshold recalibration against them.
- A real Android/iOS device or emulator to actually run the app, grant
  camera/location/notification permissions, and receive a push.
- A real driver device with GPS to test the bus ETA job and the map
  against genuine movement.

## EXACT REMAINING MANUAL STEPS

In the order you'd actually hit them:

1. `cd mobile && flutter create --platforms=android,ios .` then add the
   permissions + Maps API key from `docs/MOBILE_PLATFORM_SETUP.md`.
2. `flutter pub get && flutter pub outdated && flutter analyze` — fix
   whatever the analyzer flags; this is the first real compile check
   this code has ever had.
3. `flutter build apk --debug` — first real build.
4. Create the Firebase project (enable Blaze if you want the scheduled
   function), `firebase login`, `firebase use --add`.
5. `firebase deploy --only firestore:rules,firestore:indexes,storage:rules,database`
   then `firebase deploy --only functions` — **run both from the repo
   root**, where `firebase.json` lives.
6. `flutterfire configure` inside `mobile/`.
7. Fill in `.env` from `.env.example`, put your service-account JSON at
   `./secrets/serviceAccountKey.json`.
8. `python scripts/seed_firebase.py`.
9. `./setup.sh && ./run.sh` (or the `.bat` equivalents) to bring up
   `iris_ai` + `bus_eta`.
10. Connect the real iPhone RTSP stream; verify `/camera/status` shows
    `ONLINE`.
11. `flutter run --dart-define=BACKEND_BASE_URL=http://<your-machine-ip>:8000`
    on a real device.
12. Log in as Admin, enroll the 10 students' irises via the new camera
    capture button, calibrate `IRIS_MATCH_THRESHOLD` against a few real
    comparisons, start the recognition loop from the new Camera screen.
13. Test each portal end-to-end against real data.
