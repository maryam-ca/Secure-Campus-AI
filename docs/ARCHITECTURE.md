# SecureCampus — Architecture

## System diagram

```
                         ┌─────────────────────────┐
                         │        iPhone 13          │
                         │  RTSP & RTMP Cam app       │
                         │  (OctoStream) — RGB feed   │
                         └────────────┬──────────────┘
                                      │ RTSP (local Wi-Fi)
                                      ▼
                       ┌───────────────────────────────┐
                       │      iris_ai service            │
                       │  (Python / FastAPI / OpenCV)    │
                       │                                  │
                       │  camera → segmentation →         │
                       │  normalization → encoding →      │
                       │  matching → threshold            │
                       └───────┬───────────────┬─────────┘
                               │                │
                     Admin SDK │                │ Admin SDK
                               ▼                ▼
                     ┌───────────────┐  ┌────────────────┐
                     │ Cloud Firestore│  │Firebase Storage │
                     │ (app data)     │  │(captured images)│
                     └───────┬────────┘  └────────┬────────┘
                             │                     │
                    ┌────────┴─────────────────────┴────────┐
                    │      Firebase Cloud Messaging           │
                    └────────┬─────────────────────┬────────┘
                             │                      │
                             ▼                      ▼
                 ┌─────────────────────┐  ┌────────────────────┐
                 │   Flutter mobile app  │  │  Realtime Database   │
                 │ (5 role-based portals)│  │  (live driver GPS)   │
                 └─────────────────────┘  └──────────▲───────────┘
                                                       │ writes while
                                                       │ trip active
                                              ┌────────┴─────────┐
                                              │  Driver's phone GPS │
                                              └──────────────────┘
```

## Why this split

- **Firestore** holds everything that is "application data": students,
  courses, attendance, gate entries, alerts, library, bus/stop
  configuration, notifications. It's the natural fit for
  role-filtered, query-able, persisted records (spec §4/§38).
- **Realtime Database** holds *only* the live driver GPS
  (`driverLocation/{busId}`), because that's a single small value
  updated every few seconds while a trip is active — RTDB's low-latency
  key-value model fits that far better than Firestore document writes,
  and its rules make "student cannot read this, ever" trivial to
  enforce independently of Firestore's role documents (spec §33/§39).
- **Firebase Storage** holds the one binary artifact the system
  captures: unknown-person frames for the Security Portal (spec §20).
- **The iris_ai service is a separate Python process**, not part of the
  Flutter app or a Cloud Function, because the recognition pipeline
  needs OpenCV/NumPy/SciPy and continuous camera access — none of which
  belong in a mobile client or fit a short-lived serverless function
  well. It talks to Firebase using the **Admin SDK** (a trusted service
  account), which is why the Firestore rules can safely deny *all*
  client access to `irisProfiles` — only this trusted backend can ever
  touch biometric data.

## Role enforcement (defense in depth)

1. **Flutter navigation**: each portal's router only exposes screens for
   the signed-in user's role (`mobile/lib/core/router`).
2. **Firestore rules** (`firebase/firestore.rules`): re-enforce the same
   boundaries server-side, keyed off `users/{uid}.role`, so a modified
   or malicious client cannot read/write outside its role.
3. **Realtime Database rules** (`firebase/database.rules.json`): a
   parallel, independent enforcement specifically for the live GPS path,
   using a `roles/{uid}` mirror written by the Admin SDK at account
   creation (RTDB rules cannot query Firestore directly).
4. **Storage rules** (`firebase/storage.rules`): gate read access to
   captured security images to Admin/Security only.

## Data flow: classroom attendance (spec §16)

1. iris_ai service polls the camera (`/stream/start?mode=attendance`).
2. On a successful capture+match, it calls
   `firebase_client.find_active_course_for_camera` to determine which
   course is in session at that camera right now (Admin-configured
   schedule on the `courses` document), then
   `firebase_client.record_attendance`, which:
   - upserts today's `classSessions/{courseId}_{date}` document (this is
     what makes "a class happened today" a real fact instead of an
     assumption — it's only ever written when a real recognition event
     actually occurs for that course), then
   - checks for an existing `attendance` record for that student+course
     within the dedupe window before writing (no duplicate marks).
3. The student's own portal reads `attendance` filtered to
   `studentId == self` for the "present" count, and `classSessions`
   filtered to `courseId == X` for the "total classes" count, computing
   the percentage client-side from real Firestore documents (spec §17 —
   never hardcoded). See `mobile/lib/repositories/student_repository.dart`.

## Data flow: gate entry / unknown person (spec §18–22)

1. Same service, `mode=gate`, physically repositioned camera.
2. Match → `record_gate_entry` (Admin/Security-only collection).
3. No match → real frame is JPEG-encoded, `create_unknown_alert`
   checks the per-camera cooldown, and if not suppressed: uploads to
   Storage, writes a `securityAlerts` doc, and notifies every active
   Security user via `notify_role("security", ...)`.

## Data flow: 10-minute bus alert (spec §35)

Not part of the iris_ai service — this is a small scheduled job (see
`docs/ARCHITECTURE.md` §"Bus ETA job" below) that:

1. Reads the driver's current `driverLocation/{busId}` from RTDB.
2. For each student with a `busAssignments` record and a registered
   stop, computes straight-line/haversine distance (or a routing-API
   ETA if `MAP_API_KEY` is configured) from the bus to that stop.
3. When ETA first crosses below ~10 minutes for a given student+trip, it
   calls `firebase_client.notify_user` for that student only, and
   records that it already sent this trip's alert (e.g. a
   `busAssignments/{id}.lastAlertTripId` field) so it isn't repeated
   every polling cycle.

### Bus ETA job

This is intentionally a separate, small scheduled script/service (not
folded into iris_ai, which has nothing to do with buses) — see the
"Next phase" section of the top-level README for where this lands in
the build sequence.
