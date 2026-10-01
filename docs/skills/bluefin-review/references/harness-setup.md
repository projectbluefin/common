# Bluefin Review — Harness Setup

Harness wiring for [`../SKILL.md`](../SKILL.md). The skill is plain Markdown
and works in any agent harness. This file covers model routing, which is where
the cost of a run is decided.

## Target profile

| Seat | Model | Why |
|---|---|---|
| Planner (session start) | `github-copilot/claude-opus-5.5:medium` | Scope, policy tables, clusters, landing order |
| Main loop after handoff | `github-copilot/gemini-3.8-flash:high` | Lane verification and ledger updates are high-volume, low-judgment |
| Lanes (`bluefin-review` agent) | `github-copilot/gemini-3.8-flash:high` | Rebase, test, push, merge |
| Advisor | `github-copilot/claude-opus-5.5:medium` | Judgment calls on the main session |

Substitute any strong/fast pair your provider offers. Keep roles, not model
names, in shared files.

## omp

`~/.omp/agent/config.yml`:

```yaml
modelRoles:
  default: github-copilot/claude-opus-5.5:medium
  smol: github-copilot/gemini-3.8-flash:high
  advisor: github-copilot/claude-opus-5.5:medium
advisor:
  enabled: true
prewalk:
  enabled: true
```

- `prewalk.enabled` arms a one-shot handoff from `@default` to `@smol`. It
  opens on the first successful `todo` call and switches after the first
  completed `edit` or `write`. The skill's plan phase ends with `todo init` and
  the ledger `write`, so the switch lands before any lane work.
- If `default` and `smol` resolve to the same model and thinking level,
  prewalk is a no-op and the whole run bills at that one model.
- Lanes: the repo ships `.omp/agents/bluefin-review.md` with
  `model: "@smol"`. Without it, a lane inherits the parent's active model; a
  lane spawned before the handoff runs on the planner.
  `task.agentModelOverrides.bluefin-review` overrides that per user.
- Subagents get no advisor unless their frontmatter or `task.agentAdvisor`
  opts in. Leave lanes without one; one advisor on the main session is the
  budget.
- Next batch: `/prewalk restart` returns to `@default` and re-arms.
- Prewalk arms once, at session start, and disarms after its handoff. If you
  change `modelRoles` or switch models mid-session, start a new session or run
  `/prewalk` to re-arm it before `/bluefin-review`.
- Confirm the handoff right after the ledger's first write: the footer model
  should read the `@smol` model, or the session log should show a
  `model_change` to it. If it still shows the planner, run `/prewalk` or switch
  with `/model`.
- Startup overrides: `omp --no-prewalk` disables it for one session;
  `omp --prewalk-into <model-or-role>` picks another target.

Check the live values before a run:

```bash
omp config get modelRoles
omp config get prewalk.enabled
```

## pi

pi loads the skill from `.agents/skills/` and the `/bluefin-review` template
from `.pi/prompts/` once the project is trusted. pi has no prewalk: start on
the planning model, then switch with `/model` to the fast model after the
ledger's first write. pi has no built-in `task` tool either. Without a
subagent extension, run the lanes sequentially in the main session.

## Other harnesses

| Harness | Skill | Command |
|---|---|---|
| Claude Code | `.claude/skills/bluefin-review` | `.claude/commands/bluefin-review.md` |
| GitHub Copilot | `.github/skills/bluefin-review` | — |
| Codex, Gemini CLI, OpenCode, others reading the Agent Skills layout | `.agents/skills/bluefin-review` | — |

None of these have a prewalk equivalent. Switch models manually at the handoff
point, or pin the planner and lane models separately if the harness supports
per-agent models.

## Layout

Every harness path is a relative symlink into `docs/`, so there is one copy:

| Path | Target |
|---|---|
| `.agents/skills/bluefin-review` | `docs/skills/bluefin-review/` |
| `.claude/skills/bluefin-review` | `docs/skills/bluefin-review/` |
| `.github/skills/bluefin-review` | `docs/skills/bluefin-review/` |
| `.pi/prompts/bluefin-review.md` | `docs/harness/bluefin-review-command.md` |
| `.claude/commands/bluefin-review.md` | `docs/harness/bluefin-review-command.md` |
| `.omp/commands/bluefin-review.md` | `docs/harness/bluefin-review-command.md` |
| `.omp/agents/bluefin-review.md` | `docs/harness/bluefin-review-omp-agent.md` |

The command and agent files live outside the skill directory on purpose.
Harnesses that scan skill folders recursively would pick up any `.md` with a
`description` front-matter key as a second skill of the same name.

To use the skill outside a `common` checkout, link it user-wide:

```bash
ln -s ~/src/common/docs/skills/bluefin-review ~/.agents/skills/bluefin-review
```
