# Version Audit — Current Stable Toolchain (Sept 2026)

This documents exactly what versions this project was updated to, and —
critically — exactly how each was verified, since this build
environment has no Flutter/Dart/Android SDK and no network path to
`pub.dev`, `dl.google.com`, or `storage.googleapis.com` (confirmed via
direct `curl` — all return 403 at the network layer, not a settings
issue). Two verification methods were used, and this doc is explicit
about which applies to which component:

- **Executed**: actually installed/run/tested in this sandbox (PyPI and
  npm registries are reachable here).
- **Researched**: confirmed via web search against official sources
  (docs.flutter.dev, firebase.google.com, developer.android.com), dated
  and cited, but never executed against a real toolchain.

## Before → after

| Component | Before this update | After | Method |
|---|---|---|---|
| Dart SDK floor (pubspec `environment.sdk`) | `>=3.3.0` | `>=3.9.0` | Researched — Flutter 3.47.1 ships Dart 3.13.1 (docs.flutter.dev, confirmed Aug 19 2026 release) |
| firebase_core | `^3.1.0` | `^4.6.0` | Researched — official BoM 4.11.0 table, firebase.google.com/support/release-notes/flutter, dated 2026-03-23 |
| firebase_auth | `^5.1.0` | `^6.3.0` | Researched — same source |
| cloud_firestore | `^5.0.1` | `^6.2.0` | Researched — same source |
| firebase_database | `^11.0.1` | `^12.2.0` | Researched — same source |
| firebase_storage | `^12.1.0` | `^13.2.0` | Researched — same source |
| firebase_messaging | `^15.0.1` | `^16.1.2` | Researched — BoM 4.10.0 table (2026-03-02), same source family |
| fastapi | 0.111.0 | 0.141.1 | **Executed** — queried live via `pip index versions`, installed, full test suite re-run and passing |
| uvicorn | 0.30.1 | 0.52.4 | Executed — same |
| pydantic / pydantic-settings | 2.7.4 / 2.3.4 | 2.13.5 / 2.15.0 | Executed — same |
| opencv-python-headless | 4.10.0.84 | 5.0.0.93 (major version jump) | Executed — installed the true major-version-5 release and re-ran the full iris pipeline test suite against it; all 7 tests still pass |
| numpy | 1.26.4 | 2.5.2 (major version jump) | Executed — same test re-run |
| firebase-admin (Python) | 6.5.0 | 7.5.0 | Executed — same |
| qrcode / pillow | 7.4.2 / 10.3.0 | 8.2 / 12.3.0 | Executed — QR generation + independent decode-verification re-run and passing |
| pytest | 8.2.2 | 9.1.1 | Executed |
| python-dotenv / requests / python-multipart | various | latest | Executed |
| email-validator | *(missing entirely)* | 2.3.0, added | **Real bug found and fixed** — see below |
| Docker base image (both Python services) | `python:3.12-slim` | unchanged | Deliberately kept at the version actually verified end-to-end in this sandbox (Python 3.12.3), rather than jumping to 3.13/3.14 without being able to test-build the image |

## The real bug this process found

Upgrading `fastapi` from 0.111.0 to 0.141.1 broke `iris_ai/app/admin_api.py`
at import time. In FastAPI 0.111.0, `email_validator` was a **required**
transitive dependency (pulled in automatically), which is why
`class CreateAccountRequest(BaseModel): email: EmailStr` worked without
it ever being listed in `requirements.txt`. In the current release
line, `email_validator` became optional (only pulled in via
`fastapi[standard]`), so the bare upgrade silently broke `EmailStr`
usage with `ImportError: email-validator is not installed`. This was
caught by actually installing the new version and booting the real
server in this sandbox, not by reading changelogs — the fix
(`email-validator==2.3.0` added explicitly to `requirements.txt`) was
verified by re-booting the server and hitting `/admin/accounts` over
real HTTP.

A second, unrelated discovery from the same install-and-test pass: newer
FastAPI internally represents `include_router()` differently (a lazy
`_IncludedRouter` wrapper rather than eagerly flattening routes into
`app.routes`), which made a naive `app.routes` introspection check
(used earlier in this project's own development) silently under-report
registered routes. The routes were never actually broken — this was a
flaw in a *verification technique*, not the application — confirmed by
switching to `/openapi.json` (FastAPI's own authoritative route
listing) plus a real HTTP round-trip.

## What could not be executed here, and why

- **Flutter/Dart**: no SDK in this sandbox; `pub.dev` and
  `storage.googleapis.com` (where the SDK itself is distributed) return
  403 from this environment's network egress. Package version floors
  in `pubspec.yaml` are therefore researched, not installed — `flutter
  pub get` / `flutter pub outdated` should be run by you as the first
  real step, and will resolve to whatever is genuinely newest-compatible
  at that moment regardless of the exact floor written here.
- **Android toolchain** (AGP/Gradle/Kotlin/compileSdk): `dl.google.com`
  and `maven.google.com` are also unreachable. The numbers in
  `docs/MOBILE_PLATFORM_SETUP.md` (AGP ~9.2, Gradle ~9.5, Kotlin ~2.2,
  compileSdk 36, JDK 17) are researched from developer.android.com and
  are what `flutter create` should produce on a current Flutter
  install — but since no `android/` folder exists in this repo, this
  could not be cross-checked against real generated Gradle files.
- **Node.js/npm-based Cloud Functions tooling** (Firebase CLI, the
  `firebase deploy` command itself): `registry.npmjs.org` IS reachable
  here, but a real Firebase project (for `firebase login` / `firebase
  deploy` to target) is not available in this environment.

## Python version

This repository's Python code was tested against **Python 3.12.3**
(the version actually present in this build sandbox). Current stable
Python as of this writing is the 3.14 line (3.14.7, Aug 5 2026) with
3.13 and 3.12 both still actively maintained (confirmed via
python.org/downloads, dated release list). Nothing in this codebase
uses version-specific syntax beyond what 3.12+ provides, so 3.12, 3.13,
or 3.14 should all work — Docker intentionally stays on 3.12 (the
empirically verified version) rather than jumping to an unverified
newer tag.
