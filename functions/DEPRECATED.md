# DEPRECATED — not deployed

This Cloud Function (`check_overdue_books`) needs Firebase's paid Blaze plan, so it is **not used** and has been removed from `firebase.json` (2026-10-13, free-first rule D-7).

The same job runs for free as a Python loop in [`../overdue_checker/`](../overdue_checker/), which is started by `run.bat` / `run.sh` / `docker-compose.yml`.

Keep this folder only as a reference. If you ever move to Blaze, add the `functions` block back to `firebase.json`, deploy this one, and **stop `overdue_checker`** — running both would notify students twice.
