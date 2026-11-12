# 원준 개인 통합 실험본 (Flutter + FastAPI)

> 이 브랜치는 **비교 평가용 복사본**입니다. `main`, `feature/backend-integration`, 고근씨 프론트엔드 원본 및 채연씨 실험 브랜치를 변경하지 않습니다. 머지하지 마세요.

## 출처와 코드 기준

- 백엔드 원본: `felixcwj/Mobile_Programming`의 `feature/backend-integration` (`30c40018`)
- 프론트 원본: `yhooni29/planit_front`의 `main` (`c4becdf0010d`)
- 이 실험본: `experiment/wonjoon-planit-integration` (같은 저장소의 `backend/` + `frontend/`)
- 프론트의 Dart 소스, 문서, 의존성 파일은 `frontend/`로 복사했습니다. **이미지·Android/iOS 등의 플랫폼 파일은 GitHub 원본에 남겨두고, 재현 스크립트가 해당 원본 커밋에서 복사합니다.** 이 과정에서 동료의 원본을 수정하지 않습니다.

## 로컬에서 실행 (Mac)

```bash
git clone --branch experiment/wonjoon-planit-integration https://github.com/felixcwj/Mobile_Programming.git planit-wonjoon
cd planit-wonjoon
bash frontend/tools/restore_upstream_assets.sh
cd frontend
flutter pub get
flutter analyze
flutter test test/api_integration_test.dart
flutter run -d chrome --web-port=5173 --dart-define=PLANIT_API_BASE_URL=http://localhost:8000
```

백엔드는 다른 터미널에서 `cd backend`, `python -m pip install -r requirements.txt`, `.env` 및 Firebase Admin 서비스 계정을 준비한 다음 `python -m uvicorn main:app --reload --port 8000`으로 실행합니다. 서버의 Firebase 서비스 계정/AI 비밀키는 프론트엔드에 절대 넣지 않습니다.

Android 에뮬레이터에서 서버가 호스트 Mac에 있을 때는 `--dart-define=PLANIT_API_BASE_URL=http://10.0.2.2:8000`을 사용합니다. 실기기는 Mac의 LAN IP를 이용하되, CORS/방화벽/HTTP 허용 정책을 기기에 맞게 구성해야 합니다. `PLANIT_ALLOWED_ORIGINS`(쉼표로 구분)으로 프론트 웹 Origin을 제한합니다. 기본 허용은 `localhost:5173` 및 `127.0.0.1:5173`입니다.

## 실제 API로 연결한 경로

- 로그인, 회원가입, 아이디 중복 확인 (서버 응답이 성공했을 때만 로그인)
- 방 만들기·초대 코드 서버 생성·코드로 참여·서버 방 목록
- 방 조건 입력(`additional_notes` 포함), AI 추천 생성/조회 및 확정
- 조건/날짜 변경 요청과 참가자 투표 화면
- 개인·반복 일정 조회/생성/수정/삭제, 공유 방 일정 및 약속 이력 캘린더 조회
- 마이페이지 닉네임과 개인 성향 서버 저장, 누적 약속 이력 조회

## 현재 제한 및 비교 시 유의 사항

