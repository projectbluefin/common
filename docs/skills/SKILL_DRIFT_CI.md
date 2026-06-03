---
title: "Skill Drift CI: Keeping Documentation in Sync"
load_when: "Your PR failed the skill-drift check, or you're updating system code and wondering if docs need to change"
categories: ["ci", "documentation", "automation"]
---

# Skill Drift CI — Keeping Documentation in Sync

Load when: The skill-drift check fails, or you're making code changes and wondering if documentation needs updates.

## What is skill drift?

**Skill drift** happens when code changes but the skill documentation doesn't. This creates outdated docs that mislead future contributors and agents.

**Example**:
```
Merge: Change CI workflow from GitHub Actions to Argo Workflows
Code: Update .github/workflows/ci.yml, add argo/ directory
Docs: *forgot to update docs/skills/ci-cd.md*
Result: Next agent reads docs, tries to follow GitHub Actions workflow
        but finds Argo instead → confusion, mistakes, wasted time
```

## How skill-drift CI works

The `skill-drift-check.yml` workflow compares **code changes** to **skill documentation updates** on every PR:

```
PR opened
   │
   ├─ Extract changed files from PR
   │  └─ e.g., ".github/workflows/ci.yml", "build_files/something.sh"
   │
   ├─ Check if changed files match "code paths" patterns
   │  └─ Patterns defined in repo's skill-drift workflow config
   │
   ├─ If code files changed:
   │  └─ Check if skill files in "skill paths" also changed
   │     └─ Patterns: docs/skills/**, AGENTS.md, etc.
   │
   └─ Result:
      ├─ Code + skill files both changed? ✓ PASS
      ├─ Only code changed, no skill updates? ✗ FAIL
      └─ Only skill docs changed? ✓ PASS (new docs are good)
```

## Configuration by Repository

### Common (`projectbluefin/common`)

```yaml
# .github/workflows/skill-drift.yml
code-paths: '[
  "docs/**",
  ".github/workflows/**",
  "system_files/**",
  "*.yaml",
  "*.yml",
  "Justfile"
]'

skill-paths: '[
  "docs/skills/**",
  "docs/qa/**",
  "AGENTS.md"
]'
```

**Meaning**: If you change system files, workflows, or configs, check if the corresponding skill doc needs updating.

### Bluefin-LTS (`projectbluefin/bluefin-lts`)

```yaml
code-paths: '[
  ".github/workflows/**",
  "build_files/**",
  "Justfile",
  "image-versions.yml"
]'

skill-paths: '[
  "docs/skills/**",
  "AGENTS.md"
]'
```

## When the check fails

### Scenario 1: Code changed, but skill docs didn't

**Error message**:
```
skill-drift-check FAILED

Changed files in code-paths:
  ✓ .github/workflows/build.yml
  ✓ build_files/Containerfile

Changed files in skill-paths:
  ✗ (none)

FIX: Update one or more skill docs when you change code files.
     See: docs/skills/
```

**Fix**:

```bash
# Find which skill doc matches your code change
# Examples:
# - Changed .github/workflows/* → update docs/skills/ci-cd.md
# - Changed build_files/* → update docs/skills/build.md
# - Changed Justfile → update docs/skills/justfile.md

# Edit the skill doc
vim docs/skills/ci-cd.md

# Stage and commit
git add docs/skills/ci-cd.md
git commit --amend --no-edit  # amend the previous commit

# Or create a new commit if needed
git commit -m "docs(skills): update CI/CD skill for [your change]"

# Force-push
git push origin --force-with-lease
```

### Scenario 2: Skill docs changed, but code path says "not needed"

**Error message**:
```
skill-drift-check OK

Changed files:
  ✓ docs/skills/my-doc.md (no code changes detected)

NOTE: Skill-only changes are allowed! You are documenting
      newly discovered gaps or clarifications.
```

**No fix needed** — this is allowed. Creating new skill docs without code changes is fine.

### Scenario 3: Code change is truly unrelated to any skill

**When this happens**: You refactor internal code that has no user-facing impact.

**Example**: Rename an internal variable, reorder imports, fix a typo in comments.

**Fix**: Add this to your PR description:

```markdown
## Skill drift waiver

Skill drift CI flagged this PR because:
- Changed `.github/workflows/build.yml`

But this change is internal refactoring (no functionality change):
- Only reordered build step comments
- No new features or behavior changes
- No operator-facing impact

Waiver approved by: [maintainer name]
```

Then reply to the skill-drift check comment with:
```
/skill-drift-waiver [reason]
```

A maintainer will review and may override the check.

## Which skill doc maps to which code?

Use this reference to find the right skill when code changes:

| Code path | Skill doc | What it covers |
|-----------|-----------|----------------|
| `.github/workflows/ci.yml`, `build.yml` | `ci-cd.md` or `build.md` | CI/build pipeline |
| `.github/workflows/e2e*.yml`, test configs | `e2e-ci.md` | Post-merge testing |
| `system_files/**`, `etc/`, `usr/` | System skill (varies) | System configuration |
| `Justfile`, `.just` files | `justfile.md` (if exists) | Just recipes |
| Issue templates, workflows/sync-templates | `bonedigger-templates.md` | Bonedigger template system |
| `.github/CODEOWNERS`, branch protection | `governance.md` | Contributor governance |
| `docs/skills/**` itself | (same file) | Skill documentation itself |

