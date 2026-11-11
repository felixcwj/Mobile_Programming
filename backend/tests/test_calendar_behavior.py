from datetime import datetime, timezone
from copy import deepcopy

from fastapi import FastAPI
from fastapi.testclient import TestClient
import pytest

from calendar_routes import make_calendar_router
import calendar_routes


class Snapshot:
    def __init__(self, path, data):
        self.id = path.split("/")[-1]
        self.exists = data is not None
        self.data = deepcopy(data)

    def to_dict(self):
        return deepcopy(self.data)


class Document:
    def __init__(self, db, path):
        self.db = db
        self.path = path
        self.id = path.split("/")[-1]

    def collection(self, child):
        return Query(self.db, self.path + "/" + child)

    def get(self, transaction=None):
        return Snapshot(self.path, self.db.data.get(self.path))

    def create(self, data):
        if self.path in self.db.data:
            raise ValueError("already exists")
        self.set(data)

    def delete(self):
        self.db.data.pop(self.path, None)

    def normalize(self, data):
        return {
            key: (datetime.now(timezone.utc) if value is calendar_routes.firestore.SERVER_TIMESTAMP else deepcopy(value))
            for key, value in data.items()
        }

    def set(self, data):
        self.db.data[self.path] = self.normalize(data)

    def update(self, values):
        if self.path not in self.db.data:
            raise ValueError("not found")
        self.db.data[self.path].update(self.normalize(values))


class Query:
    def __init__(self, db, path):
        self.db = db
        self.path = path
        self.filters = []
        self.order = None
        self.count = 1000

    def document(self, doc_id):
        return Document(self.db, self.path + "/" + doc_id)

    def where(self, name, op, value):
        self.filters.append((name, op, value))
        return self

    def order_by(self, name):
        self.order = name
        return self

    def limit(self, count):
        self.count = count
        return self

    def stream(self):
        prefix = self.path + "/"
        results = []
        for key, data in self.db.data.items():
            if not key.startswith(prefix) or "/" in key[len(prefix):]:
                continue
            if all(self.matches(data.get(field), operator, target) for field, operator, target in self.filters):
                results.append(Snapshot(key, data))
        if self.order:
            results.sort(key=lambda item: item.data[self.order])
        return results[: self.count]

    @staticmethod
    def matches(value, operator, target):
        if operator == "in":
            return value in target
        if operator == "==":
            return value == target
        if operator == ">=":
            return value >= target
        if operator == "<":
            return value < target
        raise AssertionError(operator)


class Transaction:
    def create(self, ref, data):
        ref.create(data)

    def set(self, ref, data):
        ref.set(data)

    def update(self, ref, data):
        ref.update(data)


class FakeDB:
    def __init__(self):
        self.data = {}

    def collection(self, path):
        return Query(self, path)

    def transaction(self):
        return Transaction()


@pytest.fixture
def setup_calendar(monkeypatch):
    monkeypatch.setattr(calendar_routes.firestore, "transactional", lambda fn: fn)
    db = FakeDB()
    app = FastAPI()

    def user():
        return {"uid": "alpha"}

    app.include_router(make_calendar_router(db, user))
    return TestClient(app), db


def payload():
    return {
        "title": "Dinner",
        "starts_at": "2026-11-05T18:00:00+09:00",
        "ends_at": "2026-11-05T19:30:00+09:00",
        "location": "Seoul",
        "memo": "",
        "all_day": False,
    }


