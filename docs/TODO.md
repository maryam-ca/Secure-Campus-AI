# SecureCampus — Master To-Do (in order)

Tick a box only when **verified** (test run, device check, saved file). Then add a line in [CHANGELOG.md](CHANGELOG.md) and update the row in [ISSUES.md](ISSUES.md).
Sources: [PROJECT_STATUS.md](PROJECT_STATUS.md) · [PROPOSAL_TRACEABILITY.md](PROPOSAL_TRACEABILITY.md) · [ISSUES.md](ISSUES.md).
Effort: S < 1 h · M half day · L 1–2 days · XL several days.
Last updated: 2026-10-13. Part A: 16 / 46 done · Part B: 0 / 26 done.

## The split (confirmed 2026-10-13)

| | Modules |
|---|---|
| **Before mid-term (Part A)** | Library, **Bus tracking**, Admin portal, Student / Security / Librarian / Driver portals, login + roles, notifications, rules, tests, docs |
| **After mid-term (Part B)** | **Lost card recovery (with OCR)** and **iris/eye recognition** (attendance, gate entry, unknown-person alerts, evaluation) |

Rule for Part A: the existing eye-recognition and card code stays in the project and **must not break** — it is only paused, not removed. Keep `iris_ai` tests green and the app compiling after every change.

## Decisions (answered 2026-10-13)
| # | Decision |
|---|---|
| D-1 | Teacher dashboard not required |
| D-2 | Students get bus status text only (no student map). **Two in-app reminders per trip (added 2026-10-13): at 20 min "get ready", at 10 min "head to your stop"** |
| D-3 | Card recovery must extract name + registration number from the photo (OCR) |
| D-4 | **Use Firebase for login and storage (confirmed 2026-10-13).** Auth already Firebase. Alert images → Firebase Storage; Supabase removed. Bucket must still be created in the console (A1.8b) |
| D-5 | Eye-image consent is handled in the last phase |
| D-6 | Part A = library + bus tracking + everything else; Part B = card recovery + eye recognition |
| D-7 | **Free-first:** no billing account, no Blaze. Spark plan only; no Google Maps Platform key (maps use OpenStreetMap); no Cloud Functions |

Open question for the supervisor: the committee result says "Partially Accepted with changes" and mentions *face* recognition; our proposal is *iris*. Get the required changes in writing **before** starting Part B (task A0.5).

---

# PART A — Before mid-term

## A0 — Protect the work
- [x] A0.1 `git init`, `.gitignore`, first commit **I-13**
- [x] A0.2 Push to GitHub (`maryam-ca/Secure-Campus-AI`)
- [ ] A0.3 (S) Move `studnet 1.jpeg` out of the project folder **I-14**
- [ ] A0.4 (S) Encrypted/offline backup of `.env`, `secrets/serviceAccountKey.json`, `CREDENTIALS.md`
- [ ] A0.5 (S) Email Dr. Yaser: what exactly are "the changes" (committee result), is iris still approved, confirm D-1…D-6. Save the reply in `docs/`
- [ ] A0.6 (S) Write down the mid-term date and a one-sentence demo scope at the top of this file

## A1 — Make everything that stays in scope correct and runnable
Environment
- [x] A1.1 (S) Recreate `.venv` for `iris_ai`, `bus_eta`, `overdue_checker` from requirements; re-run pytest on pinned versions **I-12, I-21**
- [x] A1.2 (S) Add `overdue_checker` to `setup.*`, `run.*`, `docker-compose.yml` (+Dockerfile) **I-09**
- [x] A1.3 (S) Update `.env.example` (add overdue interval; Supabase vars removed after A1.8) **I-17**
- [x] A1.4 (S) Decide canonical overdue job: `overdue_checker`; mark `functions/` deprecated **I-18**

Security
- [x] A1.5 (M) Admin auth on `POST /iris/enroll` and `/recognize/once`; app sends the token **I-02**
- [x] A1.6 (S) `deactivate_account` also disables the Firebase Auth user **I-11**
- [ ] A1.7 (S) Rotate admin + seeded passwords; update `CREDENTIALS.md` **I-03**

Storage (D-4, D-7)
- [x] A1.8 (S) **Firebase Storage for alert images (your decision 2026-10-13).** Code switched: backend uploads to `security_alerts/{camera}/{ts}.jpg`, Supabase removed everywhere, Flutter widget (already Firebase-based) now works as-is; alert is still created if the upload fails; 2 new tests. **I-01, I-04, I-07, I-31**
- [ ] A1.8b (S) **You:** Firebase console → Build → Storage → **Get started** for project `campus-a4087` (bucket `campus-a4087.firebasestorage.app`), then deploy `storage.rules` (`firebase deploy --only storage`). Tell me the result; I re-run the bucket check. If the console demands Blaze, tell me — fallback is no photo (text-only alert) or Supabase again

