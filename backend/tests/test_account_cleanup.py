from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import account_cleanup


def test_eligible_requires_both_dates_and_past_due():
    now = datetime(2026, 11, 3, tzinfo=timezone.utc)
    record = {"deletion_requested_at": now - timedelta(days=31), "deletion_due_at": now - timedelta(days=1)}
    assert account_cleanup.eligible(record, now)
    assert not account_cleanup.eligible({**record, "deletion_due_at": now + timedelta(days=1)}, now)
    assert not account_cleanup.eligible({"deletion_due_at": now - timedelta(days=1)}, now)
    assert not account_cleanup.eligible({"deletion_requested_at": now - timedelta(days=31)}, now)


class Snapshot:
    def __init__(self, ref):
        self.reference = ref
        self.id = ref.id
        self.exists = True

    def to_dict(self):
        return self.reference.data.copy()


class Ref:
    def __init__(self, uid, data):
        self.id = uid
        self.data = data
        self.deleted = False

    def get(self, transaction=None):
        return Snapshot(self)

    def update(self, fields):
        self.data.update(fields)

    def delete(self):
        self.deleted = True


class Query:
    def __init__(self, snapshots):
        self.snapshots = snapshots

    def where(self, *args):
        return self

    def limit(self, count):
        self.count = count
        return self

    def stream(self):
        return self.snapshots[:self.count]


class DB:
    def __init__(self, snapshots):
        self.snapshots = snapshots
        self.recursive_calls = []

    def collection(self, name):
        return Query(self.snapshots)

    def recursive_delete(self, ref):
        self.recursive_calls.append(ref.id)


def test_dry_run_does_not_delete_anything():
    now = datetime(2026, 11, 3, tzinfo=timezone.utc)
    ref = Ref("alice", {
        "deletion_requested_at": now - timedelta(days=31),
        "deletion_due_at": now - timedelta(days=1),
    })
    db = DB([Snapshot(ref)])
    auth = SimpleNamespace(delete_user=lambda uid: (_ for _ in ()).throw(AssertionError("must not delete")))
    result = account_cleanup.process_due(db, auth, now, execute=False)
    assert result == {"eligible": 1, "processed": 0, "failures": 0, "dry_run": True}
    assert not db.recursive_calls
