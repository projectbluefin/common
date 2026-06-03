---
name: dakota-debugging
description: Use when a BuildStream build fails in projectbluefin/dakota, when diagnosing element errors, or when reading CI build logs to understand what went wrong
---

# Debugging BuildStream Build Failures (dakota)

## Powerlevel

- **Level:** 1

Load with: `cat ~/src/skills/dakota-debugging/SKILL.md`

## When to Use

- A BuildStream element build fails and you need to diagnose the root cause
- Reading CI build logs to find which elements failed and why
- Reproducing a CI failure locally using `bst shell --build`
- Clearing stale or corrupted build artifacts from the cache
- Classifying a failure (fetch, compile, install, compose, cache, junction)

## When NOT to Use

- Understanding the CI pipeline setup itself → use `dakota-ci`
- Writing new `.bst` element files from scratch → use `dakota-buildstream` or `dakota-add-package`
- **Editing `project.conf` or any `.bst` file** → load `dakota-buildstream` FIRST, then this skill
- Updating a package version after fixing a failure → use `dakota-update-refs`

> ⚠️ This skill diagnoses failures. `dakota-buildstream` is the reference for writing/editing BST files.
> If you are fixing a BST file as part of debugging, you need BOTH skills loaded simultaneously.
> Loading only `dakota-debugging` and editing BST files is the root cause of repeated syntax errors.

## Overview

Systematic guide for diagnosing and fixing BuildStream build failures in the dakota project. Covers all failure categories from source fetching through OCI assembly, plus CI-specific debugging.

## Quick Reference

| Command | Purpose |
|---|---|
| `just bst artifact log <element>` | View build log for a built/failed element |
| `just bst shell --build <element>` | Interactive shell inside build sandbox |
| `just bst show <element>` | Inspect resolved deps, variables, commands |
| `just bst source fetch <element>` | Fetch sources (test network/URL issues) |
| `just bst source track <element>` | Update source ref to latest upstream |
| `just bst artifact delete <element>` | Delete cached artifact (fix stale cache) |
| `just bst build <element>` | Build a single element in isolation |

## Diagnostic Flowchart

```
Build failed
  → Where in the pipeline?
    fetch error       → Source fetch/track failure
    compile error     → Build command failure
    install error     → Install command failure
    overlap/missing   → Compose/filter failure
    script error      → OCI assembly failure
    stale result      → Cache issue
```

**Step 1:** Read the error. BuildStream prints the failing element name and phase.
**Step 2:** Run `just bst artifact log <element>` to get the full log.
**Step 3:** Match to a category below.

## Failure Categories

### 1. Source Fetch Failures

**Symptoms:** `Failed to fetch`, `Connection refused`, `404 Not Found`, `ref not found`, `Could not find base directory matching pattern`

| Cause | Fix |
|---|---|
| Wrong URL or expired link | Check source URL; update alias in `include/aliases.yml` if domain changed |
| Wrong git ref / tag deleted | Run `just bst source track <element>` to update ref |
| Network issue / GNOME CAS down | Retry; check connectivity to `gbm.gnome.org:11003` |
| Missing source alias | Add alias to `include/aliases.yml` |
| Tarball checksum mismatch | Source was updated without updating ref; `bst source track` to get new hash |
| Tarball has no wrapping directory | Add `base-dir: ""` to the `tar` source. Common with Go binary releases (e.g., fzf ships a bare binary). |

**Debug command:** `just bst source fetch <element>` -- isolates fetch from build.

### 2. Build Command Failures

**Symptoms:** `configure failed`, `compilation error`, `command not found`, `missing header`

| Cause | Fix |
|---|---|
| Missing build dependency | Add dep to `build-depends:` -- use `just bst show <element>` to check current deps |
| Wrong configure flags | Check upstream docs; inspect with `just bst show <element>` to see resolved variables |
| Sandbox restriction (no network) | BuildStream sandboxes have no network at build time; vendor deps or use source elements |
| Missing build tool | Ensure the right `buildsystem-*` stack or tool element is in `build-depends:` |