Flutter
- [x] A1.9 (S) Remove the unused import (`admin_dashboard_screen.dart:5`); `flutter analyze` → 0 warnings
- [x] A1.10 (M) Replace the counter `widget_test.dart` with real smoke tests (login renders, role redirect) **I-08**
- [x] A1.11 (M) Replace `google_maps_flutter` with `flutter_map` + OpenStreetMap tiles in the admin bus screen (no key, no billing); remove the Maps key requirement; respect OSM tile usage policy (set user-agent, no heavy prefetch) **I-05**
- [x] A1.12 (S) `POST_NOTIFICATIONS` permission + runtime request **I-06**

- [ ] A1.13 (S) **You decide:** Flutter SDK mismatch blocks `flutter build apk` (project made with 3.47.2, `C:lutter` is 3.38.7). Switch `C:lutter` to 3.47.x (`cd C:lutter; git checkout 3.47.7; flutter doctor`), then `flutter build apk --debug` must succeed **I-32**

## A2 — Library module (proposal §4.2)
- [ ] A2.1 (M) Verify the full flow on a phone with real printed QR codes: scan → student reg-no → issue (auto issue date, manual return date) → student portal shows it → return
- [x] A2.2 (M) **"Return date near" notification:** `overdue_checker` sends it once per issue (`dueSoonNotifiedAt`, window `DUE_SOON_HOURS`=48) — code + unit tests done; **still to do: real-device check** **I-24**
- [x] A2.3 (S) Overdue notification still works (once per issue) — test with a short due date
- [x] A2.4 (L) **(code done, not run on a device; rules not emulator-tested)** **"Report unauthorized issue":** student button on an issued book → report doc → notifications to librarian + security; screens to view/resolve; Firestore rules **I-23**
- [ ] A2.5 (M) Librarian catalog management (add/edit book, availability); search/filter works
- [ ] A2.6 (S) Rules test: student sees only own `libraryIssues`; librarian can read `students` (reg-no lookup)

## A3 — Bus tracking module (proposal §4.3, D-2)
- [ ] A3.1 (M) Driver: start/stop trip, GPS to RTDB only while a trip is active (real phone, location permission)
- [ ] A3.2 (M) Admin: bus, stops, driver account, assign students to stops; live map shows the marker (OpenStreetMap, A1.11)
- [ ] A3.3 (M) `bus_eta`: **two reminders per trip — 20 min ("get ready") and 10 min ("head to your stop")**, each once per student per trip. **Code + 19 unit tests done**; still to do: test with a real walk/drive and short thresholds **I-20**
- [ ] A3.4 (M) Student portal: bus status **text only** (assigned bus/stop, trip running or not, ETA, and the 20/10-minute reminders in the Alerts list); no map, no live location **I-25**
- [ ] A3.5 (S) Rules test: student cannot read `driverLocation` or others' assignments
- [ ] A3.6 (S) ETA method: keep the free straight-line estimate at 25 km/h (leave `MAP_API_KEY` empty); state this in the report. Optional free upgrade: OSRM public routing API

## A4 — Shared portals, monitoring, notifications
- [ ] A4.1 (M) Login + redirect for all five roles on a real phone; wrong-role access blocked; deactivated user blocked
- [ ] A4.2 (M) Admin: create/edit/deactivate students and staff, courses + schedules
- [ ] A4.3 (S) FCM: foreground banner, background, app-killed delivery
- [ ] A4.4 (L) **Activity log (library + bus + accounts now; attendance/gate added in Part B):** `activityLogs` written by backend, Admin/Security screen with filters, append-only rules **I-26**
- [ ] A4.5 (L) **Reports (library usage, bus trips now; attendance/security added in Part B):** Admin report screen with CSV/PDF export **I-27**
- [ ] A4.6 (S) Student dashboard: attendance / entry-status cards show an honest "No data yet" until Part B **I-30**
- [ ] A4.7 (M) Firebase-emulator rules tests for everything above; commit the test file

