from datetime import date, datetime, time, timezone
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, Field, model_validator


KST = ZoneInfo("Asia/Seoul")


class AppointmentDateChange(BaseModel):
    date: date
    version: int = Field(ge=1)


class AppointmentConfirmation(BaseModel):
    recommendation_revision: str = Field(min_length=1)
    version: int | None = Field(default=None, ge=1)


def appointment_window(day, start, end):
    starts = datetime.combine(day, time.fromisoformat(start), KST)
    ends = datetime.combine(day, time.fromisoformat(end), KST)
    if ends <= starts:
        raise HTTPException(409, "약속의 종료 시각은 시작 시각보다 늦어야 합니다.")
    return starts.astimezone(timezone.utc), ends.astimezone(timezone.utc)


def make_appointment_router(db, current_user, collect_constraints):
    router = APIRouter(tags=["appointments"])
    User = Annotated[dict, Depends(current_user)]

    def room_ref(room_id):
        return db.collection("rooms").document(room_id)

    def own_history(uid, room_id):
        return db.collection("users").document(uid).collection("appointment_history").document(room_id)

    def room_for_member(room_id, uid):
        snap = room_ref(room_id).get()
        if not snap.exists:
            raise HTTPException(404, "약속 방을 찾을 수 없습니다.")
        data = snap.to_dict() or {}
        if uid not in data.get("member_uids", []):
            raise HTTPException(403, "현재 약속 방 참가자만 접근할 수 있습니다.")
        return data

    def history_data(room_id, room, appointment, uid):
        return {
            "room_id": room_id,
            "title": room.get("title") or "새 약속방",
            "date": appointment["date"],
            "starts_at": appointment["starts_at"],
            "ends_at": appointment["ends_at"],
            "location": appointment.get("location", ""),
            "appointment_version": appointment["version"],
            "status": "active",
            "uid": uid,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }

    @router.post("/rooms/{room_id}/appointment/confirm")
    def confirm_appointment(room_id: str, body: AppointmentConfirmation, user: User):
        uid = user["uid"]
        room = room_for_member(room_id, uid)
        if room.get("owner_uid") != uid:
            raise HTTPException(403, "약속 확정은 방장만 할 수 있습니다.")
        conditions = collect_constraints(room_id, uid)
        rec_ref = room_ref(room_id).collection("recommendations").document("latest")
        recommendation = rec_ref.get()
        if not recommendation.exists:
            raise HTTPException(409, "먼저 AI 추천을 생성하세요.")
        rec = recommendation.to_dict() or {}
        if rec.get("source_revision") != conditions["source_revision"] or body.recommendation_revision != rec.get("source_revision"):
            raise HTTPException(409, "추천 조건이 바뀌었습니다. 최신 추천을 확인하세요.")
        plan = rec.get("plan") or {}
        if isinstance(plan.get("date"), date):
            day = plan["date"]
        else:
            try:
                day = date.fromisoformat(str(plan["date"]))
            except (KeyError, ValueError, TypeError):
                raise HTTPException(409, "추천 일정에 날짜가 없습니다.")
        stops = plan.get("stops") or []
        if not stops:
            raise HTTPException(409, "추천 장소와 시간이 없습니다.")
        start_value = str(stops[0].get("start_time", ""))
        end_value = str(stops[-1].get("end_time", ""))
        try:
            starts_at, ends_at = appointment_window(day, start_value, end_value)
        except ValueError:
            raise HTTPException(409, "추천 일정의 시각이 올바르지 않습니다.")
        location = str(stops[0].get("name") or stops[0].get("address") or conditions.get("meeting_region") or "")[:240]
        ref = room_ref(room_id)

        @firestore.transactional
        def apply(transaction):
            current = ref.get(transaction=transaction)
            latest = rec_ref.get(transaction=transaction)
            if not current.exists or not latest.exists:
                raise HTTPException(409, "약속 방 또는 추천 정보가 변경되었습니다.")
            live = current.to_dict() or {}
            current_rec = latest.to_dict() or {}
            if live.get("owner_uid") != uid or uid not in live.get("member_uids", []):
                raise HTTPException(403, "약속 확정 권한이 없습니다.")
            if current_rec.get("source_revision") != body.recommendation_revision:
                raise HTTPException(409, "AI 추천 결과가 변경되었습니다.")
            previous = live.get("confirmed_appointment")
            if previous is not None:
                if body.version is None or previous.get("version") != body.version:
                    raise HTTPException(409, "이미 확정된 약속입니다. 최신 버전을 확인하세요.")
            elif body.version is not None:
                raise HTTPException(409, "아직 확정된 약속이 없습니다.")
            new_version = (previous or {}).get("version", 0) + 1
            value = {
                "date": day.isoformat(),
                "starts_at": starts_at,
                "ends_at": ends_at,
                "location": location,
                "version": new_version,
                "recommendation_revision": body.recommendation_revision,
                "confirmed_by": uid,
            }
            members = list(live.get("member_uids", []))
            transaction.update(ref, {
                "confirmed_appointment": value,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            for member_uid in members:
                transaction.set(own_history(member_uid, room_id), history_data(room_id, live, value, member_uid))
            return value

        return {"room_id": room_id, "appointment": apply(db.transaction())}

    @router.patch("/rooms/{room_id}/appointment/date")
    def change_date(room_id: str, body: AppointmentDateChange, user: User):
        uid = user["uid"]
        ref = room_ref(room_id)

        @firestore.transactional
        def apply(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists:
                raise HTTPException(404, "약속 방을 찾을 수 없습니다.")
            room = snap.to_dict() or {}
            if uid not in room.get("member_uids", []) or room.get("owner_uid") != uid:
                raise HTTPException(403, "약속 날짜 변경은 방장만 할 수 있습니다.")
            appointment = room.get("confirmed_appointment")
            if not appointment:
                raise HTTPException(409, "확정된 약속이 없습니다.")
            if appointment.get("version") != body.version:
                raise HTTPException(409, "약속 날짜가 다른 곳에서 수정되었습니다.")
            old_start = appointment["starts_at"].astimezone(KST)
            old_end = appointment["ends_at"].astimezone(KST)
            if old_start.date() == body.date:
                return appointment
            starts_at, ends_at = appointment_window(body.date, old_start.time().isoformat(), old_end.time().isoformat())
            updated = {**appointment, "date": body.date.isoformat(), "starts_at": starts_at, "ends_at": ends_at, "version": body.version + 1, "recommendation_revision": None}
            transaction.update(ref, {"confirmed_appointment": updated, "updated_at": firestore.SERVER_TIMESTAMP})
            for member_uid in room.get("member_uids", []):
                transaction.set(own_history(member_uid, room_id), history_data(room_id, room, updated, member_uid))
            return updated

        return {"room_id": room_id, "appointment": apply(db.transaction()), "recommendation_needs_refresh": True}

    @router.get("/rooms/{room_id}/appointment")
    def get_confirmed(room_id: str, user: User):
        room = room_for_member(room_id, user["uid"])
        return {"room_id": room_id, "appointment": room.get("confirmed_appointment")}

    @router.get("/mypage/appointments")
    def my_appointments(user: User):
        query = db.collection("users").document(user["uid"]).collection("appointment_history").limit(200)
        results = []
        for snap in query.stream():
            data = snap.to_dict() or {}
            results.append({"room_id": snap.id, **data})
        results.sort(key=lambda item: item.get("starts_at") or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        return {"appointments": results, "count": len(results)}

    @router.get("/calendar/confirmed-appointments")
    def my_confirmed_calendar(user: User):
        uid = user["uid"]
        query = db.collection("users").document(uid).collection("appointment_history").limit(200)
        events = []
        for snap in query.stream():
            data = snap.to_dict() or {}
            if data.get("status") != "active":
                continue
            events.append({
                "id": "meeting:" + snap.id,
                "room_id": snap.id,
                "title": data.get("title") or "약속",
                "starts_at": data.get("starts_at"),
                "ends_at": data.get("ends_at"),
                "location": data.get("location", ""),
                "source": "meeting",
                "version": data.get("appointment_version"),
            })
        return {"events": events}

    return router
