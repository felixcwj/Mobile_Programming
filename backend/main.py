"""Plan It Firebase-backed authentication API."""
import os
import hashlib
import unicodedata
import re
from datetime import datetime, timezone
from typing import Annotated

import firebase_admin
import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, credentials, firestore
from google.api_core.exceptions import AlreadyExists
from pydantic import BaseModel, Field, EmailStr, model_validator

load_dotenv()

API_KEY = os.getenv("FIREBASE_WEB_API_KEY", "").strip()
SERVICE_ACCOUNT = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "serviceAccountKey.json")
if not API_KEY:
    raise RuntimeError(".env 파일에 FIREBASE_WEB_API_KEY를 설정하세요.")
if not os.path.isfile(SERVICE_ACCOUNT):
    raise RuntimeError(f"Firebase 서비스 계정 파일을 찾을 수 없습니다: {SERVICE_ACCOUNT}")

firebase_admin.initialize_app(credentials.Certificate(SERVICE_ACCOUNT))
db = firestore.client()
app = FastAPI(title="Plan It Firebase 인증 API", version="2.1.0")
security = HTTPBearer(auto_error=False)


class SignupRequest(BaseModel):
    id: str = Field(min_length=4, max_length=12, pattern=r"^[A-Za-z0-9_]+$")
    nickname: str = Field(min_length=2, max_length=12)
    password: str = Field(min_length=8, max_length=20)
    password_confirm: str
    email: EmailStr
    name: str = Field(min_length=1, max_length=50)
    phone: str = Field(min_length=10, max_length=20)

    @model_validator(mode="after")
    def check(self):
        if self.nickname != self.nickname.strip():
            raise ValueError("닉네임 앞뒤에 공백을 사용할 수 없습니다.")
        if self.password != self.password_confirm:
            raise ValueError("비밀번호가 일치하지 않습니다.")
        if not re.fullmatch(r"01[016789]\d{7,8}", self.phone.replace("-", "")):
            raise ValueError("전화번호 형식이 올바르지 않습니다.")
        return self


def normalized_id(value: str) -> str:
    """Keep Firebase Auth UID case-insensitive for newly created accounts."""
    return value.lower()


def nickname_key(value: str) -> str:
    """Stable Firestore document ID for case-insensitive nickname uniqueness."""
    normalized = unicodedata.normalize("NFKC", value).casefold()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


@firestore.transactional
def store_profile_with_nickname(transaction, nickname_ref, profile_ref, profile_data):
    if nickname_ref.get(transaction=transaction).exists:
        raise HTTPException(409, "이미 사용 중인 닉네임입니다.")
    transaction.create(nickname_ref, {"uid": profile_ref.id, "nickname": profile_data["nickname"]})
    transaction.set(profile_ref, profile_data)


class LoginRequest(BaseModel):
    id: str
    password: str


class PasswordRequest(BaseModel):
    password: str


async def firebase_password_login(email: str, password: str) -> dict:
    """Firebase Auth public REST API: verify password and return ID/refresh tokens."""
    url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.post(
                url,
                params={"key": API_KEY},
                json={"email": email, "password": password, "returnSecureToken": True},
            )
    except httpx.RequestError:
        raise HTTPException(503, "Firebase 인증 서버에 연결할 수 없습니다.")
    if response.status_code != 200:
        # Don't leak whether account, email, or password is correct.
        if response.status_code in (400, 401):
            raise HTTPException(401, "아이디 또는 비밀번호가 일치하지 않습니다.")
        raise HTTPException(502, "Firebase 인증 요청에 실패했습니다.")
    return response.json()


def current_user(
    authorization: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
) -> dict:
    if authorization is None or authorization.scheme.lower() != "bearer":
        raise HTTPException(401, "로그인이 필요합니다.")
    try:
        return auth.verify_id_token(authorization.credentials, check_revoked=True)
    except Exception:
        raise HTTPException(401, "로그인 인증이 만료되었거나 올바르지 않습니다.")


@app.get("/health")
def health():
    return {"status": "ok", "database": "firebase"}


@app.get("/auth/check-id")
def check_id(id: str = Query(min_length=4, max_length=12, pattern=r"^[A-Za-z0-9_]+$")):
    normalized = normalized_id(id)
    try:
        auth.get_user(normalized)
        return {"id": normalized, "available": False}
    except auth.UserNotFoundError:
        return {"id": normalized, "available": True}
    except Exception:
        raise HTTPException(503, "아이디 중복 확인에 실패했습니다.")


