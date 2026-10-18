# Web deployment (Vercel)

Live site: https://securecampus-seven.vercel.app (Vercel project `securecampus`, account `maryamfatima454`, team `maryams-projects-791bda4b`).

Vercel cannot build Flutter by itself, so the site is a **static upload of a release web build**. It is not auto-deployed from GitHub: pushing to `main` does not update it. The repo's root `vercel.json` turns Vercel's own Git builds off (`git.deploymentEnabled: false`); without it, every push made Vercel try to build the repository itself, found no web output, and replaced the live site with a 404 page. Redeploy by hand after changes:

```
cd mobile
flutter build web --release
# copy build/web into an empty folder, add vercel.json (cleanUrls, no-cache header), then:
vercel deploy --prod --yes --name securecampus
```

Notes
- The login page has no pre-filled accounts or "Demo accounts" button in any build: users sign in with their own email and password.
- Routing uses `#/` (e.g. `/#/login`), so no rewrites are needed.
- The Python services (`iris_ai`, `bus_eta`, `overdue_checker`) are not hosted on Vercel. The web app calls `BACKEND_BASE_URL` (default `http://localhost:8000`), so features that need that service (admin account creation, camera control) do not work on the public site.
- Firestore rules are deployed separately: `firebase deploy --only firestore:rules --project campus-a4087`, signed in as an account that owns the project.
