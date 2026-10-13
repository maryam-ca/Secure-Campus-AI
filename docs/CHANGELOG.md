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