@app.get("/auth/check-nickname")
def check_nickname(nickname: str = Query(min_length=2, max_length=12)):
    if nickname != nickname.strip():
        raise HTTPException(422, "닉네임 앞뒤에 공백을 사용할 수 없습니다.")
    try:
        available = not db.collection("nickname_reservations").document(nickname_key(nickname)).get().exists
        return {"nickname": nickname, "available": available}
    except Exception:
        raise HTTPException(503, "닉네임 중복 확인에 실패했습니다.")


@app.post("/auth/signup", status_code=status.HTTP_201_CREATED)
def signup(body: SignupRequest):
    uid = normalized_id(body.id)
    try:
        account = auth.create_user(
            uid=uid,
            email=str(body.email),
            password=body.password,
            display_name=body.nickname,
        )
    except auth.UidAlreadyExistsError:
        raise HTTPException(409, "이미 사용 중인 아이디입니다.")
    except auth.EmailAlreadyExistsError:
        raise HTTPException(409, "이미 가입된 이메일입니다.")
    except Exception:
        raise HTTPException(503, "Firebase 회원가입에 실패했습니다. 설정을 확인하세요.")

    nickname_ref = db.collection("nickname_reservations").document(nickname_key(body.nickname))
    profile_ref = db.collection("users").document(account.uid)
    profile_data = {
        "id": account.uid,
        "nickname": body.nickname,
        "nickname_key": nickname_key(body.nickname),
        "email": str(body.email),
        "name": body.name,
        "phone": body.phone,
        "created_at": datetime.now(timezone.utc),
    }
    try:
        transaction = db.transaction()
        store_profile_with_nickname(transaction, nickname_ref, profile_ref, profile_data)
    except Exception as exc:
        # If Firestore fails, clean up the newly created Authentication account.
        try:
            auth.delete_user(account.uid)
        except Exception:
            pass
        if isinstance(exc, HTTPException):
            raise exc
        if isinstance(exc, AlreadyExists):
            raise HTTPException(409, "이미 사용 중인 닉네임입니다.")
        raise HTTPException(503, "프로필 저장에 실패했습니다. Firebase 설정을 확인하세요.")

    return {"message": "회원가입이 완료되었습니다.", "id": account.uid}


@app.post("/auth/login")
async def login(body: LoginRequest):
    try:
        account = auth.get_user(normalized_id(body.id))
    except auth.UserNotFoundError:
        raise HTTPException(401, "아이디 또는 비밀번호가 일치하지 않습니다.")
    except Exception:
        raise HTTPException(503, "Firebase 계정 조회에 실패했습니다.")
    if not account.email or account.disabled:
        raise HTTPException(401, "아이디 또는 비밀번호가 일치하지 않습니다.")
    result = await firebase_password_login(account.email, body.password)
    return {
        "access_token": result["idToken"],
        "token_type": "bearer",
        "expires_in": int(result["expiresIn"]),
        "refresh_token": result["refreshToken"],
        "uid": result["localId"],
    }


@app.get("/users/me")
def my_profile(user: Annotated[dict, Depends(current_user)]):
    snapshot = db.collection("users").document(user["uid"]).get()
    if not snapshot.exists:
        raise HTTPException(404, "프로필 정보를 찾을 수 없습니다.")
    data = snapshot.to_dict() or {}
    return {k: data.get(k) for k in ("id", "nickname", "email", "name", "phone")}


@app.post("/auth/verify-password")
async def verify_password(body: PasswordRequest, user: Annotated[dict, Depends(current_user)]):
    try:
        account = auth.get_user(user["uid"])
    except Exception:
        raise HTTPException(401, "사용자 정보를 확인할 수 없습니다.")
    if not account.email:
        raise HTTPException(400, "비밀번호 인증을 사용할 수 없는 계정입니다.")
    await firebase_password_login(account.email, body.password)
    return {"verified": True}


@app.post("/auth/logout")
def logout(user: Annotated[dict, Depends(current_user)]):
    # Revokes all refresh tokens for this user, including other logged-in devices.
    try:
        auth.revoke_refresh_tokens(user["uid"])
    except Exception:
        raise HTTPException(503, "로그아웃 처리에 실패했습니다.")
    return {"message": "로그아웃되었습니다. 앱에서도 보관 중인 토큰을 삭제하세요."}
