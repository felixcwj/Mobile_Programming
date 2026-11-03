from datetime import datetime, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError

import calendar_routes
from calendar_routes import CalendarSelection, EventInput, ExternalChange, SyncBatch


def test_event_dates_require_timezone():
    with pytest.raises(ValidationError):
        EventInput(title="Study", starts_at="2026-11-05T10:00:00", ends_at="2026-11-05T11:00:00")


def test_end_must_follow_start():
    with pytest.raises(ValidationError):
        EventInput(title="Study", starts_at="2026-11-05T12:00:00+09:00", ends_at="2026-11-05T11:00:00+09:00")


def test_empty_title_rejected():
    with pytest.raises(ValidationError):
        EventInput(title="   ", starts_at="2026-11-05T10:00:00+09:00", ends_at="2026-11-05T11:00:00+09:00")


def test_duplicate_selected_calendar_rejected():
    with pytest.raises(ValidationError):
        CalendarSelection(device_id="phone", calendar_ids=["a", "a"])


def test_external_upsert_requires_event():
    with pytest.raises(ValidationError):
        ExternalChange(calendar_id="primary", external_event_id="abc", status="upsert")


def test_sync_batch_has_limit():
    change = {"calendar_id": "primary", "external_event_id": "a", "status": "deleted"}
    with pytest.raises(ValidationError):
        SyncBatch(device_id="phone", changes=[change] * 101)


def test_calendar_routes_require_authentication():
    app = FastAPI()

    def require_user():
        from fastapi import HTTPException
        raise HTTPException(401, "로그인이 필요합니다.")

    app.include_router(calendar_routes.make_calendar_router(None, require_user))
    client = TestClient(app)
    response = client.get("/calendar/pending-deletions")
    assert response.status_code == 401


def test_calendar_router_exposes_required_routes():
    app = FastAPI()

    def user():
        return {"uid": "test"}

    app.include_router(calendar_routes.make_calendar_router(None, user))
    paths = {(route.path, method) for route in app.routes for method in getattr(route, "methods", [])}
    for route in [
        ("/calendar/events", "GET"),
        ("/calendar/events", "POST"),
        ("/calendar/events/{event_id}", "GET"),
        ("/calendar/events/{event_id}", "PUT"),
        ("/calendar/events/{event_id}", "DELETE"),
        ("/calendar/selected-calendars", "GET"),
        ("/calendar/selected-calendars", "PUT"),
        ("/calendar/sync/external", "POST"),
        ("/calendar/sync/changes", "GET"),
        ("/calendar/events/{event_id}/external-link", "POST"),
        ("/calendar/pending-deletions", "GET"),
        ("/calendar/events/{event_id}/external-delete-decision", "POST"),
    ]:
        assert route in paths, sorted(paths)


def test_invalid_calendar_selection_request_returns_422():
    app = FastAPI()

    def user():
        return {"uid": "test"}

    app.include_router(calendar_routes.make_calendar_router(None, user))
    client = TestClient(app)
    response = client.put("/calendar/selected-calendars", json={"device_id": "phone", "calendar_ids": ["a", "a"]})
    assert response.status_code == 422
