import pytest

from room_rules import INVITE_CODE_LENGTH, INVITE_SPECIAL_CHARACTERS, MAX_ROOM_MEMBERS, generate_invite_code, get_room_max_members


def test_invite_code_uses_seven_uppercase_numbers_and_requested_symbols():
    codes = {generate_invite_code() for _ in range(100)}
    assert len(codes) == 100
    assert INVITE_SPECIAL_CHARACTERS == "#@!"
    assert all(len(code) == INVITE_CODE_LENGTH for code in codes)
    assert all(any(c.isalpha() for c in code) and any(c.isdigit() for c in code) for code in codes)
    assert all(any(c in INVITE_SPECIAL_CHARACTERS for c in code) for code in codes)
    assert all(set(code) <= (set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") | set(INVITE_SPECIAL_CHARACTERS)) for code in codes)


@pytest.mark.parametrize("stored, expected", [
    ({"max_members": 2}, 2),
    ({"max_members": 5}, 5),
    ({"max_members": 8}, 8),
    ({"max_members": 30}, MAX_ROOM_MEMBERS),
    ({"max_members": 1}, 2),
    ({}, MAX_ROOM_MEMBERS),
    ({"max_members": "invalid"}, MAX_ROOM_MEMBERS),
])
def test_room_capacity(stored, expected):
    assert get_room_max_members(stored) == expected
