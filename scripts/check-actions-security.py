#!/usr/bin/env python3
"""Validate GitHub Actions workflows against the Project Bluefin Actions Security Baseline.

Checks:
1. Top-level permissions: Workflows must declare top-level 'permissions:' (typically 'permissions: {}'
   or explicit minimal grants) to fail closed.
2. SHA pinning: All external (third-party) actions must be pinned to a full 40-character commit SHA
   with a version comment.
3. pull_request_target restrictions: Workflows triggered by pull_request_target must not perform
   untrusted checkouts of PR head refs.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Tuple

try:
    import yaml
except ImportError:
    yaml = None

SHA_RE = re.compile(r"^[0-9a-f]{40}$", re.IGNORECASE)
USES_RE = re.compile(r"^\s*(?:-\s+)?uses:\s*([^\s#]+)(.*)$")
UNTRUSTED_CHECKOUT_RE = re.compile(
    r"github\.event\.pull_request\.head\.(?:sha|ref)", re.IGNORECASE
)


class SecurityIssue:
    def __init__(
        self,
        filename: str,
        line_no: int | None,
        message: str,
        severity: str = "ERROR",
    ):
        self.filename = filename
        self.line_no = line_no
        self.message = message
        self.severity = severity

    def __str__(self) -> str:
        loc = f"{self.filename}:{self.line_no}" if self.line_no else self.filename
        return f"{self.severity}: [{loc}] {self.message}"


def check_workflow_file(path: Path) -> List[SecurityIssue]:
    issues: List[SecurityIssue] = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    # Parse YAML if available
    workflow_data = None
    if yaml is not None:
        try:
            workflow_data = yaml.safe_load(content)
        except Exception as e:
            issues.append(SecurityIssue(str(path), None, f"YAML parse error: {e}"))
            return issues

    # 1. Check top-level permissions
    has_top_level_perms = False
    top_level_perm_issues: List[str] = []
    if workflow_data is not None and isinstance(workflow_data, dict):
        if "permissions" in workflow_data and workflow_data["permissions"] is not None:
            has_top_level_perms = True
            perms = workflow_data["permissions"]
            if perms == "write-all":
                top_level_perm_issues.append(
                    "Top-level 'permissions: write-all' is forbidden. "
                    "Baseline requires fail-closed top-level permissions (e.g. 'permissions: {}' or explicit scoped permissions)."
                )
    else:
        # Fallback line-based check: look for top-level permissions: at col 0
        for line in lines:
            m_top = re.match(r"^permissions:\s*(.*)", line)
            if m_top:
                has_top_level_perms = True
                val = m_top.group(1).strip()
                if val == "write-all":
                    top_level_perm_issues.append(
                        "Top-level 'permissions: write-all' is forbidden. "
                        "Baseline requires fail-closed top-level permissions (e.g. 'permissions: {}' or explicit scoped permissions)."
                    )
                break

    if not has_top_level_perms:
        issues.append(
            SecurityIssue(
                str(path),
                None,
                "Missing top-level 'permissions:' declaration. "
                "Baseline requires explicit top-level permissions (e.g. 'permissions: {}') "
                "to fail closed on unconfigured jobs.",
            )
        )
    for issue_msg in top_level_perm_issues:
        issues.append(SecurityIssue(str(path), None, issue_msg))

    # 2. Check uses: pinning and version comments
    for i, line in enumerate(lines, 1):
        m = USES_RE.match(line)
        if not m:
            continue
        full_ref = m.group(1).strip()
        comment = m.group(2).strip()

        # Local workflow calls (e.g. ./.github/workflows/...) are exempt
        if full_ref.startswith("./"):
            continue

        # Split action/repo from ref
        if "@" in full_ref:
            action_name, ref = full_ref.split("@", 1)
        else:
            action_name, ref = full_ref, ""

        # First-party projectbluefin/* actions/workflows are exempt from external SHA pinning
        # (they use managed floating tags like @v1 or @main per policy)
        if action_name.startswith("projectbluefin/"):
            continue

        # External third-party actions must be pinned to 40-char SHA
        if not ref or not SHA_RE.match(ref):
            issues.append(
                SecurityIssue(
                    str(path),
                    i,
                    f"External action '{action_name}' must be pinned to a full 40-character commit SHA "
                    f"(found ref '{ref}'). Floating tags are prohibited by baseline.",
                )
            )
        elif not comment.startswith("#"):
            issues.append(
                SecurityIssue(
                    str(path),
                    i,
                    f"External action '{full_ref}' is pinned to a SHA but missing a human-readable "
                    f"version comment (e.g. '# v4').",
                    severity="WARNING",
                )
            )

    # 3. Check pull_request_target trigger and untrusted checkouts
    is_pr_target = False
    if workflow_data is not None and isinstance(workflow_data, dict):
        on_trigger = (
            workflow_data.get("on")
            if "on" in workflow_data
            else workflow_data.get(True)
        )
        if isinstance(on_trigger, str) and on_trigger == "pull_request_target":
            is_pr_target = True
        elif isinstance(on_trigger, list) and "pull_request_target" in on_trigger:
            is_pr_target = True
        elif isinstance(on_trigger, dict) and "pull_request_target" in on_trigger:
            is_pr_target = True
    else:
        for line in lines:
            if re.search(r"^\s*(?:on:\s*)?pull_request_target(?:\s*:|$)", line):
                is_pr_target = True
                break

    if is_pr_target:
        for i, line in enumerate(lines, 1):
            if UNTRUSTED_CHECKOUT_RE.search(line):
                issues.append(
                    SecurityIssue(
                        str(path),
                        i,
                        "Dangerous untrusted PR checkout detected in 'pull_request_target' workflow. "
                        "Do not check out untrusted pull request code into a privileged runner context.",
                    )
                )

    return issues


def scan_workflows_dir(workflows_dir: Path) -> Tuple[List[SecurityIssue], int]:
    all_issues: List[SecurityIssue] = []
    workflow_files = sorted(
        list(workflows_dir.glob("*.yml")) + list(workflows_dir.glob("*.yaml"))
    )
    for wf in workflow_files:
        issues = check_workflow_file(wf)
        all_issues.extend(issues)
    return all_issues, len(workflow_files)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify GitHub Actions workflows conform to Project Bluefin security baseline."
    )
    parser.add_argument(
        "--workflows-dir",
        type=Path,
        default=Path(".github/workflows"),
        help="Path to workflows directory (default: .github/workflows)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as errors",
    )
    args = parser.parse_args()

    if not args.workflows_dir.is_dir():
        print(f"Error: {args.workflows_dir} is not a directory", file=sys.stderr)
        return 1

    issues, count = scan_workflows_dir(args.workflows_dir)

    errors = [i for i in issues if i.severity == "ERROR"]
    warnings = [i for i in issues if i.severity == "WARNING"]

    for issue in issues:
        print(str(issue))

    if args.strict:
        errors.extend(warnings)

    print(
        f"\nScanned {count} workflow(s): {len(errors)} error(s), {len(warnings)} warning(s)."
    )

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
