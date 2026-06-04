---
name: dakota-patch-junctions
description: Use when modifying upstream freedesktop-sdk or gnome-build-meta elements in dakota, when fixing bugs in junction dependencies, or when deciding between patching an element vs replacing it entirely
---

# Patching Upstream Junctions (dakota)

## Powerlevel

- **Level:** 2

Bluefin builds on top of two upstream BuildStream projects via junctions: **freedesktop-sdk** and **gnome-build-meta**. When you need to modify an upstream element (fix a bug, change a build flag, backport a fix), you have two mechanisms: **patch_queue** (modify in-place) or **config.overrides** (replace entirely).

Load with: `cat ~/src/skills/dakota-patch-junctions/SKILL.md`

## When to Use

- Fixing a bug in an upstream element (freedesktop-sdk or gnome-build-meta)
- Changing build flags or configure options on an upstream package
- Backporting a fix from a newer upstream version
- Deciding whether to patch an element or replace it with a local override

## When NOT to Use

- Creating a full local element replacement (too many changes for a patch) → use `dakota-bst-overrides` instead
- Debugging build failures caused by a patch → use `dakota-debugging`
- Updating junction refs to a newer upstream version → use `dakota-update-refs`

## Mechanism: patch_queue

Both junction elements apply a directory of patches to the upstream checkout:

```yaml
# elements/freedesktop-sdk.bst
sources:
- kind: git_repo
  url: gitlab:freedesktop-sdk/freedesktop-sdk.git
  ref: <pinned-ref>
- kind: patch_queue
  path: patches/freedesktop-sdk

# elements/gnome-build-meta.bst
sources:
- kind: git_repo
  url: gnome:gnome-build-meta.git
  ref: <pinned-ref>
- kind: patch_queue
  path: patches/gnome-build-meta
```

BuildStream applies all `.patch` files from the queue directory **in filename-sorted order** after checking out the git source.

> ⛔ **NEVER edit `elements/gnome-build-meta.bst` or `elements/freedesktop-sdk.bst` to list a new patch.** The `patch_queue` source plugin reads the directory automatically — there is no per-file registration list in the junction `.bst` file. Adding a patch entry to the `.bst` file will corrupt it with invalid source syntax. To add a new patch: drop the file into the patch directory and name it so it sorts correctly. That is all.

## Patch Directories

| Junction | Patch directory |
|---|---|
| freedesktop-sdk | `patches/freedesktop-sdk/` |
| gnome-build-meta | `patches/gnome-build-meta/` |

## Creating a Patch

### Step 1: Clone the upstream project at the pinned ref

Find the ref in the junction element:
```bash
grep 'ref:' elements/freedesktop-sdk.bst
grep 'ref:' elements/gnome-build-meta.bst
```

Clone and checkout (the `gitlab:` alias in `include/aliases.yml` resolves to `https://gitlab.com/`):
```bash
# freedesktop-sdk:
git clone https://gitlab.com/freedesktop-sdk/freedesktop-sdk.git /tmp/fdsdk
cd /tmp/fdsdk && git checkout <ref-from-junction>

# gnome-build-meta:
git clone https://gitlab.gnome.org/GNOME/gnome-build-meta.git /tmp/gbm
cd /tmp/gbm && git checkout <ref-from-junction>
```

**Preferred: use the BST source cache (no network needed).** The BST bare git cache at
`~/.cache/buildstream/sources/git_repo/` already has the repo at the pinned ref. Use a
worktree instead of cloning. Requires `safe.bareRepository=all` to work on bare repos:

```bash
FDSDK_CACHE="$HOME/.cache/buildstream/sources/git_repo/gitlab_freedesktop_sdk_freedesktop_sdk.git"
REF="freedesktop-sdk-25.08.11"   # tag name from junction ref

git -C "$FDSDK_CACHE" -c safe.bareRepository=all worktree add -f /tmp/fdsdk-work "$REF"
cd /tmp/fdsdk-work
```

Cleanup after generating patch:
```bash
git -C "$FDSDK_CACHE" -c safe.bareRepository=all worktree remove /tmp/fdsdk-work
```

### Step 2: Apply existing patches first

If the patch directory already has patches, apply them before making changes:
```bash
# git am works for git format-patch output (0NNN-*.patch files)
git am /path/to/dakota/patches/freedesktop-sdk/0*.patch
# For plain diffs, use git apply instead:
git apply /path/to/dakota/patches/freedesktop-sdk/*.patch
```

### Step 3: Make your changes and commit

```bash
vim elements/components/openssh.bst
git add elements/components/openssh.bst
git commit -m "openssh: Use /etc/ssh as sysconfdir"
```

### Step 4: Generate the patch

