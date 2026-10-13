# SecureCampus — Master To-Do (in order)

Do the phases **in sequence**; each one unblocks the next. Tick a box only when it is *verified* (test run, device check, or file saved), then add a line in [CHANGELOG.md](CHANGELOG.md) and update the issue row in [ISSUES.md](ISSUES.md).

Sources: [PROJECT_STATUS.md](PROJECT_STATUS.md) (state) · [PROPOSAL_TRACEABILITY.md](PROPOSAL_TRACEABILITY.md) (what the approved proposal still requires) · [ISSUES.md](ISSUES.md).

Effort: S = under 1 hour · M = half a day · L = 1–2 days · XL = several days.
Last updated: 2026-10-13. Progress: 2 / 59 done (0.3: jpeg is git-ignored but still in folder).

---

## Phase 0 — Protect the work (do first, ~half a day)
- [x] 0.1 (S) `git init` inside `securecampus/`; confirm `.gitignore` covers `.env`, `secrets/`, `CREDENTIALS.md`, all `.venv/`, `mobile/build/`, `.dart_tool/`, `scripts/.env`; first commit. **I-13**
- [x] 0.2 (S) Create a **private** GitHub/GitLab remote and push (check `git status` shows no secrets first).
- [ ] 0.3 (S) Move `studnet 1.jpeg` out of the repo. **I-14**
- [ ] 0.4 (S) Make an encrypted/offline backup of `.env`, `secrets/serviceAccountKey.json`, `CREDENTIALS.md` (they are not in git).
- [ ] 0.5 (S) Rotate the admin password and the seeded student passwords once the demo data is final. **I-03**

## Phase 1 — Make the existing system correct and runnable (≈ 2–3 days)
**Environment**
- [ ] 1.1 (S) Add `supabase` to `iris_ai/requirements.txt`. **I-04**
- [ ] 1.2 (S) Delete and recreate `iris_ai/.venv`, `bus_eta/.venv`, `overdue_checker/.venv` from requirements; re-run both pytest suites on the pinned versions. **I-12, I-21**
- [ ] 1.3 (S) Add `overdue_checker/.venv` to `.gitignore`; add `overdue_checker` to `setup.*`, `run.*`, `docker-compose.yml` (+ Dockerfile). **I-09**
- [ ] 1.4 (S) Add `SUPABASE_*` and `OVERDUE_CHECK_INTERVAL_SECONDS` to `.env.example`. **I-17**

**Security fixes**
- [ ] 1.5 (M) Require admin token on `POST /iris/enroll`; send the Bearer token from `backend_api_service.enrollIris`. **I-02**
- [ ] 1.6 (S) Require admin on `POST /recognize/once` (or remove it from production). **I-02**
- [ ] 1.7 (S) `deactivate_account`: also disable the Firebase Auth user (and re-enable on reactivation). **I-11**
- [ ] 1.8 (S) Restrict CORS to known origins (or document why `*` is acceptable for the demo). **I-10**

**Flutter**
- [ ] 1.9 (S) `flutter pub get` online, then `flutter analyze`; record the issue count; fix errors. **I-19**
- [ ] 1.10 (M) Replace `SecureStorageImage` with a widget that calls `fetchSecurityAlertImageUrl` (signed URL, 5-min expiry); update Admin + Security screens. **I-01**
- [ ] 1.11 (S) Add Google Maps API key meta-data to `AndroidManifest.xml` (key kept out of git). **I-05**
- [ ] 1.12 (S) Add `POST_NOTIFICATIONS` permission + runtime request. **I-06**
- [ ] 1.13 (M) Replace the counter `widget_test.dart` with real smoke tests (login screen renders, router redirects by role). **I-08**

**Housekeeping**
- [ ] 1.14 (S) Decide canonical overdue implementation (`overdue_checker`) and mark `functions/` deprecated. **I-18**
- [ ] 1.15 (S) Update `firebase/storage.rules` comment/block for the unused Firebase Storage path. **I-07**
- [ ] 1.16 (M) Rewrite README, ARCHITECTURE, LIMITATIONS to the current state; write `docs/SUPABASE_STORAGE_SETUP.md`; replace `mobile/README.md`. **I-17**

