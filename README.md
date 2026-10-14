# 모여봄 — AI 약속 플래너 (Flutter UI)

모바일 프로그래밍 팀 프로젝트의 **Decorate widgets** 과제를 위해 기존 UI를 정리한 버전입니다.

## 구현한 화면

- 홈: 새 약속 생성, 약속방 목록, 약속 현황
- 새 약속 만들기: 약속 이름, 날짜, 참여 인원 선택
- 약속방: 선호 지역, 시작 시간, 1인 예산, 희망 활동 입력
- 추천 일정: 선택 활동을 활용한 예시 타임라인
- 일정 수정: 문장 입력 및 고정 예시 재표시
- 달력: 약속이 있는 날짜 표시, 날짜별 약속 확인
- 마이페이지: 게스트 계정의 시연용 UI

**주의:** 현재 프로젝트는 UI 프로토타입입니다. 실제 LLM 호출, 지도/장소 데이터, 로그인, 회원가입, 데이터베이스 및 사용자 초대는 구현하지 않았습니다. 추천 일정과 수정 결과는 **시연용 예시**입니다. 약속 정보는 앱을 종료하면 초기화됩니다.

## 실행

Flutter SDK를 설치한 뒤, 터미널에서 다음과 같이 실행합니다.

```bash
cd ai_meet_planner
flutter create .
flutter pub get
flutter run
```

Chrome에서 실행하려면 `flutter run -d chrome`을 사용합니다. macOS에서는 `flutter run -d macos`로 실행할 수 있습니다(플랫폼 개발 환경 설정 필요).

## 파일 구성

```text
lib/
  main.dart
  app_theme.dart
  models/meeting.dart
  screens/
    main_shell.dart
    create_meeting_screen.dart
    room_screen.dart
    recommendation_screen.dart
    revision_screen.dart
  widgets/ui.dart
```
