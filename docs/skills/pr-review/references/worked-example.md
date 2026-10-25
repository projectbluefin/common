# Worked Example — Backlog Review Session

> An illustrative session, not current state. The backlog shown is from
> 2026-08-06.

## Dossier (batch 1 of 2)

**1 / 5 — PR #936** `fix(report): preserve external queue preferences`
Author: joshyorko · Age: 2h · Size: +80 / -5 · Effort: **small**
Files: `.github/workflows/unit-tests.yml`, `Justfile`, `docs/SKILL.md`,
`system_files/bluefin/usr/libexec/bonedigger-report`,
`tests/test_bonedigger_report.bats`
Blast radius: bluefin only + CI + docs
CI: validate=STALE-RED (branch predates the fix on `main`) · build(x86_64)=pass · test=pass
Mergeable: BEHIND · Linked issue: —
Summary: Preserves caller-supplied queue preference in the bonedigger report script.

**2 / 5 — PR #934** `fix: guard ublue-fastfetch with command -v check`
Author: kylerankin · Age: 1d · Size: +5 / -0 · Effort: **trivial**
Files: `system_files/shared/usr/bin/ublue-fastfetch`
Blast radius: **ALL variants** (`system_files/shared/`)
CI: validate=STALE-RED (branch predates the fix on `main`) · build(x86_64)=pass
Mergeable: BEHIND · Linked issue: #550
Summary: Adds a `command -v fastfetch` guard so the script exits cleanly.

⚠️ COMPETING PAIR: #934 ↔ #931 (shared closing issue: #550)

**3 / 5 — PR #933** `fix(sec): add sigstoreSigned policy for ghcr.io/projectbluefin`
Author: hanthor · Age: 1d · Size: +31 / -0 · Effort: **needs-real-attention**
Files: `system_files/shared/etc/containers/policy.json` + signing certs
Blast radius: **ALL variants** — security policy
CI: build(x86_64)=pass · Compose=pass
Mergeable: CLEAN · Label: `3-human-queue`
Summary: Adds sigstore signature verification for projectbluefin images.

**4 / 5 — PR #932** `fix: add consistent bootc sudo policy`
Author: castrojo · Age: 1d · Size: +1 / -0 · Effort: **trivial**
Files: `system_files/shared/etc/sudoers.d/001-bootc`
Blast radius: **ALL variants**
CI: build(x86_64)=pass
Mergeable: CLEAN
Summary: Adds a sudoers drop-in for consistent bootc sudo policy.

**5 / 5 — PR #926** `[quality] add BATS regression coverage for theming hook`
Author: kubestellar-hive [bot] · Age: 3d · Size: +92 / -0 · Effort: **small**
Files: `Justfile`, `docs/TESTING.md`, `tests/test_theming_hook.bats`
Blast radius: tests + docs only
CI: build(x86_64)=pass
Mergeable: CLEAN
Summary: Adds BATS test coverage for the theming setup hook.

---

## Per-PR verdict prompts

```
PR #936 — fix(report): preserve external queue preferences
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge

PR #934 — fix: guard ublue-fastfetch with command -v check
⚠️ COMPETING with #931 (both close #550) — resolve pair first.
Verdict? (merge / close / defer / rebase / changes / open / skip)
> open
[agent shows diff]
> merge (acknowledged: #931 will be deferred)

PR #933 — fix(sec): add sigstoreSigned policy
Verdict? (merge / close / defer / rebase / changes / open / skip)
> changes: Split the cert and rekor key into their own commit for auditability.

PR #932 — fix: add consistent bootc sudo policy
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge

PR #926 — [quality] add BATS regression coverage for theming hook
Verdict? (merge / close / defer / rebase / changes / open / skip)
> merge
```

## Staged action plan

```bash
## Action plan — batch 1

# PR #936 — update branch (stale-red validate), then merge
gh pr update-branch 936
gh pr merge 936 --squash --auto

# PR #934 — update branch (stale-red validate), then merge
gh pr update-branch 934
gh pr merge 934 --squash --auto

# PR #933 — request changes
gh pr review 933 --request-changes --body "Split the cert and rekor key into their own commit for auditability."

# PR #932 — merge (squash via queue)
gh pr merge 932 --squash --auto

# PR #926 — merge (squash via queue)
gh pr merge 926 --squash --auto
```

```
Execute action plan? (gum confirm)
> Yes
```

## Landing report

| PR | Action | Result |
|---|---|---|
| #936 | update-branch + merge | ✅ branch updated, auto-merge enabled |
| #934 | update-branch + merge | ✅ branch updated, auto-merge enabled |
| #933 | changes | ✅ review posted |
| #932 | merge | ✅ auto-merge enabled |
| #926 | merge | ✅ auto-merge enabled |