## Phase 2 — Close the gaps against the approved proposal (≈ 4–6 days)
Missing features the supervisor signed off on. Details in [PROPOSAL_TRACEABILITY.md](PROPOSAL_TRACEABILITY.md).
- [ ] 2.1 (M) **Gate-before-class rule:** in `record_attendance`, require a `gateEntries` record for that student today before marking Present; otherwise return "not verified at gate" and raise a security alert. Add unit tests. **I-22**
- [ ] 2.2 (M) **Campus Entry Status** on the student dashboard (ENTERED / NOT ENTERED + last entry time) via a derived field (e.g. `students/{uid}.lastGateEntryAt`, written by the backend) so students still can't read `gateEntries`. Update rules + tests. **I-30**
- [ ] 2.3 (L) **Report unauthorized issue:** student button on an issued book → creates a report doc + notifications to the librarian and security; librarian/security screens to view and resolve it; Firestore rules. **I-23**
- [ ] 2.4 (M) **"Return date near" notification:** extend `overdue_checker` to notify N days/hours before `expiryDate` (once per issue, dedupe field `dueSoonNotifiedAt`). **I-24**
- [ ] 2.5 (L) **Activity log:** write an `activityLogs` entry for each attendance, gate, library issue/return, bus trip start/stop and alert; Admin/Security screen with filters; rules (append-only from backend). **I-26**
- [ ] 2.6 (L) **Reports:** Admin screen to generate attendance (per course/student), library usage and security-alert reports, with CSV (or PDF) export. **I-27**
- [ ] 2.7 (S) **Bus tracking for students:** decide (a) show students only status/ETA text, or (b) a map. Implement the choice; record it as a decision in the report. **I-25**
- [ ] 2.8 (M) **Card recovery:** confirm photo upload works end-to-end and the right student is notified. Optional: ML Kit OCR to pre-fill name/reg-no (only if the supervisor requires "extraction"). **I-28**
- [ ] 2.9 (S) Get written confirmation from Dr. Yaser Ali Shah that (a) Teacher dashboard is out of scope, (b) YOLO/Colab are not required, (c) bus tracking wording (2.7). Save the reply in `docs/`. **D-1, I-29**

## Phase 3 — Hardware setup and the iris evaluation (the core of the thesis; ≈ 1–2 weeks)
- [ ] 3.1 (M) Set up the iPhone RTSP stream; confirm `/camera/status` = ONLINE; document the fixed distance, lighting and mount. **I-20**
- [ ] 3.2 (L) **Dataset preparation (WBS 8.1):** (a) public NIR set (CASIA-Iris / IITD / UBIRIS) for algorithm validation, (b) your own RGB iPhone captures of the 10 students, 5+ images each, multiple days/lighting; get written consent; store outside git.
- [ ] 3.3 (L) Write `scripts/evaluate_iris.py`: compute genuine/impostor Hamming distance distributions, ROC, FAR/FRR/EER, rank-1 accuracy; save plots + CSV to `docs/results/`.
- [ ] 3.4 (M) Calibrate `IRIS_MATCH_THRESHOLD` from the EER point; write the value and the chart into `docs/IRIS_MODEL.md` §6. **I-15**
- [ ] 3.5 (L) If RGB accuracy is poor, improve segmentation (eye/iris detector, glare/eyelid masking, quality gate) and re-run 3.3; keep before/after numbers.
- [ ] 3.6 (M) Add a basic spoofing note/test (printed photo, screen) — the proposal's table claims anti-spoofing advantages, so test and report honestly.
- [ ] 3.7 (M) Enroll all 10 students via the app; run live attendance + gate scenarios; log results (time-to-recognize, false rejects).
- [ ] 3.8 (S) Decide multi-camera: run two `iris_ai` instances (classroom + gate) or document one-at-a-time. **I-16**

