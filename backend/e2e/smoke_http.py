"""Real HTTP smoke suite against ephemeral Firebase Auth + Firestore emulators.

No production credentials, accounts, external AI, or Kakao calls are used.
All checks run through the live Uvicorn app and Firebase emulator SDKs.
"""
from __future__ import annotations

import os
import sys
from datetime import datetime, timezone
from uuid import uuid4

import httpx

assert os.environ.get("FIRESTORE_EMULATOR_HOST"), "Firestore emulator must be configured"
assert os.environ.get("FIREBASE_AUTH_EMULATOR_HOST"), "Auth emulator must be configured"
assert os.environ.get("GOOGLE_CLOUD_PROJECT", "").startswith("demo-"), "Refusing non-demo project"

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import main  # noqa: E402

BASE = "http://127.0.0.1:8765"
client = httpx.Client(base_url=BASE, timeout=20)
prefix = uuid4().hex[:6]
checks: list[str] = []


def request(method, path, *, token=None, body=None, params=None, status=200):
    headers = {"Authorization": f"Bearer {token}"} if token else None
    response = client.request(method, path, headers=headers, json=body, params=params)
    if response.status_code != status:
        raise AssertionError(f"{method} {path}: expected {status}, got {response.status_code}: {response.text[:700]}")
    return response.json()


def account(number):
    identifier = f"qa{prefix}{number}"
    password = f"Qatest_{prefix}a123"
    nickname = f"QA-{prefix}-{number}"
    email = f"{identifier}@example.com"
    request("POST", "/auth/signup", body={
        "id": identifier, "password": password, "password_confirm": password,
        "nickname": nickname, "email": email,
        "name": f"QA{number}", "phone": "01012345678",
    }, status=201)
    result = request("POST", "/auth/login", body={"id": identifier, "password": password})
    assert result.get("access_token") and result["uid"] == identifier
    assert request("GET", "/users/me", token=result["access_token"])["id"] == identifier
    return identifier, password, result["access_token"]


assert request("GET", "/health")["status"] == "ok"
request("GET", "/rooms", status=401)
checks.append("Health and unauthorized access")

a, password_a, ta = account(1)
b, password_b, tb = account(2)
c, password_c, tc = account(3)
request("POST", "/auth/login", body={"id": a, "password": "wrong"}, status=401)
checks.append("Three real Firebase Auth account signups and login tokens")

assert request("GET", "/auth/check-id", params={"id": a})["available"] is False
assert request("GET", "/auth/check-id", params={"id": "freeuser42"})["available"] is True
request("POST", "/auth/signup", body={
    "id": a, "password": password_a, "password_confirm": password_a,
    "nickname": f"Other{prefix}", "email": "different@example.com",
    "name": "Duplicate", "phone": "01012345678",
}, status=409)
checks.append("Username uniqueness and validation")

created = request("POST", "/rooms", token=ta, body={"title": "E2E shared outing", "max_members": 2}, status=201)
rid = created["room_id"]
invite = created["invite_code"]
assert len(invite) == 7
assert any(char.isalpha() for char in invite)
assert any(char.isdigit() for char in invite)
assert any(char in "#@!" for char in invite)
assert any(room["room_id"] == rid for room in request("GET", "/rooms", token=ta)["rooms"])
request("POST", "/rooms/join", token=tb, body={"invite_code": invite})
request("POST", "/rooms/join", token=tc, body={"invite_code": invite}, status=409)
request("POST", "/rooms/join", token=tc, body={"invite_code": "ABCDEFG8"}, status=422)
request("GET", f"/rooms/{rid}", token=tc, status=403)
checks.append("Invite-code generation, seven-character validation, capacity and access checks")

meeting_date = "2026-12-05"
initial = "2026-12-05T13:00:00+09:00"
schedule = request("PUT", f"/rooms/{rid}/schedule", token=ta,
                   body={"starts_at": initial, "version": 0})
assert schedule["schedule"]["version"] == 1
request("PUT", f"/rooms/{rid}/schedule", token=tb, body={"starts_at": initial, "version": 1}, status=403)
request("PUT", f"/rooms/{rid}/schedule", token=ta, body={"starts_at": initial, "version": 0}, status=409)
shared_b = request("GET", "/calendar/room-appointments", token=tb)["events"]
assert len(shared_b) == 1 and shared_b[0]["room_id"] == rid and shared_b[0]["status"] == "scheduled"
assert request("GET", "/calendar/room-appointments", token=tc)["events"] == []
checks.append("Shared room schedule appears for members only")

