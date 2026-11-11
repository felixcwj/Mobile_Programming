# 플랜잇 Firebase 백엔드 (FastAPI)

## Firebase 콘솔 준비
1. https://console.firebase.google.com/ 새 프로젝트 만들기
2. 빌드 > Authentication > 시작하기 > 로그인 방법 > **이메일/비밀번호** 활성화
3. 빌드 > Firestore Database > 데이터베이스 만들기 (프로젝트에 맞는 위치 선택)
4. 프로젝트 설정 > 일반 > 앱 추가(웹 `</>`) > 앱 등록 > `apiKey` 복사
5. 프로젝트 설정 > 서비스 계정 > 새 비공개 키 생성 -> JSON 파일을 `serviceAccountKey.json`으로 저장
   - 비공개 키는 팀 채팅/GitHub에 절대 올리지 않기

## 실행
```bash
python -m pip install -r requirements.txt
cp .env.example .env
```
`.env`의 FIREBASE_WEB_API_KEY를 실제 키로 바꾸고 서비스 계정 JSON을 프로젝트 폴더에 저장한 다음:
```bash
python -m uvicorn main:app --reload
```
http://127.0.0.1:8000/docs

## API
- `GET /auth/check-id?id=test1234` 아이디 중복 확인
- `POST /auth/signup` 회원가입. 입력: `id`, `nickname`, `password`, `password_confirm`, `email`, `name`, `phone`
- `POST /auth/login` 아이디/비밀번호 로그인. 입력: `id`, `password`. 출력: `access_token`(Firebase ID 토큰), `refresh_token`, `expires_in` 등
- `GET /users/me` 내 프로필 (Bearer 토큰 필수)
- `POST /auth/verify-password` 현재 비밀번호 재확인 (Bearer 토큰 필수)
- `POST /auth/logout` 리프레시 토큰 무효화 (모든 기기에서 세션 갱신 불가)

Swagger Authorize: **access_token만** 입력 (`Bearer ` 접두어 불필요).

로그인 access_token은 약 1시간 후 만료됩니다. 모바일 앱에서는 Firebase Auth SDK를 통해 토큰을 자동 갱신하거나, Firebase Secure Token API를 사용해 갱신하도록 별도 구현해야 합니다. 앱에 토큰을 안전하게 저장하고 로그아웃 시 삭제하세요.

## 설계 및 주의사항
- Firebase Authentication UID와 앱 로그인 아이디는 구분합니다. 로그인 아이디 변경 시 `usernames` 매핑만 바꾸고 UID는 유지합니다.
- 이메일/비밀번호 인증은 Firebase Authentication, 나머지 사용자 정보는 Firestore `users/{uid}`에 저장.
- 기존 SQLite `mannaja.db`는 **자동 이전되지 않음**. Firebase로 새로 회원가입하거나 추후 마이그레이션해야 함.
- 기존 SQLite에서 발급된 토큰도 Firebase에서 인정되지 않음.
- 관리자 서비스 계정은 서버에만 보관. Flutter 앱에는 절대 포함하지 말 것.
- 웹 API 키는 클라이언트 식별용이며, 서비스 계정 키와 달리 비밀 관리자 자격 증명이 아님.
- 개발용 예시. 공개 서비스 전 레이트 리밋, 이메일 인증, 개인정보 처리/보존 정책, Firestore 보안 규칙, CORS 설정, 로그/모니터링 필요.
- Firebase Auth 및 Firestore 무료 제공량과 과금 조건은 프로젝트/설정에 따라 달라질 수 있으니 콘솔에서 확인.

## 방 생성 및 확정 약속 날짜 변경 (2026-11-11)
- 방 초대 코드는 정확히 7자리입니다. 기존 8자리 코드는 더 이상 참여 요청에 사용할 수 없으므로, 기존 방은 `migrate_invite_codes.py`로 초대 코드를 변경해야 합니다.
- `POST /rooms`의 `max_members`는 2~8명이며 실제 방 참여 제한에 반영됩니다. 기존 방에 정원 설정이 없으면 8명으로 간주합니다.
- `GET /rooms/{room_id}/appointment/date-availability?date=2026-11-20`은 저장된 참가자별 가능 날짜와 새 날짜의 일치 여부를 알려줍니다.
- `PATCH /rooms/{room_id}/appointment/date?require_all_available=true`를 선택하면 전원 가능 날짜가 맞는 경우에만 변경됩니다. 기본값은 이전 버전과 동일하게 비강제입니다.
- **가능 날짜 일치 ≠ 전원의 날짜 변경 동의**입니다. 동의/투표는 API에 구현되어 있지만 실 Firebase 연동 검증 및 날짜 변경 후 코스 자동 재추천은 아직 남아 있습니다.

