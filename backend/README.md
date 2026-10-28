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
- Authentication UID를 앱의 ID와 동일하게 사용. ID 변경 기능을 구현하려면 UID 전략 변경 필요.
- 이메일/비밀번호 인증은 Firebase Authentication, 나머지 사용자 정보는 Firestore `users/{id}`에 저장.
- 기존 SQLite `mannaja.db`는 **자동 이전되지 않음**. Firebase로 새로 회원가입하거나 추후 마이그레이션해야 함.
- 기존 SQLite에서 발급된 토큰도 Firebase에서 인정되지 않음.
- 관리자 서비스 계정은 서버에만 보관. Flutter 앱에는 절대 포함하지 말 것.
- 웹 API 키는 클라이언트 식별용이며, 서비스 계정 키와 달리 비밀 관리자 자격 증명이 아님.
- 개발용 예시. 공개 서비스 전 레이트 리밋, 이메일 인증, 개인정보 처리/보존 정책, Firestore 보안 규칙, CORS 설정, 로그/모니터링 필요.
- Firebase Auth 및 Firestore 무료 제공량과 과금 조건은 프로젝트/설정에 따라 달라질 수 있으니 콘솔에서 확인.
