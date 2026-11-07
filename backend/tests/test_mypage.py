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

    def get_user(uid):
        if uid != "alice":
            raise mypage_routes.auth.UserNotFoundError("unknown user")
        return SimpleNamespace(email="alice@example.com", disabled=False)

    monkeypatch.setattr(mypage_routes.auth, "get_user", get_user)
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
    assert set(paths) >= {"/mypage/profile", "/mypage/password", "/mypage/deletion", "/mypage/id", "/mypage/donation"}


def test_donation_disabled_without_url(context, monkeypatch):
    client, _, _, _ = context
    monkeypatch.delenv("DEVELOPER_DONATION_URL", raising=False)
    response = client.get("/mypage/donation")
    assert response.status_code == 200
    assert response.json() == {
        "title": "개발자에게 후원하기",
        "enabled": False,
        "url": None,
    }


def test_donation_exposes_real_https_link(context, monkeypatch):
    client, _, _, _ = context
    monkeypatch.setenv("DEVELOPER_DONATION_URL", "https://example.com/support")
    response = client.get("/mypage/donation")
    assert response.status_code == 200
    assert response.json() == {
        "title": "개발자에게 후원하기",
        "enabled": True,
        "url": "https://example.com/support",
    }


@pytest.mark.parametrize("url", [
    "javascript:alert(1)",
    "http://example.com/pay",
    "https://user:pass@example.com/pay",
    "https://example.com/path with space",
    "https:///broken",
])
def test_donation_rejects_unsafe_link(context, monkeypatch, url):
    client, _, _, _ = context
    monkeypatch.setenv("DEVELOPER_DONATION_URL", url)
    response = client.get("/mypage/donation")
    assert response.status_code == 200
    assert response.json()["enabled"] is False
    assert response.json()["url"] is None


def test_login_id_change_without_uid_migration(context):
    client, db, _, _ = context
    bad = client.put("/mypage/id", json={"new_id": "other_id", "password": "incorrect"})
    assert bad.status_code == 401
    response = client.put("/mypage/id", json={"new_id": "other_id", "password": "old_password"})
    assert response.status_code == 200, response.text
    assert response.json()["id"] == "other_id"
    assert db.storage["users/alice"]["id"] == "other_id"
    assert db.storage["usernames/other_id"] == {"uid": "alice"}
    assert client.put("/mypage/id", json={"new_id": "other_id", "password": "old_password"}).json()["changed"] is False


def test_login_id_change_rejects_taken_alias(context):
    client, db, _, _ = context
    db.storage["usernames/taken_id"] = {"uid": "another"}
    response = client.put("/mypage/id", json={"new_id": "taken_id", "password": "old_password"})
    assert response.status_code == 409
    assert db.storage["users/alice"]["id"] == "alice"


def test_preferences_save_and_retrieve(context):
    client, db, _, _ = context
    form = {
        "gender": "female",
        "birthday": "2004-12-28",
        "mbti": "INTJ",
        "activity_preference": "outdoor",
        "alcohol_preference": 3,
        "neighborhood": "서울 동작구",
        "has_car": False,
    }
    result = client.put("/mypage/preferences", json=form)
    assert result.status_code == 200, result.text
    assert result.json()["preferences"] == form
    assert client.get("/mypage/preferences").json()["preferences"] == form
    partial = client.put("/mypage/preferences", json={"has_car": True})
    assert partial.status_code == 200
    assert partial.json()["preferences"]["has_car"] is True
    assert partial.json()["preferences"]["mbti"] == "INTJ"
    assert db.storage["users/alice"]["preferences"]["birthday"] == "2004-12-28"


def test_preferences_validation_and_pending_deletion(context):
    client, _, _, _ = context
    assert client.put("/mypage/preferences", json={"alcohol_preference": 6}).status_code == 422
    assert client.put("/mypage/preferences", json={"birthday": "2099-01-01"}).status_code == 422
    assert client.put("/mypage/preferences", json={"gender": "invalid"}).status_code == 422
    assert client.post("/mypage/deletion", json={"password": "old_password"}).status_code == 200
    assert client.put("/mypage/preferences", json={"mbti": "ISTJ"}).status_code == 409


def test_support_email_configuration(context, monkeypatch):
    client, _, _, _ = context
    monkeypatch.delenv("SUPPORT_EMAIL", raising=False)
    assert client.get("/mypage/support").json() == {
        "title": "고객센터", "enabled": False, "email": None,
    }
    monkeypatch.setenv("SUPPORT_EMAIL", "team@example.com")
    assert client.get("/mypage/support").json() == {
        "title": "고객센터", "enabled": True, "email": "team@example.com",
    }
    monkeypatch.setenv("SUPPORT_EMAIL", "bad-address")
    assert client.get("/mypage/support").json()["enabled"] is False
