# Red Check Triage

Companion to [`../SKILL.md`](../SKILL.md). A red check is not evidence against
a PR until you know which kind it is. Most reds in this repo are environmental.
Classify before presenting a card, and never park a PR in `3-human-queue` on an
unclassified red.

## Failure kinds

| Kind | Meaning | Action |
|---|---|---|
| **stale-red** | `validate` red on a lint/index step whose fix already landed on `main` — most often `check-skill-index` reporting a missing `docs/SKILL.md` link | Confirm the fix is on `main`, then `gh pr update-branch <N>` |
| **infra-flake** | A check died on a network or API error, not an assertion — HTTP 403/429/5xx, DNS, registry timeouts | Re-run, then file the fragility. See below |
| **fork-expected** | `Compose PR test image` red on a fork PR | Expected — the Actions token cannot push to `ghcr.io/projectbluefin/*` from fork context |
| **bad-title** | `validate` red on the "Validate PR title (Conventional Commits)" step only | Needs a Conventional Commits prefix. Common on bot/orchestrator PRs titled `[architect] ...`, `[quality] ...`, `[strategist] ...`, `[sec-check] ...`, `[scanner] ...`. The edit alone will not turn it green — see the retitle invariant in `SKILL.md` (close and reopen required) |
| **real failure** | Anything else | Report to human as blocking |

## Identify the failing step first

`validate` is one job with several steps, and a title violation looks identical
to a stale index in the rollup:

```bash
gh run view "$(gh pr checks <N> --json name,link \
  --jq '.[]|select(.name=="validate")|.link' | grep -oP '(?<=runs/)\d+')" --log-failed \
  | grep -oP '(?<=\t)[^\t]+(?=\t\d{4}-)' | sort -u
```

Card CI line example:
`CI: validate=STALE-RED(skill-index) · build(x86_64)=pass · test=pass`

## Infra-flake vs real failure

A traceback ending in `HTTPError`, `URLError`, `TimeoutError`, or a registry
5xx is an infrastructure failure. It says nothing about the diff. Treat a
one-line dependency bump failing a network-dependent check as
flake-until-proven-otherwise.

The cheapest proof is **correlation**: if the same check failed on unrelated
branches in the same few minutes, it is the environment, not any one PR.

```bash
gh run list --workflow "Validate PR" --limit 15 \
  --json conclusion,headBranch,createdAt \
  --jq '.[]|"\(.conclusion)\t\(.headBranch)\t\(.createdAt)"'
```

Merge-queue branches (`gh-readonly-queue/main/pr-*`) failing alongside a PR
branch at the same timestamp is conclusive — those carry unrelated diffs.

Re-running is the correct response and not a workaround to apologise for. What
*is* required is filing the underlying fragility as an issue, so the flake
becomes a fixable defect instead of recurring folklore. A check that hard-fails
the whole job on any non-404 HTTP status is a defect in the check.

## gh CLI traps

**Multi-line issue and comment bodies belong in a file.** Passing prose to
`--body` inline runs it through the shell first, so backticks become command
substitution and parentheses become syntax errors — unavoidable when the body
contains code fences or tracebacks.

```bash
cat > /tmp/body.md <<'EOF'
...markdown with `backticks`, (parens), and code fences...
EOF
gh issue create --title "..." --body-file /tmp/body.md
```

The quoted heredoc delimiter (`<<'EOF'`, not `<<EOF`) is what disables
expansion. Without the quotes the trap returns.

**Keep `--jq` expressions trivial.** `gh` has no `-c` flag, and array-membership
idioms like `[a,b]|index(.number)` error rather than filtering. For anything
beyond field selection, dump to a file and process it with `python3`.
