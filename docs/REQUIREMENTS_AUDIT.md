# Requirements audit: proposal vs. the code on `main` (Phase 1)

Checked on 2026-10-18 against the project proposal (SecureCampus_Final.pdf). "Phase 2" items are on the `phase-2` branch.

## 1. Proposal requirements and where they stand

| # | Proposal requirement | Status on `main` | Where |
|---|---|---|---|
| 4.2 | Librarian scans the book QR code to fetch its details | Done | `features/librarian/librarian_scan_screen.dart` (mobile_scanner, manual entry fallback) |
| 4.2 | Student ID entered to issue; issue date automatic, return date manual | Done | `librarian_scan_screen.dart`, `repositories/librarian_repository.dart` |
| 4.2 | Record stored and shown on the student portal; status and return dates | Done | `features/student/widgets/library_section.dart` |
| 4.2 | Student can report an unauthorized issue; alert to librarian | Done (librarian and admin) | `issue_report_repository.dart`, Librarian/Admin Reports |
| 4.2 | ...alert to **security** | **Not done by decision:** Security no longer shows Book Reports; the dialog text now says "librarian and the admin" | proposal says "librarian and security" |
| 4.2 | Notification when the return date is near | Done | `overdue_checker/` (due soon and overdue) |
| 4.3 | Driver shares live location | Done | `features/driver/driver_dashboard_screen.dart` |
| 4.3 | Compare with saved student stops; notify about 10 minutes before | Done (one alert, own stop, road-distance ETA) | `bus_eta/` |
| 4.4 | Role-based access control | Done (app routing and Firestore rules, 20 emulator tests) | `firebase/firestore.rules`, `core/router` |
| 4.4 | Activity logs for attendance, library and bus | **Partial:** library lock history, report and loan records, bus trip status; **no single activity log** | gap, see section 3 |
| 4.4 / 4.7 | Alerts for suspicious activity, security monitoring of attendance and gate | Phase 2 | `phase-2` branch |
| 4.5 | Found card: any user submits; matched with records; student notified | Done as a form (name and registration number), Admin verifies, Admin notifies | `found_card_report_screen.dart`, `admin_lost_cards_screen.dart` |
| 4.5 | Capture an image of the card and **extract** name and registration number | **Not done** (the finder types them) | gap |
| 4.6 | Student dashboard: bus updates, library | Done | `features/student/` |
| 4.6 | Student dashboard: attendance, campus entry status | Phase 2 | `phase-2` branch |
| Methodology 3 | Student registration and profile, course enrollment, registration numbers | Done (add, CSV import, edit, courses per student) | `features/admin/` |
| Methodology 5 | Admin assigns bus service to students; students with it see bus tracking | Done (status and ETA text; no live map for students) | `admin_bus_screen.dart`, `bus_assignment_section.dart` |
| Methodology 9, 11 | Admin-controlled account creation; role-based login; notifications | Done | `iris_ai/app/admin_api.py` (account service), `auth_service.dart` |
| Scope | Report generation | Library reports done; attendance reports Phase 2 | Admin > Library > Reports |
| Scope | Free-tier technologies | Done (OpenStreetMap, OSRM, Firebase free plan, Python loops) | |

## 2. Code that is not a proposal requirement (extra)

Kept because it supports a requirement or the demo:

| Extra | Why it is there |
|---|---|
| Book lock (safe) and lock history | Library safety rule; not in the proposal |
| Forced first-login password change | Supports "credentials provided by the admin" |
| Admin verification, resolve and delete of found-card reports; 24-hour Resolved view for Security | Supports "Admin can manage and track" |
| Campus location and ordered stops; auto-end of a trip; stale-GPS handling | Supports the bus module |
| Phase 2 locked menu entries and greyed dashboard cards | Show the phase plan; no code behind them |
| `bus_eta` road routing (OSRM) | Supports "calculates the estimated arrival time" |
| Web build and the Vercel deployment | Not in the proposal (it is a mobile app); convenience only |
| `scripts/` (QR code generator, seed data, rules checker, role backfill) | Dev tools; the QR generator is needed to make book QR codes |
| Dockerfiles, `docker-compose.yml`, setup and run scripts | Run the Python services |

Removed in this audit because they were dead or Phase 2 leftovers:
- The unused `PortalScaffold` class (the `SectionCard` widget it shared a file with moved to `section_card.dart`).
- The unused packages `image_picker` and `firebase_storage` (both were Phase 2).
- The deprecated `functions/` Cloud Function (replaced by `overdue_checker`); README updated.
- Four empty feature folders (`attendance`, `bus`, `iris`, `notifications`).

## 3. Gaps against the proposal (not implemented)

1. **Central activity log** (4.4, WBS 6.5): there is no single log of system activities and security events.
2. **Card image capture and text extraction** (4.5, WBS 4.1 and 4.4): the finder types the name and registration number; nothing reads a photo.
3. **Security alerts for book reports** (4.2): by decision Security does not see them.
4. **Teacher role** (Summary, Admin and Teacher dashboards, login): not built. The Word proposal marks it for deletion.
5. **Campus entry status and attendance** (4.6): Phase 2.

## 4. Left alone on purpose

- `firebase/storage.rules` and the `storage` entry in `firebase.json`: used only by Phase 2 (unknown-person photos). Not removed because deleting them changes the Firebase deploy.
- Older docs (ARCHITECTURE, PROJECT_STATUS, AUDIT_REPORT, ...) still describe Phase 2 in places.
- The service folder is still named `iris_ai` although on `main` it is only the account service.
