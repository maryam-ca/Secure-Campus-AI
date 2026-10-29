# Web deployment (Vercel)

Live site: https://securecampus-seven.vercel.app (Vercel project `securecampus`, account `maryamfatima454`, team `maryams-projects-791bda4b`).

Vercel cannot build Flutter by itself, so the site is a **static upload of a release web build**. Vercel's own Git builds are off, so a push alone does not make Vercel rebuild it; the GitHub Action below (or the manual steps) does. The repo's root `vercel.json` turns Vercel's own Git builds off (`git.deploymentEnabled: false`); without it, every push made Vercel try to build the repository itself, found no web output, and replaced the live site with a 404 page. Redeploy by hand after changes:

```
cd mobile
flutter build web --release
# copy build/web into an empty folder, add vercel.json (cleanUrls, no-cache header), then:
vercel deploy --prod --yes --name securecampus
```

## Optional: automatic deploy (GitHub Action, off by default)

The workflow only runs when started by hand. To make every push deploy, add `push:` / `branches: [main]` under `on:` in the workflow file after creating the secrets. Without a token, use `.\deploy_web.bat` (see below).

`.github/workflows/deploy-web.yml` builds the Flutter web app from the pushed commit on GitHub, uploads it to the live Vercel project and then downloads the live `main.dart.js` to check it is byte-for-byte the build it just made (the job fails if not). So after `git push` the site updates in about 5-8 minutes, and the **Actions** tab shows green when it is live. You can also run it by hand: Actions > "Deploy web app to Vercel" > Run workflow.

One-time setup (the job stops with "Secret ... is not set" until this is done). Do it signed in to Vercel as `maryamfatima454`:

1. **VERCEL_TOKEN**: vercel.com > Account Settings > Tokens > Create Token (name `github-deploy`, scope: the `maryams-projects` team, expiry as you like). Copy it once.
2. **VERCEL_PROJECT_ID**: vercel.com > the `securecampus` project > Settings > General > *Project ID* (starts `prj_`).
3. **VERCEL_ORG_ID**: vercel.com > Settings of the team/account that owns the project > General > *Team ID* (starts `team_`; for a personal account it is the account ID shown there).
4. On GitHub: repo `maryam-ca/Secure-Campus-AI` > Settings > Secrets and variables > Actions > **New repository secret**, add the three with exactly those names. Never paste the token into chat, a commit or a file.
5. Actions tab > "Deploy web app to Vercel" > **Run workflow** (or just push).

Rotate the token on Vercel and update the GitHub secret if it is ever exposed. The manual route below still works as a fallback.

**One-click version:** run `.\deploy_web.bat` from the repo root. It checks that the Vercel CLI is signed in as `maryamfatima454` (if not: `vercel logout`, then `vercel login`), builds the web app from the current code, and deploys it. To confirm what is live, download `https://securecampus-seven.vercel.app/main.dart.js` and search it for a phrase from the newest feature; after the upload press Ctrl+F5 in the browser (Flutter keeps the old version in a service worker).

Notes
- The login page has no pre-filled accounts or "Demo accounts" button in any build: users sign in with their own email and password.
- Routing uses `#/` (e.g. `/#/login`), so no rewrites are needed.
- The Python services (`iris_ai`, `bus_eta`, `overdue_checker`) are not hosted on Vercel. The web app calls `BACKEND_BASE_URL` (default `http://localhost:8000`), so features that need that service (admin account creation, camera control) do not work on the public site.
- Firestore rules are deployed separately: `firebase deploy --only firestore:rules --project campus-a4087`, signed in as an account that owns the project.
