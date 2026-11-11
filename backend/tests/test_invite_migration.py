from migrate_invite_codes import needs_migration


def test_only_exact_seven_character_allowed_code_is_accepted():
    for code in ('A1#BCDE', 'A1@BCDE', 'A1!BCDE', 'ABCDEFG', '1234567'):
        assert not needs_migration(code)
    for code in ('ABCDEFG8', 'ABCDEF12', '', None, 'A1_BCDE', 'abc123!'):
        assert needs_migration(code)
