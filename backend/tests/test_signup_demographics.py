"""Signup demographic fields are optional, validated, and compatible with existing clients."""
import ast
from datetime import date
from pathlib import Path
import re

import pytest
from pydantic import EmailStr, Field, ValidationError, model_validator


def signup_model():
    path = Path(__file__).resolve().parents[1] / "main.py"
    source = ast.parse(path.read_text(encoding="utf-8"))
    klass = next(node for node in source.body
                 if isinstance(node, ast.ClassDef) and node.name == "SignupRequest")
    from pydantic import BaseModel
    scope = {
        "BaseModel": BaseModel, "EmailStr": EmailStr, "Field": Field,
        "model_validator": model_validator, "date": date, "re": re,
    }
    module = ast.fix_missing_locations(ast.Module(body=[klass], type_ignores=[]))
    exec(compile(module, str(path), "exec"), scope)
    return scope["SignupRequest"]


BASE = {
    "id": "tester1", "nickname": "tester",
    "password": "password123", "password_confirm": "password123",
    "email": "tester@example.com", "name": "Alex",
    "phone": "01012345678",
}


def test_optional_signup_demographics_are_backward_compatible():
    Signup = signup_model()
    result = Signup(**BASE)
    assert result.gender is None
    assert result.birthday is None
    selected = Signup(**BASE, gender="male", birthday="2003-12-28")
    assert selected.gender == "male"
    assert selected.birthday == date(2003, 12, 28)


@pytest.mark.parametrize("extra", [
    {"gender": "invalid"},
    {"birthday": "2035-01-01"},
    {"birthday": "2001-02-29"},
])
def test_invalid_demographic_values_are_rejected(extra):
    Signup = signup_model()
    with pytest.raises(ValidationError):
        Signup(**BASE, **extra)
