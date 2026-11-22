# PlanIt shared classroom backend (Vercel)

The frontend release APK is configured at run time using **팀 서버 연결**. No
backend host or private credentials are included in the APK.

## Set up the real HTTPS server

1. Create a Vercel project linked to `felixcwj/Mobile_Programming`, setting the
   **Root Directory** to `backend` and the Framework to FastAPI.
2. In Vercel → Project → Settings → Environment Variables, add:
   - `FIREBASE_WEB_API_KEY`: Firebase Web API key for
     `mobile-programming-d4e67` (public Firebase client configuration)
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the **entire** Firebase service account
     JSON as one **sensitive/server-only** environment variable. Never put it
     in GitHub, the APK, issue comments or this chat.
   - `KAKAO_REST_API_KEY`: Kakao REST API key, **server-only**.
   - `OPENROUTER_API_KEY`: set only when the professor provides the evaluation
     AI key. This key is **server-only** and does not require a new APK.
   - `OPENROUTER_MODEL`: the model approved for the classroom evaluation.
3. Redeploy the reviewed integration branch, verify `GET /health` returns
   `{"status":"ok","database":"firebase"}`, then use two test accounts
   to validate the real Firebase/Kakao integrations.

A service-account file path in `FIREBASE_SERVICE_ACCOUNT_JSON` also works on
a developer laptop. Do not expose the development port to the public Internet.

## Install on physical devices

Download the `planit-android-tablet-release` artifact from GitHub Actions.
It is a universal Android APK suitable for Android 13 Lenovo Tab M8 (4th Gen)
2024 and typical Galaxy Android devices. Unzip and install the APK from Files;
approve Android's one-time "Install unknown apps" permission if prompted.
Open PlanIt → **팀 서버 연결** → paste the same Vercel HTTPS address on each
device → **연결 확인 및 저장** → sign up/sign in with distinct test accounts.

The `planit-android-dev-lan` debug APK supports a developer-hosted HTTP
backend inside the same private Wi-Fi. Each tablet must enter the laptop's
actual `http://192.168.x.x:8000` or other private LAN address. `10.0.2.2`
works only inside the Android emulator, NOT on the Lenovo tablet.

## Running a local classroom backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Keep serviceAccountKey.json outside the repository. Configure your .env
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Devices must be on the same Wi-Fi with client isolation disabled and the
host firewall permitting TCP/8000. Use HTTPS instead on an untrusted network.

## Evaluation checklist

Test two real devices for registration/login, room creation and 7-character
invite, maximum 8 people, region validation, collaborative preferences and
votes, AI recommendation with a live Kakao place list, confirmation, shared
calendar, personal event CRUD, logout/relogin restoration and rapid scrolling.
The paid OpenRouter key goes in the Vercel backend environment **the day before
evaluation**, never into a mobile build.

CI's Firebase emulator suite verifies API behavior, but does not replace a
live external API test. The Android UI stress smoke checks startup and
taps/swipes only; it is not a two-device full UI test.
