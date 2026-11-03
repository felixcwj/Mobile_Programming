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
