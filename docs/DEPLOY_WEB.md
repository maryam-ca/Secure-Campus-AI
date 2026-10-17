# Web deployment (Vercel)

Live site: https://securecampus-theta.vercel.app (Vercel project `securecampus`, scope `azhars-projects-61cd967e`).

Vercel cannot build Flutter by itself, so the site is a **static upload of a release web build**. It is not auto-deployed from GitHub: pushing to `main` does not update it. Redeploy by hand after changes:

```
cd mobile
flutter build web --release
# copy build/web into an empty folder, add vercel.json (cleanUrls, no-cache header), then:
vercel deploy --prod --yes --name securecampus
```

Notes
- It is a **release** build, so the debug-only "Demo accounts" button (and the demo passwords) are not included. Never pass `--dart-define-from-file=demo_accounts.json` to a build that goes on a public URL.
- Routing uses `#/` (e.g. `/#/login`), so no rewrites are needed.
- The Python services (`iris_ai`, `bus_eta`, `overdue_checker`) are not hosted on Vercel. The web app calls `BACKEND_BASE_URL` (default `http://localhost:8000`), so features that need that service (admin account creation, camera control) do not work on the public site.
- Firestore rules are deployed separately: `firebase deploy --only firestore:rules --project campus-a4087`, signed in as an account that owns the project.