- **실서비스 Firebase 프로젝트·OpenRouter·카카오 API, iOS/Android 실기기에서의 종단 간 호출은 아직 미실시입니다.** 단, Firebase **공식 Auth·Firestore 에뮬레이터**와 실제 FastAPI HTTP 서버를 함께 실행한 테스트는 통과했습니다. Python의 모의 DB 단위테스트와는 별개의 검증입니다.
- 백엔드 실서비스 주소를 아직 배포하지 않았으므로 실행 시 `PLANIT_API_BASE_URL`을 지정해야 합니다. 기본 빈 값일 때는 서버 연결 실패로 안내합니다.
- 앱 재시작 시 ID 토큰은 메모리에서 사라져 다시 로그인해야 합니다. 안전한 토큰 갱신·기기 저장은 후속 작업입니다.
- 프론트의 상세 주소·프로필 사진 서버 API는 아직 없습니다. 저장하려 하면 오류를 안내하며 성공한 것으로 표시하지 않습니다.
- 임시 약속 날짜 변경은 방장만 가능, 확정 약속은 방장 즉시/참가자 제안·투표로 처리합니다. 확정 약속 **시각** 변경 API는 미제공입니다.
- 기존 **미연동 프리뷰 위젯 테스트**는 임시 로그인/미리보기 문구와 로컬 저장을 전제로 작성되어 통합 코드에서는 실패할 수 있습니다. 통합 CI에서는 해당 테스트를 별도로 비차단 실행하고, 새 HTTP 연동 테스트를 필수로 실행합니다. 실패를 숨기거나 성공이라고 주장하지 않습니다.
- 이 브랜치는 동료 프론트의 디자인 변경을 자동으로 가져오지 않습니다. 비교 평가 이후 최신 디자인 변경분을 별도 대조해야 합니다.

## 실제 자동 검증 보고 (2026-11-12)

| 검증 종류 | 결과 | 검증 범위 |
| --- | --- | --- |
| Python 백엔드 | **86개 통과** | 모의 Firebase 기반 API·데이터 규칙 |
| Flutter 분석·웹 빌드 | **통과** | Dart 정적 분석과 Chrome용 웹 빌드 |
| Flutter 연결·프로필 테스트 | **15개 통과** | HTTP 계약, 로그인·방 생성 레이스 회귀, 기존 프로필 테스트 |
| 실제 Firebase Auth + Firestore 에뮬레이터 | **17개 복합 시나리오 통과** | 계정·권한, 7자리 초대, 인원 제한, 공유/개인 캘린더, 투표·승인·거절, 다중 약속 이력, 탈퇴 신청·취소 |
| Dart 클라이언트 → FastAPI → 공식 Firebase 에뮬레이터 | **통과** | 실제 HTTP 인증 토큰, 방 생성·참여, 일정 저장·조회 |
| Chrome UI → FastAPI → 공식 Firebase 에뮬레이터 | **통과** | 화면 회원가입·로그인·방 생성·날짜 선택·Firestore 저장. 방 생성과 초기 로딩 사이의 경합 오류 발견 후 수정 |
| Android 네이티브 디버그 APK | **빌드 성공** | 실제 APK 생성. 기기 실행 테스트 아님 |
| iOS 시뮬레이터 앱 | **빌드 성공** | macOS/Xcode에서 unsigned Runner.app 빌드. 시뮬레이터 설치/조작 테스트 아님 |
| 구형 로컬 미리보기 위젯 테스트 | **7개 통과 / 6개 실패** | 서버 연동 전의 임시 로그인·저장 기대값을 유지하는 테스트. 아직 새 동작에 맞게 전면 전환되지 않음 |

검증 실행 기록:
- [Firebase 공식 에뮬레이터·실제 HTTP·Chrome UI E2E 성공](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403306)
- [Python + Flutter 분석·웹 빌드·연동 테스트 성공](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403296)
- [Android APK 및 iOS Simulator 빌드 성공](https://github.com/felixcwj/Mobile_Programming/actions/runs/43174078738)

실제 OpenRouter·카카오 API 성공 여부는 이 결과로 입증되지 않습니다. AI 추천 결과는 Firebase 에뮬레이터에서 계약에 맞는 fixture를 저장해 나머지 확정·날짜변경 로직을 검증한 것입니다. 운영 Firebase 초대코드 마이그레이션 및 탈퇴 30일 후 자동 삭제 스케줄러도 실제 운영 확인이 필요합니다.

## 다음 주 비교 기준

실계정 회원가입→로그인, 다른 계정으로 초대 코드 참여, 개인 조건 제출, AI 추천/확정, 사용자별 캘린더 반영, 마이페이지 저장, 브라우저 새로고침·재접속과 오류 처리, 동일 시나리오 재현성. `flutter analyze`와 `flutter build web` 결과도 함께 비교합니다.
