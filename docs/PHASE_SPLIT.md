# Phase 1 and Phase 2: where the code lives

| Branch | Contains |
|---|---|
| `main` | **Phase 1 only.** Everything that needs no iris camera. |
| `phase-2` | The full code, including Phase 2. Created from the commit just before Phase 2 was removed from `main`. |

## What is Phase 2 (removed from `main`, kept on `phase-2`)

- **Iris recognition service:** `iris_ai/app/camera`, `recognition`, `preprocessing`, `pipeline.py`, `models`, the `/iris/enroll`, `/recognize/once`, `/camera/status` and `/stream/*` endpoints, and the Firebase writes for attendance, gate entries and unknown-person alerts. Docs: `docs/IRIS_MODEL.md`.
- **Admin app:** Camera control screen, Gate & Security screen, iris status and "Enroll Iris" on the student pages, the iris filter on the students list, per-course attendance on the student overview, the camera ID on a course.
- **Student app:** Attendance screen and attendance cards.
- **Security app:** Gate Entries and Unknown-Person Alerts screens.
- **Firestore rules:** `attendance`, `classSessions`, `gateEntries`, `irisProfiles`, `securityAlerts`, and Security's read access to student records. These collections are closed to every role on `main`.

## What `main` still shows for Phase 2

Only **locked menu entries and greyed cards** ("Under development"): no screen, no data and no code behind them. Admin: Iris Recognition, Class Attendance, Gate & Security, Settings. Student: Attendance. Security: Gate Entries, Unknown-Person Alerts. The Admin and Student dashboards have greyed Attendance and Gate Entries cards with no numbers.

## The `iris_ai/` folder on `main`

It is kept (with its name) because the Admin portal creates and deactivates accounts through it. On `main` it is only the account service (`/health` and `/admin/*`).

## Bringing Phase 2 in later

```
git checkout main
git merge phase-2      # resolve conflicts if main changed in the same files
```

`phase-2` is a snapshot, so it will not contain `main` changes made after the split. Merge `main` into `phase-2` first (`git checkout phase-2 && git merge main`) and fix conflicts there, then merge `phase-2` back into `main`. After merging, publish the Firestore rules again.