**Debug command:** `just bst shell --build <element>` -- drops you into the sandbox with all build-deps staged. Run commands manually to isolate the failure.

### 3. Install Command Failures

**Symptoms:** `No such file or directory`, `Permission denied`, `install: cannot create`

| Cause | Fix |
|---|---|
| Missing `%{install-root}` prefix | All install paths MUST start with `%{install-root}` |
| Target directory doesn't exist | Add `install -d "%{install-root}%{prefix}/..."` before copying files |
| Wrong path variable | Use `%{bindir}`, `%{datadir}`, `%{indep-libdir}` -- see `dakota-buildstream` |
| Using `/usr/sbin` | GNOME OS uses merged-usr -- always `/usr/bin` |
| Missing `%{install-extra}` | Should be last install-command (convention, not fatal) |

**Debug command:** `just bst shell --build <element>` -- then manually run install commands to see exact error.

### 4. Compose/Filter Failures

**Symptoms:** `overlap error`, files missing from final image, `FAILED: ... file already exists`

| Cause | Fix |
|---|---|
| File overlap between elements | Add `public.bst.overlap-whitelist` to the overriding element |
| Files in excluded split domain | Don't install to `/usr/include/`, `/usr/lib/debug/`, `/usr/share/doc/` unless intended |
| Package not in image despite building | Ensure element is in `bluefin/deps.bst` depends list |
| Missing `strip-binaries: ""` | Required for non-ELF elements (fonts, configs, pre-built binaries) -- strip fails on non-ELF |

**Debug steps:**
1. `just bst show oci/layers/bluefin.bst` -- check compose config, exclude lists
2. `just bst artifact checkout <element> --directory /tmp/inspect` -- inspect what the element actually installs
3. See `dakota-oci-layers` for the full filter chain

### 5. Cache Corruption / Stale Artifacts

**Symptoms:** Build succeeds but produces wrong output, element shows as `cached` but content is outdated, hash mismatch errors

| Cause | Fix |
|---|---|
| Element source changed but artifact cached | `just bst artifact delete <element>` then rebuild |
| Dependency changed but downstream cached | Delete the downstream element's artifact too |
| CAS corruption (rare) | `rm -rf ~/.cache/buildstream/artifacts` -- nuclear option, forces full rebuild |

**Key insight:** BuildStream's cache keys include all dependencies. If you change a source ref but the element still shows `cached`, either the ref change didn't take effect or there's a junction caching issue. Run `just bst show <element>` and check `Keys:` -- if the key matches the old build, the source change wasn't picked up.

### 6. Junction / Upstream Failures

**Symptoms:** `Element not found in junction`, `Failed to resolve`, errors in freedesktop-sdk or gnome-build-meta elements

| Cause | Fix |
|---|---|
| Junction ref points to broken upstream commit | Update ref in `freedesktop-sdk.bst` or `gnome-build-meta.bst` |
| Patch no longer applies cleanly | Update patch in `patches/` directory to match new upstream |
| Override element path changed upstream | Update `config.overrides` in the junction element |

**Debug:** `just bst show <junction>:<element>` -- shows resolved element through the junction.

## CI-Specific Debugging

### Reading CI Logs

CI uploads artifacts on every run (including failures):

| Artifact | Contents |
|---|---|
| `buildstream-logs` | Full BuildStream build log (`logs/build.log`) |

Download from the GitHub Actions run page > Artifacts section.

### `on-error: continue`

CI uses `on-error: continue` in `buildstream-ci.conf`. This means:
- BuildStream does **not** stop at the first failure
- It builds everything it can, skipping elements whose deps failed
- The build log contains **ALL** failures, not just the first
- Search the log for `FAILURE` to find every failing element

### CI-Specific Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| Build OOM-killed | `builders: 1` but element needs >7GB RAM | Reduce `max-jobs` for that element via `variables: { max-jobs: 1 }` |
| Disk space exhaustion | BuildStream CAS fills the runner | Check `Disk space before/after build` steps; `cache-buildtrees: never` should already be set |
| `--no-interactive` prompt | Element needs user input | Fix the element; CI runs `--no-interactive` and will hang/fail |

