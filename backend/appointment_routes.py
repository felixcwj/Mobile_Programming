from datetime import date, datetime, time, timezone
from typing import Annotated
from zoneinfo import ZoneInfo
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from firebase_admin import firestore
from pydantic import BaseModel, Field, model_validator


KST = ZoneInfo("Asia/Seoul")


class AppointmentDateChange(BaseModel):
    date: date
    version: int = Field(ge=1)
    additional_notes: str | None = Field(default=None, max_length=1000, description='일정 변경에 반영할 자유 서술 기타 사항')

    @model_validator(mode='after')
    def clean_notes(self):
        if self.additional_notes is not None:
            self.additional_notes = self.additional_notes.strip()
        return self


class RoomScheduleInput(BaseModel):
    starts_at: datetime | None = None
    version: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.starts_at is not None and self.starts_at.tzinfo is None:
            raise ValueError("약속 시작 시각에는 시간대 정보가 필요합니다.")
        return self


class AppointmentConfirmation(BaseModel):
    recommendation_revision: str = Field(min_length=1)
    version: int | None = Field(default=None, ge=1)


def appointment_window(day, start, end):
    starts = datetime.combine(day, time.fromisoformat(start), KST)
    ends = datetime.combine(day, time.fromisoformat(end), KST)
    if ends <= starts:
        raise HTTPException(409, "약속의 종료 시각은 시작 시각보다 늦어야 합니다.")
    return starts.astimezone(timezone.utc), ends.astimezone(timezone.utc)


