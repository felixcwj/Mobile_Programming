# Plan It — Flutter 프론트엔드 연동 가이드

> 기준: `feature/backend-integration` 브랜치, 2026-11-07. **개발용 API 계약서**입니다. 실제 Firebase·AI·카카오 API 및 실기기 연동 검증 전이며 `main`에 아직 병합하지 않았습니다.

## 0. 가장 먼저 읽어주세요

- **현재 공개된 서버 주소는 없습니다.** GitHub URL은 API 요청 주소가 아닙니다. 서버 담당자가 FastAPI를 실행하고 접근 가능한 **Base URL**을 공유해야 연결할 수 있습니다.
- 로컬 개발 중 FastAPI 실행 예시: `cd backend && python -m uvicorn main:app --reload`; 문서: `http://127.0.0.1:8000/docs`. Python 패키지, Firebase 환경 변수 및 서버용 서비스 계정이 설정되어 있어야 합니다.
- 같은 PC의 Flutter 웹/데스크톱에서 로컬 서버를 호출할 때와 **Android 에뮬레이터, iOS 시뮬레이터, 실제 휴대폰**에서 서버를 호출할 때의 호스트 주소가 다를 수 있습니다. 실제 기기는 같은 네트워크에서 서버 PC의 LAN 주소 등을 사용해야 하며 방화벽·HTTPS 설정을 확인해야 합니다. **서버 비밀키 JSON을 Flutter 코드에 넣지 마세요.**
- 경로에서 `{room_id}`, `{event_id}`, `{decision_id}`는 실제 ID로 바꿉니다. 예: `/rooms/abc123/appointment`.
- 아래 JSON은 입력/출력 **예시**입니다. 실제 Firebase ID, 시각, 장소, 오류 메시지는 달라집니다.

## 1. 로그인과 공통 요청

로그인 외에는 대부분 로그인된 사용자가 필요합니다. `POST /auth/login` 응답의 `access_token`은 **Firebase ID 토큰**이고, 다른 API 요청에 다음 헤더를 첨부합니다.

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

`refresh_token`은 `Authorization` 헤더에 넣지 않습니다. 토큰 만료 시 Firebase Auth SDK 등으로 갱신해야 합니다. 비밀번호·토큰을 일반 로그에 출력하지 않고 안전한 저장 방법을 사용하세요.

### 회원가입 및 로그인

| 동작 | 메서드·경로 | 입력 | 응답의 주요 키 |
| --- | --- | --- | --- |
| 아이디 중복 확인 | GET `/auth/check-id?id=test1234` | query `id` | `id`, `available` |
| 닉네임 중복 확인 | GET `/auth/check-nickname?nickname=플랜잇` | query `nickname` | `nickname`, `available` |
| 회원가입 | POST `/auth/signup` | 아래 JSON | `id`, `message` |
| 로그인 | POST `/auth/login` | `id`, `password` | `access_token`, `refresh_token`, `expires_in`, `uid` |
| 로그인 사용자 확인 | GET `/users/me` | 없음 | `id`, `nickname`, `email`, `name`, `phone` |
| 비밀번호 재확인 | POST `/auth/verify-password` | `password` | `verified` |
| 로그아웃 | POST `/auth/logout` | 없음 | `message` |

회원가입 예시:

```json
{
  "id": "test1234",
  "nickname": "플랜잇",
  "password": "examplePassword123",
  "password_confirm": "examplePassword123",
  "email": "tester@example.com",
  "name": "테스트",
  "phone": "01012345678"
}
```

로그인 예시: `{"id":"test1234","password":"examplePassword123"}`.

회원가입은 아이디 4~12자(영문/숫자/밑줄), 닉네임 2~12자, 비밀번호 8~20자, 한국 휴대전화 형식을 검사합니다. `/auth/logout`은 서버에서 **해당 계정의 리프레시 토큰을 일괄 무효화**하므로 클라이언트에도 저장한 인증 정보를 삭제해야 합니다.

## 2. 마이페이지 화면

| 화면 / 버튼 | 메서드·경로 | 입력 / 주의점 |
| --- | --- | --- |
| 내 정보 보기 | GET `/mypage/profile` | 없음 |
| 닉네임·이름·전화번호 저장 | PUT `/mypage/profile` | `nickname`, `name`, `phone` **세 필드 모두 필수** |
| 나의 기본 성향 불러오기 | GET `/mypage/preferences` | 응답 `{"preferences": {...}}` |
| 나의 기본 성향 저장 | PUT `/mypage/preferences` | 아래 예시. 변경한 키만 보내도 기존 값 유지 |
| 아이디 변경 | PUT `/mypage/id` | `{"new_id":"newid123","password":"현재비밀번호"}` |
| 비밀번호 변경 | POST `/mypage/password` | `current_password`, `new_password`, `new_password_confirm` |
| 탈퇴 신청 상태 | GET `/mypage/deletion` | `status`, `requested_at`, `due_at` |
| 탈퇴 신청 | POST `/mypage/deletion` | `{"password":"현재비밀번호"}` |
| 탈퇴 신청 취소 | DELETE `/mypage/deletion` | 없음 |
| 지금까지 참여한 약속 | GET `/mypage/appointments` | `appointments`, `count` |
| 고객센터 | GET `/mypage/support` | `title`, `enabled`, `email` |
| 개발자 후원 | GET `/mypage/donation` | `title`, `enabled`, `url` |

