# PlanIt shared classroom backend (Vercel)

The frontend release APK is configured at run time using **팀 서버 연결**. No
backend host or private credentials are included in the APK.

## Set up the real HTTPS server

1. Vercel project **`planit-team-backend`** has been created on the user's Hobby team.
   Vercel GitHub integration cannot read this private repo, so source deployment
   must be performed by the connected deployment tool or Vercel CLI. The
   framework is FastAPI, and the real server URL is
   **`https://planit-team-backend.vercel.app`**.
2. In Vercel → Project → Settings → Environment Variables, add:
   - `FIREBASE_WEB_API_KEY`: Firebase Web API key for
     `mobile-programming-d4e67` (public Firebase client configuration)
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the **entire** Firebase service account
     JSON as one **sensitive/server-only** environment variable. Never put it
     in GitHub, the APK, issue comments or this chat.
   - `KAKAO_REST_API_KEY`: Kakao REST API key, **server-only**.
   - `AI_API_KEY` (or legacy `OPENROUTER_API_KEY`): set only when the professor
     provides the paid evaluation AI key. The key is **server-only**.
   - `AI_MODEL` (or legacy `OPENROUTER_MODEL`): chosen AI model.
   - `AI_API_BASE_URL`: an HTTPS OpenAI-compatible chat completions endpoint,
     defaults to OpenRouter. These three variables can be changed without
     rebuilding the Android APK.
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

## No-cost classroom practice and temporary HTTPS sharing

Until the $10 paid key arrives, the backend can assemble a provisional
recommendation from verified Kakao place IDs and shared preferences.
This is explicitly **not an AI-generated route**; actual operating hours,
route times and prices are unknown. A free model HTTP 429 uses the same
fallback unless ENABLE_KAKAO_FALLBACK=0.

To run a common backend on the same Wi-Fi, on a trusted Mac with the existing
Firebase service-account file and backend/.env Kakao key, run:

    bash backend/start_classroom.sh

Use its private-LAN IP in the debug APK's **팀 서버 연결**.

For devices on different networks, install cloudflared once with
`brew install cloudflared`, and run:

    bash backend/start_classroom.sh --tunnel

The printed HTTPS trycloudflare.com URL works in the release APK.
This free temporary URL changes each time you restart the tunnel. Never
use personal data or share server credentials with the tunnel users.

After receiving a paid OpenAI-compatible API key, set AI_API_KEY, AI_MODEL
and AI_API_BASE_URL on the server. The Android APK does not change.

## Preconfigured team release APK

The release APK defaults to `https://planit-team-backend.vercel.app`.
Once the backend's private Firebase Admin JSON and Kakao REST key are configured
on the Vercel project and deployment is healthy, teammates only need to install
and sign up. They do **not** need to type the server address manually.
The **팀 서버 연결** button remains available for temporary LAN/tunnel testing.
