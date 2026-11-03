# Calendar backend draft

This branch adds `calendar_routes.py` and registers it in FastAPI without changing the authentication endpoints.

## Authentication

All `/calendar/*` APIs require `Authorization: Bearer <Firebase ID token>`. Each user only accesses documents under `users/{uid}`.

## API endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | /calendar/events?starts_from=...&starts_before=... | Get personal calendar events in start-time range |
| POST | /calendar/events | Create a personal event |
| GET | /calendar/events/{id} | Read a personal event |
| PUT | /calendar/events/{id} | Update event; include current `version` |
| DELETE | /calendar/events/{id}?version=... | Soft-delete event |
| GET | /calendar/selected-calendars | Get selected device calendar IDs |
| PUT | /calendar/selected-calendars | Set selected device calendar IDs |
| POST | /calendar/sync/external | Receive external device calendar upserts/deletions |
| POST | /calendar/events/{id}/external-delete-decision | Choose `delete` or `keep` |

Dates use timezone-aware ISO 8601, such as `2026-11-03T18:00:00+09:00`.

Example create request:

```json
{
  "title": "Dinner",
  "starts_at": "2026-11-03T18:00:00+09:00",
  "ends_at": "2026-11-03T19:00:00+09:00",
  "location": "Seoul",
  "memo": "",
  "all_day": false
}
```

## Not completed

- This server cannot access phone calendar events on its own. Flutter must request permission, read selected calendars, detect changes and call sync APIs.
- Changes from this app must be written back to the device by the Flutter integration, with version/conflict checks.
- Local-to-device outbound sync and resolution for concurrent changes are still needed.
- Event deletions from external calendars only set `external_delete_pending`, requiring user confirmation.
- AI meeting events need a shared room/event schema agreed with the home backend owner; no invented integration has been made.
- End-to-end testing with Firebase credentials, Android/iOS integration, and Firestore rules validation have not yet been completed.
- For production usage: device-specific calendar IDs should be scoped by device, support deselection cleanup, and the sync batch needs limits/rate limiting and conflict-resolution tests.

This code is a review draft. Do not merge until the integration above is tested.
