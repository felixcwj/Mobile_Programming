"""Room invitation and capacity rules shared across room API operations."""

import secrets
import string

INVITE_CODE_LENGTH = 7
MAX_ROOM_MEMBERS = 8
# Requested invitation symbols. Pass invite codes in JSON bodies, never unescaped in URL fragments.
INVITE_SPECIAL_CHARACTERS = "#@!"
_INVITE_ALPHABET = string.ascii_uppercase + string.digits + INVITE_SPECIAL_CHARACTERS
_RANDOM = secrets.SystemRandom()


def generate_invite_code() -> str:
    """Generate seven secure characters containing a letter, a digit and a symbol."""
    chars = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.digits),
        secrets.choice(INVITE_SPECIAL_CHARACTERS),
    ]
    chars.extend(secrets.choice(_INVITE_ALPHABET) for _ in range(INVITE_CODE_LENGTH - len(chars)))
    _RANDOM.shuffle(chars)
    return "".join(chars)


def get_room_max_members(room: dict) -> int:
    """Keep existing rooms usable and never allow more than eight participants."""
    raw = room.get("max_members", MAX_ROOM_MEMBERS)
    try:
        configured = int(raw)
    except (TypeError, ValueError):
        return MAX_ROOM_MEMBERS
    return min(MAX_ROOM_MEMBERS, max(2, configured))