성향 저장 예시:

```json
{
  "gender": "female",
  "birthday": "2004-12-28",
  "mbti": "INFP",
  "activity_preference": "indoor",
  "alcohol_preference": 1,
  "neighborhood": "서울 동작구",
  "has_car": false
}
```

성향 값 규칙:

- `gender`: `female`, `male`, `other`, `prefer_not_to_say`
- `birthday`: `YYYY-MM-DD`, 미래 날짜 불가
- `mbti`: 16개 표준 MBTI 문자열(대문자) 또는 `unknown`
- `activity_preference`: `indoor` / `outdoor` / `both`
- `alcohol_preference`: 정수 1~5
- `neighborhood`: 최대 60자 문자열
- `has_car`: `true` / `false`

**성향의 목적:** 프로필 표시뿐 아니라 **AI 약속 추천의 개인화 입력**에 일부 사용합니다. 추천에 전달되는 값은 활동 선호, 음주 선호도, 거주 지역, 차량 보유 여부, MBTI이며 성별·생년월일은 외부 AI에 전달하지 않습니다. 사용자가 성향을 입력하지 않아도 추천은 가능한 구조입니다.

고객센터 `enabled: true`인 경우 기기의 이메일 작성기를 열어 `email`로 문의 초안을 작성하게 하세요. **이 API는 메일을 자동 발송하지 않습니다.** 팀 Gmail 주소가 서버의 `SUPPORT_EMAIL`에 설정되기 전까지는 비활성화됩니다. 후원도 `DEVELOPER_DONATION_URL` 설정 전에는 비활성화됩니다.

**아직 API가 없는 UI:** 프로필 이미지 파일 업로드, 자기소개 및 세부 집 주소. 이 버튼은 서버 기능이 준비되기 전까지 저장 성공으로 표시하지 마세요.

## 3. 약속 방·AI 추천 화면

| 화면 / 버튼 | 메서드·경로 | 입력 / 응답 |
| --- | --- | --- |
| 방 만들기 | POST `/rooms` | `{"title":"주말 약속","max_members":3}` → `room_id`, `invite_code` |
| 내 방 목록 | GET `/rooms` | `rooms`, `count` |
| 방 상세 | GET `/rooms/{room_id}` | `member_uids`, `owner_uid`, `members` |
| 초대코드로 참여 | POST `/rooms/join` | `{"invite_code":"ABCDEFGH"}` |
| 내가 입력한 약속 조건 저장 | POST `/rooms/{room_id}/preferences` | 아래 예시 |
| 참가자별 조건 조회 | GET `/rooms/{room_id}/preferences` | `members`, `submitted_count`, `total_members` |
| 만남 위치 방식 변경 | PATCH `/rooms/{room_id}/meeting` | `{"mode":"middle"}` 또는 `{"mode":"fixed","region":"강남역"}`; 방장만 |
| 장소 검색 | GET `/places/search?query=강남역%20카페` | `places`, `count` |
| AI 추천 생성 | POST `/rooms/{room_id}/recommend` | `plan`, `source_revision`, `meeting_area` 등 |
| AI 추천 조회 | GET `/rooms/{room_id}/recommendation` | `plan`, `source_revision`, `is_stale` |
| 방에서 나가기 | DELETE `/rooms/{room_id}/members/me` | `message`, `room_deleted` |
| 방 채팅 보내기 | POST `/rooms/{room_id}/messages` | `{"text":"여기서 만날까요?"}` |
| 방 채팅 읽기 | GET `/rooms/{room_id}/messages?limit=50` | `messages`, `count` |
| 활동 변경 제안 | POST `/rooms/{room_id}/decisions` | 아래 설명 |
| 변경안 동의/거절 | POST `/rooms/{room_id}/decisions/{decision_id}/vote` | `{"approve":true}` 또는 `false` |
| 변경안 목록 | GET `/rooms/{room_id}/decisions` | `decisions` |

약속 조건 저장 예시:

```json
{
  "budget": 30000,
  "region": "서울 강남구",
  "available_date": "2026-11-15",
  "start_time": "12:00",
  "end_time": "17:00",
  "activities": ["카페", "전시"],
  "departure_location": "사당역"
}
```

