# Known Limitations & What Requires Physical Setup

Per project spec §48/§60/§61, this file is the single honest list of
what cannot be automated or fully verified without your own hardware
and credentials, and what is architecturally real but functionally
unproven until that hardware is attached.

## Requires your Firebase project (cannot be provided by this build)

- A real Firebase project, Firestore database, Realtime Database
  instance, Storage bucket, and a service-account JSON key.
- Running `firebase deploy --only firestore:rules,storage:rules` (and
  publishing `database.rules.json` via the RTDB console/CLI) so the
  rules in `firebase/` actually take effect.
- Enabling Email/Password sign-in in Firebase Authentication.
- Generating `mobile/lib/firebase_options.dart` via the FlutterFire CLI
  against *your* project (`flutterfire configure`) — a placeholder
  config would either fail to compile or silently point at a project
  that doesn't exist, so none is included; see README "Firebase setup".

## Requires the physical iPhone 13 + RTSP app

- `CAMERA_RTSP_URL` must point at a real, currently-streaming RTSP URL
  from the iPhone on the same local network as the machine running
  `iris_ai`. Until then, `/camera/status` correctly and honestly
  reports `NOT_CONFIGURED` or `OFFLINE` — verified in this build (see
  the live curl output in the development log) — rather than a faked
  `ONLINE`.
- The recognition pipeline's accuracy on real faces/eyes, as opposed to
  the synthetic test images used to validate pipeline mechanics, is
  **unverified until you run it against real captures**. See
  `docs/IRIS_MODEL.md` §5–6 for why RGB capture specifically changes
  expected accuracy, and §6 for exactly which metrics are marked "not
  yet evaluated".

## Requires generating the native Android/iOS platform folders

`mobile/` contains only Dart source (`lib/`, `pubspec.yaml`,
`analysis_options.yaml`) — the native `android/`/`ios/` folders that
`flutter create` normally scaffolds are **not present**, because the
Flutter SDK isn't available in this build environment. See
`docs/MOBILE_PLATFORM_SETUP.md` for the exact command to generate them
and the exact camera/location/notification permission entries each
feature (Driver GPS, Librarian QR scan, Admin iris-photo capture, push
notifications) needs added afterward.

## Requires a physical Android/iOS device for the Flutter app

- Firebase Auth session behavior, FCM push delivery, camera-permission
  prompts (QR scanning), and location-permission prompts (driver GPS)
  all require a real device or emulator with Google Play services (for
  Android) — none of this can be executed inside this sandboxed build
  environment, which has no Flutter SDK, no emulator, and no access to
  Google's Firebase/FlutterFire package registry (only a specific
  allow-listed set of domains — pypi, npm, GitHub — was reachable while
  building this).
- `flutter pub get` / `flutter build` have **not** been run against this
  code in this environment for that reason. The Dart source was written
  carefully and reviewed by hand, but has not been compiler-verified
  here. Run `flutter analyze` and `flutter pub get` yourself as the
  first step after unpacking (see README).

## Requires the driver's phone GPS

- `geolocator`-based location streaming only produces real coordinates
  on a real device with location services enabled and permission
  granted — there is no simulated-location fallback anywhere in the
  driver feature code, by design (spec §32/§36).

## Requires physically printed QR codes

- `qr_codes/*.png` are real, generated, and verified to decode back to
  their book IDs (see the build log / `scripts/generate_qr_codes.py`
  output) — but they only become useful once printed and attached to
  the physical books, and scanned with a real device camera via the
  Librarian portal's scanner screen.

## What was and wasn't executed during this build

Executed and verified in this build environment:
- The full iris recognition pipeline (segmentation → normalization →
  encoding → matching) against synthetic test images — 7/7 tests
  passing, including a real bug found and fixed during development
  (see `docs/IRIS_MODEL.md` §5).
- The bus ETA haversine/routing math — 5/5 tests passing, including a
  sanity check against a known real-world distance (Islamabad–Lahore).
- The FastAPI service booting and serving real HTTP responses,
  including a real "camera not configured" response rather than a
  faked success, and the admin account-creation routes registering
  correctly.
- QR code generation and independent decode-verification for all 5
  books.
- Every Dart file's imports resolve to real files, every referenced
  class exists under the exact name used, every imported package is
  declared in `pubspec.yaml`, and brace/parenthesis balance checks pass
  across all 48 files — a static consistency sweep, not a compile. One
  real bug (a Kotlin-style `.let()` call that isn't valid Dart) was
  found and fixed this way before delivery.

Not executed (requires resources unavailable in this environment):
- Firestore/RTDB/Storage/FCM calls against a real Firebase project.
- The Flutter app build/compile/run — **no Dart/Flutter compiler was
  available to actually verify this code compiles.** The static checks
  above catch structural mistakes (missing files, wrong class names,
  unbalanced braces) but not type errors, null-safety issues, or
  Flutter/package API mismatches. Run `flutter analyze` yourself as the
  first step after `flutter pub get`.
- RTSP capture against a real iPhone stream.
- GPS-based bus ETA against a real driver device.
- Push notification delivery end-to-end (the FCM token registration and
  backend send calls are both implemented, but were never exercised
  against a real device/project together).