personal = request("POST", "/calendar/events", token=ta, status=201, body={
    "title": "Weekly private lecture", "starts_at": "2026-12-05T10:00:00+09:00",
    "ends_at": "2026-12-05T11:00:00+09:00", "repeat": "weekly",
    "category": "school", "reminder_minutes": 30,
})
event_id = personal["id"]
assert personal["repeat"] == "weekly"
recurring_a = request("GET", "/calendar/recurring-events", token=ta)["events"]
recurring_b = request("GET", "/calendar/recurring-events", token=tb)["events"]
assert any(e["id"] == event_id for e in recurring_a) and recurring_b == []
range_query = {"starts_from": "2026-12-01T00:00:00+09:00",
               "starts_before": "2027-01-01T00:00:00+09:00"}
assert any(e["id"] == event_id for e in request("GET", "/calendar/events", token=ta, params=range_query)["events"])
assert request("GET", "/calendar/events", token=tb, params=range_query)["events"] == []
request("PUT", f"/calendar/events/{event_id}", token=ta, body={
    "title": "Updated lecture", "starts_at": "2026-12-05T10:00:00+09:00",
    "ends_at": "2026-12-05T11:00:00+09:00", "repeat": "monthly",
    "category": "school", "reminder_minutes": None, "version": 1,
})
request("DELETE", f"/calendar/events/{event_id}", token=ta, params={"version": "1"}, status=409)
request("DELETE", f"/calendar/events/{event_id}", token=ta, params={"version": "2"})
assert request("GET", "/calendar/recurring-events", token=ta)["events"] == []
checks.append("Private recurring event create/update/optimistic lock/delete")

for token in (ta, tb):
    request("POST", f"/rooms/{rid}/preferences", token=token, params={"regenerate": "false"}, body={
        "budget": 40000, "region": "홍대", "departure_location": "홍대",
        "available_date": meeting_date, "start_time": "13:00",
        "end_time": "17:00", "activities": ["카페", "산책"],
        "additional_notes": "조용한 카페",
    })
detail = request("GET", f"/rooms/{rid}", token=ta)
assert all(m["submitted"] for m in detail["members"])
request("GET", f"/rooms/{rid}/preferences", token=tc, status=403)
checks.append("Participant conditions persist in real Firestore")

# External OpenRouter/Kakao integration is out of scope for the emulator test.
# Only its saved output contract is seeded, while all app APIs and Firestore writes
# remain the actual backend and official Firestore emulator.
constraints = main._collect_constraints(rid, a)
revision = constraints["source_revision"]
rec_ref = main.db.collection("rooms").document(rid).collection("recommendations").document("latest")


def seed_plan(day: str, expected_revision: str):
    rec_ref.set({
        "source_revision": expected_revision,
        "plan": {
            "title": "E2E verified test route",
            "date": day,
            "stops": [{
                "start_time": "13:00", "end_time": "15:00",
                "name": "QA fixture place", "address": "서울 마포구",
                "place_id": "emulator-fixture-place", "activity": "카페",
            }],
        },
    })


seed_plan(meeting_date, revision)
assert request("GET", f"/rooms/{rid}/recommendation", token=ta)["is_stale"] is False
first = request("POST", f"/rooms/{rid}/appointment/confirm", token=ta, body={
    "recommendation_revision": revision,
})
assert first["appointment"]["version"] == 1
first_id = first["appointment"]["appointment_id"]
assert first_id
assert len(request("GET", "/calendar/room-appointments", token=tb)["events"]) == 1
checks.append("Saved recommendation confirmation and both participant histories")

# Approved date changes must survive failures of disabled third-party services.
changed = request("PATCH", f"/rooms/{rid}/appointment/date", token=ta, body={
    "date": "2026-12-06", "version": 1,
})
assert changed["appointment"]["date"] == "2026-12-06"
assert changed["recommendation_needs_refresh"] is True
assert changed["recommendation_status"] in ("failed", "pending", "updated")
assert request("GET", f"/rooms/{rid}/appointment", token=ta)["appointment"]["date"] == "2026-12-06"
checks.append("Approved date changes persist even if third-party AI is unavailable")

