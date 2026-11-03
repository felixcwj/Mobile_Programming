# MyPage backend

The MyPage API is implemented in `backend/mypage_routes.py` and registered in `backend/main.py`. All requests need a Firebase ID token (`Authorization: Bearer <token>`). It uses the existing `users/{uid}` profiles and `nickname_reservations/{nickname_key}` reservations.

## API

| Method | Path | Description |
| --- | --- | --- |
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

- **Username changes are not implemented.** The existing authentication backend uses the human-chosen login ID as the immutable Firebase Auth UID, so naively changing the `id` field would break login and document ownership. This needs a dedicated username-to-UID mapping or migration, agreed with the auth backend owner.
- **30-day account deletion is pending status only.** A server scheduler / authorized worker must actually delete the Firebase Auth account, Firestore user data, nickname reservation, and associated data on/after `deletion_due_at` in a safe, auditable and idempotent process. Until that worker exists, no account is automatically deleted. A product policy is also needed on whether pending users may continue to log in. Current implementation allows authentication while pending, and blocks profile/password edits until the request is cancelled.
- The donation action can be a frontend external link. No payment processing or backend payment API is implemented.
- Tests use an isolated fake Firestore database and mocked auth. Actual Firebase integration tests and security rule review are still required. Mac gRPC was seen timing out while REST HTTPS worked; do not assume these APIs are production-ready until runtime integration succeeds.

## Test

```bash
cd backend
python -m pytest -q tests/test_mypage.py
```

GitHub Actions validates syntax and MyPage API behavior. This PR is intentionally draft and is not merged into main.
