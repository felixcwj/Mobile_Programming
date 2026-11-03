import hashlib
from datetime import datetime, timezone
from typing import Annotated, Literal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from firebase_admin import firestore
from pydantic import BaseModel, Field, model_validator


class EventInput(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    starts_at: datetime
    ends_at: datetime
    location: str = Field(default="", max_length=240)
    memo: str = Field(default="", max_length=2000)
    all_day: bool = False

    @model_validator(mode="after")
    def check_dates(self):
        if self.starts_at.tzinfo is None or self.ends_at.tzinfo is None:
            raise ValueError("일정 시간에는 시간대 정보가 필요합니다.")
        if self.ends_at <= self.starts_at:
            raise ValueError("종료 시간은 시작 시간보다 늦어야 합니다.")
        if not self.title.strip():
            raise ValueError("일정 제목을 입력하세요.")
        self.title = self.title.strip()
        return self


class EventUpdate(EventInput):
    version: int = Field(ge=1)


class CalendarSelection(BaseModel):
    calendar_ids: list[str] = Field(max_length=20)

    @model_validator(mode="after")
    def validate_ids(self):
        if any(not value.strip() or len(value) > 200 for value in self.calendar_ids):
            raise ValueError("캘린더 ID 형식이 올바르지 않습니다.")
        if len(set(self.calendar_ids)) != len(self.calendar_ids):
            raise ValueError("중복된 캘린더 ID가 있습니다.")
        return self


class ExternalChange(BaseModel):
    calendar_id: str = Field(min_length=1, max_length=200)
    external_event_id: str = Field(min_length=1, max_length=300)
    status: Literal["upsert", "deleted"]
    event: EventInput | None = None
    base_version: int | None = Field(default=None, ge=1)

    @model_validator(mode="after")
    def validate_change(self):
        if self.status == "upsert" and self.event is None:
            raise ValueError("upsert에는 event가 필요합니다.")
        return self


class SyncBatch(BaseModel):
    changes: list[ExternalChange] = Field(max_length=100)


class DeleteDecision(BaseModel):
    decision: Literal["delete", "keep"]


def make_calendar_router(db, current_user):
    router = APIRouter(prefix="/calendar", tags=["calendar"])
    User = Annotated[dict, Depends(current_user)]

    def events(uid):
        return db.collection("users").document(uid).collection("calendar_events")

    def read_event(uid, event_id):
        snapshot = events(uid).document(event_id).get()
        if not snapshot.exists:
            raise HTTPException(404, "일정을 찾을 수 없습니다.")
        return snapshot, snapshot.to_dict() or {}

    def public_event(snapshot):
        data = snapshot.to_dict() or {}
        return {"id": snapshot.id, **data}

    def event_fields(body):
        return {
            "title": body.title,
            "starts_at": body.starts_at.astimezone(timezone.utc),
            "ends_at": body.ends_at.astimezone(timezone.utc),
            "location": body.location,
            "memo": body.memo,
            "all_day": body.all_day,
        }

    @router.get("/events")
    def list_events(
        user: User,
        starts_from: datetime = Query(),
        starts_before: datetime = Query(),
    ):
        if starts_from.tzinfo is None or starts_before.tzinfo is None:
            raise HTTPException(422, "조회 날짜에는 시간대 정보가 필요합니다.")
        if starts_before <= starts_from or (starts_before - starts_from).days > 366:
            raise HTTPException(422, "조회 기간은 1년 이내여야 합니다.")
        query = (
            events(user["uid"])
            .where("starts_at", ">=", starts_from.astimezone(timezone.utc))
            .where("starts_at", "<", starts_before.astimezone(timezone.utc))
            .order_by("starts_at")
            .limit(500)
        )
        return {"events": [public_event(s) for s in query.stream() if not (s.to_dict() or {}).get("deleted")], "limit": 500}

    @router.post("/events", status_code=201)
    def create_event(body: EventInput, user: User):
        ref = events(user["uid"]).document(str(uuid4()))
        ref.create({
            **event_fields(body),
            "source": "personal",
            "version": 1,
            "external": None,
            "external_delete_pending": False,
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP,
        })
        return public_event(ref.get())

    @router.get("/events/{event_id}")
    def get_event(event_id: str, user: User):
        snapshot, _ = read_event(user["uid"], event_id)
        return public_event(snapshot)

    @router.put("/events/{event_id}")
    def update_event(event_id: str, body: EventUpdate, user: User):
        ref = events(user["uid"]).document(event_id)

        @firestore.transactional
        def update(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "일정을 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if data.get("source") == "meeting":
                raise HTTPException(403, "약속 방 일정은 방 기능에서 수정해야 합니다.")
            if data.get("version") != body.version:
                raise HTTPException(409, "다른 곳에서 일정이 수정되었습니다. 다시 불러오세요.")
            transaction.update(ref, {
                **event_fields(body),
                "version": body.version + 1,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })

        update(db.transaction())
        return public_event(ref.get())

    @router.delete("/events/{event_id}")
    def delete_event(event_id: str, user: User, version: int = Query(ge=1)):
        ref = events(user["uid"]).document(event_id)

        @firestore.transactional
        def remove(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "일정을 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if data.get("source") == "meeting":
                raise HTTPException(403, "약속 방 일정은 방 기능에서 삭제해야 합니다.")
            if data.get("version") != version:
                raise HTTPException(409, "다른 곳에서 일정이 수정되었습니다. 다시 불러오세요.")
            transaction.set(ref, {
                **data,
                "deleted": True,
                "version": version + 1,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })

        remove(db.transaction())
        return {"deleted": True}

    @router.get("/selected-calendars")
    def get_selected(user: User):
        doc = db.collection("users").document(user["uid"]).collection("calendar_config").document("selection").get()
        return {"calendar_ids": (doc.to_dict() or {}).get("calendar_ids", [])}

    @router.put("/selected-calendars")
    def set_selected(body: CalendarSelection, user: User):
        db.collection("users").document(user["uid"]).collection("calendar_config").document("selection").set({
            "calendar_ids": body.calendar_ids,
            "updated_at": firestore.SERVER_TIMESTAMP,
        })
        return {"calendar_ids": body.calendar_ids}

    @router.post("/sync/external")
    def sync_external(body: SyncBatch, user: User):
        uid = user["uid"]
        selected_ref = db.collection("users").document(uid).collection("calendar_config").document("selection")
        selected = set((selected_ref.get().to_dict() or {}).get("calendar_ids", []))
        results = []
        for change in body.changes:
            if change.calendar_id not in selected:
                results.append({"external_event_id": change.external_event_id, "status": "calendar_not_selected"})
                continue
            link_id = hashlib.sha256((change.calendar_id + "\0" + change.external_event_id).encode()).hexdigest()
            link_ref = db.collection("users").document(uid).collection("external_event_links").document(link_id)
            event_id = link_ref.get().to_dict()
            event_id = event_id.get("event_id") if event_id else None
            if event_id:
                snapshot = events(uid).document(event_id).get()
                data = snapshot.to_dict() if snapshot.exists else None
            else:
                data = None
            if change.status == "deleted":
                if data and not data.get("deleted"):
                    events(uid).document(event_id).update({
                        "external_delete_pending": True,
                        "updated_at": firestore.SERVER_TIMESTAMP,
                    })
                    outcome = "confirmation_required"
                else:
                    outcome = "already_absent"
            elif data and data.get("deleted"):
                outcome = "deleted_locally"
            elif data and data.get("external_delete_pending"):
                outcome = "confirmation_required"
            elif data and change.base_version != data.get("version"):
                outcome = "conflict"
            elif data:
                events(uid).document(event_id).update({
                    **event_fields(change.event),
                    "version": data["version"] + 1,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                })
                outcome = "updated"
            else:
                new_ref = events(uid).document(str(uuid4()))
                new_data = {
                    **event_fields(change.event),
                    "source": "external",
                    "external": {"calendar_id": change.calendar_id, "external_event_id": change.external_event_id},
                    "external_delete_pending": False,
                    "deleted": False,
                    "version": 1,
                    "created_at": firestore.SERVER_TIMESTAMP,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                }

                @firestore.transactional
                def create_linked(transaction):
                    existing = link_ref.get(transaction=transaction)
                    if existing.exists:
                        return existing.to_dict().get("event_id"), False
                    transaction.create(new_ref, new_data)
                    transaction.create(link_ref, {"event_id": new_ref.id})
                    return new_ref.id, True

                event_id, created = create_linked(db.transaction())
                outcome = "created" if created else "already_linked"
            results.append({"external_event_id": change.external_event_id, "event_id": event_id, "status": outcome})
        return {"results": results}

    @router.post("/events/{event_id}/external-delete-decision")
    def external_delete_decision(event_id: str, body: DeleteDecision, user: User):
        ref = events(user["uid"]).document(event_id)

        @firestore.transactional
        def decide(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "일정을 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if not data.get("external_delete_pending"):
                raise HTTPException(409, "삭제 확인 대기 중인 일정이 아닙니다.")
            changes = {
                "external_delete_pending": False,
                "version": data["version"] + 1,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
            if body.decision == "delete":
                changes["deleted"] = True
            else:
                changes["external"] = None
                changes["source"] = "personal"
            transaction.update(ref, changes)
            return data.get("external")

        previous_link = decide(db.transaction())
        if previous_link and body.decision == "keep":
            import hashlib
            link_id = hashlib.sha256((previous_link["calendar_id"] + "\0" + previous_link["external_event_id"]).encode()).hexdigest()
            db.collection("users").document(user["uid"]).collection("external_event_links").document(link_id).delete()
        return {"decision": body.decision, "event_id": event_id}

    return router
