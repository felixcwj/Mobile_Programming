"""Regression tests: Kakao keyword search must never silently pick a wrong location."""
import ast
import asyncio
from pathlib import Path

import pytest
from fastapi import HTTPException


def location_resolver(search):
    file = Path(__file__).resolve().parents[1] / "main.py"
    tree = ast.parse(file.read_text(encoding="utf-8"))
    node = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef)
                and n.name == "_resolve_departure")
    namespace = {"_kakao_search": search, "HTTPException": HTTPException, "re": __import__("re")}
    module = ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[]))
    exec(compile(module, str(file), "exec"), namespace)
    return namespace["_resolve_departure"]


def test_english_ambiguous_places_rejected_without_calling_kakao():
    called = 0

    async def search(*args, **kwargs):
        nonlocal called
        called += 1
        return []

    resolver = location_resolver(search)
    for input_value in ("USA", "gangnam"):
        with pytest.raises(HTTPException) as exc:
            asyncio.run(resolver(input_value))
        assert exc.value.status_code == 422
    assert called == 0


def test_unrelated_first_hit_is_not_used():
    async def search(*args, **kwargs):
        return [{"name": "도프커피 을지로입구역점", "place_id": "123"}]

    resolver = location_resolver(search)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(resolver("강남역"))
    assert exc.value.status_code == 422
    assert "모호" in exc.value.detail


def test_exact_korean_name_is_selected():
    async def search(*args, **kwargs):
        return [
            {"name": "다른 카페", "place_id": "123"},
            {"name": "강남역", "place_id": "456"},
        ]

    resolver = location_resolver(search)
    assert asyncio.run(resolver("강남역"))["place_id"] == "456"
