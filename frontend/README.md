# 플랜잇 (PlanIt)

친구들의 취향을 모아 함께할 하루를 계획하는 Flutter 앱입니다.
현재 로그인, 홈, 프로필, 약속방, 캘린더 화면이 연결되어 있습니다.
Dart 패키지 이름은 `meetsync`입니다.

## 개발 환경

- 실행을 확인한 버전: Flutter **3.47.8 stable**, Dart **3.13.7**
- 웹 실행: Google Chrome
- `pubspec.lock`을 함께 사용해 패키지 버전을 맞춥니다. 현재 잠금 파일은
  Flutter 3.47.0 이상, Dart 3.13.0 이상을 요구합니다.

## 브랜치 받아서 실행하기

```sh
git clone --branch main https://github.com/yhooni29/planit_front.git
cd planit_front
flutter --version
flutter doctor
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port=5173
```

이미 저장소를 받은 경우, 진행 중인 변경 사항을 커밋하거나 보관한 뒤 실행합니다.

```sh
git fetch origin
git switch main
git pull --ff-only origin main
flutter pub get --enforce-lockfile
flutter run -d chrome --web-port=5173
```

실행하면 Chrome에서 앱이 열립니다. 실행 주소는 `http://localhost:5173`입니다.
5173 포트를 다른 프로그램이 사용 중이면 `--web-port` 값을 변경하세요.
다른 컴퓨터에서는 위 명령으로 개발 서버를 직접 실행해야 합니다.

로그인 화면에서는 비어 있지 않은 아이디와 비밀번호를 입력하면 홈으로 이동합니다.
현재 실제 인증 서버에 연결되어 있지 않으므로 개발 확인용 값을 사용하세요.
프로필·약속방·일정은 로그인 세션의 메모리에 저장되며,
로그아웃하거나 앱을 재시작하면 초기화됩니다.

## VS Code 실행

Flutter/Dart 확장이 설치된 VS Code에서 프로젝트 폴더를 열고,
`flutter pub get --enforce-lockfile`을 한 번 실행합니다.
실행 및 디버그에서 **PlanIt (Chrome)**을 선택하고 `F5`를 누르면 됩니다.
설정은 [`.vscode/launch.json`](.vscode/launch.json)에 있습니다.

터미널에서 `flutter run`을 실행한 경우 `r`은 Hot reload,
`R`은 Hot restart, `q`는 실행 종료입니다.

## 작업 및 검증

공유 기준 브랜치에서 개인 작업 브랜치를 만들어 개발할 수 있습니다.

```sh
git switch -c feature/my-task
flutter analyze
flutter test
```

고객센터 수신 주소는 선택적으로 실행 시 변경할 수 있습니다.

```sh
flutter run -d chrome --web-port=5173 --dart-define=SUPPORT_EMAIL=support@example.com
```

기본 웹 실행에는 별도의 API 키나 `.env` 파일이 필요하지 않습니다.
인증, 실제 초대·참여, AI 추천 생성, 서버 영구 저장은 후속 연동 대상입니다.

## 코드 안내

- `lib/main.dart`: 앱 진입점
- `lib/screens/`: 로그인, 홈, 프로필, 약속방, 캘린더 화면
- `lib/models/`, `lib/services/`: 공통 데이터와 세션 상태 관리
- `test/`: 모델 및 화면 테스트
- [프로필 연동 안내](docs/profile_integration.md)
- [약속방 연동 안내](docs/rooms_integration.md)
- [캘린더 연동 안내](docs/calendar_integration.md)