## General Debugging Workflow

1. **Identify the failing element** -- BuildStream names it in the error output
2. **Read the log** -- `just bst artifact log <element>` (or download CI artifact)
3. **Classify the failure** -- match to a category above
4. **Inspect the element** -- `just bst show <element>` for deps, variables, commands
5. **Reproduce interactively** -- `just bst shell --build <element>` to run commands by hand
6. **Fix and rebuild** -- edit the `.bst` file, `just bst build <element>`
7. **Clear cache if needed** -- `just bst artifact delete <element>` before rebuilding

## Runtime Image Debugging

These failures build successfully but surface on a running/upgraded image.

### Stale ldconfig Cache After `bootc upgrade`

**Symptoms:** GDM fails to start after upgrade. `gnome-shell --wayland --display-server` with `LIBGL_DEBUG=verbose` shows `MESA-LOADER: failed to open dri: libgallium-<new-version>.so: cannot open shared object file`. Old Mesa version still in `/etc/ld.so.cache` even though new Mesa installed.

**Root cause chain:**
1. `bootc upgrade` updates Mesa (e.g. 25.3.5 → 26.0.4) but does NOT invalidate `/etc/ld.so.cache`
2. `ldconfig.service` uses `always-ldconfig.conf` (from gnome-build-meta): `ConditionPathExists=|!/etc/ld.so.cache.stamp-%A` where `%A` = systemd specifier for `IMAGE_VERSION`
3. If `IMAGE_VERSION` is missing from os-release, `%A` = `""` → stamp path = `/etc/ld.so.cache.stamp-` → always present → ldconfig never reruns
4. GBM loads the old `.so` name → fails → mutter cannot init KMS → gnome-shell crashes silently (no journal entries, no coredump)

**Immediate workaround (on live system):**
```bash
sudo ldconfig && sudo systemctl restart gdm
```

**Permanent fix:** Two layers of protection are now in place:

1. **Build-time (primary, PR #517 + #518):** `elements/oci/bluefin.bst` now runs `ldconfig -r /layer -f /layer/etc/ld.so.conf` during image assembly, after all packages are installed and before `build-oci`. This bakes a correct `/etc/ld.so.cache` directly into every image. On `bootc switch`, bootc's 3-way merge adopts the image's fresh cache. This is the authoritative fix — it prevents the stale-cache problem regardless of whether the runtime service fires.

2. **Runtime (secondary):** Ensure `IMAGE_VERSION` is set in `/usr/lib/os-release` (see `elements/oci/os-release.bst`). With `IMAGE_VERSION` present, `%A` changes per image version → stamp path changes → `always-ldconfig.service` reruns on first boot after upgrade. Fixed in dakota via PR #271.

**⚠️ Critical distinction:** The systemd specifier is `%A` = `IMAGE_VERSION=` (NOT `%w` which = `VERSION_ID=`). Confusing these was the root cause of an incorrect initial diagnosis. Always verify specifier meaning from systemd docs before proposing a fix.

**Diagnostic commands:**
```bash
# Check IMAGE_VERSION (this is what %A reads — NOT VERSION_ID)
grep IMAGE_VERSION /usr/lib/os-release
# Check stamp file — empty suffix means ldconfig never reruns on upgrade
ls -la /etc/ld.so.cache.stamp-*
# Check ldconfig ran on this boot
journalctl -b0 -u always-ldconfig.service --no-pager | tail -10
# Check what Mesa version is in the cache vs installed
ldconfig -p | grep libgallium
```

**Note:** This class of bug (silent crash, no journal entries) is particularly tricky because gnome-shell's startup failure leaves no trace. Always check `LIBGL_DEBUG=verbose` output first when GDM fails silently after an upgrade.

## Related Skills

- `dakota-buildstream` -- variable names, element kinds, source kinds
- `dakota-oci-layers` -- how packages flow into the final image, compose filtering
- `dakota-add-package` -- end-to-end workflow for new packages
- `dakota-patch-junctions` -- fixing upstream element issues via patches
- `dakota-ci` -- CI pipeline overview and Blacksmith caching