def make_appointment_router(db, current_user, collect_constraints, regenerate_room=None):
    router = APIRouter(tags=["appointments"])
    User = Annotated[dict, Depends(current_user)]

    def room_ref(room_id):
        return db.collection("rooms").document(room_id)

    def own_history(uid, room_id):
        # Legacy/latest alias retained for existing clients and older rooms.
        return db.collection("users").document(uid).collection("appointment_history").document(room_id)

    def appointment_history(uid, room_id, appointment_id):
        # Distinct document per appointment, even when multiple appointments share a room.
        return db.collection("users").document(uid).collection("appointment_history").document(
            f"{room_id}__{appointment_id}"
        )

    def write_history(transaction, uid, room_id, room, appointment):
        data = history_data(room_id, room, appointment, uid)
        transaction.set(own_history(uid, room_id), data)
        if appointment.get("appointment_id"):
            transaction.set(appointment_history(uid, room_id, appointment["appointment_id"]), data)

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
            "additional_notes": appointment.get("additional_notes", ""),
            "appointment_version": appointment["version"],
            "appointment_id": appointment.get("appointment_id"),
            "status": "active",
            "uid": uid,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }

    @router.put("/rooms/{room_id}/schedule")
    def set_room_schedule(room_id: str, body: RoomScheduleInput, user: User):
        """A room's unconfirmed start date/time, shown to all current members."""
        uid = user["uid"]
        ref = room_ref(room_id)

        @firestore.transactional
        def apply(transaction):
            snap = ref.get(transaction=transaction)
            if not snap.exists:
                raise HTTPException(404, "약속 방을 찾을 수 없습니다.")
            live = snap.to_dict() or {}
            if uid not in live.get("member_uids", []) or live.get("owner_uid") != uid:
                raise HTTPException(403, "약속 일정 설정은 방장만 할 수 있습니다.")
            if live.get("confirmed_appointment"):
                raise HTTPException(409, "확정된 약속은 별도 날짜 변경 기능을 이용하세요.")
            previous = live.get("room_schedule") or {}
            current_version = previous.get("version", 0)
            if body.version != current_version:
                raise HTTPException(409, "약속 일정이 변경되었습니다. 다시 불러오세요.")
            previous_start = previous.get("starts_at")
            new_start = body.starts_at.astimezone(timezone.utc) if body.starts_at else None
            if previous_start == new_start:
                return previous or None
            # Retain the version after clearing so a stale device cannot re-add a removed date.
            value = {"starts_at": new_start, "version": current_version + 1}
            transaction.update(ref, {"room_schedule": value, "updated_at": firestore.SERVER_TIMESTAMP})
            return value

        return {"room_id": room_id, "schedule": apply(db.transaction())}

    @router.get("/rooms/{room_id}/schedule")
    def get_room_schedule(room_id: str, user: User):
        room = room_for_member(room_id, user["uid"])
        return {"room_id": room_id, "schedule": room.get("room_schedule")}

    @router.get("/calendar/room-appointments")
    def room_calendar(user: User):
        """Private room timeline: all recorded appointments plus pending room dates."""
        joined = list(db.collection("rooms").where("member_uids", "array_contains", user["uid"]).stream())
        current_rooms = {snap.id: (snap.to_dict() or {}) for snap in joined}
        events = []
        for key, data in user_history_entries(user["uid"]):
            rid = data.get("room_id")
            if rid not in current_rooms or data.get("status") != "active":
                continue
            events.append({
                "id": "meeting:" + key,
                "room_id": rid,
                "appointment_id": data.get("appointment_id"),
                "title": data.get("title") or "새 약속방",
                "starts_at": data.get("starts_at"),
                "ends_at": data.get("ends_at"),
                "location": data.get("location", ""),
                "source": "meeting",
                "status": "confirmed",
                "version": data.get("appointment_version"),
            })
        for rid, room in current_rooms.items():
            scheduled = room.get("room_schedule") or {}
            if room.get("confirmed_appointment") or not scheduled.get("starts_at"):
                continue
            events.append({
                "id": "meeting:" + rid,
                "room_id": rid,
                "appointment_id": None,
                "title": room.get("title") or "새 약속방",
                "starts_at": scheduled["starts_at"],
                "ends_at": None,
                "location": "",
                "source": "meeting",
                "status": "scheduled",
                "version": scheduled.get("version"),
            })
        events.sort(key=lambda event: event["starts_at"])
        return {"events": events, "count": len(events)}

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
        new_appointment_id = uuid4().hex

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
                "appointment_id": new_appointment_id,
                "date": day.isoformat(),
                "starts_at": starts_at,
                "ends_at": ends_at,
                "location": location,
                "version": new_version,
                "recommendation_revision": body.recommendation_revision,
                "confirmed_by": uid,
                "additional_notes": (previous or {}).get("additional_notes", ""),
            }
            members = list(live.get("member_uids", []))
            transaction.update(ref, {
                "confirmed_appointment": value,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            for member_uid in members:
                if previous and not previous.get("appointment_id"):
                    legacy = {**previous, "appointment_id": f"legacy-{room_id}"}
                    transaction.set(appointment_history(member_uid, room_id, legacy["appointment_id"]),
                                    history_data(room_id, live, legacy, member_uid))
                write_history(transaction, member_uid, room_id, live, value)
            return value

        return {"room_id": room_id, "appointment": apply(db.transaction())}

    def date_availability(room_id, room, target_date, transaction=None):
        """Read saved preferred dates; these are not explicit votes/consent."""
        desired = target_date.isoformat()
        members = []
        for member_uid in room.get("member_uids", []):
            pref_ref = room_ref(room_id).collection("preferences").document(member_uid)
            snap = pref_ref.get(transaction=transaction)
            available_date = (snap.to_dict() or {}).get("available_date") if snap.exists else None
            available_date = str(available_date) if available_date else None
            if available_date is None:
                state = "missing"
            elif available_date == desired:
                state = "available"
            else:
                state = "different_date"
            members.append({"uid": member_uid, "available_date": available_date, "status": state})
        total = len(members)
        matched = sum(member["status"] == "available" for member in members)
        return {
            "room_id": room_id,
            "date": desired,
            "total_members": total,
            "available_count": matched,
            "all_available": total > 0 and matched == total,
            "members": members,
            "requires_member_confirmation": total == 0 or matched != total,
            "note": "저장된 가능 날짜만 비교합니다. 참가자의 명시적인 날짜 변경 동의는 아닙니다.",
        }

    @router.get("/rooms/{room_id}/appointment/date-availability")
    def check_date_availability(room_id: str, date: date, user: User):
        room = room_for_member(room_id, user["uid"])
        return date_availability(room_id, room, date)

    async def refresh_recommendation(room_id, uid, result):
        if not result.get("recommendation_needs_refresh"):
            result["recommendation_status"] = "unchanged"
            return result
        if regenerate_room is None:
            result["recommendation_status"] = "stale"
            return result
        try:
            result["recommendation"] = await regenerate_room(room_id, uid)
            result["recommendation_status"] = "updated"
        except HTTPException as exc:
            result["recommendation_status"] = "pending" if exc.status_code == 409 else "failed"
            result["recommendation_error"] = exc.detail
        return result

    @router.patch("/rooms/{room_id}/appointment/date")
    async def change_date(
        room_id: str,
        body: AppointmentDateChange,
        user: User,
        require_all_available: bool = Query(default=False, description="저장된 가능 날짜가 전원 일치할 때만 변경"),
    ):
        uid = user["uid"]
        ref = room_ref(room_id)
        current_room = room_for_member(room_id, uid)
        current_appointment = current_room.get('confirmed_appointment')
        if not current_appointment:
            raise HTTPException(409, '확정된 약속이 없습니다.')
        if current_appointment.get('version') != body.version:
            raise HTTPException(409, '약속 날짜가 다른 곳에서 수정되었습니다.')
        if current_room.get('owner_uid') != uid:
            proposal_ref = ref.collection('date_change_requests').document()
            proposal = {
                'request_id': proposal_ref.id, 'date': body.date.isoformat(),
                'version': body.version, 'additional_notes': body.additional_notes,
                'status': 'pending', 'created_by': uid,
                'voters': list(current_room.get('member_uids', [])), 'votes': {uid: True},
                'created_at': datetime.now(timezone.utc),
            }
            proposal_ref.create(proposal)
            return {'room_id': room_id, 'proposal_created': True, 'date_change_request': proposal,
                    'recommendation_needs_refresh': False, 'recommendation_status': 'awaiting_votes',
                    'message': '방 구성원 전체의 동의를 받으면 일정이 변경됩니다.'}

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
            if old_start.date() == body.date and (
                body.additional_notes is None or body.additional_notes == appointment.get('additional_notes', '')
            ):
                return appointment, False, date_availability(room_id, room, body.date, transaction)
            availability = date_availability(room_id, room, body.date, transaction)
            if require_all_available and not availability["all_available"]:
                raise HTTPException(409, detail={
                    "message": "참가자 전원의 저장된 가능 날짜가 일치하지 않습니다.",
                    "availability": availability,
                })
            starts_at, ends_at = appointment_window(body.date, old_start.time().isoformat(), old_end.time().isoformat())
            updated = {**appointment, "appointment_id": appointment.get("appointment_id") or f"legacy-{room_id}",
                       "date": body.date.isoformat(), "starts_at": starts_at, "ends_at": ends_at,
                       "version": body.version + 1, "recommendation_revision": None}
            if body.additional_notes is not None:
                updated['additional_notes'] = body.additional_notes
            transaction.update(ref, {"confirmed_appointment": updated, "updated_at": firestore.SERVER_TIMESTAMP})
            for member_uid in room.get("member_uids", []):
                write_history(transaction, member_uid, room_id, room, updated)
            return updated, True, availability

        appointment, changed, availability = apply(db.transaction())
        return await refresh_recommendation(room_id, uid, {
            "room_id": room_id,
            "appointment": appointment,
            "recommendation_needs_refresh": changed,
            "availability": availability,
        })

    @router.get('/rooms/{room_id}/appointment/date-requests')
    def list_date_change_requests(room_id: str, user: User):
        room_for_member(room_id, user['uid'])
        requests = [snap.to_dict() or {} for snap in room_ref(room_id).collection('date_change_requests').stream()]
        requests.sort(key=lambda entry: entry.get('created_at') or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        return {'room_id': room_id, 'requests': requests}

    class DateChangeVote(BaseModel):
        approve: bool

    @router.post('/rooms/{room_id}/appointment/date-requests/{request_id}/vote')
    async def vote_date_change(room_id: str, request_id: str, body: DateChangeVote, user: User):
        uid = user['uid']
        ref = room_ref(room_id)
        request_ref = ref.collection('date_change_requests').document(request_id)

        @firestore.transactional
        def apply(transaction):
            room_snap = ref.get(transaction=transaction)
            request_snap = request_ref.get(transaction=transaction)
            if not room_snap.exists or not request_snap.exists:
                raise HTTPException(404, '방 또는 날짜 변경 요청을 찾을 수 없습니다.')
            room = room_snap.to_dict() or {}
            request = request_snap.to_dict() or {}
            voters = list(request.get('voters', []))
            if uid not in room.get('member_uids', []) or uid not in voters:
                raise HTTPException(403, '투표 권한이 없습니다.')
            if request.get('status') != 'pending':
                raise HTTPException(409, '이미 처리된 날짜 변경 요청입니다.')
            if set(voters) != set(room.get('member_uids', [])):
                raise HTTPException(409, '참여자 구성이 바뀌어 새 요청이 필요합니다.')
            appointment = room.get('confirmed_appointment')
            if not appointment or appointment.get('version') != request.get('version'):
                raise HTTPException(409, '약속이 변경되어 새 요청이 필요합니다.')
            votes = dict(request.get('votes', {}))
            votes[uid] = body.approve
            approved = bool(body.approve and all(votes.get(voter) is True for voter in voters))
            new_status = 'rejected' if not body.approve else ('approved' if approved else 'pending')
            updates = {'votes': votes, 'status': new_status}
            if approved:
                starts = appointment['starts_at'].astimezone(KST)
                ends = appointment['ends_at'].astimezone(KST)
                target = date.fromisoformat(request['date'])
                starts_at, ends_at = appointment_window(target, starts.time().isoformat(), ends.time().isoformat())
                updated = {**appointment, 'appointment_id': appointment.get('appointment_id') or f'legacy-{room_id}',
                           'date': target.isoformat(), 'starts_at': starts_at,
                           'ends_at': ends_at, 'version': appointment['version'] + 1,
                           'recommendation_revision': None}
                if request.get('additional_notes') is not None:
                    updated['additional_notes'] = request['additional_notes']
                transaction.update(ref, {'confirmed_appointment': updated, 'updated_at': firestore.SERVER_TIMESTAMP})
                for member_uid in voters:
                    write_history(transaction, member_uid, room_id, room, updated)
                updates['approved_at'] = datetime.now(timezone.utc)
            transaction.update(request_ref, updates)
            request.update(updates)
            return request, approved

        request, applied = apply(db.transaction())
        result = {'room_id': room_id, 'date_change_request': request, 'recommendation_needs_refresh': applied}
        if applied:
            return await refresh_recommendation(room_id, uid, result)
        result['recommendation_status'] = ('rejected' if request['status'] == 'rejected' else 'awaiting_votes')
        return result

    @router.get("/rooms/{room_id}/appointment")
    def get_confirmed(room_id: str, user: User):
        room = room_for_member(room_id, user["uid"])
        return {"room_id": room_id, "appointment": room.get("confirmed_appointment")}

    def user_history_entries(uid):
        snapshots = list(db.collection("users").document(uid).collection("appointment_history").limit(500).stream())
        records = [(snap.id, snap.to_dict() or {}) for snap in snapshots]
        # Ignore legacy latest-per-room aliases when their actual event record exists.
        real_record_ids = {key for key, data in records if key != data.get("room_id")}
        alias_status = {key: data.get("status") for key, data in records if key == data.get("room_id")}
        visible = []
        for key, data in records:
            if key == data.get("room_id") and f"{key}__{data.get('appointment_id')}" in real_record_ids:
                continue
            # The latest-per-room alias is marked left on room exit. Apply that
            # to past events too, so the user's calendar hides all exited-room events.
            if alias_status.get(data.get("room_id")) == "left":
                data = {**data, "status": "left"}
            visible.append((key, data))
        return visible

    @router.get("/mypage/appointments")
    def my_appointments(user: User):
        results = [{"history_id": key, **data} for key, data in user_history_entries(user["uid"])]
        results.sort(key=lambda item: item.get("starts_at") or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        return {"appointments": results, "count": len(results)}

    @router.get("/calendar/confirmed-appointments")
    def my_confirmed_calendar(user: User):
        events = []
        for key, data in user_history_entries(user["uid"]):
            if data.get("status") != "active":
                continue
            events.append({
                "id": "meeting:" + key,
                "room_id": data.get("room_id"),
                "appointment_id": data.get("appointment_id"),
                "title": data.get("title") or "약속",
                "starts_at": data.get("starts_at"),
                "ends_at": data.get("ends_at"),
                "location": data.get("location", ""),
                "source": "meeting",
                "version": data.get("appointment_version"),
            })
        return {"events": events}

    return router
