# Factory Improvement — CI Patterns and Cross-Repo Dispatch

Part of [factory-improvement](../SKILL.md) — known CI pitfalls and cross-repo dispatch patterns.

---

## Known CI Pitfalls (2026-06-11)

Three patterns that have caused silent CI failures or `startup_failure` across factory repos. See [`docs/skills/ci-pitfalls.md`](../../ci-pitfalls/SKILL.md) for full detail and code examples.

| Pitfall | Symptom | Fix |
|---|---|---|
| **Consumer PR colon format** | `check-consumer-contract.yml` fails silently | PR body must use `Consumer PR: <URL>` (colon format) — NOT a Markdown heading |
| **Caller permissions starvation** | Reusable workflow job shows `startup_failure` with no output | Caller `permissions:` block must include the union of all permissions the reusable jobs need |
| **`workflow_run` name mismatch** | Post-merge e2e gate always skips | `workflow_run.workflows:` must match the **exact** `name:` field of the target YAML — verify it produces the artifact being tested |

---

## Cross-Repo Dispatch Patterns

When dispatching workflows across repos (e.g., `execute-release.yml` → `iso`), `GITHUB_TOKEN` **cannot** create `repository_dispatch` events on other repositories. Use a GitHub App installation token:

```yaml
- name: Generate dispatch token
  id: app-token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.ISO_DISPATCH_APP_ID }}
    private-key: ${{ secrets.ISO_DISPATCH_PRIVATE_KEY }}
    repositories: iso

- name: Dispatch
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: gh api repos/projectbluefin/iso/dispatches -f event_type="stable-promoted" ...
```

Never use `secrets.GITHUB_TOKEN` for cross-repo dispatch — it will silently fail (GitHub returns 404, not 403).
