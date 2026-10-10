"""Regression tests for the GVariant menu-tuple parser.

PR #1430 introduces ``_parse_custom_command_menu`` in
``tests/test_chairlift_config.py`` to pin the Bluefin Custom Command Menu
slot for the ChairLift ``--ask-bluefin`` dispatcher. The first version of
that helper split the 4-tuple body with a bare ``body[1:-1].split(',')``
and so mis-parsed any menu entry whose label or command contained a
comma. The shipped entries are all comma-free, so the bug never tripped
in practice, but a future edit to ``04-bluefin-custom-command-menu``
(for example a flatpak command whose path contains a comma) would
silently break the 4-tuple assert.

These tests pin a GVariant-aware splitter independently of
``test_chairlift_config.py`` so the regression is covered even before
PR #1430 lands. Once that PR is in, both the helper inside
``test_chairlift_config.py`` and this stand-alone test assert the same
behaviour.

GVariant text format (used by dconf / GSettings) is documented at
https://docs.gtk.org/glib/struct.Variant.html#g-variant-text-format :

* Strings are enclosed in single quotes.
* An embedded single quote is escaped by doubling it (``''``).
* Tuples are written as ``(v1, v2, v3, v4)`` with comma separators at
  the top level only -- a comma inside a quoted string is part of the
  value.
"""

import re

import pytest


_GVARIANT_QUOTED_FIELD = r"'((?:[^'\\]|\\.|'')*)'"
_GVARIANT_UNESCAPE = re.compile(r"\\(.)|''")
_GVARIANT_MENU_TUPLE = re.compile(
    rf"\(\s*{_GVARIANT_QUOTED_FIELD}\s*,"
    rf"\s*{_GVARIANT_QUOTED_FIELD}\s*,"
    rf"\s*{_GVARIANT_QUOTED_FIELD}\s*,"
    rf"\s*(true|false)\s*\)"
)


def _split_gvariant_menu_tuple_fields(body: str) -> list[str]:
    """Split a GVariant 4-tuple body on its top-level commas.

    Walks the body character by character, tracks single-quote nesting,
    and respects GVariant's ``''`` escape for an embedded quote. A bare
    comma inside a quoted string is part of the value, not a separator.
    """
    parts: list[str] = []
    current: list[str] = []
    in_string = False
    i = 0
    while i < len(body):
        ch = body[i]
        if in_string:
            if ch == "'" and i + 1 < len(body) and body[i + 1] == "'":
                current.append("''")
                i += 2
                continue
            if ch == "'":
                in_string = False
                current.append(ch)
                i += 1
                continue
            current.append(ch)
            i += 1
            continue
        if ch == "'":
            in_string = True
            current.append(ch)
            i += 1
            continue
        if ch == ",":
            parts.append("".join(current).strip())
            current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    parts.append("".join(current).strip())
    return parts


def test_split_keeps_commas_inside_quoted_strings():
    """The shipped dconf menu has no embedded commas today, but a future
    slot could (for example a flatpak command pointing at a path with a
    comma). The splitter must keep such commas inside the field."""
    assert _split_gvariant_menu_tuple_fields("'a, b', 'c, d', '', true") == [
        "'a, b'",
        "'c, d'",
        "''",
        "true",
    ]


def test_split_handles_gvariant_doubled_quote_escape():
    """GVariant escapes an embedded single quote by doubling it (``''``).
    The splitter must keep an escaped comma attached to the surrounding
    field, not treat it as a separator."""
    assert _split_gvariant_menu_tuple_fields("'it''s, ok', '', '', false") == [
        "'it''s, ok'",
        "''",
        "''",
        "false",
    ]


def test_split_unescapes_gvariant_doubled_quote_when_decoding():
    """Round-trip: a field's content can be recovered by stripping the
    surrounding quotes and replacing ``''`` with a single quote."""
    parts = _split_gvariant_menu_tuple_fields("'it''s, ok', '', '', false")
    assert parts[0].strip("'").replace("''", "'") == "it's, ok"


def test_split_handles_simple_four_field_tuple():
    """The shipped slot 11 shape parses without surprises."""
    assert _split_gvariant_menu_tuple_fields(
        "'Ask Bluefin', '/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper --ask-bluefin', '', true"
    ) == [
        "'Ask Bluefin'",
        "'/home/linuxbrew/.linuxbrew/bin/chairlift-wrapper --ask-bluefin'",
        "''",
        "true",
    ]


def test_split_tolerates_whitespace_around_commas():
    """GVariant allows arbitrary whitespace around commas and inside the
    tuple; the splitter must not depend on tight spacing."""
    assert _split_gvariant_menu_tuple_fields(
        "  'Ask Bluefin'  ,  ''  ,  ''  ,  true  "
    ) == [
        "'Ask Bluefin'",
        "''",
        "''",
        "true",
    ]


def test_split_keeps_escaped_backslash_inside_string():
    """GVariant permits ``\\`` to escape the next character; the splitter
    must not confuse a ``\\,`` with a top-level separator."""
    assert _split_gvariant_menu_tuple_fields(r"'a\,b', '', '', true") == [
        r"'a\,b'",
        "''",
        "''",
        "true",
    ]


def test_regex_fullmatch_accepts_embedded_comma():
    """A regex-based equivalent of the splitter must also handle an
    embedded comma. Lock the contract: a 4-tuple with a comma in the
    first field matches cleanly, so the downstream code can rely on the
    four captured groups being the four real fields, in order."""
    body = "('Foo, Bar', '/usr/bin/whatever', '', true)"
    match = _GVARIANT_MENU_TUPLE.fullmatch(body)
    assert match is not None, f"expected match for {body!r}"
    label, command, accelerator, enabled = match.groups()
    assert label == "Foo, Bar"
    assert command == "/usr/bin/whatever"
    assert accelerator == ""
    assert enabled == "true"


def test_regex_fullmatch_rejects_wrong_field_count():
    """A 3-tuple is a schema violation, not a 4-tuple with a missing
    field; the regex must not silently match it. This mirrors the
    ``assert len(parts) == 4`` guard in the production parser."""
    assert _GVARIANT_MENU_TUPLE.fullmatch("('a', 'b', 'c')") is None
    assert _GVARIANT_MENU_TUPLE.fullmatch("('a', 'b', 'c', true, false)") is None


def test_regex_fullmatch_rejects_unquoted_bool():
    """GVariant requires ``true`` / ``false`` outside the quotes; a
    quoted ``'true'`` is a string, not a boolean."""
    assert _GVARIANT_MENU_TUPLE.fullmatch("('a', 'b', 'c', 'true')") is None


@pytest.mark.parametrize(
    "body,expected",
    [
        (
            "('label', 'command', 'accel', true)",
            ("label", "command", "accel", "true"),
        ),
        (
            "('a, b', 'c, d', 'e, f', false)",
            ("a, b", "c, d", "e, f", "false"),
        ),
    ],
)
def test_regex_fullmatch_round_trip(body, expected):
    """The four captured groups must come back in order, with each
    field's value unquoted (no surrounding single quotes)."""
    match = _GVARIANT_MENU_TUPLE.fullmatch(body)
    assert match is not None, f"expected match for {body!r}"
    assert match.groups() == expected
