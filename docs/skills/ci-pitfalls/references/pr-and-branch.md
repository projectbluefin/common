# PR and Branch — ci-pitfalls

Part of [ci-pitfalls](../SKILL.md) — branch-from-target rule, bulk SHA bump regex trap, and actions PR consumer validation evidence format.

---

## ⛔ Branch-from-target rule (merge queue repos)

Every projectbluefin repo runs a merge queue. A PR with merge conflicts or a dirty diff **cannot enter the queue** and stalls work for everyone on that branch.

**Root cause of dirty diffs:** Creating a branch from `main` when the PR targets `testing`. The `testing` branch in `bluefin`, `bluefin-lts`, and `dakota` accumulates CI and release-pipeline commits that never land on `main`. A branch created from `main` is missing those commits — the PR diff shows them all as "deleted".

### Branch targets

| Repo | PR targets | Branch FROM |
|---|---|---|
| `bluefin`, `bluefin-lts`, `dakota` | `testing` | `testing` |
| `common`, `actions`, `knuckle` | `main` | `main` |

### Mandatory pre-open gate (every PR)

```bash
TARGET=testing   # or main — match the PR target
git fetch origin

# 1. Only your files in the diff
git diff --name-only origin/${TARGET}..HEAD
# If unintended files appear → wrong base. Recreate from origin/${TARGET}.

# 2. No merge conflicts
git merge --no-commit --no-ff origin/${TARGET}
git merge --abort 2>/dev/null || true

# 3. No known red CI
# Do not open a PR if local tests fail. The merge queue will reject it.
just check && pre-commit run --all-files
```

### Recreating a branch with the wrong base

```bash
# Identify your commits
git log --oneline origin/${TARGET}..HEAD

# Recreate from the correct base
git checkout -b <branch>-clean origin/${TARGET}
git cherry-pick <your-sha1> <your-sha2> ...
```

*Observed violation: `projectbluefin/dakota` PR was created from `main` targeting `testing`. The `testing` branch had 20+ diverged commits — 12 workflow files, Justfile changes, and BST element updates all appeared as "deleted" in the diff. PR closed; clean PR recreated from `testing`.*

---

## Bulk SHA bump — regex multiline trap

When scripting a bulk `projectbluefin/actions` SHA pin update across workflow files, Python's `[^@]*` character class matches newlines. If the regex is `(projectbluefin/actions[^@]*)@([a-f0-9]{40})`, a line containing `projectbluefin/actions` in a **comment** (no `@` sign) will extend the match across subsequent lines until the next `@`, inadvertently replacing the SHA of unrelated actions (e.g., `actions/checkout`).

**Safe approach — line-scoped replacement:**

```python
import re

def bump_sha(content: str, new_sha: str) -> str:
    lines = content.splitlines(keepends=True)
    result = []
    for line in lines:
        # Only replace if projectbluefin/actions is on THIS line
        if 'projectbluefin/actions' in line:
            line = re.sub(
                r'(projectbluefin/actions[^@\n]*)@([a-f0-9]{40})',
                rf'\g<1>@{new_sha}',
                line,
            )
        result.append(line)
    return ''.join(result)
```

Key difference: `[^@\n]*` (excludes newline) instead of `[^@]*`.

**Verify after any bulk bump:**

```bash
# Find lines using the new SHA that are NOT from projectbluefin/actions
grep -rn "$NEW_SHA" .github/workflows/ | grep -v 'projectbluefin/actions'
```

If any non-`projectbluefin/actions` lines appear, restore their original SHAs.

---

## projectbluefin/actions PR — consumer validation evidence

Any PR to `projectbluefin/actions` that modifies an action or reusable workflow (`reusable-*.yml`, composite action `action.yml`) triggers the **Consumer Validation** CI check. The PR body must contain exactly these three lines:

```
Consumer PR: https://github.com/projectbluefin/{bluefin|bluefin-lts|dakota}/pull/{N}
Consumer CI run: https://github.com/projectbluefin/{repo}/actions/runs/{N}
Out-of-org consumer impact: {explanation or "N/A"}
```

### ⛔ Consumer PR body format — colon syntax is REQUIRED

The `check-consumer-contract.yml` regex matches `^Consumer PR:` **literally** (colon, no space before colon, space after). Using a Markdown heading silently fails:

```markdown
# WRONG — regex does not match a heading; check silently fails
## Consumer PR
https://github.com/projectbluefin/bluefin/pull/N

# CORRECT — colon format on one line
Consumer PR: https://github.com/projectbluefin/bluefin/pull/N
Consumer CI run: https://github.com/projectbluefin/bluefin/actions/runs/N
```

Same rule applies to `Consumer CI run:`. The CI run URL must point to a **passing** run in the consumer repo (bluefin, bluefin-lts, or dakota) that exercises the changed action.

Leaving these lines blank or using placeholder text (`TODO`, `TBD`, `<!-- ...-->`) fails the check. The CI error is: `Consumer validation evidence is required for action or reusable workflow changes. See docs/skills/consumer-validation.md.`
