# PlanIt — classroom Android tablet QA build

## What is inside this branch?
- Authoritative FastAPI backend, based on Chaeyeon's `feature/planit-ai-improvements` snapshot.
- Flutter submodule pinned to Yonghoon's `feature/login-update`, plus **tracked integration overlay** under `integration/frontend_overlay`.
- Run `python3 integration/apply_frontend.py` **after clone**. This modifies only the local submodule checkout. The teammate's upstream repository remains unchanged.
- The overlay implements a shared FastAPI authentication path (real email/UID), room creation and joining, persisted room restoration, personal calendar API, room schedule, verified-region preference submission and AI recommendation/confirmation.
- CI checks backend pytest, Flutter static analysis/widget tests, Firebase Auth/Firestore emulator multi-account E2E, and Android 13 tablet-sized release APK boot and touch/scroll smoke test. These are meaningful automated tests but do not replace physical-device and real-cloud API tests.

## Install on the Lenovo Tab M8 (4th Gen) 2024 or a teammate's Galaxy

1. Open the green **PlanIt team integration (Flutter)** workflow on the GitHub Actions tab of this branch.
2. Under **Artifacts**, download `planit-android-tablet-release` (ZIP) and extract `app-release.apk`.
3. Send the APK to each test device and install it from Files/Downloads. Grant only the one-off Android permission to install from that file manager if prompted. Do not install unknown APKs from strangers.
4. Open **플랜잇** → login screen → **Team server** (**팀 서버 연결** in Korean), and configure one identical **HTTPS** API URL on every device. The release build defaults to `https://planit-team-backend.vercel.app`; it is not usable until server-side Firebase credentials are configured and its `/health` returns HTTP 200.
5. Create two distinct test accounts; room owner creates a room and shares the exact 7-character invite code; the other member joins; then check room appointments and personal calendars on both devices.

The release APK targets Android 13 and is universal (ARM 32/64-bit), not the emulator-only `10.0.2.2` build. It has been booted and gesture-stressed on a simulated 800×1280 low-RAM Android 13 device. The physical school-issued Lenovo tablet and Galaxy still require direct hands-on testing.

## Deploy the shared backend before class (no paid AI key required)

The `planit-team-backend` Vercel project is provisioned and points at `https://planit-team-backend.vercel.app`. It **currently returns HTTP 500**, because `FIREBASE_SERVICE_ACCOUNT_JSON` is not configured. Do not distribute it as a functioning backend until these steps are complete:

1. On the Vercel project **Settings → Environment Variables**, configure `FIREBASE_SERVICE_ACCOUNT_JSON` with the full service account JSON for Firebase project `mobile-programming-d4e67`. Mark it **Sensitive/Encrypted** and Production-scoped. This key must never be committed to GitHub, embedded in an APK, or pasted into a team chat. The backend accepts JSON text in this env var.
2. Keep the Firebase Web API key in `FIREBASE_WEB_API_KEY` configured for the **same** Firebase project.
3. Configure `KAKAO_REST_API_KEY` as a server-side protected variable to enable real Korean map lookup and the verified-place no-cost fallback recommendations.
4. Redeploy the backend in Vercel and confirm `https://planit-team-backend.vercel.app/health` returns `{"status":"ok","database":"firebase"}`.
5. When the professor provides the paid AI key, set `AI_API_KEY` (server-only), `AI_MODEL` (the model name for that provider), and `AI_API_BASE_URL` (provider's compatible HTTPS chat-completions endpoint). Redeploy the backend only: **the APK does not need rebuilding**.

Without the paid AI key, the app can use its clearly labeled Kakao-verified course fallback if the Kakao key is configured and the shared Firebase backend is functioning. The fallback is not described as an AI-generated route.

### Private classroom-server alternative

From a Mac that already has `~/.config/mobile-programming/serviceAccountKey.json` (never commit it), run `bash backend/start_classroom.sh --tunnel` after configuring `FIREBASE_WEB_API_KEY` and `KAKAO_REST_API_KEY` securely in `backend/.env`. This requires `cloudflared` installed and the Mac to remain running. Copy the resulting `https://...trycloudflare.com` URL to **팀 서버 연결** on each device. Use disposable class accounts. Do not use plain HTTP with the release APK.

## Source setup

```bash
git clone --recurse-submodules -b experiment/planit-team-integration-20261122 https://github.com/felixcwj/Mobile_Programming.git planit-integrated
cd planit-integrated
python3 integration/apply_frontend.py
cd frontend
flutter --version  # CI-pinned SDK: Flutter 3.41.9 (Dart 3.11.5)
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run -d emulator-5554 --dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000
```

Run the backend in the other terminal, with private server credentials:
```bash
cd planit-integrated/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Privately configure Firebase service account, web API key, Kakao REST key and OpenRouter key
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

On **a physical phone**, replace `10.0.2.2` with the backend machine's reachable LAN IP; do not expose server private credentials or run an HTTP backend on the public Internet. For iOS simulator on the same Mac the appropriate host is usually localhost. Firebase Auth/Firestore must refer to the **same Firebase project** on both ends.

## App language

PlanIt starts in English regardless of the device language. After signing in, open **Profile → Language** and choose **English** or **한국어**. The setting applies immediately and persists on the device. Account names, room and event titles, server-provided messages and content, and recommendation details retain their original language.

The overlay carries the ARB catalogs and generation config. Run it with `python -X utf8 integration/apply_frontend.py` on Windows. Reapplying the overlay is safe and restores its tracked files in the frontend checkout. Run `flutter gen-l10n` in `frontend` after updating the catalogs.

## Quality gates (automated checks passed; physical/cloud checks separate)
- Flutter analyze and tests pass after the overlay.
- Auth: two independent accounts sign up, login, nickname + profile photo persisted, logout/relogin restores state.
- Two devices: first makes a room, second joins using the actual 7-digit invite code, both see matching state.
- Wrong/overseas location rejected with a helpful message; correct Korean area accepted. Kakao and AI keys operational.
- Each member submits constraints, AI recommendation returns verified Kakao place IDs, confirms to a shared appointment.
- New and edited personal events survive relogin; shared event is visible to each room member, not duplicated.
- Repeated taps, double submit, rapid scrolling, no network, 429 on free models, stale version conflicts show recoverable errors.

## Known limitations
- API/Flutter integration is implemented as an overlay because the frontend repository isn't writable by the integration maintainer.
- Calendar API retrieves one year before and after the current date; scrolling outside this range needs date-window pagination.
- Existing direct Firebase accounts registered through the old `profiles` collection are not automatically migrated to the authoritative `users` model. **Do not delete user records or silently recreate test accounts.**
- A public backend URL exists, but is **not operational until its Firebase Admin credentials are configured**. Check `/health` before use.
- Firebase emulator and mocked external provider results do not prove live Google/Kakao or paid model access. No professor-supplied AI key is needed to install or navigate the app.
- Additional work may be required based on actual compile/test/device results, especially collaborative preference voting and existing historical accounts.

## Shared team QA
Track findings in https://github.com/felixcwj/Mobile_Programming/issues/5. Do not send Firebase service account keys or tokens in issues or chat.

## Feedback format
Create one GitHub issue per reproducible defect: device, account type (no personal info), steps, expected, actual, screenshot with secrets removed, severity, and affected endpoint.
