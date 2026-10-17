# SecureCampus Build Plan: Phase 1 and Phase 2

Phase 1 delivers everything that needs no iris camera. Phase 2 adds iris recognition, class attendance and gate entry once camera hardware is available.

## Overview

SecureCampus is a smart campus security and management system. It has a Flutter app with five role portals (Admin, Student, Security, Librarian, Driver), a Firebase backend, and three Python services.

| Service | Stack | Purpose |
| --- | --- | --- |
| Flutter app (`mobile/`) | Flutter, Firebase | All five role portals |
| `iris_ai/` | Python, FastAPI | Account creation (Phase 1); camera and iris recognition (Phase 2) |
| `bus_eta/` | Python | Turns live driver GPS into ETAs and the 10-minute bus alert |
| `overdue_checker/` | Python | Scheduled overdue-book notifications |

The project follows a strict no-fake-data policy: screens show real data or an empty state, never mock records.

## Phase 1, part 1: foundation, auth and admin data

Build the shared base first, then sign-in, then the admin features that create the data every other role depends on.

| # | Feature | Module | Depends on |
| --- | --- | --- | --- |
| 1 | Firebase project, security rules, config | `firebase/`, `firebase_options.dart` | None |
| 2 | Theme, router, constants, shared widgets | `core/`, `config/` | 1 |
| 3 | Data models and repositories | `models/`, `repositories/` | 1 |
| 4 | Auth service and provider | `services/auth_service`, `providers/auth_provider` | 1, 3 |
| 5 | Login and change password | `features/auth` | 4 |
| 6 | Splash and account error screens | `features/common` | 4 |
| 7 | Role-based routing to each portal | `core/router` | 4, 5 |
| 8 | Account creation API (no camera needed) | `iris_ai/admin_api` | 1 |
| 9 | Admin: accounts | `features/admin` | 8 |
| 10 | Admin: students (list, import, overview) | `features/admin` | 9 |
| 11 | Admin: courses | `features/admin` | 10 |
| 12 | Admin: library (books, QR codes) | `features/admin` | 3 |
| 13 | Admin: bus (campus location, live map, assignment) and stops (route order) | `features/admin` | 10 |
| 14 | Admin: home shell and dashboard | `features/admin` | 9 to 13 |

## Phase 1, part 2: library, transport, student portal, notifications

These features run on phone GPS, QR scanning and Firestore data, so none of them needs the iris camera. QR scanning uses the phone camera.

| # | Feature | Module | Depends on |
| --- | --- | --- | --- |
| 15 | Librarian: catalog | `features/librarian` | 12 |
| 16 | Librarian: QR scan, issue and return, return verification | `features/librarian` | 15 |
| 17 | Book lock (reserve and lock a book) | `features/library`, `book_lock_repository` | 15 |
| 18 | Overdue book checker (scheduled job) | `overdue_checker/` | 16 |
| 19 | Librarian: reports | `features/librarian` | 16 |
| 20 | Driver: dashboard, live GPS sharing, trip start and end | `features/driver` | 13 |
| 21 | Bus ETA service and 10-minute alert | `bus_eta/` | 20 |
| 22 | Student: home | `features/student/widgets` | 7, 10 |
| 23 | Student: library | `features/student/widgets` | 16 |
| 24 | Student: bus assignment | `features/student/widgets` | 13, 21 |
| 25 | Push notification service | `services/push_notification_service` | 1 |
| 26 | Student: notifications (overdue and bus alerts) | `features/student/widgets` | 18, 21, 25 |
| 27 | Found-card report and lost cards | `features/common`, `features/admin` | 10 |
| 28 | Issue reports | `features/common`, `issue_report_repository` | 7 |

The student portal is read-only, so it comes after the features that produce its data. A student sees only their own data: never gate history or the live bus map.

## Phase 2: iris recognition, class attendance, gate entry

Build from the bottom up: data contract, recognition core tested offline, then the live camera, then the features that consume matches. Class attendance comes before gate entry because it has simpler rules (known students, one open session).