# Refresh a stored recommendation for a second appointment in the same room.
constraints2 = main._collect_constraints(rid, a)
revision2 = constraints2["source_revision"]
seed_plan("2026-12-06", revision2)
again = request("POST", f"/rooms/{rid}/appointment/confirm", token=ta, body={
    "recommendation_revision": revision2, "version": 2,
})
second_id = again["appointment"]["appointment_id"]
assert first_id != second_id
history_a = request("GET", "/mypage/appointments", token=ta)["appointments"]
assert sum(h.get("room_id") == rid for h in history_a) == 2
history_b = request("GET", "/mypage/appointments", token=tb)["appointments"]
assert sum(h.get("room_id") == rid for h in history_b) == 2
checks.append("Two appointments in one room persist as distinct history records")

request("DELETE", f"/rooms/{rid}/members/me", token=tb)
assert request("GET", "/calendar/room-appointments", token=tb)["events"] == []
history_b_left = request("GET", "/mypage/appointments", token=tb)["appointments"]
assert all(h["status"] == "left" for h in history_b_left if h.get("room_id") == rid)
assert len(request("GET", "/calendar/room-appointments", token=ta)["events"]) == 2
checks.append("Leaving room hides personal shared calendar and preserves other member history")

# --- Extended real SDK checks: MyPage, voting, privacy, recovery ---
original_profile = request("GET", "/mypage/profile", token=ta)
updated_profile = request("PUT", "/mypage/profile", token=ta, body={
    "nickname": f"Vfy{prefix}", "name": "Verified QA", "phone": "01012345678",
})
assert updated_profile["nickname"] == f"Vfy{prefix}"
assert request("GET", "/mypage/profile", token=ta)["nickname"] == f"Vfy{prefix}"
request("GET", "/mypage/profile", status=401)
prefs_saved = request("PUT", "/mypage/preferences", token=ta, body={
    "gender": "male", "birthday": "2003-12-28",
    "mbti": "INTJ", "activity_preference": "indoor",
    "alcohol_preference": 2, "neighborhood": "서울", "has_car": False,
})
assert prefs_saved["preferences"]["mbti"] == "INTJ"
assert request("GET", "/mypage/preferences", token=ta)["preferences"]["has_car"] is False
assert request("GET", "/mypage/preferences", token=tb)["preferences"] == {}
checks.append("Live MyPage nickname update, private preferences and unauthorized request rejection")

# A fresh two-member room exercises real Firestore transaction-based voting.
vroom = request("POST", "/rooms", token=ta,
                body={"title": "Voting QA meeting", "max_members": 2}, status=201)
vrid = vroom["room_id"]
request("POST", "/rooms/join", token=tb, body={"invite_code": vroom["invite_code"]})
initial_preferences = {
    "budget": 30000, "region": "홍대", "departure_location": "홍대",
    "available_date": "2026-12-11", "start_time": "12:00", "end_time": "18:00",
    "activities": ["카페", "산책"], "additional_notes": "조용한 장소",
}
for token in (ta, tb):
    request("POST", f"/rooms/{vrid}/preferences", token=token,
            params={"regenerate": "false"}, body=initial_preferences)

proposed = request("POST", f"/rooms/{vrid}/preferences", token=tb,
                   params={"regenerate": "false"},
                   body={**initial_preferences, "budget": 55000})
assert proposed["proposal_created"] is True and proposed["recommendation_status"] == "awaiting_votes"
did = proposed["decision"]["decision_id"]
listing = request("GET", f"/rooms/{vrid}/decisions", token=ta)["decisions"]
assert any(d["decision_id"] == did for d in listing)
before_vote = request("GET", f"/rooms/{vrid}/preferences", token=ta)
assert next(entry["preferences"]["budget"] for entry in before_vote["members"] if entry["uid"] == b) == 30000
accepted = request("POST", f"/rooms/{vrid}/decisions/{did}/vote",
                   token=ta, body={"approve": True})
assert accepted["decision"]["status"] == "approved"
assert next(entry["preferences"]["budget"] for entry in request("GET", f"/rooms/{vrid}/preferences", token=ta)["members"] if entry["uid"] == b) == 55000
request("POST", f"/rooms/{vrid}/decisions/{did}/vote",
        token=ta, body={"approve": True}, status=409)
checks.append("Real unanimous approval preserves old conditions until vote, then commits")

