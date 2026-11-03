import os
import re
from urllib.parse import urlsplit
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import auth, firestore
from pydantic import BaseModel, Field, model_validator


class ProfileEdit(BaseModel):
    nickname: str = Field(min_length=2, max_length=12)
    name: str = Field(min_length=1, max_length=50)
    phone: str = Field(min_length=10, max_length=20)

    @model_validator(mode="after")
    def check(self):
        if self.nickname != self.nickname.strip() or not self.name.strip():
            raise ValueError("닉네임이나 이름 앞뒤에 불필요한 공백을 사용할 수 없습니다.")
        if not re.fullmatch(r"01[016789]\d{7,8}", self.phone.replace("-", "")):
            raise ValueError("전화번호 형식이 올바르지 않습니다.")
        return self


class PasswordChange(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=20)
    new_password_confirm: str

    @model_validator(mode="after")
    def check(self):
        if self.new_password != self.new_password_confirm:
            raise ValueError("새 비밀번호 확인이 일치하지 않습니다.")
        if self.new_password == self.current_password:
            raise ValueError("기존 비밀번호와 다른 비밀번호를 사용하세요.")
        return self


class DeletionRequest(BaseModel):
    password: str = Field(min_length=1)

class UsernameChange(BaseModel):
    new_id: str = Field(min_length=4, max_length=12, pattern=r"^[A-Za-z0-9_]+$")
    password: str = Field(min_length=1)