def test_crud_and_deleted_event_access(setup_calendar):
    client, db = setup_calendar
    response = client.post("/calendar/events", json=payload())
    assert response.status_code == 201, response.text
    created = response.json()
    assert created["version"] == 1
    assert created["deleted"] is False
    event_id = created["id"]

    response = client.get("/calendar/events", params={
        "starts_from": "2026-11-01T00:00:00+09:00",
        "starts_before": "2026-12-01T00:00:00+09:00",
    })
    assert response.status_code == 200, response.text
    assert len(response.json()["events"]) == 1

    change = {**payload(), "title": "Updated", "version": 1}
    response = client.put(f"/calendar/events/{event_id}", json=change)
    assert response.status_code == 200, response.text
    assert response.json()["version"] == 2

    assert client.put(f"/calendar/events/{event_id}", json=change).status_code == 409
    response = client.delete(f"/calendar/events/{event_id}", params={"version": 2})
    assert response.status_code == 200, response.text
    assert client.get(f"/calendar/events/{event_id}").status_code == 404
    assert client.put(f"/calendar/events/{event_id}", json={**change, "version": 3}).status_code == 404


def test_external_delete_requires_confirmation(setup_calendar):
    client, db = setup_calendar
    selected = client.put("/calendar/selected-calendars", json={
        "device_id": "device1",
        "calendar_ids": ["primary"],
    })
    assert selected.status_code == 200, selected.text

    upsert = {
        "device_id": "device1",
        "changes": [{
            "calendar_id": "primary",
            "external_event_id": "abc",
            "status": "upsert",
            "event": payload(),
        }],
    }
    imported = client.post("/calendar/sync/external", json=upsert)
    assert imported.status_code == 200, imported.text
    event_id = imported.json()["results"][0]["event_id"]

    removed = client.post("/calendar/sync/external", json={
        "device_id": "device1",
        "changes": [{
            "calendar_id": "primary",
            "external_event_id": "abc",
            "status": "deleted",
        }],
    })
    assert removed.status_code == 200, removed.text
    assert removed.json()["results"][0]["status"] == "confirmation_required"

    pending = client.get("/calendar/pending-deletions")
    assert pending.status_code == 200, pending.text
    assert len(pending.json()["events"]) == 1

    keep = client.post(f"/calendar/events/{event_id}/external-delete-decision", json={
        "decision": "keep",
    })
    assert keep.status_code == 200, keep.text
    assert client.get(f"/calendar/events/{event_id}").json()["source"] == "personal"


def test_kept_external_event_does_not_reimport_or_reprompt(setup_calendar):
    client, db = setup_calendar
    assert client.put("/calendar/selected-calendars", json={
        "device_id": "phone",
        "calendar_ids": ["personal"],
    }).status_code == 200
    upsert = {
        "device_id": "phone",
        "changes": [{
            "calendar_id": "personal",
            "external_event_id": "external1",
            "status": "upsert",
            "event": payload(),
        }],
    }
    first = client.post("/calendar/sync/external", json=upsert)
    assert first.status_code == 200, first.text
    event_id = first.json()["results"][0]["event_id"]
    deletion = {
        "device_id": "phone",
        "changes": [{
            "calendar_id": "personal",
            "external_event_id": "external1",
            "status": "deleted",
        }],
    }
    pending = client.post("/calendar/sync/external", json=deletion)
    assert pending.json()["results"][0]["status"] == "confirmation_required"
    waiting = client.get(f"/calendar/events/{event_id}").json()
    assert waiting["version"] == 2
    repeated = client.post("/calendar/sync/external", json=deletion)
    assert repeated.json()["results"][0]["status"] == "confirmation_required"
    assert client.get(f"/calendar/events/{event_id}").json()["version"] == 2
    kept = client.post(
        f"/calendar/events/{event_id}/external-delete-decision",
        json={"decision": "keep"},
    )
    assert kept.status_code == 200, kept.text
    assert client.get(f"/calendar/events/{event_id}").json()["source"] == "personal"
    again = client.post("/calendar/sync/external", json=deletion)
    assert again.json()["results"][0]["status"] == "kept_locally"
    replay = client.post("/calendar/sync/external", json=upsert)
    assert replay.json()["results"][0]["status"] == "kept_locally"
    assert len([p for p in db.data if "/calendar_events/" in p]) == 1
    assert client.get("/calendar/pending-deletions").json()["events"] == []