rejected = request("POST", f"/rooms/{vrid}/preferences", token=tb,
                   params={"regenerate": "false"},
                   body={**initial_preferences, "budget": 65000})
reject_id = rejected["decision"]["decision_id"]
rejection = request("POST", f"/rooms/{vrid}/decisions/{reject_id}/vote",
                    token=ta, body={"approve": False})
assert rejection["decision"]["status"] == "rejected"
assert next(entry["preferences"]["budget"] for entry in request("GET", f"/rooms/{vrid}/preferences", token=ta)["members"] if entry["uid"] == b) == 55000
checks.append("Real rejection refuses proposed changes without overwriting preferences")

region_proposal = request("PATCH", f"/rooms/{vrid}/meeting", token=tb,
                          params={"regenerate": "false"},
                          body={"mode": "fixed", "region": "강남"})
assert region_proposal["proposal_created"] is True
region_id = region_proposal["decision"]["decision_id"]
request("POST", f"/rooms/{vrid}/decisions/{region_id}/vote", token=ta,
        body={"approve": True})
room_after_vote = main.db.collection("rooms").document(vrid).get().to_dict()
assert room_after_vote["meeting_mode"] == "fixed" and room_after_vote["meeting_region"] == "강남"
checks.append("Member meeting-location proposal and owner approval use genuine Firestore transactions")

# Seed AI output only; actual FastAPI confirm, date proposal, voting and
# stored member histories use real Firestore transactions.
constraints3 = main._collect_constraints(vrid, a)
v_revision = constraints3["source_revision"]
main.db.collection("rooms").document(vrid).collection("recommendations").document("latest").set({
    "source_revision": v_revision,
    "plan": {"title": "Voting test plan", "date": "2026-12-11",
             "stops": [{"name": "QA stop", "start_time": "12:00",
                        "end_time": "13:00", "place_id": "qa-stop"}]},
})
confirmed3 = request("POST", f"/rooms/{vrid}/appointment/confirm", token=ta,
                     body={"recommendation_revision": v_revision})
assert confirmed3["appointment"]["version"] == 1
date_proposal = request("PATCH", f"/rooms/{vrid}/appointment/date", token=tb,
                        body={"date": "2026-12-13", "version": 1})
assert date_proposal["proposal_created"] is True
assert request("GET", f"/rooms/{vrid}/appointment", token=ta)["appointment"]["date"] == "2026-12-11"
date_id = date_proposal["date_change_request"]["request_id"]
assert any(d["request_id"] == date_id for d in request("GET", f"/rooms/{vrid}/appointment/date-requests",
                                                       token=ta)["requests"])
date_vote = request("POST", f"/rooms/{vrid}/appointment/date-requests/{date_id}/vote",
                    token=ta, body={"approve": True})
assert date_vote["date_change_request"]["status"] == "approved"
assert request("GET", f"/rooms/{vrid}/appointment", token=tb)["appointment"]["date"] == "2026-12-13"
assert date_vote["recommendation_status"] in ("pending", "failed", "updated")
request("POST", f"/rooms/{vrid}/appointment/date-requests/{date_id}/vote",
        token=ta, body={"approve": True}, status=409)
checks.append("Real member date-change voting updates both members' confirmed appointment safely")

# Deletion is only scheduled after password reauthentication; cancellation restores edits.
assert request("GET", "/mypage/deletion", token=tc)["status"] == "none"
request("POST", "/mypage/deletion", token=tc, body={"password": "wrong"}, status=401)
deleting = request("POST", "/mypage/deletion", token=tc, body={"password": password_c})
assert deleting["status"] == "pending" and deleting["due_at"]
assert request("GET", "/mypage/deletion", token=tc)["status"] == "pending"
request("POST", "/mypage/deletion", token=tc, body={"password": password_c}, status=409)
cancelled = request("DELETE", "/mypage/deletion", token=tc)
assert cancelled["status"] == "cancelled"
assert request("GET", "/mypage/deletion", token=tc)["status"] == "none"
checks.append("Real password-verified 30-day deletion request, duplicate protection and cancellation")

print("REAL FIREBASE EMULATOR HTTP E2E PASSED")
for i, result in enumerate(checks, start=1):
    print(f"  {i:02}. {result}")
print(f"VERIFIED {len(checks)} multi-request flows, {len((a, b, c))} real Auth emulator accounts")
