#!/usr/bin/env python3
"""Check the four OCI Printer Application version forms for internal consistency.

The version contract is recorded as data in
``docs/skills/release-promotion/references/printer-app-version-grammar.json``;
this script is the machine check over that data and over any candidate version
string. It reports, it does not decide: an immutable tag policy change is a
maintainer decision (common#1245).

Checks:

  * every published immutable tag parses under its family's grammar;
  * no published tag is claimed by two families;
  * every family records where its version comes from and how it is enforced;
  * every family records a parseable example new-upstream-release version;
  * a family that cannot express a distinct version for an unchanged-upstream
    rebuild is a finding, and so is a family whose rebuild counter is shared
    with its packaging revision (ambiguous, but at least expressible).

Exit status: 0 when there are no errors, 1 when there is at least one error,
or when ``--strict`` is given and there is at least one finding or warning.

Usage:
    python3 scripts/check-printer-app-versions.py
    python3 scripts/check-printer-app-versions.py --strict
    python3 scripts/check-printer-app-versions.py --family hplip-printer-app \
        --candidate 3.26.4-1 --format json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_CONTRACT = (
    Path(__file__).resolve().parent.parent
    / "docs"
    / "skills"
    / "release-promotion"
    / "references"
    / "printer-app-version-grammar.json"
)

REBUILD_SLOTS = ("none", "shared", "suffix")
UPSTREAM_FORMS = ("semver", "calendar-date")
REQUIRED_FIELDS = (
    "family",
    "repo",
    "upstream_form",
    "upstream_source",
    "grammar",
    "rebuild_slot",
    "version_source",
    "enforcement",
    "published_tags",
    "examples",
)


def finding(severity, family, message):
    """Build one finding record."""
    return {"severity": severity, "family": family, "message": message}


def load_contract(path=DEFAULT_CONTRACT):
    """Load and minimally validate the recorded version contract."""
    with open(path, encoding="utf-8") as handle:
        contract = json.load(handle)
    if "families" not in contract:
        raise ValueError(f"{path}: no 'families' key")
    return contract


def family_grammar(entry):
    """Compile a family grammar.

    Raises ``re.error`` when the recorded grammar is not a valid regular
    expression, and ``KeyError`` when the entry records no grammar at all.
    """
    return re.compile(entry["grammar"])


def parse_version(entry, version, grammar=None):
    """Return the named components of ``version`` under ``entry``'s grammar.

    ``grammar`` may be an already compiled pattern, so callers that check many
    versions against one family compile it once.

    Raises ValueError when the version does not match the family grammar or
    when a captured group is empty.
    """
    if grammar is None:
        grammar = family_grammar(entry)
    match = grammar.match(version)
    if not match:
        raise ValueError(
            f"{version!r} does not match the {entry['family']} grammar "
            f"{entry['grammar']}"
        )
    return {key: value for key, value in match.groupdict().items() if value}


def check_family(entry):
    """Check one family entry. Returns a list of findings."""
    family = entry.get("family", "<unnamed>")
    findings = []
    for field in REQUIRED_FIELDS:
        if field not in entry:
            findings.append(finding("error", family, f"missing required field {field!r}"))
    if findings:
        return findings

    try:
        grammar = family_grammar(entry)
    except re.error as exc:
        findings.append(finding("error", family, f"invalid grammar: {exc}"))
        return findings

    if entry.get("upstream_form") not in UPSTREAM_FORMS:
        findings.append(
            finding(
                "error",
                family,
                f"upstream_form {entry.get('upstream_form')!r} is not one of {list(UPSTREAM_FORMS)}",
            )
        )
    if entry.get("rebuild_slot") not in REBUILD_SLOTS:
        findings.append(
            finding(
                "error",
                family,
                f"rebuild_slot {entry.get('rebuild_slot')!r} is not one of {list(REBUILD_SLOTS)}",
            )
        )

    for tag in entry.get("published_tags", []):
        try:
            parse_version(entry, tag, grammar)
        except ValueError as exc:
            findings.append(finding("error", family, f"published tag invalid: {exc}"))

    if not entry.get("published_tags") and not entry.get("published_tags_note"):
        findings.append(
            finding(
                "error",
                family,
                "no published tags and no published_tags_note explaining the hold",
            )
        )

    examples = entry.get("examples", {})
    if not examples.get("upstream_release"):
        findings.append(
            finding("error", family, "examples.upstream_release is missing")
        )
    else:
        try:
            parse_version(entry, examples["upstream_release"], grammar)
        except ValueError as exc:
            findings.append(
                finding("error", family, f"examples.upstream_release invalid: {exc}")
            )

    if "rebuild" in examples:
        try:
            parse_version(entry, examples["rebuild"], grammar)
        except ValueError as exc:
            findings.append(finding("error", family, f"examples.rebuild invalid: {exc}"))
        upstream_release = examples.get("upstream_release")
        if upstream_release and examples["rebuild"] == upstream_release:
            findings.append(
                finding(
                    "error",
                    family,
                    "examples.rebuild and examples.upstream_release are the same string, "
                    "so the two transitions cannot be told apart",
                )
            )

    slot = entry.get("rebuild_slot")
    if slot == "none":
        findings.append(
            finding(
                "finding",
                family,
                "no rebuild slot: an unchanged-upstream FSDK rebuild has no distinct "
                "immutable version, because the upstream version is the whole version "
                "and the tag cannot be republished",
            )
        )
        if "rebuild" in examples:
            findings.append(
                finding(
                    "error",
                    family,
                    "examples.rebuild is recorded but rebuild_slot is 'none'",
                )
            )
    elif slot == "shared":
        findings.append(
            finding(
                "finding",
                family,
                "rebuild counter is shared with the packaging revision, so an "
                "unchanged-upstream rebuild and an upstream packaging bump are "
                "indistinguishable in the version string",
            )
        )
        if "rebuild" not in examples:
            findings.append(
                finding(
                    "error",
                    family,
                    "rebuild_slot is 'shared' but no examples.rebuild is recorded",
                )
            )
    elif slot == "suffix" and "rebuild" not in examples:
        findings.append(
            finding(
                "error",
                family,
                "rebuild_slot is 'suffix' but no examples.rebuild is recorded",
            )
        )

    return findings


def check_contract(contract):
    """Check every family in the contract plus cross-family tag uniqueness."""
    findings = []
    seen = {}
    for entry in contract.get("families", []):
        findings.extend(check_family(entry))
        family = entry.get("family", "<unnamed>")
        for tag in entry.get("published_tags", []):
            if tag in seen:
                # Tags live in per-image namespaces (each printer-app has its
                # own registry), so the same version string can legitimately
                # appear in more than one family. Report as a warning, not an
                # error: a contract that lists the same tag twice may be
                # confusing but it is not a violation.
                findings.append(
                    finding(
                        "warning",
                        family,
                        f"published tag {tag} is also claimed by {seen[tag]}",
                    )
                )
            else:
                seen[tag] = family
    return findings


def find_family(contract, family):
    """Return the contract entry for ``family``, or None."""
    for entry in contract.get("families", []):
        if entry.get("family") == family:
            return entry
    return None


def check_candidate(contract, family, version):
    """Check one candidate version string against a named family's grammar.

    Returns a list of findings; empty means the version is valid for that
    family.
    """
    entry = find_family(contract, family)
    if entry is None:
        return [finding("error", family, f"unknown family {family!r}")]
    if "grammar" not in entry:
        return [finding("error", family, "missing required field 'grammar'")]
    try:
        grammar = family_grammar(entry)
    except re.error as exc:
        return [finding("error", family, f"invalid grammar: {exc}")]
    try:
        parse_version(entry, version, grammar)
    except ValueError as exc:
        return [finding("error", family, str(exc))]
    return []


def render_text(findings):
    """Render findings as one line each."""
    lines = []
    for item in findings:
        lines.append(f"{item['severity']}: {item['family']}: {item['message']}")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--contract", default=str(DEFAULT_CONTRACT))
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument(
        "--strict", action="store_true", help="treat findings and warnings as failures"
    )
    parser.add_argument("--family", help="check a single family")
    parser.add_argument("--candidate", help="version string to check with --family")
    args = parser.parse_args(argv)

    try:
        contract = load_contract(args.contract)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: cannot read version contract: {exc}", file=sys.stderr)
        return 1

    if args.family or args.candidate:
        if not args.family:
            parser.error("--candidate requires --family")
        if not args.candidate:
            parser.error("--family requires --candidate")
        findings = check_candidate(contract, args.family, args.candidate)
    else:
        findings = check_contract(contract)

    errors = [item for item in findings if item["severity"] == "error"]
    soft = [item for item in findings if item["severity"] == "finding"]
    warnings = [item for item in findings if item["severity"] == "warning"]

    if args.format == "json":
        print(
            json.dumps(
                {
                    "errors": errors,
                    "findings": soft,
                    "warnings": warnings,
                    "strict": bool(args.strict),
                },
                indent=2,
            )
        )
    else:
        if findings:
            print(render_text(findings))
        else:
            print("printer-app version contract: OK")
        print(
            f"{len(errors)} error(s), {len(soft)} finding(s), "
            f"{len(warnings)} warning(s)"
            f"{' (strict)' if args.strict else ''}"
        )

    if errors:
        return 1
    if (soft or warnings) and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
