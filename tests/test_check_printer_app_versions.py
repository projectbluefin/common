"""Tests for scripts/check-printer-app-versions.py

The script is loaded by path (it has a dash in its name) and exercised
in-process. The contract JSON it reads is also validated against the real
recording, so drift between the data and the documented form fails here.
"""

import importlib.util
import json
from pathlib import Path

import pytest

SCRIPT_PATH = Path(__file__).parent.parent / "scripts/check-printer-app-versions.py"
CONTRACT_PATH = (
    Path(__file__).parent.parent
    / "docs/skills/release-promotion/references/printer-app-version-grammar.json"
)


def _load_module():
    spec = importlib.util.spec_from_file_location("check_printer_app_versions", SCRIPT_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_mod = _load_module()
check_family = _mod.check_family
check_contract = _mod.check_contract
check_candidate = _mod.check_candidate
find_family = _mod.find_family
load_contract = _mod.load_contract
main = _mod.main
parse_version = _mod.parse_version


def _entry(**overrides):
    base = {
        "family": "example-printer-app",
        "repo": "projectbluefin/example-printer-app",
        "upstream_form": "semver",
        "upstream_source": "example upstream release",
        "grammar": "^(?P<upstream>[0-9]+\\.[0-9]+\\.[0-9]+)-(?P<packaging>[0-9]+)"
        "(\\.(?P<rebuild>[0-9]+))?$",
        "rebuild_slot": "suffix",
        "version_source": "VERSION",
        "enforcement": "tag must equal v$VERSION",
        "published_tags": ["1.2.3-1", "1.2.3-1.1"],
        "examples": {"upstream_release": "1.2.4-1", "rebuild": "1.2.3-1.2"},
    }
    base.update(overrides)
    return base


def _severities(findings, severity=None):
    if severity is None:
        return [item["severity"] for item in findings]
    return [item for item in findings if item["severity"] == severity]


# ---------------------------------------------------------------------------
# parse_version
# ---------------------------------------------------------------------------

class TestParseVersion:
    def test_parses_named_groups(self):
        assert parse_version(_entry(), "1.2.3-4.5") == {
            "upstream": "1.2.3",
            "packaging": "4",
            "rebuild": "5",
        }

    def test_rebuild_group_absent_when_not_supplied(self):
        assert parse_version(_entry(), "1.2.3-4") == {
            "upstream": "1.2.3",
            "packaging": "4",
        }

    def test_rejects_malformed_version(self):
        with pytest.raises(ValueError, match="does not match"):
            parse_version(_entry(), "1.2")

    def test_calendar_date_grammar(self):
        entry = _entry(
            family="ps", grammar="^(?P<upstream>[0-9]{8})-(?P<packaging>[0-9]+)$"
        )
        assert parse_version(entry, "20240504-20") == {
            "upstream": "20240504",
            "packaging": "20",
        }


# ---------------------------------------------------------------------------
# check_family
# ---------------------------------------------------------------------------

class TestCheckFamily:
    def test_clean_entry_has_no_findings(self):
        assert check_family(_entry()) == []

    def test_missing_required_field(self):
        entry = _entry()
        del entry["version_source"]
        errors = _severities(check_family(entry), "error")
        assert any("version_source" in item["message"] for item in errors)

    def test_invalid_grammar(self):
        errors = _severities(check_family(_entry(grammar="^(unclosed")), "error")
        assert any("invalid grammar" in item["message"] for item in errors)

    def test_invalid_grammar_with_a_missing_field_reports_the_missing_field(self):
        entry = _entry(grammar="^(unclosed")
        del entry["version_source"]
        findings = check_family(entry)
        assert [item["message"] for item in findings] == [
            "missing required field 'version_source'"
        ]

    def test_missing_grammar_reports_the_missing_field(self):
        entry = _entry()
        del entry["grammar"]
        findings = check_family(entry)
        assert [item["message"] for item in findings] == [
            "missing required field 'grammar'"
        ]

    def test_unknown_upstream_form(self):
        errors = _severities(check_family(_entry(upstream_form="whatever")), "error")
        assert any("upstream_form" in item["message"] for item in errors)

    def test_unknown_rebuild_slot(self):
        errors = _severities(check_family(_entry(rebuild_slot="elsewhere")), "error")
        assert any("rebuild_slot" in item["message"] for item in errors)

    def test_published_tag_must_parse(self):
        entry = _entry(published_tags=["1.2.3-1", "not-a-version"])
        errors = _severities(check_family(entry), "error")
        assert any("published tag invalid" in item["message"] for item in errors)

    def test_no_published_tags_needs_a_note(self):
        entry = _entry(published_tags=[])
        errors = _severities(check_family(entry), "error")
        assert any("published_tags_note" in item["message"] for item in errors)

    def test_no_published_tags_with_a_note_is_fine(self):
        entry = _entry(published_tags=[], published_tags_note="held on #27")
        assert _severities(check_family(entry), "error") == []

    def test_missing_upstream_release_example(self):
        entry = _entry(examples={"rebuild": "1.2.3-1.2"})
        errors = _severities(check_family(entry), "error")
        assert any("upstream_release" in item["message"] for item in errors)

    def test_examples_must_parse(self):
        entry = _entry(examples={"upstream_release": "nope", "rebuild": "1.2.3-1.2"})
        errors = _severities(check_family(entry), "error")
        assert any("examples.upstream_release invalid" in i["message"] for i in errors)

        entry = _entry(examples={"upstream_release": "1.2.4-1", "rebuild": "nope"})
        errors = _severities(check_family(entry), "error")
        assert any("examples.rebuild invalid" in i["message"] for i in errors)

    def test_rebuild_example_equal_to_upstream_release_example(self):
        entry = _entry(
            examples={"upstream_release": "1.2.4-1", "rebuild": "1.2.4-1"}
        )
        errors = _severities(check_family(entry), "error")
        assert any("cannot be told apart" in item["message"] for item in errors)

    def test_no_rebuild_slot_is_a_finding_not_an_error(self):
        entry = _entry(
            grammar="^(?P<upstream>[0-9]+\\.[0-9]+\\.[0-9]+)$",
            rebuild_slot="none",
            published_tags=["3.26.4"],
            examples={"upstream_release": "3.26.5"},
        )
        results = check_family(entry)
        assert _severities(results, "error") == []
        assert any("no rebuild slot" in item["message"] for item in results)

    def test_rebuild_example_with_no_rebuild_slot_is_an_error(self):
        entry = _entry(
            grammar="^(?P<upstream>[0-9]+\\.[0-9]+\\.[0-9]+)$",
            rebuild_slot="none",
            published_tags=["3.26.4"],
            examples={"upstream_release": "3.26.5", "rebuild": "3.26.5-1"},
        )
        errors = _severities(check_family(entry), "error")
        assert any("rebuild_slot is 'none'" in item["message"] for item in errors)

    def test_shared_rebuild_slot_is_a_finding(self):
        entry = _entry(
            grammar="^(?P<upstream>[0-9]+\\.[0-9]+\\.[0-9]+)-(?P<packaging>[0-9]+)$",
            rebuild_slot="shared",
            published_tags=["1.2.3-1"],
            examples={"upstream_release": "1.2.4-1", "rebuild": "1.2.3-2"},
        )
        results = check_family(entry)
        assert _severities(results, "error") == []
        assert any("shared with the packaging revision" in i["message"] for i in results)

    def test_shared_slot_requires_a_rebuild_example(self):
        entry = _entry(
            grammar="^(?P<upstream>[0-9]+\\.[0-9]+\\.[0-9]+)-(?P<packaging>[0-9]+)$",
            rebuild_slot="shared",
            published_tags=["1.2.3-1"],
            examples={"upstream_release": "1.2.4-1"},
        )
        results = check_family(entry)
        assert any("shared with the packaging revision" in i["message"] for i in results)
        errors = _severities(results, "error")
        assert any("shared' but no examples.rebuild" in i["message"] for i in errors)

    def test_suffix_slot_requires_a_rebuild_example(self):
        entry = _entry(examples={"upstream_release": "1.2.4-1"})
        errors = _severities(check_family(entry), "error")
        assert any("suffix' but no examples.rebuild" in i["message"] for i in errors)


# ---------------------------------------------------------------------------
# check_contract
# ---------------------------------------------------------------------------

class TestCheckContract:
    def test_a_duplicate_tag_across_families_is_a_warning_not_an_error(self):
        contract = {
            "families": [
                _entry(family="a", published_tags=["1.2.3-1"]),
                _entry(family="b", published_tags=["1.2.3-1"]),
            ]
        }
        findings = check_contract(contract)
        assert _severities(findings, "error") == []
        assert any(
            "also claimed by a" in item["message"]
            and item["severity"] == "warning"
            for item in findings
        )

    def test_distinct_tags_are_fine(self):
        contract = {
            "families": [
                _entry(family="a", published_tags=["1.2.3-1"]),
                _entry(family="b", published_tags=["4.5.6-1"]),
            ]
        }
        assert _severities(check_contract(contract), "error") == []


# ---------------------------------------------------------------------------
# check_candidate
# ---------------------------------------------------------------------------

class TestCheckCandidate:
    def test_valid_candidate_has_no_findings(self):
        contract = {"families": [_entry()]}
        assert check_candidate(contract, "example-printer-app", "1.2.3-1.4") == []

    def test_valid_candidate_components(self):
        contract = {"families": [_entry()]}
        entry = find_family(contract, "example-printer-app")
        assert parse_version(entry, "1.2.3-1.4")["rebuild"] == "4"

    def test_invalid_candidate_returns_error(self):
        contract = {"families": [_entry()]}
        results = check_candidate(contract, "example-printer-app", "1.2")
        assert _severities(results, "error")

    def test_unknown_family(self):
        results = check_candidate({"families": [_entry()]}, "nope", "1.2.3-1")
        assert any("unknown family" in item["message"] for item in results)

    def test_family_with_an_invalid_grammar_reports_it(self):
        contract = {"families": [_entry(grammar="^(unclosed")]}
        results = check_candidate(contract, "example-printer-app", "1.2.3-1")
        assert any("invalid grammar" in item["message"] for item in results)

    def test_family_without_a_grammar_reports_it(self):
        entry = _entry()
        del entry["grammar"]
        results = check_candidate({"families": [entry]}, "example-printer-app", "1.2.3-1")
        assert any("grammar" in item["message"] for item in results)


# ---------------------------------------------------------------------------
# load_contract
# ---------------------------------------------------------------------------

class TestLoadContract:
    def test_recorded_contract_has_four_families(self):
        contract = load_contract(CONTRACT_PATH)
        assert len(contract["families"]) == 4

    def test_recorded_contract_has_no_errors(self):
        contract = load_contract(CONTRACT_PATH)
        assert _severities(check_contract(contract), "error") == []

    def test_recorded_contract_flags_the_known_gaps(self):
        contract = load_contract(CONTRACT_PATH)
        messages = " ".join(i["message"] for i in check_contract(contract))
        assert "no rebuild slot" in messages
        assert "shared with the packaging revision" in messages

    def test_recorded_contract_matches_json_on_disk(self):
        with open(CONTRACT_PATH, encoding="utf-8") as handle:
            assert json.load(handle) == load_contract(CONTRACT_PATH)

    def test_missing_families_key_raises(self, tmp_path):
        path = tmp_path / "contract.json"
        path.write_text(json.dumps({"contract_version": 1}))
        with pytest.raises(ValueError, match="families"):
            load_contract(path)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

class TestMain:
    def test_recorded_contract_passes(self, capsys):
        assert main(["--contract", str(CONTRACT_PATH)]) == 0
        out = capsys.readouterr().out
        assert "0 error(s), 3 finding(s)" in out

    def test_strict_fails_on_findings(self):
        assert main(["--contract", str(CONTRACT_PATH), "--strict"]) == 1

    def test_json_output(self, capsys):
        assert main(["--contract", str(CONTRACT_PATH), "--format", "json"]) == 0
        payload = json.loads(capsys.readouterr().out)
        assert payload["errors"] == []
        assert len(payload["findings"]) == 3
        assert payload["warnings"] == []

    def test_json_output_reports_warnings(self, tmp_path, capsys):
        path = tmp_path / "contract.json"
        path.write_text(
            json.dumps(
                {
                    "families": [
                        _entry(family="a", published_tags=["1.2.3-1"]),
                        _entry(family="b", published_tags=["1.2.3-1"]),
                    ]
                }
            )
        )
        assert main(["--contract", str(path), "--format", "json"]) == 0
        payload = json.loads(capsys.readouterr().out)
        assert payload["errors"] == []
        assert [item["severity"] for item in payload["warnings"]] == ["warning"]
        assert "also claimed by a" in payload["warnings"][0]["message"]

    def test_strict_fails_on_warnings_alone(self, tmp_path):
        path = tmp_path / "contract.json"
        path.write_text(
            json.dumps(
                {
                    "families": [
                        _entry(family="a", published_tags=["1.2.3-1"]),
                        _entry(family="b", published_tags=["1.2.3-1"]),
                    ]
                }
            )
        )
        assert main(["--contract", str(path)]) == 0
        assert main(["--contract", str(path), "--strict"]) == 1

    def test_candidate_mode(self, capsys):
        rc = main(
            [
                "--contract",
                str(CONTRACT_PATH),
                "--family",
                "hplip-printer-app",
                "--candidate",
                "3.26.4-1",
            ]
        )
        assert rc == 1
        assert "does not match" in capsys.readouterr().out

    def test_candidate_mode_accepts_a_valid_version(self):
        rc = main(
            [
                "--contract",
                str(CONTRACT_PATH),
                "--family",
                "hplip-printer-app",
                "--candidate",
                "3.26.5",
            ]
        )
        assert rc == 0

    def test_candidate_mode_requires_candidate(self):
        with pytest.raises(SystemExit):
            main(["--contract", str(CONTRACT_PATH), "--family", "hplip-printer-app"])

    def test_candidate_mode_requires_family(self):
        with pytest.raises(SystemExit):
            main(["--contract", str(CONTRACT_PATH), "--candidate", "3.26.5"])

    def test_unreadable_contract_exits_one(self, capsys):
        rc = main(["--contract", "/nonexistent/contract.json"])
        assert rc == 1
        assert "cannot read version contract" in capsys.readouterr().err

    def test_contract_without_families_exits_one(self, tmp_path, capsys):
        path = tmp_path / "contract.json"
        path.write_text(json.dumps({"contract_version": 1}))
        assert main(["--contract", str(path)]) == 1
        assert "cannot read version contract" in capsys.readouterr().err
