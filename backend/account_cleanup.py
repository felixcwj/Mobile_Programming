import argparse
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore


def eligible(data, now):
    due = data.get("deletion_due_at")
    requested = data.get("deletion_requested_at")
    return (
        isinstance(requested, datetime)
        and isinstance(due, datetime)
        and requested.tzinfo is not None
        and due.tzinfo is not None
        and due <= now
    )


def claim(db, ref, now):
    @firestore.transactional
    def reserve(transaction):
        snap = ref.get(transaction=transaction)
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        if not eligible(data, now):
            return None
        processing = data.get("deletion_processing_at")
        if isinstance(processing, datetime) and processing.tzinfo is not None:
            if now - processing < timedelta(hours=2):
                return None
        transaction.update(ref, {"deletion_processing_at": now})
        return data

    return reserve(db.transaction())


def release_reservation(db, collection, identifier, uid):
    if not identifier:
        return
    ref = db.collection(collection).document(identifier)
    snapshot = ref.get()
    if snapshot.exists and (snapshot.to_dict() or {}).get("uid") == uid:
        ref.delete()


def cleanup_one(db, auth_api, ref, now):
    data = claim(db, ref, now)
    if data is None:
        return False
    try:
        auth_api.delete_user(ref.id)
    except auth_api.UserNotFoundError:
        pass
    release_reservation(db, "nickname_reservations", data.get("nickname_key"), ref.id)
    release_reservation(db, "usernames", str(data.get("id") or ref.id).lower(), ref.id)
    db.recursive_delete(ref)
    return True


def process_due(db, auth_api, now, execute=False, limit=50):
    query = db.collection("users").where("deletion_due_at", "<=", now).limit(limit)
    found = 0
    processed = 0
    failures = 0
    for snapshot in query.stream():
        if not eligible(snapshot.to_dict() or {}, now):
            continue
        found += 1
        if not execute:
            continue
        try:
            if cleanup_one(db, auth_api, snapshot.reference, now):
                processed += 1
        except Exception:
            failures += 1
    return {"eligible": found, "processed": processed, "failures": failures, "dry_run": not execute}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--service-account", type=Path, required=True)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()

    if not args.service_account.is_file():
        raise SystemExit("서비스 계정 키 파일이 없습니다.")
    if args.limit < 1 or args.limit > 100:
        raise SystemExit("limit은 1~100이어야 합니다.")
    if args.execute and os.getenv("ALLOW_ACCOUNT_DELETION") != args.project_id:
        raise SystemExit("실제 삭제에는 ALLOW_ACCOUNT_DELETION을 프로젝트 ID로 설정해야 합니다.")

    app = firebase_admin.initialize_app(credentials.Certificate(str(args.service_account)))
    db = firestore.client(app=app)
    if app.project_id != args.project_id:
        raise SystemExit("설정된 Firebase 프로젝트가 일치하지 않습니다.")
    result = process_due(db, auth, datetime.now(timezone.utc), execute=args.execute, limit=args.limit)
    print(result)
    if result["failures"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
