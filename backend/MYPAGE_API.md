# MyPage backend

The MyPage API is implemented in `backend/mypage_routes.py` and registered in `backend/main.py`. All requests need a Firebase ID token (`Authorization: Bearer <token>`). It uses the existing `users/{uid}` profiles and `nickname_reservations/{nickname_key}` reservations.

## API

| Method | Path | Description |
| --- | --- | --- |
| PUT | `/mypage/id` | Change login ID without changing Firebase UID; requires current password |
| GET | `/mypage/donation` | Get the configured external donation URL and availability |
| GET | `/mypage/profile` | Current user's profile |
| PUT | `/mypage/profile` | Change nickname, name and phone number |
| POST | `/mypage/password` | Change password with current password verification |
| GET | `/mypage/deletion` | Get deletion-request status |
| POST | `/mypage/deletion` | Request deletion after password verification, due in 30 days |
| DELETE | `/mypage/deletion` | Cancel pending request before due date |

Example `PUT /mypage/profile`:

```json
{"nickname":"Nickname","name":"User Name","phone":"01012345678"}
```

Example `POST /mypage/password`:

```json
{"current_password":"oldpassword","new_password":"newpassword","new_password_confirm":"newpassword"}
```

Example `POST /mypage/deletion`:

```json
{"password":"currentpassword"}
```

The profile nickname reservation change uses a Firestore transaction to prevent a duplicate nickname. The Firebase Auth display name update is best-effort; the Firestore profile remains the authoritative display name if that secondary update fails. Password changes revoke refresh tokens; the client should discard old tokens and request sign-in again.

## Important limitations requiring integration work

- **Username change implementation is included in this draft.** `PUT /mypage/id` accepts `{"new_id":"newlogin","password":"currentpassword"}`. Firebase UID remains stable, while `users/{uid}.id` and `usernames/{new_id}` are updated transactionally. To support this, `main.py` signup, login and ID-availability paths were changed to look up `usernames` with legacy UID fallback. This is a compatibility-sensitive change to the authentication teammate’s code: review together before merging, and run actual Firebase integration tests. Existing Firebase UID values remain reserved even after a rename. It does not migrate existing users into new UID values.
- **30-day deletion:** The request/status/cancel endpoints are implemented. A guarded `backend/account_cleanup.py` CLI now finds due requests and defaults to dry-run. When explicitly executed, it claims due records, deletes Firebase Auth users, releases their username/nickname reservations when owned, and recursively deletes the user document and subcollections. **It is not scheduled or deployed**. Until a trusted server/worker is configured with credentials and recurring execution, accounts are not automatically deleted after 30 days. The cleanup scope does not yet cover unknown shared room/member references; review home-backend data ownership and retention policy before running with `--execute`. Pending users can authenticate and cancel, but cannot modify profile/password until cancellation.
- **Developer donation:** The MyPage menu label must be exactly `개발자에게 후원하기` (no emoji). `GET /mypage/donation` returns `{"title":"개발자에게 후원하기","enabled":false,"url":null}` until the server operator configures `DEVELOPER_DONATION_URL=https://real-provider.example/path` in the backend's private environment. Only HTTPS URLs without embedded credentials are returned. Flutter should show the item near the bottom of MyPage, open `url` in an external browser only when `enabled=true`, and otherwise display an unavailable message or disable the item. This backend does **not** collect payments or record donations; never invent an actual provider URL.
- Tests use an isolated fake Firestore database and mocked auth, including legacy login and renamed username login. Actual Firebase integration tests and security rule review are still required. Mac gRPC was seen timing out while REST HTTPS worked; do not assume these APIs are production-ready until runtime integration succeeds.

## Test

```bash
cd backend
python -m pytest -q tests/test_mypage.py tests/test_mypage_login_compat.py
```

GitHub Actions validates syntax, MyPage API behavior, username login compatibility and cleanup dry-run guardrails.

## Deletion worker safety

This worker is intentionally not enabled in CI or on a production scheduler. It is destructive only with explicit opt-in, and should not be executed until team data retention and shared-room cleanup are decided. For an operator-only dry-run (never put the service-account JSON in Git):

```bash
python backend/account_cleanup.py --service-account "$HOME/.config/mobile-programming/serviceAccountKey.json" --project-id mobile-programming-d4e67
```

For a future authorized deployment, schedule this script on a trusted host and supply environment-scoped credentials. Execution requires `--execute` and an `ALLOW_ACCOUNT_DELETION` variable exactly matching the selected Firebase project ID. Do not configure or run destructive mode until remaining data cleanup has been reviewed.

No real Firebase writes or deletes were performed while developing this PR. This PR is intentionally draft and is not merged into main.