`POST /rooms/{room_id}/preferences`는 기본적으로 `?regenerate=true`이며 조건 변경 시 AI 추천을 시도합니다. 참가자들이 조건을 모두 제출하지 않았거나 공통 날짜·시간이 맞지 않으면 `recommendation_status: "pending"`과 설명이 돌아올 수 있습니다. **조건 저장 성공과 추천 생성 성공은 별개**입니다. 예산은 **1인 기준 원화 정수**입니다.

변경안 예시:

```json
{
  "mode": "approval",
  "change_type": "replace",
  "from_activity": "카페",
  "to_activity": "전시"
}
```

`mode`는 `instant`(즉시 반영) 또는 `approval`(참여자 투표), `change_type`은 `replace` 또는 `add`입니다. `replace`는 `from_activity`가 필수입니다.

현재 GitHub의 추천 코드는 **OpenRouter**를 사용하며, 카카오맵은 장소 후보 검색용입니다. 프론트엔드에서는 Gemini API나 OpenRouter API의 **비밀키를 직접 다루지 않고** 위의 백엔드 API만 호출합니다.

## 4. 확정 약속·캘린더 화면

**중요: AI 추천만 생성한 상태에서는 확정된 약속이 아닙니다.** 반드시 방장이 확정 버튼을 눌러야 참가자의 확정 일정 목록에 반영됩니다.

| 동작 | 메서드·경로 | 입력 / 결과 |
| --- | --- | --- |
| 추천 확정 | POST `/rooms/{room_id}/appointment/confirm` | `{"recommendation_revision":"..."}`; 추천 조회 응답의 `source_revision` 그대로 사용. 방장만 |
| 확정된 약속 보기 | GET `/rooms/{room_id}/appointment` | `{"room_id":"...","appointment": {...}}` 또는 `appointment: null` |
| 확정 약속 날짜 변경 | PATCH `/rooms/{room_id}/appointment/date` | `{"date":"2026-11-20","version":1}`; 방장만 |
| 캘린더에 확정 약속 표시 | GET `/calendar/confirmed-appointments` | `events`: `id`, `room_id`, `title`, `starts_at`, `ends_at`, `source: "meeting"`, `version` |
| 마이페이지 약속 내역 | GET `/mypage/appointments` | `appointments`, `count`; 나간 방은 `status: "left"`로 보존 |
| 개인 일정 월/기간 조회 | GET `/calendar/events?starts_from=2026-11-01T00:00:00%2B09:00&starts_before=2026-12-01T00:00:00%2B09:00` | `events` |
| 개인 일정 등록 | POST `/calendar/events` | 아래 `EventInput` 예시 |
| 개인 일정 상세 | GET `/calendar/events/{event_id}` | 일정 데이터 |
| 개인 일정 수정 | PUT `/calendar/events/{event_id}` | `EventInput` 전 필드 + `version` |
| 개인 일정 삭제 | DELETE `/calendar/events/{event_id}?version=1` | `deleted: true` |

개인 일정 추가 예시:

```json
{
  "title": "팀 회의",
  "starts_at": "2026-11-15T12:00:00+09:00",
  "ends_at": "2026-11-15T13:00:00+09:00",
  "location": "중앙대학교",
  "memo": "발표 준비",
  "all_day": false
}
```

- **캘린더 화면은 두 API를 함께 조회**해야 합니다. `/calendar/events`는 개인/외부 캘린더에서 동기화된 일정 목록, `/calendar/confirmed-appointments`는 참여 중인 확정 약속 목록입니다. 두 데이터를 화면에서 합쳐 보여주세요.
- `starts_from`과 `starts_before`에는 **시간대가 포함된 ISO 8601** 날짜·시간이 필수입니다. `+`는 URL에서 `%2B`로 인코딩하세요. 최대 조회 범위는 약 1년입니다.
- 확정 약속의 `id`는 `meeting:<room_id>` 형식입니다. **이 ID를 개인 일정 수정/삭제 API에 넣지 마세요.** 확정 약속의 날짜 변경은 `PATCH /rooms/{room_id}/appointment/date`, 나가기는 `DELETE /rooms/{room_id}/members/me`를 사용해야 다른 사람의 약속이 삭제되지 않습니다.
- `version`은 수정 충돌 방지용 숫자입니다. 서버에서 받은 최신 버전을 그대로 보내세요. 이전 버전이면 HTTP 409가 발생하며, 화면에서 다시 조회하도록 안내합니다.
- 날짜 변경 시 기존 AI 추천은 오래된 정보로 표시될 수 있습니다. 바뀐 날짜가 **모든 참가자에게 가능한지 확인하는 UI·동의 규칙은 아직 미완성**이며 현재 서버에서는 방장에게만 변경 권한을 부여합니다.

### 외부 휴대폰 캘린더 동기화 (선택 구현 단계)

