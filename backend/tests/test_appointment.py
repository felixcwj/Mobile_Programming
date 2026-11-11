from copy import deepcopy
from uuid import uuid4
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

    def normalized(self, values):
        return {
            key: datetime.now(timezone.utc) if value is appointment_routes.firestore.SERVER_TIMESTAMP else deepcopy(value)
            for key, value in values.items()
        }

    def create(self, values):
        if self.path in self.db.docs:
            raise ValueError("duplicate")
        self.set(values)

    def set(self, values):
        self.db.docs[self.path] = self.normalized(values)

    def update(self, values):
        self.db.docs[self.path].update(self.normalized(values))


class Collection:
    def __init__(self, db, path):
        self.db = db
        self.path = path
        self.count = 200

    def document(self, name=None):
        return Ref(self.db, self.path + "/" + (name or uuid4().hex))

    def limit(self, count):
        self.count = count
        return self

    def where(self, field, operator, value):
        assert field == "member_uids" and operator == "array_contains"
        self.member_filter = value
        return self

    def stream(self):
        prefix = self.path + "/"
        keys = [key for key in self.db.docs if key.startswith(prefix) and "/" not in key[len(prefix):]]
        if hasattr(self, "member_filter"):
            keys = [key for key in keys if self.member_filter in self.db.docs[key].get("member_uids", [])]
        return [Snap(Ref(self.db, key)) for key in keys][:self.count]


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
    assert appointment["starts_at"] == "2026-11-15T03:00:00+00:00"
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
    proposal = client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-20", "version": 1})
    assert proposal.status_code == 200 and proposal.json()["proposal_created"]
    assert db.docs["rooms/r1"]["confirmed_appointment"]["version"] == 1
    who["uid"] = "alice"
    changed = client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-20", "version": 1})
    assert changed.status_code == 200, changed.text
    assert changed.json()["appointment"]["version"] == 2
    assert changed.json()["appointment"]["date"] == "2026-11-20"
    assert changed.json()["recommendation_needs_refresh"] is True
    assert client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-25", "version": 1}).status_code == 409
    who["uid"] = "bob"
    events = client.get("/calendar/confirmed-appointments").json()["events"]
    assert events[0]["starts_at"] == "2026-11-20T03:00:00+00:00"


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


def test_date_availability_reports_unknown_and_conflicting_members(setup_app):
    client, db, who = setup_app
    db.docs["rooms/r1/preferences/alice"] = {"available_date": "2026-11-20"}
    response = client.get("/rooms/r1/appointment/date-availability", params={"date": "2026-11-20"})
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["available_count"] == 1
    assert data["all_available"] is False
    assert data["requires_member_confirmation"] is True
    assert [member["status"] for member in data["members"]] == ["available", "missing"]
    db.docs["rooms/r1/preferences/bob"] = {"available_date": "2026-11-25"}
    data = client.get("/rooms/r1/appointment/date-availability", params={"date": "2026-11-20"}).json()
    assert [member["status"] for member in data["members"]] == ["available", "different_date"]
    who["uid"] = "outsider"
    assert client.get("/rooms/r1/appointment/date-availability", params={"date": "2026-11-20"}).status_code == 403


def test_date_change_strict_mode_rejects_unavailable_members(setup_app):
    client, db, who = setup_app
    assert client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"}).status_code == 200
    db.docs["rooms/r1/preferences/alice"] = {"available_date": "2026-11-20"}
    blocked = client.patch("/rooms/r1/appointment/date?require_all_available=true", json={"date": "2026-11-20", "version": 1})
    assert blocked.status_code == 409, blocked.text
    assert blocked.json()["detail"]["availability"]["available_count"] == 1
    assert db.docs["rooms/r1"]["confirmed_appointment"]["version"] == 1
    db.docs["rooms/r1/preferences/bob"] = {"available_date": "2026-11-20"}
    response = client.patch("/rooms/r1/appointment/date?require_all_available=true", json={"date": "2026-11-20", "version": 1})
    assert response.status_code == 200, response.text
    assert response.json()["availability"]["all_available"] is True
    assert response.json()["appointment"]["version"] == 2


def test_date_change_to_same_day_does_not_require_refresh(setup_app):
    client, db, who = setup_app
    client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"})
    response = client.patch("/rooms/r1/appointment/date", json={"date": "2026-11-15", "version": 1})
    assert response.status_code == 200, response.text
    assert response.json()["recommendation_needs_refresh"] is False
    assert response.json()["appointment"]["version"] == 1


