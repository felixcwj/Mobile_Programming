"""Optional one-time migration for legacy invite codes.

Dry-run by default. Execute only after configuring a Firebase service account and
confirming that older invite codes may become invalid for people who saved them.
"""
import argparse
import os
import re
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

from room_rules import generate_invite_code


VALID_CODE = re.compile(r"^[A-Z0-9#@!]{7}$")


def needs_migration(code: object) -> bool:
    return not isinstance(code, str) or VALID_CODE.fullmatch(code) is None


@firestore.transactional
def replace_code(tx, db, room_ref, original_code: str, replacement_code: str):
    room = room_ref.get(transaction=tx)
    if not room.exists:
        return "gone"
    current = (room.to_dict() or {}).get("invite_code")
    if current != original_code or not needs_migration(current):
        return "changed"
    fresh_ref = db.collection("room_invites").document(replacement_code)
    if fresh_ref.get(transaction=tx).exists:
        return "collision"
    old_ref = db.collection("room_invites").document(original_code)
    old = old_ref.get(transaction=tx)
    if old.exists and (old.to_dict() or {}).get("room_id") != room_ref.id:
        raise RuntimeError("Old code is assigned to another room. Manual review required.")
    tx.create(fresh_ref, {"room_id": room_ref.id})
    tx.update(room_ref, {"invite_code": replacement_code, "updated_at": firestore.SERVER_TIMESTAMP})
    if old.exists:
        tx.delete(old_ref)
    return "migrated"


def migrate(db, execute=False):
    stats = {"needs_migration": 0, "migrated": 0, "collisions": 0, "errors": 0, "dry_run": not execute}
    for snapshot in db.collection("rooms").stream():
        original = (snapshot.to_dict() or {}).get("invite_code")
        if not needs_migration(original):
            continue
        stats["needs_migration"] += 1
        if not execute:
            continue
        if not isinstance(original, str) or not original:
            stats["errors"] += 1
            continue
        try:
            for _ in range(10):
                outcome = replace_code(db.transaction(), db, snapshot.reference, original, generate_invite_code())
                if outcome != "collision":
                    if outcome == "migrated":
                        stats["migrated"] += 1
                    break
                stats["collisions"] += 1
            else:
                stats["errors"] += 1
        except Exception:
            stats["errors"] += 1
    return stats


def main():
    parser = argparse.ArgumentParser(description="Migrate legacy room invitation codes to seven characters")
    parser.add_argument("--service-account", required=True, type=Path)
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not args.service_account.is_file():
        raise SystemExit("Firebase service account file not found")
    if args.execute and os.environ.get("ALLOW_INVITE_CODE_MIGRATION") != args.project_id:
        raise SystemExit("Set ALLOW_INVITE_CODE_MIGRATION to the project ID for --execute")
    app = firebase_admin.initialize_app(credentials.Certificate(str(args.service_account)))
    if app.project_id != args.project_id:
        raise SystemExit("Firebase project mismatch")
    stats = migrate(firestore.client(app=app), execute=args.execute)
    print(stats)
    if stats["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
