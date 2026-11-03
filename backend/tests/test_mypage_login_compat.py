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