## A5 — Quality and docs for mid-term
- [ ] A5.1 (L) Python tests: admin API auth (401/403/200), overdue + due-soon logic, bus alert dedupe (fake Firestore)
- [ ] A5.2 (M) Flutter tests: model parsing, router redirect
- [ ] A5.3 (S) **Regression check (D-6):** `iris_ai` pytest 7/7, `bus_eta` 5/5, `flutter analyze` 0 errors, `flutter build apk --debug` succeeds — record in CHANGELOG before the mid demo
- [ ] A5.4 (M) Rewrite README, ARCHITECTURE, LIMITATIONS to the real state **I-17**
- [ ] A5.5 (M) Mid-term report/slides: modules done, architecture, test evidence, declared deviations, plan for Part B
- [ ] A5.6 (M) Mid demo script (library issue → due-soon/overdue → bus trip → 10-min text alert → admin map/report) + backup screen recording
- [ ] A5.7 (S) Release APK on a clean phone; tag `v0.5-mid`

---

# PART B — After mid-term

## B0 — Gate before starting
- [ ] B0.1 (S) Supervisor reply on iris vs face (A0.5) saved; update the plan if "face recognition" is required
- [ ] B0.2 (M) Written consent/ethics approval for collecting eye images **D-5**, then collect

## B1 — Lost card recovery (proposal §4.5, D-3)
- [ ] B1.1 (M) Finder flow end-to-end: anonymous session → capture/upload card photo → form submit **I-28**
- [ ] B1.2 (L) **OCR:** extract name + registration number from the photo (ML Kit on device, or a Python endpoint); regex for `FA23-BSE-007` style numbers; show extracted values for confirmation
- [ ] B1.3 (M) Verify reg-no against `students`; notify the right student (FCM + in-app); handle "no match"
- [ ] B1.4 (M) Admin: list/track/update lost-card reports; rules test (finder can create only)
- [ ] B1.5 (M) Test with 10+ real/printed sample cards in varied light; record the OCR success rate for the report

## B2 — Iris / eye recognition (proposal §4.1)
- [ ] B2.1 (M) iPhone RTSP working; `/camera/status` ONLINE; distance/lighting/mount documented **I-20**
- [ ] B2.2 (L) Dataset: public set (CASIA/IITD/UBIRIS) for validation + own RGB captures of the 10 students (needs B0.2)
- [ ] B2.3 (L) `scripts/evaluate_iris.py`: genuine/impostor distributions, ROC, FAR/FRR/EER, rank-1; save to `docs/results/`
- [ ] B2.4 (M) Calibrate `IRIS_MATCH_THRESHOLD`; document in `docs/IRIS_MODEL.md` §6 **I-15**
- [ ] B2.5 (L) If RGB accuracy is poor: better eye/iris detection, glare/eyelid masking, quality gate; keep before/after numbers
- [ ] B2.6 (M) Spoofing test (printed photo / screen); report honestly
- [ ] B2.7 (M) Enroll 10 students from the Admin portal; live attendance + gate scenarios
- [ ] B2.8 (M) **Gate-before-class rule:** attendance only if a gate entry exists today; else alert **I-22**
- [ ] B2.9 (M) **Campus Entry Status** on student dashboard via a derived field (students still can't read `gateEntries`) **I-30**
- [ ] B2.10 (S) Unknown-person alert → image visible to Security/Admin, **not** to Student
- [ ] B2.11 (S) Decide multi-camera: two `iris_ai` instances or one-at-a-time **I-16**
- [ ] B2.12 (M) Hook attendance/gate/alerts into the activity log and reports (A4.4, A4.5)

## B3 — Final quality and submission
- [ ] B3.1 (L) Tests for `record_attendance` (dedupe + gate rule) and recognition outcome logic
- [ ] B3.2 (M) Performance numbers (WBS 13.3): per-frame latency, template load with 10/100/1,000 templates
- [ ] B3.3 (S) Security checklist → `docs/SECURITY_TEST.md`; tighten CORS **I-10**
- [ ] B3.4 (L) Final report: iris + OCR results, testing evidence, limitations, deviations (Firebase Storage/Blaze, overdue loop, no Teacher, classical iris not YOLO/Colab, RGB camera)
- [ ] B3.5 (M) ER/UML diagrams of real collections; user manual per role
- [ ] B3.6 (M) Final demo script + backup video; Q&A prep (why classical, why RGB, privacy, look-alikes)
- [ ] B3.7 (S) Freeze CHANGELOG, tag `v1.0`, new dated section in PROJECT_STATUS

---

## Critical path
A0.5 → A1.8 → A2 and A3 (parallel) → A4 → A5.3 → **mid-term** → B0 → B1 and B2 (parallel; start B2.2 data collection first) → B3 → **final**.
