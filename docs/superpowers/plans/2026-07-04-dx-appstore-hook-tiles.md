# DX App-Store Hook Tiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the DX Bazaar article into a tile-first app-store page that only shows GUI apps with real app IDs and routes installs to Homebrew through hooks.

**Architecture:** Keep Bazaar native `appstream://` tile rendering, expand hook coverage using a single table-driven mapping in the hook scripts, and slim `article-devtools.md` to short headings plus tile grids. Verify each mapped app through tests and keep mirrored hook scripts behavior-identical.

**Tech Stack:** Bazaar hooks (`hooks.py` / `bazaar-hook`), Bazaar config (`bazaar.yaml`), Markdown curated article, pytest

## Global Constraints

- Include GUI apps from both `ublue-os/tap` and `ublue-os/experimental-tap`.
- Include AI GUI apps under the same rules.
- Use native Bazaar app tiles only (real `appstream://` IDs).
- Do not keep command-line app sections on the DX page.
- Keep page copy minimal (tile-first, very little text).

---

## File Structure

- `system_files/bluefin/etc/bazaar/hooks.py`
  - Primary hook logic; convert GUI cask handling to a table-driven mapping.
- `system_files/bluefin/usr/libexec/bazaar-hook`
  - In-image mirrored hook script; keep behavior identical to `hooks.py`.
- `system_files/bluefin/etc/bazaar/bazaar.yaml`
  - Hook dialog wiring for each GUI app hook ID.
- `system_files/bluefin/etc/bazaar/article-devtools.md`
  - Final DX app-store style page: minimal copy + tile grids only.
- `tests/test_hooks.py`
  - Unit tests for `hooks.py`.
- `tests/test_bazaar_hook.py`
  - Unit tests for mirrored `bazaar-hook`.
- `tests/test_dx_article_devtools.py` (new)
  - Regression checks for tile-only DX content.

### Task 1: Build the verified GUI app mapping and fail tests first

**Files:**
- Modify: `tests/test_hooks.py`
- Modify: `tests/test_bazaar_hook.py`
- Create: `tests/test_dx_article_devtools.py`

**Interfaces:**
- Consumes: Brewfile GUI cask lists from `homebrew/ide.Brewfile`, `homebrew/experimental-ide.Brewfile`, `homebrew/ai-tools.Brewfile`
- Produces: `GUI_HOOK_CASES` parameter matrix shape used by both hook test files:
  - tuple[str, str, str, str] = `(hook_id, appid, tap, cask)`

- [ ] **Step 1: Add a failing parameterized test matrix for new GUI hook targets**

```python
# tests/test_hooks.py and tests/test_bazaar_hook.py
GUI_HOOK_CASES = [
    ("code", "com.visualstudio.code", "ublue-os/tap", "visual-studio-code-linux"),
    ("code", "com.vscodium.codium", "ublue-os/tap", "vscodium-linux"),
    ("zed", "dev.zed.Zed", "ublue-os/experimental-tap", "zed-linux"),
    # Add newly verified GUI appid<->cask rows here.
]

@pytest.mark.parametrize("hook_id,appid,tap,cask", GUI_HOOK_CASES)
def test_action_spawns_expected_cask(...):
    ...
```

- [ ] **Step 2: Add a failing DX article shape test**

```python
# tests/test_dx_article_devtools.py
from pathlib import Path

def test_dx_article_is_tile_first_and_no_cli_tables():
    text = Path("system_files/bluefin/etc/bazaar/article-devtools.md").read_text(encoding="utf-8")
    assert "appstream://" in text
    assert "## CLI and CNCF tooling" not in text
    assert "| Tool |" not in text
```

- [ ] **Step 3: Run targeted tests to confirm failure before implementation**

Run:

```bash
python3 -m pytest -q tests/test_hooks.py tests/test_bazaar_hook.py tests/test_dx_article_devtools.py
```

Expected: FAIL due to missing new hook mappings and current verbose DX article structure.

- [ ] **Step 4: Commit failing-test baseline**

```bash
git add tests/test_hooks.py tests/test_bazaar_hook.py tests/test_dx_article_devtools.py
git commit -m "test(bazaar): add failing coverage for DX app-store hook mapping"
```

### Task 2: Implement table-driven GUI hook routing in both hook scripts

**Files:**
- Modify: `system_files/bluefin/etc/bazaar/hooks.py`
- Modify: `system_files/bluefin/usr/libexec/bazaar-hook`
- Test: `tests/test_hooks.py`
- Test: `tests/test_bazaar_hook.py`

**Interfaces:**
- Consumes: `GUI_HOOK_CASES` test contract `(hook_id, appid, tap, cask)`
- Produces:
  - `GUI_CASK_HOOKS: dict[str, dict[str, str]]`
  - `handle_gui_cask(appid_match: str, tap: str, cask: str) -> str`

- [ ] **Step 1: Add table-driven hook metadata and generic GUI cask handler**

```python
GUI_CASK_HOOKS = {
    "code": {"appid_match": "com.visualstudio.code|com.vscodium.codium", "tap": "ublue-os/tap"},
    "zed": {"appid_match": "dev.zed.Zed", "tap": "ublue-os/experimental-tap", "cask": "zed-linux"},
}

def handle_gui_cask(appid_match, tap, cask):
    match stage:
        case "setup":
            if transaction_type == "install" and transaction_appid in appid_match.split("|"):
                return "ok"
            return "pass"
        case "setup-dialog":
            return "ok"
        case "teardown-dialog":
            return "ok" if dialog_response_id == "download" else "abort"
        case "catch":
            return "abort"
        case "action":
            spawn_brew_tap_cask(tap, cask)
            return ""
        case "teardown":
            return "deny"
```

