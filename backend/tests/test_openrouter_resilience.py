"""Isolated regression tests for OpenRouter failures; no Firebase credentials required."""
import ast
import asyncio
import json
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from fastapi import HTTPException


def course_function(monkeypatch, responses, call_payloads):
    path = Path(__file__).resolve().parents[1] / "main.py"
    tree = ast.parse(path.read_text(encoding="utf-8"))
    function = next(node for node in tree.body
                    if isinstance(node, ast.AsyncFunctionDef) and node.name == "_openrouter_course")

    class Client:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def post(self, url, headers, json):
            call_payloads.append(json)
            return responses.pop(0)

    class FakePlan:
        @classmethod
        def model_validate_json(cls, raw):
            return json.loads(raw)

    monkeypatch.setattr(httpx, "AsyncClient", Client)
    namespace = {
        "httpx": httpx,
        "HTTPException": HTTPException,
        "json": json,
        "OPENROUTER_API_KEY": "test-only-token",
        "OPENROUTER_MODEL": "openrouter/free",
        "VerifiedCoursePlan": FakePlan,
        "_check_and_enrich": lambda plan, conditions, candidates: plan,
    }
    module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    exec(compile(module, str(path), "exec"), namespace)
    return namespace["_openrouter_course"]


def fake_response(status_code, body, headers=None):
    return SimpleNamespace(status_code=status_code, headers=headers or {},
                           json=lambda: body)


CONDITIONS = {
    "date": "2026-11-15",
    "budget_per_person": 30000,
    "meeting_area": "서울",
}
CANDIDATES = [{"place_id": "123", "name": "카페", "address": "서울",
               "category": "카페"}]


def test_provider_pool_429_is_not_mislabeled_as_daily_limit(monkeypatch):
    calls = []
    response = fake_response(429, {"error": {
        "message": "Provider returned error",
        "metadata": {
            "limit_source": "upstream_provider_shared_pool",
            "provider_name": "Google AI Studio",
        }}}, {"retry-after": "60"})
    course = course_function(monkeypatch, [response], calls)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(course(CONDITIONS, CANDIDATES))
    assert exc.value.status_code == 429
    assert "Google AI Studio" in exc.value.detail
    assert "Retry-After: 60" in exc.value.detail
    assert "일일" not in exc.value.detail
    assert len(calls) == 1


def test_null_content_is_retried_once_with_low_reasoning(monkeypatch, capsys):
    calls = []
    empty = fake_response(200, {"model": "sample:free", "choices": [
        {"finish_reason": "length", "message": {"content": None, "reasoning": "private"}}
    ], "usage": {"completion_tokens": 5000,
                 "completion_tokens_details": {"reasoning_tokens": 5000}}})
    valid_plan = {
        "title": "카페 약속", "date": "2026-11-15", "summary": "테스트",
        "stops": [{"start_time": "12:00", "end_time": "13:00",
                   "place_id": "123", "activity": "카페",
                   "estimated_cost": 10000}],
        "notes": "",
    }
    valid = fake_response(200, {"choices": [
        {"finish_reason": "stop", "message": {"content": json.dumps(valid_plan)}}
    ]})
    course = course_function(monkeypatch, [empty, valid], calls)
    assert asyncio.run(course(CONDITIONS, CANDIDATES)) == valid_plan
    assert len(calls) == 2
    assert "reasoning" not in calls[0]
    assert calls[1]["reasoning"] == {"effort": "none"}
    assert "reasoning_tokens" in capsys.readouterr().out


def test_two_empty_completions_fail_without_infinite_retries(monkeypatch):
    calls = []
    empty = lambda: fake_response(200, {"choices": [
        {"finish_reason": "stop", "message": {"content": None}}
    ]})
    course = course_function(monkeypatch, [empty(), empty()], calls)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(course(CONDITIONS, CANDIDATES))
    assert exc.value.status_code == 502
    assert "두 번 연속" in exc.value.detail
    assert len(calls) == 2


def test_openrouter_per_minute_limit_is_explained(monkeypatch):
    calls = []
    response = fake_response(429, {"error": {"metadata": {
        "limit_source": "openrouter_free_tier_per_minute"}}})
    course = course_function(monkeypatch, [response], calls)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(course(CONDITIONS, CANDIDATES))
    assert exc.value.status_code == 429
    assert "분당" in exc.value.detail