**Not sure?** Look at the skill INDEX:

```bash
cat docs/skills/INDEX.md
# Tells you what each skill covers
```

## Common patterns

### Pattern 1: New workflow step requires user action

**Code change**:
```yaml
# .github/workflows/build.yml
- name: Upload to artifact registry
  run: |
    # NEW: Users must set GCP_PROJECT env var
    gcloud auth activate-service-account --key-file=$GCP_KEY
```

**Skill doc update needed**:
```markdown
# docs/skills/build.md
## Prequisites

| Requirement | How to set |
|---|---|
| `GCP_PROJECT` | `export GCP_PROJECT=my-project` |
```

### Pattern 2: New Justfile recipe

**Code change**:
```just
# Justfile
recipe deploy-to-registry:
    @echo "Deploy to artifact registry..."
    gcloud ...
```

**Skill doc update needed**:
```markdown
# (in appropriate skill doc)
## Justfile recipes

| Recipe | Purpose |
|--------|---------|
| `just deploy-to-registry` | Upload built image to GCP |
```

### Pattern 3: Changed system configuration

**Code change**:
```bash
# system_files/shared/etc/myapp/config.d/default.conf
# CHANGED: new key `feature_flag` added
feature_flag=off
```

**Skill doc update needed**:
```markdown
# docs/skills/system-config.md (or relevant skill)
## Configuration keys

| Key | Default | Purpose |
|-----|---------|---------|
| `feature_flag` | `off` | Enable experimental features |
```

### Pattern 4: Bonedigger integration change

**Code change**:
```yaml
# .github/workflows/bonedigger.yml
with:
  brand_name: "NewBrand"  # CHANGED: custom branding
  custom_label_prefix: "factory/"  # NEW: label namespace
```

**Skill doc update needed**:
```markdown
# docs/skills/bonedigger-lifecycle.md
## Custom configuration

Bonedigger supports custom branding and label prefixes:

| Input | Purpose |
|-------|---------|
| `brand_name` | Display name in pipeline widget |
| `custom_label_prefix` | Namespace for labels |
```

## How to avoid skill drift failures

### Before committing code:

1. **Ask yourself**: "Will another contributor need to understand this change?"
2. **If yes**: Which skill doc should they read?
3. **Update that skill** in the same PR

### Workflow:

```bash
# 1. Make your code change
vim .github/workflows/build.yml

# 2. Identify the matching skill
cat docs/skills/INDEX.md | grep -i build

# 3. Update the skill doc
vim docs/skills/build.md

# 4. Stage both files
git add .github/workflows/build.yml docs/skills/build.md

# 5. Commit together
git commit -m "feat(ci): add new build step

Also update build.md skill doc to document new step."

# 6. Push and open PR
git push origin my-branch
gh pr create ...
```

## Trail of Bits CI (reference)

This skill-drift automation is inspired by **Trail of Bits CI practices** for keeping security documentation, audit logs, and threat models in sync with code changes.

Key principles:

- **Code and docs live together** — if code changes, docs change
- **Automated enforcement** — CI blocks PRs that break parity
- **Clear waivers** — rare exceptions documented and justified
- **Skill index** — central discovery of who-knows-what

See [security-review documentation](https://github.com/projectbluefin/security) for the full trail-of-bits audit model.

## Troubleshooting

### "skill-drift check not running"

**Cause**: Workflow not configured in your repo.

**Fix**:
```bash
# Check if workflow exists
ls .github/workflows/skill-drift.yml

# If missing, add it:
# Copy from another repo or see projectbluefin/actions for template
```

### "Check always fails even after I update docs"

**Cause**: Glob patterns in workflow config don't match your files.

**Fix**:
```yaml
# .github/workflows/skill-drift.yml
# Double-check patterns match your changed files exactly

# Example: if you changed docs/qa/REGRESSION_CONTRACT.md
# Make sure skill-paths includes: "docs/qa/**"

with:
  skill-paths: '["docs/skills/**", "docs/qa/**", "AGENTS.md"]'
```

Then retry the check.

### "I changed docs but check says code changed too"

**Cause**: Glob patterns matched more files than you intended.

**Fix**:
```bash
# List all files the check thinks are "code" files:
git diff origin/main --name-only | while read f; do
  echo "Checking: $f"
  # Does it match code-paths patterns?
done

# If docs/** accidentally in code-paths, fix:
# code-paths: '[".github/**", "build_files/**"]'  # NOT "docs/**"
```

## Integration with other skills

Skill drift ties into:

- **CI/CD skill** — explains which checks run on your PR
- **bonedigger** — documents what happens after code+docs land together
- **Governance** — CODEOWNERS changes should also update governance.md

## See also

- [AGENTS.md](../AGENTS.md) — Central index of all skills (update when adding new skills)
- [INDEX.md](./INDEX.md) — Skills available in this repo
- [Trail of Bits Security Practices](https://trailofbits.com) — Original inspiration for this pattern
