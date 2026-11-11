from datetime import datetime, timedelta, timezone
import importlib.util
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import firebase_admin
import pytest
from fastapi.testclient import TestClient


class Snapshot:
    def __init__(self, value):
        self.value = value
        self.exists = value is not None

    def to_dict(self):
        return self.value


class FakeDB:
    def __init__(self, data):
        self.data = data

    def collection(self, name):
        db = self

        class Collection:
            def document(self, identifier):
                path = name + "/" + identifier

                class Document:
                    def get(self):
                        return Snapshot(db.data.get(path))
                return Document()

        return Collection()


@pytest.fixture
def app_module(monkeypatch, tmp_path):
    monkeypatch.setenv("FIREBASE_WEB_API_KEY", "test")
    key_file = tmp_path / "service-account.json"
    key_file.write_text("{}")
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", str(key_file))
    monkeypatch.setattr(firebase_admin, "initialize_app", Mock())
    monkeypatch.setattr(firebase_admin.credentials, "Certificate", Mock())
    monkeypatch.setattr(firebase_admin.firestore, "client", lambda: FakeDB({}))
    monkeypatch.setattr(firebase_admin.firestore, "transactional", lambda fn: fn)
    spec = importlib.util.spec_from_file_location("mypage_auth_compat_test", Path(__file__).parents[1] / "main.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_login_with_changed_username(app_module, monkeypatch):
    module = app_module
    module.db = FakeDB({
        "usernames/newid": {"uid": "alice"},
        "users/alice": {"id": "newid"},
    })
    monkeypatch.setattr(module.auth, "get_user", lambda uid: SimpleNamespace(uid=uid, email="alice@example.com", disabled=False))

    async def fake_password_login(email, password):
        assert email == "alice@example.com"
        return {"idToken": "token", "refreshToken": "refresh", "expiresIn": "3600", "localId": "alice"}

    monkeypatch.setattr(module, "firebase_password_login", fake_password_login)
    client = TestClient(module.app)
    response = client.post("/auth/login", json={"id": "newid", "password": "password"})
    assert response.status_code == 200, response.text
    assert response.json()["uid"] == "alice"
    assert client.post("/auth/login", json={"id": "alice", "password": "password"}).status_code == 401


def test_legacy_login_remains_available(app_module, monkeypatch):
    module = app_module
    module.db = FakeDB({"users/olduser": {"id": "olduser"}})
    monkeypatch.setattr(module.auth, "get_user", lambda uid: SimpleNamespace(uid=uid, email="old@example.com", disabled=False))

    async def fake_password_login(email, password):
        return {"idToken": "token", "refreshToken": "refresh", "expiresIn": "3600", "localId": "olduser"}

    monkeypatch.setattr(module, "firebase_password_login", fake_password_login)
    response = TestClient(module.app).post("/auth/login", json={"id": "olduser", "password": "password"})
    assert response.status_code == 200, response.text


def test_username_availability_checks_mapping(app_module, monkeypatch):
    module = app_module
    module.db = FakeDB({"usernames/claimed": {"uid": "alice"}})

    def no_user(uid):
        raise module.auth.UserNotFoundError("no user")

    monkeypatch.setattr(module.auth, "get_user", no_user)
    client = TestClient(module.app)
    assert client.get("/auth/check-id", params={"id": "claimed"}).json()["available"] is False
    assert client.get("/auth/check-id", params={"id": "unused"}).json()["available"] is True


def test_all_backend_routes_survive_integration(app_module):
    paths = app_module.app.openapi()["paths"]
    required = {
        "/auth/signup",
        "/auth/login",
        "/rooms",
        "/rooms/{room_id}/members/me",
        "/rooms/{room_id}/recommendation",
        "/calendar/events",
        "/calendar/sync/external",
        "/mypage/profile",
        "/mypage/preferences",
        "/mypage/deletion",
        "/mypage/support",
        "/mypage/donation",
    }
    assert required.issubset(paths), required - set(paths)


def test_ai_revision_changes_when_personal_preference_changes(app_module):
    module = app_module
    room = {"member_uids": ["alice"], "meeting_mode": "middle"}
    prefs = [{
        "uid": "alice", "budget": 30000, "region": "서울",
        "available_date": "2026-11-15", "start_time": "12:00",
        "end_time": "17:00", "activities": ["카페"],
    }]
    before = module._conditions_revision(room, prefs, [], [{"activity_preference": "indoor"}])
    after = module._conditions_revision(room, prefs, [], [{"activity_preference": "outdoor"}])
    assert before != after


def test_room_leave_only_removes_current_member(app_module):
    module = app_module

    class Ref:
        def __init__(self, value=None):
            self.value = value
            self.deleted = False

        def get(self, transaction=None):
            return SimpleNamespace(exists=self.value is not None, to_dict=lambda: self.value)

        def collection(self, name):
            return SimpleNamespace(document=lambda uid: preference)

    class Tx:
        def update(self, ref, fields):
            ref.value.update(fields)

        def delete(self, ref):
            ref.deleted = True

    room = Ref({
        "member_uids": ["alice", "bob"],
        "owner_uid": "alice",
        "invite_code": "ABCDEF12",
    })
    preference = Ref({"uid": "alice"})
    module.db = SimpleNamespace(
        collection=lambda name: SimpleNamespace(document=lambda key: invite)
    )
    invite = Ref({"room_id": "room1"})
    deleted = module._leave_room_tx(Tx(), room, "alice")
    assert deleted is False
    assert room.value["member_uids"] == ["bob"]
    assert room.value["owner_uid"] == "bob"
    assert room.deleted is False
    assert invite.deleted is False
    assert preference.deleted is True


def test_existing_confirmed_room_is_added_for_joining_member(app_module):
    module = app_module
    now = datetime(2026, 11, 20, 3, 0, tzinfo=timezone.utc)

    class Ref:
        def __init__(self, db, path):
            self.db = db
            self.path = path
            self.id = path.split("/")[-1]

        def get(self, transaction=None):
            data = self.db.docs.get(self.path)
            return SimpleNamespace(exists=data is not None, to_dict=lambda: data)

        def collection(self, name):
            return Collection(self.db, self.path + "/" + name)

    class Collection:
        def __init__(self, db, path):
            self.db = db
            self.path = path

        def document(self, name):
            return Ref(self.db, self.path + "/" + name)

    class DB:
        def __init__(self):
            self.docs = {
                "room_invites/CODE": {"room_id": "r1"},
                "rooms/r1": {
                    "member_uids": ["alice"],
                    "owner_uid": "alice",
                    "invite_code": "CODE",
                    "confirmed_appointment": {
                        "date": "2026-11-20",
                        "starts_at": now,
                        "ends_at": now + timedelta(hours=2),
                        "version": 1,
                        "location": "서울",
                    },
                },
            }

        def collection(self, name):
            return Collection(self, name)

    class Tx:
        def update(self, ref, values):
            ref.db.docs[ref.path].update(values)

        def set(self, ref, values):
            ref.db.docs[ref.path] = values

    db = DB()
    module.db = db
    room_id, joined = module._join_room_tx(Tx(), db.collection("room_invites").document("CODE"), "bob")
    assert room_id == "r1"
    assert joined is True
    assert db.docs["rooms/r1"]["member_uids"] == ["alice", "bob"]
    assert db.docs["users/bob/appointment_history/r1"]["status"] == "active"


def test_leaving_confirmed_room_keeps_personal_history(app_module):
    module = app_module
    now = datetime(2026, 11, 20, 3, 0, tzinfo=timezone.utc)

    class Ref:
        def __init__(self, db, path):
            self.db = db
            self.path = path
            self.id = path.split("/")[-1]

        def get(self, transaction=None):
            data = self.db.docs.get(self.path)
            return SimpleNamespace(exists=data is not None, to_dict=lambda: data)

        def collection(self, name):
            return Collection(self.db, self.path + "/" + name)

    class Collection:
        def __init__(self, db, path):
            self.db = db
            self.path = path

        def document(self, name):
            return Ref(self.db, self.path + "/" + name)

    class DB:
        def __init__(self):
            self.docs = {
                "rooms/r1": {
                    "member_uids": ["alice", "bob"],
                    "owner_uid": "alice",
                    "invite_code": "CODE",
                    "confirmed_appointment": {
                        "date": "2026-11-20",
                        "starts_at": now,
                        "ends_at": now + timedelta(hours=2),
                        "version": 1,
                        "location": "서울",
                    },
                },
                "room_invites/CODE": {"room_id": "r1"},
                "users/alice/appointment_history/r1": {"status": "active"},
            }

        def collection(self, name):
            return Collection(self, name)

    class Tx:
        def update(self, ref, values):
            ref.db.docs[ref.path].update(values)

        def set(self, ref, values):
            ref.db.docs[ref.path] = values

        def delete(self, ref):
            ref.db.docs.pop(ref.path, None)

    db = DB()
    module.db = db
    left_last = module._leave_room_tx(Tx(), db.collection("rooms").document("r1"), "alice")
    assert left_last is False
    assert db.docs["rooms/r1"]["member_uids"] == ["bob"]
    assert db.docs["rooms/r1"]["owner_uid"] == "bob"
    assert db.docs["users/alice/appointment_history/r1"]["status"] == "left"
    assert "room_invites/CODE" in db.docs


def test_created_room_saves_capacity_and_seven_character_invite_code(app_module, monkeypatch):
    module = app_module
    saved = {}

    class FakeDBForCreate:
        def collection(self, name):
            return SimpleNamespace(document=lambda code=None: SimpleNamespace(id=code or "newroom"))

        def transaction(self):
            return object()

    def capture(transaction, room_ref, invite_ref, payload):
        saved.update(payload)
        assert invite_ref.id == payload["invite_code"]
        return True

    module.db = FakeDBForCreate()
    monkeypatch.setattr(module, "_create_room_tx", capture)
    module.app.dependency_overrides[module.current_user] = lambda: {"uid": "alice"}
    response = TestClient(module.app).post("/rooms", json={"title": "산책 약속", "max_members": 2})
    assert response.status_code == 201, response.text
    assert len(response.json()["invite_code"]) == 7
    assert saved["max_members"] == 2
    assert saved["member_uids"] == ["alice"]
    assert TestClient(module.app).post("/rooms", json={"max_members": 9}).status_code == 422


def test_join_respects_each_rooms_capacity_and_legacy_default(app_module):
    module = app_module

    class Ref:
        def __init__(self, value):
            self.value = value

        def get(self, transaction=None):
            return SimpleNamespace(exists=self.value is not None, to_dict=lambda: self.value)

    class Transaction:
        def update(self, ref, fields):
            ref.value.update(fields)

    room = Ref({"member_uids": ["alice", "bob"], "max_members": 2})
    invite = Ref({"room_id": "r1"})
    module.db = SimpleNamespace(collection=lambda _: SimpleNamespace(document=lambda key: room))
    with pytest.raises(module.HTTPException) as exc:
        module._join_room_tx(Transaction(), invite, "charlie")
    assert exc.value.status_code == 409
    assert room.value["member_uids"] == ["alice", "bob"]

    room.value["max_members"] = 3
    room_id, joined = module._join_room_tx(Transaction(), invite, "charlie")
    assert (room_id, joined) == ("r1", True)
    assert room.value["member_uids"] == ["alice", "bob", "charlie"]

    room.value["max_members"] = 30  # 과거 데이터도 전역 상한은 8명
    room.value["member_uids"] = [str(i) for i in range(8)]
    with pytest.raises(module.HTTPException) as exc:
        module._join_room_tx(Transaction(), invite, "new-member")
    assert exc.value.status_code == 409


def test_join_accepts_requested_special_characters_and_rejects_old_symbols(app_module):
    model = app_module.JoinRoomRequest
    for code in ("A1#BCDE", "A1@BCDE", "A1!BCDE", "A1BCDEF", "ABCDEFG"):
        assert model(invite_code=code).invite_code == code
    for code in ("A1-BCDE", "A1_BCDE", "AB#CDE", "AB#CDEFG", "ABCDEFG8"):
        with pytest.raises(Exception):
            model(invite_code=code)


def test_room_notes_affect_ai_revision_and_prompt(app_module):
    module = app_module
    room = {"member_uids": ["alice"], "meeting_mode": "middle"}
    prefs = [{
        "uid": "alice", "budget": 30000, "region": "서울",
        "available_date": "2026-11-15", "start_time": "12:00",
        "end_time": "17:00", "activities": ["카페"], "additional_notes": "조용한 곳",
    }]
    before = module._conditions_revision(room, prefs)
    prefs[0]["additional_notes"] = "휠체어 접근 가능"
    assert before != module._conditions_revision(room, prefs)
    room["confirmed_appointment"] = {"additional_notes": "반려견 동반 가능"}
    assert before != module._conditions_revision(room, prefs)
    assert module.RoomPreferenceRequest(
        budget=30000, region="서울", available_date="2026-11-15",
        start_time="12:00", end_time="17:00", activities=["카페"],
        additional_notes="  조용한 곳  ",
    ).additional_notes == "조용한 곳"


class _RoomMemoryDB:
    """Firestore-like test double for voting and preference endpoints."""

    def __init__(self):
        self.docs = {
            'rooms/r1': {'owner_uid': 'alice', 'member_uids': ['alice', 'bob'], 'meeting_mode': 'middle'},
            'rooms/r1/preferences/alice': {'uid': 'alice', 'budget': 20000, 'region': '서울',
                'departure_location': '서울', 'available_date': '2026-11-15', 'start_time': '12:00',
                'end_time': '18:00', 'activities': ['카페'], 'additional_notes': ''},
        }

    def collection(self, name):
        return _MemoryCollection(self, name)

    def transaction(self):
        return self

    def update(self, ref, fields):
        ref.update(fields)

    def set(self, ref, fields):
        ref.set(fields)


class _MemoryCollection:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.filters = []

    def document(self, name=None):
        return _MemoryDocument(self.db, self.path + '/' + (name or 'newproposal'))

    def where(self, key, op, val):
        self.filters.append((key, op, val))
        return self

    def stream(self):
        result = []
        prefix = self.path + '/'
        for path, data in self.db.docs.items():
            if path.startswith(prefix) and '/' not in path[len(prefix):]:
                if all(data.get(key) == val for key, op, val in self.filters):
                    result.append(_MemoryDocument(self.db, path).get())
        return result


class _MemoryDocument:
    def __init__(self, db, path):
        self.db, self.path = db, path
        self.id = path.rsplit('/', 1)[-1]

    def get(self, transaction=None):
        data = self.db.docs.get(self.path)
        return SimpleNamespace(exists=data is not None, to_dict=lambda: data.copy() if data else None,
                               id=self.id, reference=self)

    def collection(self, name):
        return _MemoryCollection(self.db, self.path + '/' + name)

    def set(self, values):
        self.db.docs[self.path] = values.copy()

    def create(self, values):
        if self.path in self.db.docs:
            raise ValueError('duplicate')
        self.set(values)

    def update(self, values):
        self.db.docs[self.path].update(values)


def test_nonowner_condition_edit_votes_before_applying(app_module, monkeypatch):
    module = app_module
    db = _RoomMemoryDB()
    db.docs['rooms/r1/preferences/bob'] = {
        'uid': 'bob', 'budget': 30000, 'region': '서울', 'departure_location': '서울',
        'available_date': '2026-11-15', 'start_time': '12:00', 'end_time': '18:00',
        'activities': ['카페'], 'additional_notes': '',
    }
    module.db = db
    who = {'uid': 'bob'}
    module.app.dependency_overrides[module.current_user] = lambda: who
    regenerated = []

    async def regenerate(room_id, uid):
        regenerated.append((room_id, uid))
        return {'ok': True}

    monkeypatch.setattr(module, '_regenerate_room', regenerate)
    client = TestClient(module.app)
    body = {'budget': 25000, 'region': '서울', 'available_date': '2026-11-15',
            'start_time': '12:00', 'end_time': '18:00', 'activities': ['전시'],
            'additional_notes': '비건 식사 가능한 곳만'}
    proposal = client.post('/rooms/r1/preferences', json=body)
    assert proposal.status_code == 200, proposal.text
    assert proposal.json()['decision']['status'] == 'pending'
    assert db.docs['rooms/r1/preferences/bob']['budget'] == 30000
    assert regenerated == []
    who['uid'] = 'alice'
    result = client.post('/rooms/r1/decisions/newproposal/vote', json={'approve': True})
    assert result.status_code == 200, result.text
    assert result.json()['decision']['status'] == 'approved'
    assert db.docs['rooms/r1/preferences/bob']['budget'] == 25000
    assert db.docs['rooms/r1/preferences/bob']['additional_notes'] == '비건 식사 가능한 곳만'
    assert regenerated == [('r1', 'alice')]
    constraints = module._collect_constraints('r1', 'alice')
    assert any(entry['additional_notes'] == '비건 식사 가능한 곳만' for entry in constraints['preferences'])


def test_nonowner_instant_decision_is_forced_to_approval_and_chat_removed(app_module, monkeypatch):
    module = app_module
    db = _RoomMemoryDB()
    module.db = db
    who = {'uid': 'bob'}
    module.app.dependency_overrides[module.current_user] = lambda: who

    async def regenerate(room_id, uid):
        return {'ok': True}

    monkeypatch.setattr(module, '_regenerate_room', regenerate)
    client = TestClient(module.app)
    proposal = client.post('/rooms/r1/decisions', json={
        'mode': 'instant', 'change_type': 'notes',
        'additional_notes': '반려견 동반이 가능한 일정으로',
    })
    assert proposal.status_code == 201, proposal.text
    assert proposal.json()['decision']['status'] == 'pending'
    assert proposal.json()['decision']['mode'] == 'approval'
    who['uid'] = 'alice'
    rejected = client.post('/rooms/r1/decisions/newproposal/vote', json={'approve': False})
    assert rejected.json()['decision']['status'] == 'rejected'
    assert all(path not in module.app.openapi()['paths'] for path in (
        '/rooms/{room_id}/messages',
    ))


def test_member_meeting_location_edit_requires_votes(app_module, monkeypatch):
    module = app_module
    db = _RoomMemoryDB()
    module.db = db
    who = {'uid': 'bob'}
    module.app.dependency_overrides[module.current_user] = lambda: who

    async def regenerate(room_id, uid):
        return {'ok': True}

    monkeypatch.setattr(module, '_regenerate_room', regenerate)
    client = TestClient(module.app)
    response = client.patch('/rooms/r1/meeting', json={'mode': 'fixed', 'region': '홍대'})
    assert response.status_code == 200, response.text
    assert response.json()['decision']['status'] == 'pending'
    assert db.docs['rooms/r1']['meeting_mode'] == 'middle'
    who['uid'] = 'alice'
    approved = client.post('/rooms/r1/decisions/newproposal/vote', json={'approve': True})
    assert approved.status_code == 200, approved.text
    assert db.docs['rooms/r1']['meeting_mode'] == 'fixed'
    assert db.docs['rooms/r1']['meeting_region'] == '홍대'


def test_ai_payload_contains_free_text_notes(app_module, monkeypatch):
    import asyncio
    import json

    module = app_module
    monkeypatch.setattr(module, 'OPENROUTER_API_KEY', 'dummy-test-key')
    captured = {}

    class FakeResponse:
        status_code = 200

        def json(self):
            return {'choices': [{'message': {'content': json.dumps({
                'title': '산책', 'date': '2026-11-15', 'summary': '정리',
                'stops': [{'start_time': '12:00', 'end_time': '13:00',
                           'place_id': 'place1', 'activity': '카페', 'estimated_cost': 10000}],
                'notes': '안내',
            })}}]}

    class FakeClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            pass

        async def post(self, url, headers, json):
            captured.update(json)
            return FakeResponse()

    monkeypatch.setattr(module.httpx, 'AsyncClient', FakeClient)
    monkeypatch.setattr(module, '_check_and_enrich', lambda plan, conditions, candidates: {'success': True})
    conditions = {
        'date': '2026-11-15',
        'preferences': [{'additional_notes': '비건 식사'}],
        'shared_decisions': [{'change_type': 'notes', 'additional_notes': '조용한 장소'}],
        'appointment_additional_notes': '휠체어 동선',
    }
    result = asyncio.run(module._openrouter_course(conditions, [{'place_id': 'place1', 'name': '가게', 'address': '서울', 'category': '카페'}]))
    assert result == {'success': True}
    payload = json.loads(captured['messages'][1]['content'])
    assert payload['conditions']['preferences'][0]['additional_notes'] == '비건 식사'
    assert payload['conditions']['shared_decisions'][0]['additional_notes'] == '조용한 장소'
    assert payload['conditions']['appointment_additional_notes'] == '휠체어 동선'
    assert 'additional_notes' in captured['messages'][0]['content']


def test_confirmed_date_overrides_original_preference_dates_for_ai(app_module):
    module = app_module
    db = _RoomMemoryDB()
    db.docs["rooms/r1/preferences/bob"] = {
        "uid": "bob", "budget": 25000, "region": "서울",
        "departure_location": "서울", "available_date": "2026-11-15",
        "start_time": "13:00", "end_time": "17:00",
        "activities": ["전시"], "additional_notes": "",
    }
    db.docs["users/alice"] = {"preferences": {}}
    db.docs["users/bob"] = {"preferences": {}}
    module.db = db

    initial = module._collect_constraints("r1", "alice")
    assert initial["date"] == "2026-11-15"
    initial_revision = initial["source_revision"]
    old_alice_date = db.docs["rooms/r1/preferences/alice"]["available_date"]
    old_bob_date = db.docs["rooms/r1/preferences/bob"]["available_date"]

    db.docs["rooms/r1"]["confirmed_appointment"] = {
        "date": "2026-11-20",
        "starts_at": datetime(2026, 11, 20, 3, 0, tzinfo=timezone.utc),
        "ends_at": datetime(2026, 11, 20, 8, 0, tzinfo=timezone.utc),
        "version": 2,
    }
    updated = module._collect_constraints("r1", "alice")
    assert updated["date"] == "2026-11-20"
    assert updated["start_time"] == "13:00"
    assert updated["end_time"] == "17:00"
    assert updated["source_revision"] != initial_revision
    assert db.docs["rooms/r1/preferences/alice"]["available_date"] == old_alice_date
    assert db.docs["rooms/r1/preferences/bob"]["available_date"] == old_bob_date

    # After approval, an older preference date must not break course generation.
    db.docs["rooms/r1/preferences/bob"]["available_date"] = "2026-11-18"
    assert module._collect_constraints("r1", "alice")["date"] == "2026-11-20"


def test_initial_ai_recommendation_still_rejects_disagreeing_dates(app_module):
    module = app_module
    db = _RoomMemoryDB()
    db.docs["rooms/r1/preferences/bob"] = {
        "uid": "bob", "budget": 25000, "region": "서울",
        "departure_location": "서울", "available_date": "2026-11-18",
        "start_time": "13:00", "end_time": "17:00",
        "activities": ["전시"], "additional_notes": "",
    }
    module.db = db
    with pytest.raises(module.HTTPException) as exc:
        module._collect_constraints("r1", "alice")
    assert exc.value.status_code == 409


def test_confirmed_date_change_alters_revision_without_changing_notes(app_module):
    module = app_module
    room = {"member_uids": ["alice"], "confirmed_appointment": {"date": "2026-11-15", "additional_notes": ""}}
    prefs = [{"uid": "alice", "available_date": "2026-11-15", "start_time": "12:00", "end_time": "17:00", "activities": ["카페"]}]
    before = module._conditions_revision(room, prefs)
    room["confirmed_appointment"]["date"] = "2026-11-20"
    assert module._conditions_revision(room, prefs) != before