def test_external_update_rejects_stale_version(setup_calendar):
    client, _ = setup_calendar
    client.put("/calendar/selected-calendars", json={
        "device_id": "phone", "calendar_ids": ["personal"],
    })
    batch = {
        "device_id": "phone",
        "changes": [{
            "calendar_id": "personal",
            "external_event_id": "e1",
            "status": "upsert",
            "event": payload(),
        }],
    }
    initial = client.post("/calendar/sync/external", json=batch)
    event_id = initial.json()["results"][0]["event_id"]
    stale = client.post("/calendar/sync/external", json=batch)
    assert stale.status_code == 200
    assert stale.json()["results"][0]["status"] == "conflict"
    assert client.get(f"/calendar/events/{event_id}").json()["version"] == 1


def test_external_update_with_current_version(setup_calendar):
    client, _ = setup_calendar
    client.put("/calendar/selected-calendars", json={"device_id": "phone", "calendar_ids": ["school"]})
    first = client.post("/calendar/sync/external", json={
        "device_id": "phone",
        "changes": [{
            "calendar_id": "school", "external_event_id": "e1",
            "status": "upsert", "event": payload(),
        }],
    })
    event_id = first.json()["results"][0]["event_id"]
    updated = client.post("/calendar/sync/external", json={
        "device_id": "phone",
        "changes": [{
            "calendar_id": "school", "external_event_id": "e1",
            "status": "upsert", "event": {**payload(), "title": "Exam"},
            "base_version": 1,
        }],
    })
    assert updated.status_code == 200, updated.text
    assert updated.json()["results"][0]["status"] == "updated"
    assert client.get(f"/calendar/events/{event_id}").json()["version"] == 2
    assert client.get(f"/calendar/events/{event_id}").json()["title"] == "Exam"


def test_meeting_events_cannot_be_edited_through_personal_api(setup_calendar):
    client, db = setup_calendar
    db.data["users/alpha/calendar_events/room_event"] = {
        "title": "Meeting", "source": "meeting", "version": 1,
        "deleted": False, "external_delete_pending": False,
    }
    assert client.put("/calendar/events/room_event", json={**payload(), "version": 1}).status_code == 403
    assert client.delete("/calendar/events/room_event", params={"version": 1}).status_code == 403


def test_recurring_event_templates_are_private_and_persist_options(setup_calendar):
    client, db = setup_calendar
    weekly = client.post("/calendar/events", json={
        **payload(), "repeat": "weekly", "category": "school", "reminder_minutes": 30,
    })
    assert weekly.status_code == 201, weekly.text
    event_id = weekly.json()["id"]
    assert weekly.json()["repeat"] == "weekly"
    assert weekly.json()["category"] == "school"
    assert weekly.json()["reminder_minutes"] == 30
    db.data["users/beta/calendar_events/private"] = {
        **db.data[f"users/alpha/calendar_events/{event_id}"], "repeat": "daily"
    }
    results = client.get("/calendar/recurring-events")
    assert results.status_code == 200, results.text
    assert [item["id"] for item in results.json()["events"]] == [event_id]
    updated = client.put(f"/calendar/events/{event_id}", json={
        **payload(), "title": "Recurring meeting", "repeat": "monthly",
        "category": "work", "reminder_minutes": None, "version": 1,
    })
    assert updated.status_code == 200
    assert updated.json()["repeat"] == "monthly"
    assert updated.json()["version"] == 2
    assert client.delete(f"/calendar/events/{event_id}", params={"version": 2}).status_code == 200
    assert client.get("/calendar/recurring-events").json()["events"] == []


def test_invalid_recurrence_and_reminder_rejected(setup_calendar):
    client, _ = setup_calendar
    assert client.post("/calendar/events", json={**payload(), "repeat": "every_minute"}).status_code == 422
    assert client.post("/calendar/events", json={**payload(), "reminder_minutes": -1}).status_code == 422
