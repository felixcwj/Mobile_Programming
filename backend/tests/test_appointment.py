from copy import deepcopy
from datetime import datetime, timezone

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

import appointment_routes


class Snap:
    def __init__(self, ref):
        self.id = ref.path.split("/")[-1]
        self.exists = ref.path in ref.db.docs
        self.data = deepcopy(ref.db.docs.get(ref.path))

    def to_dict(self):
        return deepcopy(self.data)


class Ref:
    def __init__(self, db, path):
        self.db = db
        self.path = path
        self.id = path.split("/")[-1]

    def collection(self, name):
        return Collection(self.db, self.path + "/" + name)

    def get(self, transaction=None):
        return Snap(self)

    def set(self, values):
        self.db.docs[self.path] = deepcopy(values)

    def update(self, values):
        self.db.docs[self.path].update(deepcopy(values))


class Collection:
    def __init__(self, db, path):
        self.db = db
        self.path = path
        self.count = 200

    def document(self, name):
        return Ref(self.db, self.path + "/" + name)

    def limit(self, count):
        self.count = count
        return self

    def stream(self):
        prefix = self.path + "/"
        return [Snap(Ref(self.db, key)) for key in self.db.docs if key.startswith(prefix) and "/" not in key[len(prefix):]][:self.count]


class Transaction:
    def update(self, ref, data):
        ref.update(data)

    def set(self, ref, data):
        ref.set(data)


class FakeDB:
    def __init__(self):
        self.docs = {
            "rooms/r1": {
                "owner_uid": "alice",
                "member_uids": ["alice", "bob"],
                "title": "주말 약속",
            },
            "rooms/r1/recommendations/latest": {
                "source_revision": "revision1",
                "plan": {
                    "date": "2026-11-15",
                    "stops": [
                        {"start_time": "12:00", "end_time": "13:00", "name": "카페"},
                        {"start_time": "14:00", "end_time": "16:00", "name": "식당"},
                    ],
                },
            },
        }

    def collection(self, name):
        return Collection(self, name)

    def transaction(self):
        return Transaction()


@pytest.fixture
def setup_app(monkeypatch):
    monkeypatch.setattr(appointment_routes.firestore, "transactional", lambda fn: fn)
    db = FakeDB()
    who = {"uid": "alice"}

    def user():
        return who

    def constraints(room_id, uid):
        return {"source_revision": "revision1"}

    app = FastAPI()
    app.include_router(appointment_routes.make_appointment_router(db, user, constraints))
    return TestClient(app), db, who


def test_confirm_then_calendar_and_history(setup_app):
    client, db, who = setup_app
    assert client.get("/calendar/confirmed-appointments").json()["events"] == []
    response = client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"})
    assert response.status_code == 200, response.text
    appointment = response.json()["appointment"]
    assert appointment["version"] == 1
    assert appointment["starts_at"] == "2026-11-15T03:00:00Z"
    assert len(client.get("/calendar/confirmed-appointments").json()["events"]) == 1
    who["uid"] = "bob"
    assert client.get("/mypage/appointments").json()["count"] == 1
    assert client.get("/rooms/r1/appointment").json()["appointment"]["date"] == "2026-11-15"
    assert client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"}).status_code == 403
    who["uid"] = "alice"
    assert client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"}).status_code == 409


def test_date_change_updates_each_member_and_blocks_stale(setup_app):
    client, db, who = setup_app
    client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"})
    who["uid"] = "bob"
    assert client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-20", "version": 1}).status_code == 403
    who["uid"] = "alice"
    changed = client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-20", "version": 1})
    assert changed.status_code == 200, changed.text
    assert changed.json()["appointment"]["version"] == 2
    assert changed.json()["appointment"]["date"] == "2026-11-20"
    assert changed.json()["recommendation_needs_refresh"] is True
    assert client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-25", "version": 1}).status_code == 409
    who["uid"] = "bob"
    events = client.get("/calendar/confirmed-appointments").json()["events"]
    assert events[0]["starts_at"] == "2026-11-20T03:00:00Z"


def test_confirmation_rejects_stale_recommendation(setup_app):
    client, db, who = setup_app
    assert client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "bad"}).status_code == 409
    assert "confirmed_appointment" not in db.docs["rooms/r1"]


def test_history_is_scoped_to_current_user(setup_app):
    client, db, who = setup_app
    client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"})
    db.docs["users/charlie/appointment_history/x"] = {"uid": "charlie", "title": "비공개"}
    who["uid"] = "bob"
    data = client.get("/mypage/appointments").json()["appointments"]
    assert len(data) == 1
    assert all(item["uid"] == "bob" for item in data)
