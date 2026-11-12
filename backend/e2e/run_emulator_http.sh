#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export FIREBASE_WEB_API_KEY=demo-local-test-key
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
export GOOGLE_CLOUD_PROJECT=demo-planit-integration
export GCLOUD_PROJECT=demo-planit-integration
export FIREBASE_SERVICE_ACCOUNT_JSON="$(mktemp)"
KEY_FILE="$(mktemp)"
cleanup() {
  if [[ -n "${API_PID:-}" ]]; then kill "$API_PID" 2>/dev/null || true; fi
  rm -f "$FIREBASE_SERVICE_ACCOUNT_JSON" "$KEY_FILE"
}
trap cleanup EXIT
openssl genrsa -out "$KEY_FILE" 2048 >/dev/null 2>&1
python - "$KEY_FILE" "$FIREBASE_SERVICE_ACCOUNT_JSON" <<'PY'
import json, sys
from pathlib import Path
data = {
    "type": "service_account",
    "project_id": "demo-planit-integration",
    "private_key_id": "demo-only",
    "private_key": Path(sys.argv[1]).read_text(),
    "client_email": "firebase-adminsdk-demo@demo-planit-integration.iam.gserviceaccount.com",
    "client_id": "123456789",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/demo",
}
Path(sys.argv[2]).write_text(json.dumps(data))
PY
(cd backend && python -m uvicorn main:app --host 127.0.0.1 --port 8765 --log-level warning) &
API_PID=$!
for i in $(seq 1 45); do
  if curl -fsS http://127.0.0.1:8765/health >/dev/null; then break; fi
  if ! kill -0 "$API_PID" 2>/dev/null; then
    echo "FastAPI exited during startup" >&2
    exit 1
  fi
  sleep 1
done
curl -fsS http://127.0.0.1:8765/health >/dev/null
python backend/e2e/smoke_http.py