## Phase 4 — Device testing of every module (≈ 3–4 days)
Record each as pass/fail with date in the CHANGELOG. **I-20**
- [ ] 4.1 (M) Login for all five roles on a real phone; wrong-role access attempts blocked.
- [ ] 4.2 (M) Admin: create student/staff, edit name, reset password, deactivate (then login fails), courses + schedule, books, bus + stops, assignments.
- [ ] 4.3 (M) Library: scan real printed QR codes, issue, return, overdue and due-soon notifications arrive on the phone.
- [ ] 4.4 (M) Bus: driver starts trip, GPS stream, admin map shows marker (needs 1.11), 10-minute alert arrives once per trip.
- [ ] 4.5 (S) FCM: foreground banner, background, and app-killed delivery.
- [ ] 4.6 (S) Supabase: unknown-person alert → image visible to Security/Admin, **not** to Student (try with a student token).
- [ ] 4.7 (M) Lost card: finder reports → student notified → admin tracks.
- [ ] 4.8 (M) Firestore/RTDB rules tests with the Firebase emulator (student cannot read `gateEntries`, `irisProfiles`, live bus, others' data). Commit the test file.

## Phase 5 — Quality, testing evidence, deployment (≈ 3 days)
- [ ] 5.1 (L) Python tests: admin API auth (401/403/200), `record_attendance` dedupe + gate rule, overdue/due-soon logic, bus alert dedupe (with a fake Firestore). Target: every endpoint has one auth test.
- [ ] 5.2 (M) Flutter tests: model parsing, router redirect, attendance % calculation.
- [ ] 5.3 (M) Performance numbers for WBS 13.3: recognition latency per frame, template cache load time with 10/100/1,000 templates (matching is linear).
- [ ] 5.4 (S) Security checklist run (OWASP-style): endpoint auth, rules, secrets not in repo, signed-URL expiry. Save as `docs/SECURITY_TEST.md`.
- [ ] 5.5 (M) Build a **release** APK (signing config) and install on a clean phone; keep the APK out of git.
- [ ] 5.6 (M) One-command demo start (`run.bat` starts iris_ai, bus_eta, overdue_checker) and a dry-run on a different PC/network.
- [ ] 5.7 (S) Optional deployment: iris_ai + bus_eta + overdue_checker via Docker on one always-on machine.

## Phase 6 — Final documentation and defence (≈ 1 week)
- [ ] 6.1 (L) Final report chapters: requirements, design (updated architecture diagram incl. Supabase + overdue_checker), implementation, **testing evidence**, **iris evaluation results (3.3–3.5)**, limitations, future work. Keep the declared deviations list from PROPOSAL_TRACEABILITY.
- [ ] 6.2 (M) Update the UML/ER diagrams to match the real Firestore collections (users, students, courses, attendance, classSessions, gateEntries, securityAlerts, lostCardReports, books, libraryIssues, bus, busStops, busAssignments, notifications, + activityLogs, + library reports).
- [ ] 6.3 (M) User manual (one page per role) with screenshots.
- [ ] 6.4 (M) Demo script (10 min): gate entry → class attendance → unknown person alert → library issue/overdue → bus alert → admin reports. Rehearse twice; prepare a screen-recorded backup video in case the camera/Wi-Fi fails.
- [ ] 6.5 (S) Prepare answers: "why classical not deep learning", "why RGB iPhone", "accuracy numbers", "privacy of biometric data", "what if two students look alike".
- [ ] 6.6 (S) Final repo cleanup: tag `v1.0`, freeze CHANGELOG, update PROJECT_STATUS with a new dated section.

---

## Decisions needed from you / supervisor
| # | Question | Blocks |
|---|---|---|
| D-1 | Is the Teacher dashboard (shown in mockups) in scope? Code has none. | 2.9, report |
| D-2 | Students: bus status text only, or live map? | 2.7 |
| D-3 | Must card recovery do OCR, or is manual reg-no entry accepted? | 2.8 |
| D-4 | Is Supabase (instead of Firebase Storage) acceptable as a declared deviation? | 6.1 |
| D-5 | Do you have consent/ethics approval for collecting students' eye images? | 3.2 |

## Critical path
0 → 1.5/1.10 → 2.1 → 3.1–3.4 → 4 → 6. Phase 2 items 2.3–2.6 can be done in parallel with Phase 3 while waiting on data collection.
