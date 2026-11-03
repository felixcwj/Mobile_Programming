import argparse
import json
import os
import sys
from pathlib import Path

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account


def run(key_path: Path):
    if not key_path.is_file():
        print("FAIL: 관리자 키 파일을 찾을 수 없습니다.")
        return 2

    try:
        with key_path.open(encoding="utf-8") as handle:
            key_data = json.load(handle)
        project = key_data.get("project_id")
        if not project or key_data.get("type") != "service_account":
            print("FAIL: 올바른 서비스 계정 파일이 아닙니다.")
            return 2
        credentials = service_account.Credentials.from_service_account_file(
            str(key_path),
            scopes=["https://www.googleapis.com/auth/datastore"],
        )
        session = AuthorizedSession(credentials)
        url = (
            f"https://firestore.googleapis.com/v1/projects/{project}"
            "/databases/(default)/documents/users"
        )
        print("프로젝트:", project, flush=True)
        print("Firestore REST 읽기 확인 중", flush=True)
        response = session.get(url, params={"pageSize": 1}, timeout=(5, 15))
        if response.status_code == 200:
            print("REST_READ_OK")
            print("SDK gRPC 통신이 차단되어도 Firebase 인증과 REST 읽기는 정상입니다.")
            return 0
        print("REST_READ_FAILED: HTTP", response.status_code)
        if response.status_code in (401, 403):
            print("서비스 계정 권한 또는 API 활성화 상태를 확인해야 합니다.")
        elif response.status_code == 404:
            print("프로젝트 또는 (default) 데이터베이스를 확인해야 합니다.")
        return 1
    except Exception as exc:
        print("REST_READ_FAILED:", type(exc).__name__)
        print("상세 오류는 인증 정보가 포함될 수 있으므로 출력하지 않습니다.")
        return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--key",
        type=Path,
        default=Path.home() / ".config/mobile-programming/serviceAccountKey.json",
    )
    args = parser.parse_args()
    sys.exit(run(args.key))
