# Pre-Commit Conventions

Part of [ci-tooling](../SKILL.md) — the auto-fix loop, AI commit attribution, the docs-hygiene hooks, and the two hooks in `.pre-commit-config.yaml` that currently guard nothing.

---

## pre-commit auto-fix hooks modify files and abort the commit

When a pre-commit hook fixes a file in place, treat that run as a **failed gate that also produced a patch**. The hook output typically ends with `Files were modified by this hook`, the commit does not proceed, and you must review + re-stage the modified files before retrying.

Typical loop:

```bash
pre-commit run --all-files
git diff -- docs/skills/ci-tooling/SKILL.md   # or inspect all modified files
git add <fixed-files>
pre-commit run --all-files
```

Do **not** assume the original staged snapshot is still current after an auto-fix hook. Re-stage the files the hook touched, or the next commit attempt will either fail again or commit an older index state than the working tree.

---

## AI commit attribution (convention, not CI-gated)

AI-authored commits should carry both trailers as a convention:

```
Assisted-by: Claude Sonnet 4.6 via pi
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

The `validate.yml` attribution check was removed — it is **not** a CI gate. A missing or single trailer does not block your PR. Including both trailers is the expected convention but will never cause `exit 1`.

Note: `pi`-authored commits use `Assisted-by: <Model> via pi`. The `Co-authored-by: Copilot` trailer is optional but conventional.

---

## Docs hygiene pre-commit checks

`.pre-commit-config.yaml` defines four `language: system` local hooks that protect the agent docs structure. All four are `always_run: true` with `pass_filenames: false`.

| Hook id | Entry | What it checks |
|---|---|---|
| `check-skill-frontmatter` | `bash scripts/check-skill-frontmatter.sh` | Front-matter keys and values. The authoritative list of what it enforces is [`write-a-skill.md`](../../write-a-skill.md) § What actually validates a skill; do not restate it here. |
| `check-skill-index` | `bash scripts/check-skill-index.sh` | `docs/SKILL.md` links to every skill file in `docs/skills/`. |
| `check-doc-links` | `python3 scripts/check-doc-links.sh` | Every relative `.md` link in `docs/` resolves to an existing file. |
| `check-skill-catalog` | `python3 scripts/generate_skill_index.py --check` | `docs/skills/index.json` is regenerable-clean from the files on disk. |

`scripts/check-doc-links.sh` is a Python script despite the `.sh` name — that is why its entry is `python3`, not `bash`. Do not "fix" the entry to `bash`.

These are **hygiene gates**, not blocking CI workflow gates, consistent with the factory rule that process conventions are agent-enforced. The front-matter size budget is soft at 200 lines and hard at 500 lines; oversized legacy skills are a burn-down list — migrate them to the per-skill directory layout (`docs/skills/<name>/SKILL.md` + `references/`) in the same change that touches them. See `write-a-skill.md`.

---

## Two hooks that currently guard nothing

Both are configured and both are permanent no-ops in this repo. Know this before you cite either as enforcement.

**`check-jsonschema` / "Validate release-state.yaml"** is scoped `files: ^\.github/release-state\.yaml$`. There is no `.github/release-state.yaml` in `common` — so the hook never selects a file and `pre-commit run --all-files` never invokes it. If you ever add that file, the schema is pinned by immutable raw URL to a specific `projectbluefin/actions` commit (`e39c9470…`), which is the right shape: pin both the hook `rev` and the schema URL so `actions/main` cannot drift the schema underneath a green run.

**`no-floating-action-tags`** exempts `projectbluefin/*` via negative lookahead, and no ref in this repo uses that exemption. See [sha-pinning.md](sha-pinning.md).

---

## Skill drift detection

**Retired across the factory. Do not re-add `skill-drift.yml` in any repo.** The
retirement record — the stub reusable that returned a fake green tick to five
repos, and why bespoke per-convention CI jobs are banned — lives in
[`skill-improvement.md`](../../skill-improvement.md#why-there-is-no-ci-gate)
§ Why there is no CI gate. `common` never wired it up.
