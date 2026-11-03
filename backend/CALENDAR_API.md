# Calendar API — feature branch contract

All endpoints require a valid Firebase ID token via `Authorization: Bearer <token>`; backend documents belong to `users/{uid}`. This branch must not be merged until Firebase and device tests pass.

## Personal events

- `POST /calendar/events` — create a personal event.
- `GET /calendar/events?starts_from=<ISO8601>&starts_before=<ISO8601>` — list events whose **start time** falls in the range (maximum 500).
- `GET /calendar/events/{event_id}` — read one event.
- `PUT /calendar/events/{event_id}` — replace fields; supply current `version`, return 409 on stale updates.
- `DELETE /calendar/events/{event_id}?version=N` — soft-delete. The deletion is also visible to sync clients.
- `GET /calendar/pending-deletions` — list external deletions awaiting confirmation.
- `POST /calendar/events/{event_id}/external-delete-decision` — `{"decision":"delete"}` or `{"decision":"keep"}`.

`POST` and `PUT` accept timezone-aware ISO8601 strings for `starts_at` and `ends_at`, plus `title`, `location`, `memo`, `all_day`. The backend stores timestamps in UTC. `PUT` additionally requires `version`. All updates are scoped to the authenticated user; events marked `source=meeting` are reserved for future agreement with the home-backend owner.

Example:

```json
{
  "title": "Study group",
  "starts_at": "2026-11-05T18:00:00+09:00",
  "ends_at": "2026-11-05T19:30:00+09:00",
  "location": "Library",
  "memo": "",
  "all_day": false
}
```

## External calendars (device-side integration required)

1. Client assigns and retains a stable non-secret `device_id` unique to that app installation.
2. `PUT /calendar/selected-calendars` with `{"device_id":"...", "calendar_ids":["..."]}`; only these calendar IDs are accepted for import. `GET /calendar/selected-calendars?device_id=...` returns the stored choice.
3. `POST /calendar/sync/external` with `{"device_id":"...", "changes":[...]}`. Each change has `calendar_id`, `external_event_id`, `status` (`upsert` or `deleted`), `base_version`, and `event` for upserts. Existing event upserts must carry the current version or return a per-item `conflict` status. The batch has a 100-item limit.
4. `GET /calendar/sync/changes?updated_since=<ISO8601>&limit=100` returns backend events, including soft-delete tombstones, modified since a cursor. Device client must maintain its cursor, reconcile events, and avoid reflecting its own changes in a loop.
5. `POST /calendar/events/{event_id}/external-link` with `{"device_id":"...", "calendar_id":"...", "external_event_id":"...", "version":1}` records the external counterpart when the client created it from an app event.
6. External deletion sets `external_delete_pending=true`. The client displays a confirmation prompt. `keep` preserves a personal copy; `delete` soft-deletes it.

## Unresolved and test gates

- Flutter native calendar reading/writing, permission prompts, per-device cursor persistence, and full round-trip sync have not been built. The server cannot do these alone.
- Clock/sync cursor boundary handling, repeated deletion after a `keep` decision, cross-device event ownership, conflict resolution UX, and calendar-deselection cleanup need integration tests. Existing API is a prototype contract, not a production-grade synchronizer.
- A meeting calendar schema (room ID, participants, ownership and source of truth) must be agreed with the home-backend owner before importing AI bookings.
- iOS testing requires access to an Apple device/build; the course deliverable is Android APK.
- Firestore real credentials/service account and security-rule review are required for end-to-end verification. Never commit private credentials.
- To run isolated tests, install `backend/requirements.txt` plus `pytest`, then run `cd backend && python -m pytest -q tests/test_calendar_contract.py`.
