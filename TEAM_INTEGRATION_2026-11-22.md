# PlanIt team integration workspace — 2026-11-22

> **Status: source checkout prepared; app/API integration NOT complete.** This workspace pins both teams' code at reproducible revisions. It is NOT a claim that flows work end-to-end.

## Pinned sources

- Backend: `feature/planit-ai-improvements` @ `8288edfe9b86256597a86c8144e4e8dda400857a`
- Frontend: `yhooni29/planit_front` `feature/login-update` @ `eba1dd55965ec221e97474ad5a102771bae2db38` (Git submodule `frontend/`).
- Original branches and `main` have not been altered.

## Clone for team review

```bash
git clone --branch experiment/planit-team-integration-20261122 --recurse-submodules https://github.com/felixcwj/Mobile_Programming.git planit-team-test
cd planit-team-test
git submodule status
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Supply Firebase environment and local serviceAccountKey.json privately; NEVER commit it
python -m uvicorn main:app --reload --port 8000
```

In another terminal:
```bash
cd planit-team-test/frontend
flutter pub get
flutter run -d emulator-5554 --dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000
```

**Important:** The current Flutter app **does not consume** `PLANIT_API_BASE_URL`; the dart-define above is only a future integration convention. It authenticates via Firebase directly and keeps room/calendar data in memory. A running backend alone will not fix persistence. Do not report it as an integrated app. Access to server-side secret keys must be arranged privately.

## Critical integration gaps verified from source

1. **Two incompatible account sources.** FastAPI `/auth/signup` creates Firebase Auth accounts with the REAL email and writes `users/{uid}`; Flutter `FirebaseAccounts.register` creates an Auth account with `<id>@planit-id.invalid` and writes `profiles/{uid}`. The two systems cannot be used interchangeably. Pick one authoritative backend contract, migrate/handle test accounts safely, and update login, signup, profile and refresh flows together.
2. **Room and calendar still in memory on Flutter.** `HomeScreen` instantiates `RoomsController(rooms: [])` and `CalendarController` without a network repository, and join-room tells users backend connectivity is not implemented. Bind all create/join/list/leave/preferences/recommendation/appointment/calendar endpoints and rehydrate on login and app resume.
3. **Location validation is present on backend**, through `GET /places/validate-region` and region checks on preference save/recommendation, but Flutter must call and display the server result. Ensure region text is validated; for departure/arrival use resolved Kakao places with IDs/coordinates rather than arbitrary user strings, fail closed on no match, and restrict destinations to South Korea.
4. **Signup UI is present in frontend feature branch:** ID, email, password, confirmation -> nickname/photo -> home; backend signup has all fields in one request (compatible if called only after second step). Confirm backend accepts image encoding and id (backend 4-12 chars, frontend currently 4-20).
5. **Remove support history copy UI** without removing the ability to contact support.
6. Verify preference input type/length failures result in a friendly message, not a crash.
7. Tests must include logout/relogin state, separate test devices/accounts, offline, latency, rapid scrolling, repeated taps, concurrent edits, invite code with #, 8-member limit, map unknown/foreign queries, date conflict, token expiration, and invalid profile images.

## Team feedback template

File separate issues in this repository, one per reproducible defect:

- Build / device / OS:
- Account type (avoid real emails and personal data):
- Screen and exact action:
- Expected:
- Actual:
- Screenshot or sanitized logs:
- Severity: blocker / major / minor
- Owner and proposed fix:

**Release gate:** Do not mark integration complete until 2 independent users can register/login, create and join the same room, set/validate conditions, receive/confirm a recommendation, see shared appointment + private calendars, logout/login and recover data, with automated checks and an actual device/emulator test.