- [ ] **Step 2: Route each GUI hook ID through the generic handler**

```python
match hook_id:
    case "jetbrains-toolbox":
        response = handle_jetbrains()
    case "code" | "zed" | "cursor" | "opencode-desktop":
        cfg = GUI_CASK_HOOKS[hook_id]
        response = handle_gui_cask(cfg["appid_match"], cfg["tap"], cfg["cask"])
    case "neovim":
        response = handle_neovim()
```

- [ ] **Step 3: Mirror the same logic into `/usr/libexec/bazaar-hook`**

```bash
cp system_files/bluefin/etc/bazaar/hooks.py system_files/bluefin/usr/libexec/bazaar-hook
```

- [ ] **Step 4: Run hook tests until green**

Run:

```bash
python3 -m pytest -q tests/test_hooks.py tests/test_bazaar_hook.py
```

Expected: PASS for both files.

- [ ] **Step 5: Commit hook implementation**

```bash
git add system_files/bluefin/etc/bazaar/hooks.py system_files/bluefin/usr/libexec/bazaar-hook tests/test_hooks.py tests/test_bazaar_hook.py
git commit -m "feat(bazaar): add table-driven GUI Homebrew hook routing"
```

### Task 3: Wire dialogs for every GUI hook ID in bazaar.yaml

**Files:**
- Modify: `system_files/bluefin/etc/bazaar/bazaar.yaml`
- Test: `tests/test_hooks.py`
- Test: `tests/test_bazaar_hook.py`

**Interfaces:**
- Consumes: `GUI_CASK_HOOKS` hook IDs from Task 2
- Produces: `hooks:` entries with `id`, `when: before-transaction`, and `download` dialog response

- [ ] **Step 1: Add a dialog block per new hook ID**

```yaml
- id: cursor
  when: before-transaction
  dialogs:
    - id: cursor-warning
      title: >-
        Cursor is not supported in this format
      body-use-markup: true
      body: >-
        Cursor is not officially supported on Flatpak. We recommend
        the Homebrew version instead.
      default-response-id: cancel
      options:
        - id: cancel
          string: "Cancel"
        - id: download
          string: "Download from Homebrew"
          style: suggested
  shell: exec python3 /run/host/etc/bazaar/hooks.py
```

- [ ] **Step 2: Validate YAML syntax and rerun hook tests**

Run:

```bash
python3 -m pytest -q tests/test_hooks.py tests/test_bazaar_hook.py
```

Expected: PASS and no parsing/runtime regressions.

- [ ] **Step 3: Commit hook config wiring**

```bash
git add system_files/bluefin/etc/bazaar/bazaar.yaml
git commit -m "feat(bazaar): wire GUI Homebrew hook dialogs for DX tiles"
```

### Task 4: Rebuild DX article as minimal app-store tile page

**Files:**
- Modify: `system_files/bluefin/etc/bazaar/article-devtools.md`
- Test: `tests/test_dx_article_devtools.py`

**Interfaces:**
- Consumes: verified app IDs from Task 1 and hook coverage from Tasks 2-3
- Produces: tile-only sections:
  - `## IDEs`
  - `## AI apps`

- [ ] **Step 1: Replace verbose content with minimal headings and tile grids**

```markdown
# Developer Experience (DX)

## IDEs
![IDEs](appstream://com.visualstudio.code,appstream://com.vscodium.codium,appstream://dev.zed.Zed)

## AI apps
![AI apps](appstream://ai.jan.Jan,appstream://dev.k8slens.OpenLens)
```

- [ ] **Step 2: Keep only short guidance lines (no command tables)**

```markdown
Click a tile to install. Supported apps are redirected to Homebrew by hooks.
```

- [ ] **Step 3: Run article regression test**

Run:

```bash
python3 -m pytest -q tests/test_dx_article_devtools.py
```

Expected: PASS and confirms tile-only shape.

- [ ] **Step 4: Commit article rewrite**

```bash
git add system_files/bluefin/etc/bazaar/article-devtools.md tests/test_dx_article_devtools.py
git commit -m "feat(bazaar): convert DX page to tile-first app-store layout"
```

### Task 5: Final verification pass

**Files:**
- Test: `tests/test_hooks.py`
- Test: `tests/test_bazaar_hook.py`
- Test: `tests/test_dx_article_devtools.py`
- Validate: repo checks

**Interfaces:**
- Consumes: all prior tasks
- Produces: final green validation state for PR

- [ ] **Step 1: Run full targeted validation set**

Run:

```bash
python3 -m pytest -q tests/test_hooks.py tests/test_bazaar_hook.py tests/test_dx_article_devtools.py
```

Expected: PASS.

- [ ] **Step 2: Run repository gate checks**

Run:

```bash
just check && pre-commit run --all-files
```

Expected: PASS.

- [ ] **Step 3: Commit any final test or sync adjustments**

```bash
git add -A
git commit -m "test(bazaar): finalize DX tile hook coverage and regressions"
```