```bash
git format-patch -1 HEAD -o /path/to/dakota/patches/freedesktop-sdk/
```

Rename the output to follow the numbering convention (see below).

### Step 5: Verify

```bash
just bst show oci/bluefin.bst
```

## Naming Convention

**freedesktop-sdk** uses a numbered series:
```
0001-project-Specify-more-limits-to-the-CAS-configs.patch
0002-project.conf-Add-GNOME-CAS-servers.patch
0004-openssh-Use-etc-ssh-as-sysconfdir.patch
```

When adding a new patch, use the next number in the sequence. Gaps in numbering are acceptable.

**gnome-build-meta** uses upstream commit SHA as filename:
```
736f7794f272f9d9e4b60e9f3a7f32f40518addf.patch
```

Both formats are standard `git format-patch` output.

## Patches vs. Overrides

The junction elements also support `config.overrides` which **completely replaces** an upstream element with a local one:

```yaml
# In elements/gnome-build-meta.bst:
config:
  overrides:
    oci/os-release.bst: oci/os-release.bst
    core/meta-gnome-core-apps.bst: core/meta-gnome-core-apps.bst
    gnomeos-deps/plymouth-gnome-theme.bst: bluefin/plymouth-bluefin-theme.bst
```

### Decision Matrix

| Situation | Use | Why |
|---|---|---|
| Tweaking a build flag or variable | `patch_queue` | Small, targeted change |
| Adding a configure option | `patch_queue` | Small, targeted change |
| Bumping a source ref for one package | `patch_queue` | Changes one field |
| Fixing a bug in upstream build commands | `patch_queue` | Preserves upstream structure |
| Completely different build from upstream | `config.overrides` | Too many changes for a patch |
| Using a package from a different source | `config.overrides` | Replacing the entire element |
| Removing a single dependency from a stack element | `patch_queue` | Simple line removal — standard unified diff, applied via `git apply` |
| Removing a package from the dependency graph (complex, multi-element) | `config.overrides` | Only when the change spans too many lines to be a clean patch |
| Element needs ongoing local maintenance | `config.overrides` | Patches break on every upstream update |

**Rule of thumb:** If you'd change more than ~20 lines, consider an override instead of a patch.

## Cross-Junction Overrides

The `freedesktop-sdk.bst` junction has overrides that point to **gnome-build-meta** elements:

```yaml
# In elements/freedesktop-sdk.bst:
config:
  overrides:
    components/glib.bst: gnome-build-meta.bst:sdk/glib.bst
    components/systemd.bst: gnome-build-meta.bst:core-deps/systemd.bst
```

This means some freedesktop-sdk components are replaced by newer versions maintained in gnome-build-meta. Bluefin inherits this upstream GNOME pattern.

## Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Patch paths relative to dakota root | Patch fails to apply | Paths must be relative to the upstream project root |
| Not applying existing patches before creating new one | New patch has wrong context lines | `git am` existing patches first |
| Not testing with `bst show` after adding patch | Discover failure at build time | Always `just bst show oci/bluefin.bst` first |
| Patching an element that's already overridden | Patch has no effect | Check `config.overrides` — overrides take precedence |
| Not rebasing patches after bumping junction ref | Patches fail to apply on new upstream | Regenerate patches against new ref |

## Gotchas

- **Patches are applied in sorted filename order.** If patch B depends on patch A's changes, B must sort after A.
- **All `.patch` files in the directory are applied.** No selective skipping. Remove or rename to disable.
- **Bumping the junction ref may break patches.** When updating `ref:` in a junction element, check that all patches still apply cleanly.
- **`bst source track` on junction elements updates the ref.** This can invalidate patches — always recheck after tracking.

## Cross-References

- `dakota-update-refs` — bumping junction refs and tracking upstream
- `dakota-debugging` — diagnosing build failures after patches
- `dakota-buildstream` — element structure reference

## Lessons Learned

### Regenerating the full patch queue (Jordan's workflow — 2026-05-14)

**When to use:** Bumping the fdsdk kernel version, or any time multiple patches need to be re-based against a new upstream. This is the canonical method used by the dakota maintainers.

**⛔ Never manually edit patch files.** Regenerate from the fdsdk git tree.

Ghost's HTTPS to `gitlab.freedesktop.org` is broken (IPv6 unreachable). Use the GitLab REST API from your local machine to find MR patches, then fetch them on ghost via `refs/merge-requests/<NNN>/head`.

