# PlanIt shared integrated app — work in progress

## What is inside this branch?
- Authoritative FastAPI backend, based on Chaeyeon's `feature/planit-ai-improvements` snapshot.
- Flutter submodule pinned to Yonghoon's `feature/login-update`, plus **tracked integration overlay** under `integration/frontend_overlay`.
- Run `python3 integration/apply_frontend.py` **after clone**. This modifies only the local submodule checkout. The teammate's upstream repository remains unchanged.
- The overlay implements a shared FastAPI authentication path (real email/UID), room creation and joining, persisted room restoration, personal calendar API, room schedule, verified-region preference submission and AI recommendation/confirmation.
- Changes are preliminary and **must be verified by GitHub Actions and physical emulator/real-account tests before team-wide release**.

## Setup

```bash
git clone --recurse-submodules -b experiment/planit-team-integration-20261122 https://github.com/felixcwj/Mobile_Programming.git planit-integrated
cd planit-integrated
python3 integration/apply_frontend.py
cd frontend
flutter pub get
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

## Quality gates (not yet claimed passed)
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
- No publicly reachable server URL has been set, so teammates outside the backend host network must agree on a private reachable development server.
- A running GitHub workflow without Firebase/Kakao/OpenRouter credentials cannot prove live API behaviour.
- Additional work may be required based on actual compile/test/device results, especially collaborative preference voting and existing historical accounts.

## Feedback format
Create one GitHub issue per reproducible defect: device, account type (no personal info), steps, expected, actual, screenshot with secrets removed, severity, and affected endpoint.
