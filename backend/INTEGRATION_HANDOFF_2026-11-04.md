# 2026-11-04 13:00 Discord — backend integration handoff

## Status at 2026-11-03

- Base branch: `main`, original authentication backend written by the auth owner.
- Calendar: `feature/calendar-backend`, draft PR #2. Personal event CRUD and selected-calendar/sync API contract implemented. No real device sync or Firebase end-to-end verification.
- MyPage: `feature/mypage-backend`, draft PR #3. Profile edits, username alias, password change, 30-day deletion request/cancellation, optional donation URL, guarded cleanup CLI. Not deployed and not merged.
- **Both PRs modify `backend/main.py`**. Merging one into `main` requires rebasing/resolving the other, then running both test suites. Never replace `main.py` with only one PR's copy.
- The current macOS Firestore gRPC path timed out even via phone hotspot. Authenticated read-only Firestore REST succeeded, but this does not verify Python SDK transactions. No actual Firebase writes/deletes were run in these PRs.

## Decisions needed from the auth/room backend owner

1. Confirm whether the login ID is a stable Firebase UID for legacy accounts, and review MyPage's `usernames/{id} -> uid` lookup introduced by PR #3.
2. Share the exact Firestore collections and fields for rooms, participants, AI-suggested meeting slots, accepted meeting dates, permissions, and deletion rules. Do not invent room events from the calendar router.
3. Choose one source of truth for accepted room events (room document vs per-user calendar mirror) and the authoritative event owner for cancel/change permissions.
4. Decide whether pending account deletion should block login, how to handle room participation after user deletion, and whether account cleanup requires an audit trail.

## Flutter connection contract

All protected endpoints take the Firebase ID token as `Authorization: Bearer <id_token>`. Never commit token values or service account keys.

| Screen | Request | Notes |
|---|---|---|
| MyPage display | `GET /mypage/profile` | Display current user fields; do not cache stale login IDs |
| MyPage edit | `PUT /mypage/profile` | `nickname`, `name`, `phone` |
| Login ID edit | `PUT /mypage/id` | `new_id`, `password`; user UID remains unchanged |
| Password edit | `POST /mypage/password` | `current_password`, `new_password`, `new_password_confirm`; app must sign in again |
| Delete status | `GET /mypage/deletion` | Show pending and due date |
| Delete request | `POST /mypage/deletion` | `password`; account not instantly erased |
| Delete cancel | `DELETE /mypage/deletion` | Allowed before deadline unless processing started |
| Developer donation | `GET /mypage/donation` | Label exactly **개발자에게 후원하기**; disabled until real HTTPS URL configured; open in external browser |
| Calendar month | `GET /calendar/events` | `starts_from`, `starts_before`, ISO8601 with timezone |
| Add personal event | `POST /calendar/events` | `title`, `starts_at`, `ends_at`, `location`, `memo`, `all_day` |
| Edit personal event | `PUT /calendar/events/{id}` | Same fields plus current `version` |
| Delete personal event | `DELETE /calendar/events/{id}?version=N` | Soft delete |
| External selection | `GET/PUT /calendar/selected-calendars` | Stable `device_id`, selected `calendar_ids` only |
| External import | `POST /calendar/sync/external` | Per-event `upsert` / `deleted`; use version checks |
| Outbound change feed | `GET /calendar/sync/changes` | `updated_since`; initial cursor strategy needs design |
| External delete prompt | `GET /calendar/pending-deletions`, `POST /calendar/events/{id}/external-delete-decision` | User explicitly chooses `keep` or `delete` |

## Must-pass live integration scenarios

1. Create test account, log in, and access own MyPage. Another user's profile must never be readable using that token.
2. Edit nickname and detect a duplicate nickname; change login ID and log out/in using the new ID. Confirm legacy account login still works.
3. Reject incorrect current password. After password reset, confirm token/session handling and sign in again.
4. Add an event, view it in the correct KST date, edit with correct version, reject stale edit, delete, and verify disappearance.
5. Select one device calendar and verify unselected calendars never import. Import, update, and delete an external event. Test `keep` and `delete`, including repeat notifications.
6. Agree on meeting-room schema. Create/accept/cancel a room event and confirm all members see consistent calendar state.
7. Try app relaunch, permission denial, network interruption, repeated sync, and multiple devices to detect duplicate events.
8. Test account deletion only with disposable test accounts after deciding shared-room cleanup; never run cleanup in production before retention review.

## Blockers that must not be hidden

- The Android/iOS native calendar permission and read/write adapter is a **Flutter task**, not delivered by these FastAPI branches.
- Calendar change-feed pagination and deduplication across devices are still incomplete for a production-grade sync system.
- Account deletion worker script is **not scheduled**; actual automatic 30-day deletion is not yet running.
- Firebase SDK gRPC integration, Firestore composite indexes/rules, and real device tests have not passed.
- The direct donation link remains unset by design.

## Proposed meeting result

Record the authenticated room event source-of-truth schema, agree API base URL/development environment, assign Flutter screen-to-endpoint integration, choose the person responsible for real Firebase smoke testing, and choose a PR merge order. Merge only after both contract suites plus a real test account flow pass. Do not merge directly during the meeting just because the isolated tests passed.
