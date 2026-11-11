# Plan It 백엔드 코드 점검 및 수정 (2026-11-11)

이 ZIP은 기존 `feature/backend-integration`을 기준으로 **수정하거나 추가한 백엔드 파일만** 담습니다. 원격 저장소에는 Push하지 않았습니다.

## 이번 점검 및 수정

1. `POST /rooms/join`의 8자리 레거시 입력 허용 제거: **정확히 7자리**만 허용. 신규 생성은 영문·숫자·`#@!` 중 각 유형이 최소 하나 포함됩니다.
2. 기존 8자리 초대 코드의 안전한 전환을 위한 `backend/migrate_invite_codes.py` 추가. **실제 Firebase 데이터는 건드리지 않았습니다.** 운영 담당자가 드라이런 결과를 확인한 뒤 별도로 실행해야 합니다.
3. 채팅: `main.py` 및 API 라우터에 `/rooms/{room_id}/messages`가 없는 것을 확인. 과거 Firestore 채팅 문서는 자동으로 삭제되지 않습니다.
4. 방장 즉시 수정, 참여자 전원 동의 후 수정: 개인 조건·활동·만남 지역·확정된 약속 날짜 API 처리와 승인/거절 흐름 확인.
5. 개인/약속 기타 입력: `additional_notes`가 AI 추천 제약 및 소스 변경 감지에 포함되는 것을 확인.
6. **같은 방의 여러 약속 이력 누적**: 별도 `appointment_id`별 기록을 작성하고, 최신 기록 경로는 이전 클라이언트 호환용으로 유지. 약속 날짜를 변경해도 이전 약속은 덮어쓰지 않음. 기존 구형 확정 약속도 다음 확정 시 보존 처리.
7. 라우트 문서와 자동 테스트 보강.

## 검증 범위

- 문법 검사 `python -m compileall` 통과.
- Firebase Admin/Google SDK를 테스트용 가짜 모듈로 대체한 환경에서 **73개 백엔드 테스트 통과**. 여기에는 복수 약속 이력, 구형 기록 보존, 초대 코드 길이 검사가 포함됩니다.
- **실제 Firebase, OpenRouter, 카카오 호출 및 기기 캘린더 동기화 검증은 수행하지 않았습니다.** 실제 SDK/자격 증명/기기 없이 정상 동작을 보장할 수 없습니다.

## 운영 단계에서 남은 작업

- Firestore에 남아 있는 8자리 코드 방에 대해 **드라이런 후 초대 코드 마이그레이션 실제 실행**. 이전 코드의 외부 공유는 무효화됨.
- 테스트용 Firebase 프로젝트에서 방 생성→참가→전원 투표→AI 코스→복수 약속 확정→캘린더 동기화 시나리오를 실측.
- `account_cleanup.py` 30일 경과 계정 삭제 작업의 실제 스케줄러 등록, 권한/로그/실패 알림 설정. 코드만 있고 운영 스케줄은 설정되지 않음.
- 계정 삭제 시 방 참가자/기타 Firestore 참조 데이터의 개인정보 처리 정책 검토.

## 로컬 적용 후 테스트

```bash
cd ~/Desktop/mobileprogram_backend
unzip -o ~/Downloads/planit_backend_audited_2026-11-11.zip -d .
cd backend
python -m pytest -q tests/
```

**`.env`, `serviceAccountKey.json`, `.venv`는 ZIP에 포함하지 않았습니다.** GitHub Commit 전에 `git diff --cached --name-only`에서 비밀 파일이 포함되지 않았는지 다시 확인하세요.