| # | Feature | Module | Needs camera? |
| --- | --- | --- | --- |
| 29 | Schema and rules: iris templates, attendance records, gate entries, unknown-person alerts | `firebase/` | No |
| 30 | Course sessions (course, time, room) so attendance knows which session is open | `features/admin`, courses | No |
| 31 | Iris preprocessing: eye and iris detection, segmentation, normalization, quality checks | `iris_ai/preprocessing` | No (test on still images) |
| 32 | Recognition: feature extraction, template encoding, matching, threshold | `iris_ai/recognition`, `iris_ai/models` | No |
| 33 | Student iris enrollment, with an enrolled status on student screens | `iris_ai`, `features/admin` | Only for live capture |
| 34 | Accuracy tuning: measure false accept and false reject rates, set the threshold | `iris_ai` | No (own sample data) |
| 35 | Pipeline: frame in, detect, match, result out, with debounce and unknown handling | `iris_ai/pipeline.py` | No (video file) |
| 36 | Live camera module feeding the pipeline | `iris_ai/camera` | Yes |
| 37 | Camera control API and admin screen (start, stop, classroom or gate mode, status) | `iris_ai`, `admin_camera_control_screen` | Yes |
| 38 | Class attendance: write on match in classroom mode, admin views, low-attendance alerts | `iris_ai`, `features/admin` | Yes |
| 39 | Student attendance and course attendance widgets | `features/student/widgets` | No (reads data) |
| 40 | Gate entry: write on match in gate mode, entry and exit direction | `iris_ai` | Yes |
| 41 | Security dashboard, admin gate security, unknown-person alerts with push | `features/security`, `features/admin` | No (reads data) |
| 42 | Hardening: real-camera and lighting tests, rules review, `docs/LIMITATIONS.md` items | All | Yes |

Until the camera exists, build the attendance and gate screens against the schema and show empty states, not mock records. Student gate history is never shown to students.

## Dependencies and notes

Phase 1 has no dependency on the iris camera, and Phase 2 depends on Phase 1 for accounts, students, courses and notifications.

- **Camera constraint:** the iris camera is unavailable now, so everything in Phase 1 can ship without it. In Phase 2, only steps 36 to 38, 40 and 42 need it.
- **Offline testing:** the recognition core (steps 31 to 35) can be built and tuned on still images or recorded video. The camera module only has to hand frames to the pipeline.
- **Highest risk:** iris recognition accuracy (step 34). Do the tuning before connecting a live camera.
- **No fake data:** attendance and gate screens show empty states until real matches exist.
- **Phase 1 status:** many Phase 1 features may already be built in the repo. This document gives the build order, not a completion audit.

## How the Admin menu works (for explaining and changing it)

- The whole menu is one list in `mobile/lib/features/admin/admin_nav.dart`: main modules (groups) that hold sub-modules (items). The sidebar (`admin_sidebar.dart`), the page title strip and the page shown all read that list.
- **Add a module:** add an `AdminNavItem` (id, label, description, icon, screen) to a group.
- **Rename or move a module:** edit or move its entry; nothing else changes.
- **Turn on a Phase 2 module:** give its item a `screen`. Items without a screen show greyed and are not clickable.
- The dashboard cards open pages by id (`AdminSection` in `providers/admin_navigation_provider.dart`).
- Phase 2 dashboard cards show "Under development" and no number, so no data is invented.
- Clicking a main module opens its first page: cards for its sub-modules, drawn from the same list. The arrow beside it only expands or collapses the sidebar.
- Every page except the dashboard has a header bar: a clickable path (Home > Module > Page), a one-line description and chips to switch between sub-modules. The app bar also has a Home button.
- Every role (Admin, Student, Librarian, Security, Driver) uses the same shell, `core/widgets/portal_shell.dart`. A role only supplies its menu (`PortalNav`). Tapping the logo or app name returns to Home.