Flutter 연결 시에는 `FLUTTER_API_GUIDE.md`를 참조하세요.

## 업데이트: 채팅 제거, 수정 권한, 기타 사항, 초대 코드 (2026-11-11)
- 채팅 메시지 API(`GET/POST /rooms/{room_id}/messages`) 제거. 기존 Firestore에 남아 있는 채팅 데이터는 자동 삭제하지 않습니다.
- 초대 코드는 **영문 대문자·숫자·`#@!` 가운데 각 분류 최소 하나를 포함한 총 7자리**입니다. 예: `AB2#C@!`. 8자리 코드는 거부하며, 기존 8자리 방 초대 코드는 별도 마이그레이션이 필요합니다. `#`가 들어간 코드는 URL 경로가 아니라 `POST /rooms/join`의 JSON 본문에 전달해야 합니다.
- 첫 개인 조건 입력은 바로 저장되며, 이미 저장된 개인 조건을 **방장**이 수정하면 즉시 반영, **일반 참여자**가 수정하면 `shared_decisions` 승인 투표를 거칩니다.
- 활동/만남 지역 수정: 방장 즉시 반영, 일반 참여자 전원 동의 후 반영. 1명이라도 거절하면 기각됩니다.
- 확정 약속 날짜/기타 사항 수정: 방장 `PATCH /rooms/{room_id}/appointment/date`로 즉시 반영, 일반 참여자는 변경안을 생성하며 `/appointment/date-requests/{request_id}/vote`에서 전원 찬성한 경우에만 반영됩니다.
- 개인 조건의 `additional_notes`, 활동 변경 결정의 `additional_notes`, 확정 일정의 `additional_notes`는 **최대 1000자** 자유 텍스트이며 AI 추천 요청에 포함됩니다. 추천 과정에서 참고되지만, 공통 시간/예산/실제 장소 조건과 충돌 시 모두 적용되지는 않을 수 있습니다.
- Firebase/OpenRouter/Kakao 실계정 연동 테스트는 별도로 진행해야 합니다.

## 2026-11-11 추가 점검: 복수 약속 이력 및 엄격한 초대 코드
- `POST /rooms/join`은 `#@!` 또는 영문·숫자로 구성된 **정확히 7자리** 초대 코드만 받습니다. 신규 생성은 영문·숫자·특수문자를 각 최소 1개 포함합니다.
- **기존 Firestore에 저장된 8자리 코드는 자동 변경되지 않습니다.** `migrate_invite_codes.py`로 드라이런을 먼저 실행하고, 실제 코드 변경은 운영 담당자가 승인해 수행하세요. 기존 초대 코드를 알고 있는 사람에게 새로운 코드 전달이 필요합니다.
- 같은 방에서 서로 다른 약속을 여러 번 확정하면 고유 `appointment_id`를 부여하고 `appointment_history/{room_id}__{appointment_id}`에 누적 기록합니다. 기존 `appointment_history/{room_id}`는 최신 약속에 대한 호환성 별칭으로 유지하며, 목록 API는 중복을 제거합니다. 날짜 수정은 해당 약속 이력만 갱신합니다.
- `GET /mypage/appointments`, `GET /calendar/confirmed-appointments`는 같은 방의 다수 기록을 반환할 수 있습니다. `calendar` 이벤트의 `id`가 `meeting:{room_id}__{appointment_id}` 형식일 수 있으므로 방 하나당 이벤트 하나라고 가정하지 마세요.
- 실제 Firebase/OpenRouter/Kakao 및 기기 캘린더 API 호출은 운영 자격 증명과 실기기 없이 검증하지 못했습니다.
- 탈퇴 후 삭제 스크립트 `account_cleanup.py`는 존재하지만 **정기 실행 스케줄이 자동으로 생성되지는 않습니다**. 운영 서버의 스케줄러/Cloud Scheduler 등에 별도로 작업 등록 및 모니터링이 필요합니다.
