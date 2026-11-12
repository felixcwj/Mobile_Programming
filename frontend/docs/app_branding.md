# 플랜잇 앱 이름과 아이콘

원본 아이콘은 `assets/images/planit_app_icon.png`에 보관합니다.
사용자가 제공한 이미지를 그대로 사용하며, 기존 로그인 화면의 로고는 별도입니다.

표시 이름을 Flutter 앱 제목, 웹 제목·설치 이름, Android·iOS·macOS 이름,
Windows·Linux 창 제목에 적용했습니다. 내부 패키지와 번들 식별자는 유지합니다.
Linux 창 아이콘은 번들 내 Flutter 이미지 에셋을 읽습니다.

플랫폼별 아이콘을 다시 생성하려면 macOS에서 프로젝트 루트를 기준으로 실행합니다.

```sh
swift -module-cache-path /private/tmp/planit-swift-cache tools/generate_app_icons.swift
```

추가 패키지는 필요하지 않습니다. iOS 아이콘은 흰 배경으로 투명도를 제거하고,
웹 maskable 아이콘은 마스킹 시 그림이 잘리지 않도록 여백을 추가합니다.
Windows ICO에는 16~256px의 7개 크기를 포함합니다.

아이콘 크기·참조, Apple plist 문법, Windows ICO 구조를 확인했습니다.
각 플랫폼에서 앱을 빌드·설치해 표시되는지 확인하는 검증은 수행하지 않았습니다.

이름·아이콘 변경은 Hot Reload 대신 앱을 완전히 종료한 후 다시 실행해야 합니다.
설치된 웹 앱은 기존 이름·아이콘이 캐시에 남아 있다면 재설치가 필요할 수 있습니다.
