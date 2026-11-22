"""Run a real FastAPI ↔ Firebase Auth/Firestore emulator smoke test.

This uses isolated demo-planit Firebase emulators and an ephemeral dummy service
account. It NEVER contacts the production Firebase project or Kakao/OpenRouter.
"""
import json
import os
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import httpx
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient


def _configure_test_credentials():
    project = "demo-planit"
    os.environ["FIREBASE_WEB_API_KEY"] = "emulator-only-key"
    os.environ["FIREBASE_AUTH_EMULATOR_HOST"] = "127.0.0.1:9099"
    os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:8080"
    os.environ["GOOGLE_CLOUD_PROJECT"] = project
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(serialization.Encoding.PEM,
                            serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption()).decode()
    fd, filename = tempfile.mkstemp(prefix="planit-emulator-only-", suffix=".json")
    with os.fdopen(fd, "w") as target:
        json.dump({
            "type": "service_account",
            "project_id": project,
            "private_key_id": "emulator-only",
            "private_key": pem,
            "client_email": "planit-emulator@demo-planit.iam.gserviceaccount.com",
            "client_id": "1234567890",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        }, target)
    os.environ["FIREBASE_SERVICE_ACCOUNT_JSON"] = filename
    return Path(filename)


def check(response, code=200):
    assert response.status_code == code, (
        f"{response.request.method} {response.request.url.path}: "
        f"HTTP {response.status_code}: {response.text[:500]}"
    )
    return response.json()


def main():
    credential = _configure_test_credentials()
    try:
        import main as backend

        async def emulator_password_login(email, password):
            url = ("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/"
                   "accounts:signInWithPassword")
            async with httpx.AsyncClient(timeout=12) as session:
                response = await session.post(
                    url, params={"key": "emulator-only-key"},
                    json={"email": email, "password": password,
                          "returnSecureToken": True},
                )
                response.raise_for_status()
                return response.json()

        backend.firebase_password_login = emulator_password_login

        async def supported_region(region):
            if region.strip() == "서울":
                return {"name": "서울", "latitude": 37.566,
                        "longitude": 126.978, "method": "emulator_fixture"}
            return None

        backend._lookup_supported_region = supported_region

        with TestClient(backend.app) as client:
            assert check(client.get("/health"))["status"] == "ok"
            users = [
                ("ci_alice", "alice@example.com", "앨리스"),
                ("ci_bob", "bob@example.com", "밥"),
            ]
            auth_headers = []
            for login_id, email, nickname in users:
                check(client.post("/auth/signup", json={
                    "id": login_id, "nickname": nickname,
                    "email": email, "password": "Passw0rd-ci-test!",
                    "password_confirm": "Passw0rd-ci-test!",
                }), 201)
                token_data = check(client.post("/auth/login", json={
                    "id": login_id, "password": "Passw0rd-ci-test!"
                }))
                assert token_data["uid"] == login_id
                header = {"Authorization": "Bearer " + token_data["access_token"]}
                profile = check(client.get("/users/me", headers=header))
                assert profile["nickname"] == nickname
                auth_headers.append(header)

            a, b = auth_headers
            check(client.put("/mypage/preferences", headers=a,
                             json={"mbti": "INFP"}))
            preferences = check(client.get("/mypage/preferences", headers=a))
            assert preferences["preferences"]["mbti"] == "INFP"

            assert check(client.get("/places/validate-region", headers=a,
                                    params={"query": "서울"}))["valid"] is True
            for unknown in ["Paris", "ㅁㄴㅇㄹ"]:
                result = check(client.get("/places/validate-region", headers=a,
                                          params={"query": unknown}))
                assert result["valid"] is False

            room = check(client.post("/rooms", headers=a,
                                     json={"title": "통합 시험 방", "max_members": 2}), 201)
            room_id = room["room_id"]
            invite = room["invite_code"]
            assert len(invite) == 7 and any(s in invite for s in "#@!")
            check(client.post("/rooms/join", headers=b,
                              json={"invite_code": invite}))
            assert any(r["room_id"] == room_id
                       for r in check(client.get("/rooms", headers=b))["rooms"])

            today = datetime.now(ZoneInfo("Asia/Seoul"))
            start = (today + timedelta(days=2)).replace(hour=13, minute=0,
                                                         second=0, microsecond=0)
            end = start + timedelta(hours=1)
            check(client.put(f"/rooms/{room_id}/schedule", headers=a,
                             json={"starts_at": start.isoformat(),
                                   "version": 0}))
            for header in (a, b):
                shared = check(client.get("/calendar/room-appointments",
                                          headers=header))
                assert any(event["room_id"] == room_id
                           for event in shared["events"]), shared

            for header in (a, b):
                check(client.post(f"/rooms/{room_id}/preferences",
                                  headers=header, json={
                    "budget": 30000, "region": "서울",
                    "available_date": start.date().isoformat(),
                    "start_time": "13:00", "end_time": "18:00",
                    "activities": ["카페"], "additional_notes": "조용한 실내",
                }))
            submitted = check(client.get(f"/rooms/{room_id}/preferences", headers=a))
            assert submitted["submitted_count"] == 2

            event_payload = {
                "title": "개인 일정 테스트",
                "starts_at": start.isoformat(),
                "ends_at": end.isoformat(),
                "repeat": "none", "category": "personal",
            }
            item = check(client.post("/calendar/events", headers=a,
                                     json=event_payload), 201)
            event_id = item["id"]
            params = {"starts_from": (start - timedelta(days=1)).isoformat(),
                      "starts_before": (start + timedelta(days=3)).isoformat()}
            alice_events = check(client.get("/calendar/events", headers=a,
                                            params=params))["events"]
            bob_events = check(client.get("/calendar/events", headers=b,
                                          params=params))["events"]
            assert any(event["id"] == event_id for event in alice_events)
            assert all(event["id"] != event_id for event in bob_events)
            updated = check(client.put(f"/calendar/events/{event_id}",
                                       headers=a,
                                       json={**event_payload,
                                             "title": "수정한 개인 일정",
                                             "version": 1}))
            assert updated["title"] == "수정한 개인 일정"
            check(client.delete(f"/calendar/events/{event_id}", headers=a,
                                params={"version": 2}))
            after_delete = check(client.get("/calendar/events", headers=a,
                                            params=params))["events"]
            assert all(event["id"] != event_id for event in after_delete)

            new_login = check(client.post("/auth/login", json={
                "id": "ci_alice", "password": "Passw0rd-ci-test!"
            }))
            restored = check(client.get("/rooms", headers={
                "Authorization": "Bearer " + new_login["access_token"]
            }))
            assert any(r["room_id"] == room_id for r in restored["rooms"])
            print("PASS: Firebase Auth/Firestore emulator, signup/login, "
                  "profiles, regions, room join, shared appointments, "
                  "personal calendar CRUD and account data restoration")
    finally:
        credential.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