서버의 API 경로는 존재하지만 **Flutter 기기의 캘린더 접근 권한과 실제 동기화 코드는 아직 구현되지 않았습니다.**

| 동작 | 메서드·경로 |
| --- | --- |
| 선택된 기기 캘린더 조회 | GET `/calendar/selected-calendars?device_id=iphone1` |
| 동기화할 캘린더 선택 | PUT `/calendar/selected-calendars` (`device_id`, `calendar_ids`) |
| 외부 변경사항 서버 반영 | POST `/calendar/sync/external` (`device_id`, `changes`) |
| 서버 변경사항 조회 | GET `/calendar/sync/changes?updated_since=2026-11-01T00:00:00%2B09:00` |
| 외부 일정과 연결 | POST `/calendar/events/{event_id}/external-link` |
| 외부에서 삭제된 일정 확인 대기 | GET `/calendar/pending-deletions` |
| 삭제 또는 보존 결정 | POST `/calendar/events/{event_id}/external-delete-decision` |

스키마 상세는 `backend/CALENDAR_API.md`(별도 `feature/calendar-backend` 브랜치 원본 문서) 또는 실행 중인 서버의 `/docs`에서 확인하세요. 기기 캘린더의 변경을 앱이 자동 감지·동기화한다고 가정하지 마세요.

## 5. 공통 응답 처리 및 자주 발생하는 오류

FastAPI는 대체로 JSON을 반환하며, 실패 시 `{"detail":"오류 내용"}` 또는 `detail`에 객체를 반환할 수 있습니다. 화면에 `detail` 객체 전체를 그대로 출력하지 말고 안내 문구로 변환하세요.

| HTTP 코드 | 의미 | 프론트엔드 동작 |
| --- | --- | --- |
| 200 / 201 | 성공 / 생성됨 | 새 데이터 렌더링 |
| 401 | 로그인 없거나 토큰 만료·비밀번호 오류 | 인증 상태 확인, 재로그인/갱신 |
| 403 | 방 비참여자·권한 부족 | 수정 버튼 숨김 또는 권한 안내 |
| 404 | 방·일정·추천 없음 | 빈 화면 또는 오류 안내 |
| 409 | 최신 버전 충돌, 미확정, 조건 미완료 | 재조회 후 필요 시 다시 입력 |
| 422 | 입력값 형식 오류 | 필수값·날짜·시간대 검사 |
| 429 / 502 / 503 / 504 | 추천 한도·외부 서비스·서버 문제 | 무한 재시도 금지, 오류 안내 및 재시도 버튼 |

주의: 백엔드가 반환하는 `datetime`은 ISO 8601 문자열로 표현되며 `+00:00` 등 표기가 포함될 수 있습니다. 화면에서는 KST로 변환해 표시하세요.

## 6. 프론트엔드 연결 순서 (추천)

1. 로그인 후 `access_token`을 각 요청의 `Authorization` 헤더에 넣기
2. 마이페이지 `GET/PUT /mypage/profile` 및 `GET/PUT /mypage/preferences`
3. 방 만들기·초대 참여·약속 조건 저장·추천 조회
4. 추천 확정 버튼 → `POST /rooms/{room_id}/appointment/confirm`
5. 캘린더 `/calendar/events`와 `/calendar/confirmed-appointments`를 함께 표시
6. 개인 일정 수정/삭제와 방장 날짜 변경, 다른 사용자는 본인만 방 나가기
7. 마이페이지 약속 내역, 고객센터, 후원 버튼
8. 실제 Android/iOS 기기와 Firebase 연결·권한·오류 처리 검증

## 7. 아직 결정·구현이 필요한 부분

- 서버 Base URL/실행 및 배포 환경
- **추천 확정·날짜 변경 권한**: 현재 방장만 가능하게 구현한 잠정 정책, 다른 참가자의 동의 규칙은 팀 논의 필요
- 과거 약속 보관 방식: 현재 **방 하나당 최신 확정 약속 한 건** 기록, 같은 방에서 여러 번 약속 시 추가 설계 필요
- 확정 날짜 변경 후 모든 참가자의 가능 날짜 재검증과 AI 코스 재추천
- 프로필 사진, 자기소개, 상세주소의 저장 API와 실제 스토리지
- 팀 Gmail 주소 `SUPPORT_EMAIL`, 후원 URL `DEVELOPER_DONATION_URL` 설정
- 외부 캘린더 실기기 연동, Firebase 실환경 및 AI·카카오 외부 호출 검증
- 외부 호출 비용 및 무료 이용량 확인

**이 문서는 동작 보증서가 아니라 현재 코드에 구현된 API를 연결하기 위한 계약서입니다.** 실제 연결 중 발견되는 오류와 미결정 요구사항은 백엔드 담당자에게 전달해 주세요.
