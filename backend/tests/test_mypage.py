import hashlib
import unicodedata
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError

import mypage_routes
from mypage_routes import PasswordChange, ProfileEdit, make_mypage_router


def key(name):
    return hashlib.sha256(unicodedata.normalize("NFKC", name).casefold().encode()).hexdigest()


class Snapshot:
    def __init__(self, ref):
        self.exists = ref.path in ref.db.storage
        self.data = dict(ref.db.storage.get(ref.path, {}))

    def to_dict(self):
        return dict(self.data)


class Document:
    def __init__(self, db, path):
        self.db = db
        self.path = path

    def collection(self, name):
        return Collection(self.db, self.path + "/" + name)

    def get(self, transaction=None):
        return Snapshot(self)

    def update(self, data):
        self.db.storage[self.path].update(data)

    def set(self, data):
        self.db.storage[self.path] = dict(data)


class Collection:
    def __init__(self, db, path):
        self.db = db
        self.path = path

    def document(self, identifier):
        return Document(self.db, self.path + "/" + identifier)


class Transaction:
    def __init__(self, db):
        self.db = db

    def update(self, ref, data):
        ref.update(data)

    def set(self, ref, data):
        ref.set(data)

    def delete(self, ref):
        self.db.storage.pop(ref.path, None)


class FakeDB:
    def __init__(self):
        self.storage = {
            "users/alice": {
                "id": "alice",
                "nickname": "Alice",
                "nickname_key": key("Alice"),
                "email": "alice@example.com",
                "name": "Alice Kim",
                "phone": "01012345678",
            },
            "nickname_reservations/" + key("Alice"): {"uid": "alice", "nickname": "Alice"},
            "nickname_reservations/" + key("Taken"): {"uid": "other", "nickname": "Taken"},
        }

    def collection(self, name):
        return Collection(self, name)

    def transaction(self):
        return Transaction(self)


@pytest.fixture
def context(monkeypatch):
    monkeypatch.setattr(mypage_routes.firestore, "transactional", lambda fn: fn)
    monkeypatch.setattr(mypage_routes.firestore, "SERVER_TIMESTAMP", datetime.now(timezone.utc), raising=False)
    monkeypatch.setattr(mypage_routes.firestore, "DELETE_FIELD", None, raising=False)

    def password_login(email, password):
        async def check():
            if password != "old_password":
                raise HTTPException(401, "Incorrect password")
            return {"idToken": "unused"}
        return check()

    monkeypatch.setattr(mypage_routes.auth, "get_user", lambda uid: SimpleNamespace(email="alice@example.com", disabled=False))
    update_user = Mock()
    revoke = Mock()
    monkeypatch.setattr(mypage_routes.auth, "update_user", update_user)
    monkeypatch.setattr(mypage_routes.auth, "revoke_refresh_tokens", revoke)
    db = FakeDB()
    app = FastAPI()
    app.include_router(make_mypage_router(db, lambda: {"uid": "alice"}, key, password_login))
    return TestClient(app), db, update_user, revoke


def test_profile_edit_validation():
    with pytest.raises(ValidationError):
        ProfileEdit(nickname="invalid ", name="User", phone="01012345678")
    with pytest.raises(ValidationError):
        ProfileEdit(nickname="Valid", name="User", phone="123")
    with pytest.raises(ValidationError):
        PasswordChange(current_password="old", new_password="different1", new_password_confirm="different2")


def test_get_and_edit_profile(context):
    client, db, update_user, _ = context
    assert client.get("/mypage/profile").json()["nickname"] == "Alice"
    edited = client.put("/mypage/profile", json={"nickname": "NewName", "name": "New Name", "phone": "01012345678"})
    assert edited.status_code == 200, edited.text
    assert edited.json()["nickname"] == "NewName"
    assert "nickname_reservations/" + key("NewName") in db.storage
    assert "nickname_reservations/" + key("Alice") not in db.storage
    update_user.assert_called_once_with("alice", display_name="NewName")


def test_duplicate_nickname_is_rejected(context):
    client, db, _, _ = context
    response = client.put("/mypage/profile", json={"nickname": "Taken", "name": "Alice", "phone": "01012345678"})
    assert response.status_code == 409
    assert db.storage["users/alice"]["nickname"] == "Alice"


def test_password_change_needs_current_password(context):
    client, _, update_user, revoke = context
    bad = client.post("/mypage/password", json={"current_password": "bad", "new_password": "new_password_123", "new_password_confirm": "new_password_123"})
    assert bad.status_code == 401
    assert not update_user.called
    ok = client.post("/mypage/password", json={"current_password": "old_password", "new_password": "new_password_123", "new_password_confirm": "new_password_123"})
    assert ok.status_code == 200, ok.text
    update_user.assert_called_once_with("alice", password="new_password_123")
    revoke.assert_called_once_with("alice")


def test_deletion_request_and_cancel(context):
    client, db, _, _ = context
    assert client.get("/mypage/deletion").json()["status"] == "none"
    assert client.post("/mypage/deletion", json={"password": "bad"}).status_code == 401
    request = client.post("/mypage/deletion", json={"password": "old_password"})
    assert request.status_code == 200, request.text
    assert request.json()["status"] == "pending"
    assert db.storage["users/alice"]["deletion_due_at"] - db.storage["users/alice"]["deletion_requested_at"] == timedelta(days=30)
    assert client.get("/mypage/deletion").json()["status"] == "pending"
    assert client.put("/mypage/profile", json={"nickname": "NewName", "name": "Alice", "phone": "01012345678"}).status_code == 409
    assert client.delete("/mypage/deletion").status_code == 200
    assert client.get("/mypage/deletion").json()["status"] == "none"


def test_router_paths(context):
    client, _, _, _ = context
    paths = client.get("/openapi.json").json()["paths"]
    assert set(paths) >= {"/mypage/profile", "/mypage/password", "/mypage/deletion"}
