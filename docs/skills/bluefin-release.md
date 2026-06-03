---
name: bluefin-release
description: Bluefin release process — use when cutting a release, generating changelogs, managing stream tags (gts/stable/latest/beta), or understanding the release cadence.
---

# Bluefin Release Skill

## Powerlevel

- **Level:** 1


Manages releases, changelogs, and stream tag progression.

Load with: `cat ~/src/skills/bluefin-release/SKILL.md`

## When to Use

- Cutting a new release for any Bluefin stream (gts/stable/latest/beta)
- Generating changelogs with `just changelogs BRANCH`
- Managing stream tag progression (understanding what moves when)
- Writing or editing GitHub release notes

## When NOT to Use

- Day-to-day code changes that are not a release — use `cat ~/src/skills/bluefin-build/SKILL.md`
- Handling Renovate version bump PRs — use `cat ~/src/skills/bluefin-renovate/SKILL.md`
- ISO promotion as part of a release — also load `cat ~/src/skills/bluefin-iso/SKILL.md`

## How It Works

1. Identify the target stream (gts/stable/latest/beta)
2. Generate changelog: `bash /mnt/skills/user/bluefin-release/scripts/changelog.sh BRANCH`
3. Review and edit changelog
4. Tag and push via GitHub Actions

## Stream Cadence

| Stream | Base | Stability | Notes |
|---|---|---|---|
| `gts` | F43 | Highest | Good Till September — long support |
| `stable` | F44 | High | Current stable Fedora |
| `latest` | F44 | Medium | Tracks latest Fedora |
| `beta` | F44 | Low | Testing upcoming changes |

## Usage

```bash
# Generate changelog for a stream
just changelogs stable
just changelogs stable "optional handwritten notes"
```

**Arguments:**
- `branch` — stream name: `stable`, `gts`, `latest`, `beta`
- `handwritten` — optional additional notes to prepend

## Dispatching a release manually

To publish a release without waiting for a stable rebuild:

```bash
gh workflow run generate-release.yml \
  --repo projectbluefin/bluefin \
  --ref stable \
  --field stream_name='["stable"]'
```

To unblock a broken release when a fix exists on a branch but isn't merged yet, dispatch on the fix branch — `--ref` makes the workflow run using that branch's scripts while GHCR images are already tagged:

```bash
gh workflow run generate-release.yml \
  --repo projectbluefin/bluefin \
  --ref <fix-branch> \
  --field stream_name='["stable"]' \
  --field handwritten="First stable release of Bluefin on Fedora 44."
```

## Output

Changelog in markdown format, ready for GitHub release notes.

## Release Checklist

1. [ ] CI passing on target branch
2. [ ] `just changelogs BRANCH` reviewed and edited
3. [ ] Tag created via GitHub Actions (not manual)
4. [ ] Release notes published
5. [ ] Announcement in appropriate channels

**Bootstrap note:** on the very first release for a stream, `changelogs.py` requires ≥ 2 stable tags in GHCR to compute a diff. If the repo has only 1 tag, ensure the bootstrap fix is present (`get_tags()` returns the single tag as both prev and curr, producing an empty but valid diff).
