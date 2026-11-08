# Pre-commit conventions

Part of [CI tooling](../SKILL.md). The hook configuration is
[`.pre-commit-config.yaml`](../../../../.pre-commit-config.yaml).

## Auto-fixes

`Files were modified by this hook` means the run failed and changed files.
Review those changes, re-stage the affected files, then rerun
`pre-commit run --all-files`. Do not commit the older staged snapshot.

## Attribution

Follow the current repository contract; use the actual model and runtime,
not attribution copied from an example. Attribution is not a CI gate.

## Release-state schema

The `check-jsonschema` hook validates `.github/release-state.yaml` when that
file exists. Pin both the hook revision and the schema URL to immutable
commits; a floating schema can silently change validation between runs.
No matching file means the hook is skipped.

## Shipped agent bundle

`check-agent-bundle` validates the on-device skills shipped under
`system_files/shared/usr/share/ublue-os/agent/`. After editing a skill with
`scope: on-device`, run:

```bash
python3 scripts/generate_skill_index.py --write
```

Commit the regenerated bundle with its source. Documentation formatting,
mandatory skill updates, and repository-wide skill catalogs are not gates.
