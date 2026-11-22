#!/usr/bin/env bash
set -euo pipefail

# Start the classroom server on your Mac. No secrets are copied into the APK.
backend="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$backend")"
cd "$backend"

if [[ -z "${FIREBASE_SERVICE_ACCOUNT_JSON:-}" &&
      -f "$HOME/.config/mobile-programming/serviceAccountKey.json" ]]; then
  export FIREBASE_SERVICE_ACCOUNT_JSON="$HOME/.config/mobile-programming/serviceAccountKey.json"
fi

# The existing FlutterFire web API key is public client configuration.
if [[ -z "${FIREBASE_WEB_API_KEY:-}" && -f "$project/frontend/lib/firebase_options.dart" ]]; then
  export FIREBASE_WEB_API_KEY="$(
    python3 - "$project/frontend/lib/firebase_options.dart" <<'PY'
import re
import sys
s = open(sys.argv[1], encoding="utf8").read()
m = re.search(r"static const FirebaseOptions web = FirebaseOptions\(\s*apiKey:\s*'([^']+)'", s)
print(m.group(1) if m else "")
PY
  )"
fi

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install -q -r requirements.txt

echo "PlanIt API: http://0.0.0.0:8000"
echo "Same Wi-Fi devices: use the Mac private IP address, never 10.0.2.2."
if [[ "${1:-}" != "--tunnel" ]]; then
  exec .venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000
fi

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Install cloudflared on macOS: brew install cloudflared"
  exit 2
fi

.venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT INT TERM
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 http://127.0.0.1:8000/health >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "PlanIt API exited before becoming ready."
    exit 1
  fi
  sleep 1
done
if ! curl -fsS --max-time 2 http://127.0.0.1:8000/health >/dev/null; then
  echo "PlanIt API health check failed."
  exit 1
fi
echo "Copy the temporary HTTPS URL printed below to 팀 서버 연결 on every device."
echo "Keep this terminal running. Only use disposable classroom accounts."
exec cloudflared tunnel --url http://127.0.0.1:8000