def make_mypage_router(db, current_user, nickname_key, password_login):
    router = APIRouter(prefix="/mypage", tags=["mypage"])
    User = Annotated[dict, Depends(current_user)]

    def profile_ref(uid):
        return db.collection("users").document(uid)

    def profile(uid):
        snapshot = profile_ref(uid).get()
        if not snapshot.exists:
            raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
        return snapshot.to_dict() or {}

    def present(data):
        keys = ("id", "nickname", "email", "name", "phone", "deletion_requested_at", "deletion_due_at")
        return {key: data.get(key) for key in keys}

    async def reauthenticate(uid, password):
        try:
            account = auth.get_user(uid)
        except Exception:
            raise HTTPException(503, "사용자 인증 정보를 조회할 수 없습니다.")
        if account.disabled or not account.email:
            raise HTTPException(403, "비밀번호 인증을 사용할 수 없는 계정입니다.")
        await password_login(account.email, password)
        return account

    @router.get("/donation")
    def get_donation(user: User):
        configured_url = os.getenv("DEVELOPER_DONATION_URL", "").strip()
        safe_url = None
        if configured_url:
            try:
                parsed = urlsplit(configured_url)
                if (
                    parsed.scheme == "https"
                    and parsed.hostname
                    and not parsed.username
                    and not parsed.password
                    and not any(char.isspace() for char in configured_url)
                ):
                    safe_url = configured_url
            except ValueError:
                pass
        return {
            "title": "개발자에게 후원하기",
            "enabled": bool(safe_url),
            "url": safe_url,
        }

    @router.get("/profile")
    def get_profile(user: User):
        return present(profile(user["uid"]))

    @router.put("/profile")
    def edit_profile(body: ProfileEdit, user: User):
        uid = user["uid"]
        ref = profile_ref(uid)
        new_nickname_key = nickname_key(body.nickname)

        @firestore.transactional
        def change(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if data.get("deletion_requested_at"):
                raise HTTPException(409, "탈퇴 신청을 취소한 후 수정하세요.")
            old_key = data.get("nickname_key") or nickname_key(data.get("nickname", ""))
            new_ref = db.collection("nickname_reservations").document(new_nickname_key)
            old_ref = db.collection("nickname_reservations").document(old_key)
            old_owned = False
            if old_key != new_nickname_key:
                reservation = new_ref.get(transaction=transaction)
                if reservation.exists and (reservation.to_dict() or {}).get("uid") != uid:
                    raise HTTPException(409, "이미 사용 중인 닉네임입니다.")
                old_reservation = old_ref.get(transaction=transaction)
                old_owned = old_reservation.exists and (old_reservation.to_dict() or {}).get("uid") == uid
            transaction.update(ref, {
                "nickname": body.nickname,
                "nickname_key": new_nickname_key,
                "name": body.name.strip(),
                "phone": body.phone.replace("-", ""),
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            if old_key != new_nickname_key:
                transaction.set(new_ref, {"uid": uid, "nickname": body.nickname})
                if old_owned:
                    transaction.delete(old_ref)
            return old_key != new_nickname_key

        nickname_changed = change(db.transaction())
        if nickname_changed:
            try:
                auth.update_user(uid, display_name=body.nickname)
            except Exception:
                pass
        return present(profile(uid))

    @router.put("/id")
    async def change_login_id(body: UsernameChange, user: User):
        uid = user["uid"]
        new_id = body.new_id.lower()
        await reauthenticate(uid, body.password)
        try:
            auth.get_user(new_id)
        except auth.UserNotFoundError:
            pass
        except Exception:
            raise HTTPException(503, "아이디 중복 확인에 실패했습니다.")
        else:
            if new_id != uid:
                raise HTTPException(409, "이미 사용 중인 아이디입니다.")

        ref = profile_ref(uid)
        username_ref = db.collection("usernames").document(new_id)

        @firestore.transactional
        def reserve(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if data.get("deletion_requested_at"):
                raise HTTPException(409, "탈퇴 신청을 취소한 후 변경하세요.")
            previous = str(data.get("id") or uid).lower()
            if previous == new_id:
                return False
            existing = username_ref.get(transaction=transaction)
            if existing.exists and (existing.to_dict() or {}).get("uid") != uid:
                raise HTTPException(409, "이미 사용 중인 아이디입니다.")
            old_ref = db.collection("usernames").document(previous)
            old_doc = old_ref.get(transaction=transaction)
            transaction.set(username_ref, {"uid": uid})
            transaction.update(ref, {
                "id": new_id,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            if old_doc.exists and (old_doc.to_dict() or {}).get("uid") == uid:
                transaction.delete(old_ref)
            return True

        changed = reserve(db.transaction())
        return {"id": new_id, "changed": changed, "message": "로그인 아이디가 변경되었습니다."}

    @router.post("/password")
    async def change_password(body: PasswordChange, user: User):
        uid = user["uid"]
        if profile(uid).get("deletion_requested_at"):
            raise HTTPException(409, "탈퇴 신청을 취소한 후 변경하세요.")
        await reauthenticate(uid, body.current_password)
        try:
            auth.update_user(uid, password=body.new_password)
            auth.revoke_refresh_tokens(uid)
        except Exception:
            raise HTTPException(503, "비밀번호를 변경하지 못했습니다.")
        return {"changed": True, "message": "비밀번호를 변경했습니다. 다시 로그인하세요."}

    @router.get("/deletion")
    def get_deletion(user: User):
        data = profile(user["uid"])
        return {
            "requested_at": data.get("deletion_requested_at"),
            "due_at": data.get("deletion_due_at"),
            "status": "pending" if data.get("deletion_requested_at") else "none",
        }

    @router.post("/deletion")
    async def request_deletion(body: DeletionRequest, user: User):
        uid = user["uid"]
        await reauthenticate(uid, body.password)
        ref = profile_ref(uid)
        now = datetime.now(timezone.utc)
        due = now + timedelta(days=30)

        @firestore.transactional
        def apply(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if data.get("deletion_requested_at"):
                raise HTTPException(409, "이미 탈퇴 신청이 접수되었습니다.")
            transaction.update(ref, {
                "deletion_requested_at": now,
                "deletion_due_at": due,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })

        apply(db.transaction())
        return {
            "status": "pending",
            "requested_at": now,
            "due_at": due,
            "message": "탈퇴 신청을 접수했습니다. 30일 이내 취소할 수 있습니다.",
        }

    @router.delete("/deletion")
    def cancel_deletion(user: User):
        uid = user["uid"]
        ref = profile_ref(uid)

        @firestore.transactional
        def apply(transaction):
            snapshot = ref.get(transaction=transaction)
            if not snapshot.exists:
                raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
            data = snapshot.to_dict() or {}
            if not data.get("deletion_requested_at"):
                raise HTTPException(409, "진행 중인 탈퇴 신청이 없습니다.")
            due = data.get("deletion_due_at")
            if due is not None and datetime.now(timezone.utc) >= due:
                raise HTTPException(409, "탈퇴 취소 가능 기간이 지났습니다.")
            transaction.update(ref, {
                "deletion_requested_at": firestore.DELETE_FIELD,
                "deletion_due_at": firestore.DELETE_FIELD,
                "updated_at": firestore.SERVER_TIMESTAMP,
            })

        apply(db.transaction())
        return {"status": "cancelled"}

    return router