def test_non_owner_date_change_requires_unanimous_approval_and_includes_notes(setup_app):
    client, db, who = setup_app
    assert client.post('/rooms/r1/appointment/confirm', json={'recommendation_revision': 'revision1'}).status_code == 200
    who['uid'] = 'bob'
    request = client.patch('/rooms/r1/appointment/date', json={
        'date': '2026-11-22', 'version': 1,
        'additional_notes': '조용한 카페 위주로, 계단 없는 곳 선호',
    })
    assert request.status_code == 200, request.text
    req_id = request.json()['date_change_request']['request_id']
    assert db.docs['rooms/r1']['confirmed_appointment']['date'] == '2026-11-15'
    who['uid'] = 'alice'
    approved = client.post(f'/rooms/r1/appointment/date-requests/{req_id}/vote', json={'approve': True})
    assert approved.status_code == 200, approved.text
    assert approved.json()['date_change_request']['status'] == 'approved'
    assert approved.json()['recommendation_needs_refresh'] is True
    assert db.docs['rooms/r1']['confirmed_appointment']['date'] == '2026-11-22'
    assert db.docs['rooms/r1']['confirmed_appointment']['additional_notes'] == '조용한 카페 위주로, 계단 없는 곳 선호'
    assert db.docs['users/bob/appointment_history/r1']['additional_notes'] == '조용한 카페 위주로, 계단 없는 곳 선호'
    assert client.post(f'/rooms/r1/appointment/date-requests/{req_id}/vote', json={'approve': True}).status_code == 409


def test_reject_date_request_preserves_existing_appointment(setup_app):
    client, db, who = setup_app
    client.post('/rooms/r1/appointment/confirm', json={'recommendation_revision': 'revision1'})
    who['uid'] = 'bob'
    request = client.patch('/rooms/r1/appointment/date', json={'date': '2026-11-25', 'version': 1})
    req_id = request.json()['date_change_request']['request_id']
    who['uid'] = 'alice'
    rejected = client.post(f'/rooms/r1/appointment/date-requests/{req_id}/vote', json={'approve': False})
    assert rejected.status_code == 200
    assert rejected.json()['date_change_request']['status'] == 'rejected'
    assert db.docs['rooms/r1']['confirmed_appointment']['version'] == 1


def test_owner_can_change_appointment_notes_immediately(setup_app):
    client, db, who = setup_app
    client.post('/rooms/r1/appointment/confirm', json={'recommendation_revision': 'revision1'})
    revised = client.patch('/rooms/r1/appointment/date', json={
        'date': '2026-11-15', 'version': 1,
        'additional_notes': '식당은 매운 음식 제외',
    })
    assert revised.status_code == 200, revised.text
    assert revised.json()['appointment']['version'] == 2
    assert revised.json()['appointment']['additional_notes'] == '식당은 매운 음식 제외'
    assert revised.json()['recommendation_needs_refresh'] is True


def test_unconfirmed_room_schedule_visible_to_all_members(setup_app):
    client, db, who = setup_app
    response = client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-15T13:00:00+09:00", "version": 0})
    assert response.status_code == 200, response.text
    assert response.json()["schedule"]["version"] == 1
    assert response.json()["schedule"]["starts_at"] == "2026-11-15T04:00:00+00:00"
    assert client.get("/rooms/r1/schedule").json()["schedule"]["version"] == 1
    events = client.get("/calendar/room-appointments").json()["events"]
    assert len(events) == 1
    assert events[0]["status"] == "scheduled"
    assert events[0]["ends_at"] is None
    who["uid"] = "bob"
    assert client.get("/calendar/room-appointments").json()["events"][0]["room_id"] == "r1"
    assert client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-16T13:00:00+09:00", "version": 1}).status_code == 403
    who["uid"] = "outsider"
    assert client.get("/calendar/room-appointments").json()["events"] == []
    assert client.get("/rooms/r1/schedule").status_code == 403


def test_room_schedule_conflict_and_clearing(setup_app):
    client, db, who = setup_app
    assert client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-15T13:00:00+09:00"}).status_code == 200
    assert client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-16T13:00:00+09:00", "version": 0}).status_code == 409
    assert client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-16T13:00:00", "version": 1}).status_code == 422
    deleted = client.put("/rooms/r1/schedule", json={"starts_at": None, "version": 1})
    assert deleted.status_code == 200, deleted.text
    assert client.get("/calendar/room-appointments").json()["events"] == []


def test_confirmed_room_appears_once_and_leaving_removes_calendar_event(setup_app):
    client, db, who = setup_app
    assert client.put("/rooms/r1/schedule", json={"starts_at": "2026-11-15T12:00:00+09:00"}).status_code == 200
    confirmed = client.post("/rooms/r1/appointment/confirm", json={"recommendation_revision": "revision1"})
    assert confirmed.status_code == 200, confirmed.text
    result = client.get("/calendar/room-appointments").json()
    assert result["count"] == 1
    assert result["events"][0]["status"] == "confirmed"
    assert result["events"][0]["ends_at"] is not None
    who["uid"] = "bob"
    assert client.get("/calendar/room-appointments").json()["count"] == 1
    db.docs["rooms/r1"]["member_uids"].remove("bob")
    assert client.get("/calendar/room-appointments").json()["count"] == 0
    assert client.get("/mypage/appointments").json()["count"] == 1