```bash
# Check for new kernel MRs (run on local machine)
curl -s "https://gitlab.com/api/v4/projects/freedesktop-sdk%2Ffreedesktop-sdk/merge_requests?state=opened&search=linux.yml&per_page=5" | \
  python3 -c "import sys,json; [print(f\"!{mr['iid']} {mr['title']} {mr['created_at'][:10]}\") for mr in json.load(sys.stdin)]"

# Get MR patch to see what version it bumps to
curl -s "https://gitlab.com/freedesktop-sdk/freedesktop-sdk/-/merge_requests/<NNN>.patch" | head -15

# On ghost — using BST source cache (bare repo)
FDSDK="$HOME/.cache/buildstream/sources/git_repo/gitlab_freedesktop_sdk_freedesktop_sdk.git"

# Create worktree at junction base tag
git -C "$FDSDK" worktree prune
git -C "$FDSDK" worktree add -f /tmp/fdsdk-work freedesktop-sdk-25.08.11
cd /tmp/fdsdk-work

# Apply all current dakota patches
git am ~/src/dakota/patches/freedesktop-sdk/*.patch

# Fetch and cherry-pick the MR commit
git -C "$FDSDK" fetch "https://gitlab.com/freedesktop-sdk/freedesktop-sdk.git" \
  "refs/merge-requests/<NNN>/head"
MR_SHA=$(git -C "$FDSDK" rev-parse FETCH_HEAD)
git cherry-pick "$MR_SHA"
# ⚠️ EXPECTED CONFLICT on elements/include/linux.yml — the MR's "from" ref differs
# from our patched base. Resolve: write the target ref directly, then:
#   git add elements/include/linux.yml && git cherry-pick --continue --no-edit

# Regenerate patch queue from junction base tag
rm -f ~/src/dakota/patches/freedesktop-sdk/*.patch
git format-patch freedesktop-sdk-25.08.11 -o ~/src/dakota/patches/freedesktop-sdk/

# Junction ref stays at 25.08.11 — all changes live in the patch queue
# Commit in dakota
cd ~/src/dakota
git add patches/freedesktop-sdk/ elements/freedesktop-sdk.bst
git commit -m "fix(kernel): update patch queue for v<X.Y.Z>"

# Cleanup
git -C "$FDSDK" worktree remove /tmp/fdsdk-work
```

**Always verify the fsverity fix before dropping the backport patch.**  
Kernel v7.0.1–v7.0.6 all ship the broken `ovl_ensure_verity_loaded`. bootc will not boot without it.

```bash
# Verify against kernel.org (run on local machine)
curl -s "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/fs/overlayfs/util.c?h=v<VERSION>" | \
  grep -A3 "ovl_ensure_verity_loaded"
# BROKEN:  if (!fsverity_active(inode) && IS_VERITY(inode))
# FIXED:   if (IS_VERITY(inode) && !fsverity_get_info(inode))
```

### Patch apply failures after junction bump (2026-05-10)

**Pattern:** When the auto-tracker bumps a junction ref, patches in `patches/freedesktop-sdk/` may fail to apply because upstream merged them in the new release.

**Symptom:** `just bst show oci/bluefin.bst` fails immediately with:
```
error: patch failed: files/linux/fdsdk-config.sh:139
error: files/linux/fdsdk-config.sh: patch does not apply
FAILURE freedesktop-sdk.bst: Applying patch queue
```

**Root cause (dual):** Both the target lines AND surrounding context can change simultaneously. In the 25.08.10→25.08.11 bump, `CRYPTO_RMD160` was removed (shifting line numbers) AND `CRYPTO_AES_ARM64`/`CRYPTO_AES_ARM64_CE` were already gone — so `git apply` failed on context drift even before it could check if the target lines existed.

**Diagnosis:** Fetch upstream at both old and new refs with `git fetch --depth=1`, check out the specific file, and `grep` directly:
```bash
git init /tmp/fdsdk-new && cd /tmp/fdsdk-new
git remote add origin https://gitlab.com/freedesktop-sdk/freedesktop-sdk.git
git fetch --depth=1 origin <new-ref>
git checkout FETCH_HEAD -- files/linux/fdsdk-config.sh
grep -n "CRYPTO_AES_ARM64\|S2IO\|CRYPTO_AES_TI" files/linux/fdsdk-config.sh
```

**Fix:** If confirmed absent upstream — delete the patch files. No other changes needed; `patch_queue` reads the directory automatically.

**Process gate:** Always run `just bst show oci/bluefin.bst` as the FIRST action when checking out any junction bump PR. It catches patch failures in ~5 seconds, before a 90-minute build.

**⛔ Pre-push gate (hard rule — 2026-05-14):** Run `just bst show oci/bluefin.bst` on ghost and confirm zero errors BEFORE every `git push` to any upstream-targeted branch. This applies even for "trivial" patch edits. Hand-crafting patch files without verifying they apply cleanly, then pushing to an upstream PR, is a violation. The 5-second check is never optional.
