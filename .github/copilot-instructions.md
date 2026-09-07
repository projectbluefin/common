# bluefin-common — Copilot Instructions

## 🚫 ABSOLUTE PROHIBITION — ublue-os org

**NEVER write to any `ublue-os/*` repository.** Read-only `gh api` calls are
allowed. If a task requires `ublue-os` write access, stop and tell the human.

## Operating contract

Read [`AGENTS.md`](../AGENTS.md) for the full repo contract — build commands,
PR rules, mandatory gates, and boundaries.

## Skill routing

Use [`docs/SKILL.md`](../docs/SKILL.md) or run `just skill <query>` to find the
skill for your task, then load only that skill file from [`docs/skills/`](../docs/skills/).

## MCP integration

The public Project Bluefin Model Context Protocol endpoint is configured in
`.vscode/mcp.json` and `.cursor/mcp.json` (`https://mcp.projectbluefin.io/mcp`).
Query `search_knowledge` for org patterns, `get_factory_status` / `get_work_queue`
for live Hive state, and `get_quickstart` / `get_repository_map` for onboarding.
