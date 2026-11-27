# Plan It 백엔드 개선 내용 (2026-11-11)

기존 `feature/backend-integration`을 기반으로 합니다. 공식 GitHub 원격 저장소에는 **아직 Push하지 않았습니다.**

## 변경 사항

1. 새 방 초대 코드 8자리 → **7자리**. 기존 8자리 코드로 참여하는 기능은 유지.
2. 방 생성 시 `max_members`를 Firestore에 저장하고, 입장 시 **방별 정원(최대 8명)**을 검사. 기존 방에 정원이 없으면 8명으로 간주.
3. `GET /rooms/{room_id}/appointment/date-availability?date=YYYY-MM-DD` 추가: `available` / `different_date` / `missing`을 반환.
4. `PATCH /rooms/{room_id}/appointment/date?require_all_available=true` 선택적 제한 추가. 저장된 가능 날짜가 모두 일치하지 않으면 409. 기본값은 이전 동작과 호환.
5. 날짜를 실제로 바꾸지 않는 요청은 추천을 재생성해야 한다는 신호를 반환하지 않도록 수정.
6. 백엔드 API 문서 갱신 및 예시 API 키를 placeholder로 대체.

## 검증

- Python 문법 검사(`compileall`) 통과.
- Firebase Admin이 현 실행 환경에 설치되지 않아 **Firebase/외부 서비스 실제 호출 테스트는 미수행**.
- Firebase를 모의 객체로 대체한 단위/라우트 테스트 **60개 통과** (`backend/tests/`).

## 실행 및 GitHub 반영

1. 기존 폴더를 백업해 두고 수정본의 `backend/` 하위 파일을 로컬 Git 작업 폴더에 복사.
2. `cd backend && python -m pip install -r requirements.txt`.
3. `.env`와 Firebase 서비스 계정을 본인 환경에 맞게 설정. `.env.example`은 예시일 뿐 실제 키를 포함하지 않음.
4. `python -m uvicorn main:app --reload` 및 `/docs` 확인.
5. Git 작업 폴더에서 `git status`로 변경사항을 확인하고 `git add -A backend/ && git commit -m "Fix room limits and date availability" && git push -u origin HEAD`.

## 남은 작업

- 전체 동의/투표 규칙의 팀 확정 및 구현
- 같은 방의 여러 약속 이력 누적 구조
- 기기 캘린더 동기화 및 실기기 Firebase/OpenRouter/카카오 연동 검증
- 탈퇴 후 자동 삭제 작업의 운영 스케줄 설정

## 후속 변경: 권한·기타 사항·특수문자 코드
- 신규 초대 코드: 영문 대문자 + 숫자 + `#@!` 특수문자 포함 정확히 7글자. 이전 영숫자 코드의 기존 방 참여는 유지.
- `backend/main.py`에서 채팅 라우트 제거.
- 개인 선호 추가 입력 필드: `additional_notes`(최대 1000자). AI 추천 제약과 revision hash에 포함.
- 방장의 기존 개인 조건 수정/활동·만남 지역 결정: 즉시 반영. 일반 참가자의 기존 조건 수정/활동·만남 지역 변경: `shared_decisions`에 제안 등록 후 전원 동의로 반영, 거절 시 미적용.
- 확정 약속 날짜 및 기타 사항 변경: 방장은 즉시 반영, 일반 참가자는 `date_change_requests`에 대기 상태로 생성. `GET /rooms/{room_id}/appointment/date-requests` 조회, `POST /rooms/{room_id}/appointment/date-requests/{request_id}/vote`로 찬반 투표. 전원 찬성 시 원자적으로 약속/참가자 이력 갱신. 수정 후 AI 재추천 필요.
- 동의 완료는 즉시 모델 재추천을 *시도*하지만 외부 API 연결/장소 검색에 실패하면 `recommendation_status`에 실패 또는 대기를 반환할 수 있음.
- 주의: 현재 저장된 첫 선호는 즉시 입력 가능, 일반 참가자의 **재수정부터** 전원 동의를 받음. Firestore 기보유 채팅 데이터는 삭제하지 않음.
