# PlanIt 독립 통합 실험 E2E 검증 보고서

검증일: **2026-11-12 (KST)**  
실험 브랜치: `experiment/wonjoon-planit-integration`  
확장 E2E 검증 커밋: `47dd5ab01` (2026-11-12, 빌드·E2E 성공)  
원본 Flutter: `yhooni29/planit_front` main `c4becdf0010d`  
원본 백엔드: `feature/backend-integration` `30c40018`

## 실제 GitHub Actions 결과

| 검증 | 결과 | 실행 로그 |
|---|---|---|
| 백엔드 Python 테스트 | **86 통과 / 1 warning** | [통합 체크](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403296) |
| Flutter `analyze`, 웹 빌드 | **통과** | [통합 체크](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403296) |
| 신규 Flutter API/프로필 테스트 | **14 통과** | [통합 체크](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403296) |
| FastAPI + Firebase Auth/Firestore 공식 에뮬레이터 | **17개 실제 HTTP 시나리오 통과** | [에뮬레이터 E2E](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403306) |
| Dart `PlanitApi` → FastAPI → 실제 Firebase 에뮬레이터 HTTP 연결 | **12개 검증 통과** | [에뮬레이터 E2E](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403306) |
| Flutter Chrome UI → 실제 백엔드 → Firebase 에뮬레이터 | **실제 Chrome UI 로그인 + 방 생성 + 날짜 선택 및 공유 캘린더 저장 통과** | [에뮬레이터 E2E](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403306) |
| 기존 프리뷰 기반 위젯 테스트(비차단) | **7 통과 / 6 실패** | [통합 체크](https://github.com/felixcwj/Mobile_Programming/actions/runs/43175403296) |

두 GitHub Actions 워크플로의 **최종 실행 결론은 모두 success**입니다. 다만 미리보기 기반 위젯 테스트 6개는 진짜 서버 연결 이전의 임시 데이터 흐름을 전제로 작성되어 현재 실패합니다. 이 실패를 숨기지 않고 비차단 단계로 분리했습니다. 테스트를 최신 연동 구조로 개편해야 전체 테스트가 무조건 통과하는 상태가 됩니다.

## 실제 API/SDK로 검증한 기능

`backend/e2e/smoke_http.py`는 가짜 FastAPI 응답이 아닌 **실행 중인 Uvicorn 서버와 공식 Firebase SDK, Auth/Firestore 에뮬레이터**를 사용합니다.

1. 서버 /health, 인증 없는 요청 차단
2. 서로 다른 3개 Firebase Auth 계정 가입·로그인·토큰 검증
3. 아이디 중복 검증
4. 정확히 7자리 초대 코드 생성 및 입장 검사, 방 최대 인원, 비참가자 접근 차단
5. 방장이 등록한 약속 날짜를 참여자 캘린더에서 실제 조회
6. 개인 반복 일정 생성·조회·수정·삭제, 낙관적 버전 충돌, 타 사용자 비공개
7. 참가자별 조건 Firestore 저장 및 조회
8. 이미 저장된 추천 코스로 약속 확정 후 참가자별 이력 조회
9. 날짜 변경이 승인된 뒤 외부 AI 호출 실패에도 날짜 유지
10. 동일 방의 두 번째 약속 확정 시 과거 약속 기록 보존
11. 방 탈퇴 사용자의 공유 일정 숨김, 다른 참여자 데이터 유지
12. 마이페이지 닉네임 변경 및 비공개 성향 저장
13. 일반 참가자의 조건 수정 제안과 전원 승인
14. 조건 변경 제안 거절 및 기존 값 유지
15. 만남 지역 변경 제안·승인
16. 확정 약속 날짜 변경 제안·동의
17. 비밀번호 확인 기반 탈퇴 신청, 중복 요청 차단, 취소

`frontend/tool/live_api_e2e.dart`는 실제 Dart HTTP 클라이언트로 서버에 연결해 12개 항목을 검증합니다. `frontend/test/browser_live_widget_test.dart`는 **Chrome의 Flutter 화면에서** 로그인 필드를 입력하고 방 생성 버튼을 조작하여 서버에 실제로 방이 만들어졌는지 확인하고, UI에서 날짜를 골라 참가자 공유 캘린더에 저장된 것도 확인합니다.

## 네이티브 빌드 확인

- Android 디버그 APK와 iOS 시뮬레이터 앱의 빌드 성공을 GitHub Actions에서 확인했습니다. [빌드 실행](https://github.com/felixcwj/Mobile_Programming/actions/runs/43174895792). 빌드 성공은 실제 기기에 설치·구동했다는 뜻은 아닙니다.
- 실제 Chrome 브라우저 E2E에서 발견한 **이전 방 목록 응답이 방금 생성한 방을 삭제하는 비동기 동시성 버그**는 `RoomsController`의 요청/로컬 변경 버전 보호로 수정했고, 확장 Chrome E2E를 다시 통과했습니다.

## 아직 완료되지 않은 실환경 검증

**중요: 아래 항목은 테스트하지 않았습니다. 완료로 표시하지 마세요.**

- **실제 Firebase 운영/스테이징 프로젝트:** 에뮬레이터가 아닌 실제 Firebase에 생성·수정·조회한 테스트 미실시. 이 실행 환경에 서비스 계정 키·Firebase 웹 키가 제공되지 않았으며 운영 데이터는 건드리지 않았습니다.
- **OpenRouter:** 유효한 실 API 키로 추천을 생성한 테스트 미실시. 에뮬레이터 E2E는 **추천 결과를 Firestore에 테스트 데이터로 저장**해 이후 확정·이력 로직을 검증한 것이며 실제 LLM 호출 성공을 의미하지 않습니다.
- **카카오 장소 검색:** 실 API 키로 검색하고 OpenRouter 추천의 장소 ID를 검증하는 전체 경로 미실시.
- **iOS/Android 실제 기기:** 브라우저 UI 검증은 실시했으나 앱 패키지 설치, 기기 캘린더 OS 권한·연동, 푸시/알림, 앱 재실행 시 로그인 갱신 등 미실시.
- **기존 8자리 초대 코드 운영 DB 마이그레이션:** 스크립트 존재, 운영 데이터 변경 미실시.
- **삭제 유예 기간 30일 계정 정리 스케줄러:** 운영 스케줄 실행 확인 미실시.
- **같은 방에서 여러 차례 약속을 만드는 전체 Flutter 사용자 동선:** 백엔드 이력 누적은 검증했으나, 새로운 날짜를 처음부터 기획하는 UX 미완성.
- **이전 프리뷰 위젯 테스트 6개:** 최신 서버 통합 흐름으로 수정 필요.

## 재현 명령과 안전 경계

프로덕션 Firebase 서비스 계정을 사용하지 않도록 `demo-planit-integration` 프로젝트 ID만 허용하는 테스트 스크립트를 사용합니다. 임시 자격증명은 테스트 중 생성하고 즉시 제거합니다.

- 전체 백엔드/Flutter CI: `.github/workflows/planit-flutter-experiment.yml`
- Firebase + Dart + Chrome E2E: `.github/workflows/planit-firebase-emulator-e2e.yml`
- 실행 스크립트: `backend/e2e/run_emulator_http.sh`
- 실행 시뮬레이터: `backend/e2e/firebase.json`
- 브라우저 원본 에셋 복원: `frontend/tools/restore_upstream_assets.sh`

**팀원 프론트엔드 저장소, 백엔드 통합 브랜치 및 main에는 병합하지 않았습니다.** 비교 평가용 단독 실험본으로 유지합니다.
