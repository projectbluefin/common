# On-Device Agent Contract (Bluefin)

**Summary:** This file is the on-device reading of the `projectbluefin/common`
agent contract. It tells an agent running on a finished Bluefin machine what it
is, what it can read, and how to act — without the source-tree steps that only
work in a contributor checkout. The full, editable contract lives in the
`projectbluefin/common` repository; this bundle is a read-only snapshot of the
shared half, plus the skills most useful for working on a running machine.

**Read this first:** the root filesystem is read-only on a running machine. You
cannot edit the source skills here. When you find a bug or a gap, gather
evidence and open or update an issue in the right repository instead of writing
to `/usr/share/ublue-os/agent/`. The repo-editing steps in the bundled skills
assume a checkout; skip those parts.

## What this bundle is

- Read-only context shipped by the `projectbluefin/common` image at
  `/usr/share/ublue-os/agent/`.
- A router (`SKILL.md`) that points to the skill matching your task.
- A small subset of the repository's skills, marked so you know which steps are
  on-device-only.
- A generated catalog (`index.json`) listing exactly these skills.
- A drop-in directory (`context.d/`) that variant images (Utah, ...) fill with
  their own context. See `INDEX.md` for what is present now.

## The image you are in

Every Bluefin image knows what it is. Read it before asserting identity:

```bash
cat /usr/share/ublue-os/image-info.json
/usr/libexec/ublue-booted-image ref        # what bootc actually booted
```

`image-info.json` bakes the identity keys (`image-name`, `image-flavor`,
`image-vendor`, `image-ref`, `image-tag`) at compose time — do not write image
names or tags from memory.

## Logs, reporting, and what you can change

The root filesystem is read-only on a running machine, so you cannot edit the
system itself. Here is where to look and what actually works:

- Logs: `ujust logs-this-boot`, `ujust logs-last-boot`, or `journalctl -b`.
- Report a problem: where available (the Bluefin layer ships it), `ujust report`
  gathers a bug report and selects its tracker via `/usr/libexec/ublue-image-repo`.
- Change something for real: user-level overrides under your home directory, or
  a new image. There is no way to make a persistent system change by writing to
  `/` — see "What to do when asked to change something" for the read-only rule.
- Find what the image is built from: `cat /usr/share/ublue-os/image-info.json`
  or `/usr/libexec/ublue-booted-image` shows the source ref and tag the image
  was built from.

## What to do when asked to change something

1. Confirm the task belongs here. Common is the shared OCI layer consumed by
   Bluefin, Bluefin-LTS, and Dakota; a change here reaches every variant. If the
   task is specific to one variant, it belongs in that variant's repository,
   not here.
2. Gather evidence: read the relevant bundled skill, run the read-only commands
   it lists, and quote what you find.
3. If the fix is a documentation correction, file or update an issue in
   `projectbluefin/common` with the evidence. Do not edit `/` to change the
   source-of-truth docs.
4. Never write to `system_files/`, `/usr/share/`, or any `ublue-os/*` path on a
   running machine to "fix" shared config. That is a source-tree action with no
   review and it breaks every variant at once.

## Working on the source (only in a checkout)

These steps apply only when you have a `projectbluefin/common` checkout with
write access, not on the device. They are here so the bundle is self-describing.

- Base branch is `main`. Every change, including docs, goes in as a branch and
  PR targeting `main`.
- Read `docs/skills/*.md` as the editable source. The copies in this bundle are
  generated from them; edit the source and regenerate with
  `python3 scripts/generate_skill_index.py --write`.
- Run `just check` and `pre-commit run --all-files` before committing.
- Link issues with `Refs #NNN` or `Fixes #NNN`. Agents implement accepted work
  only; never set `lgtm`, `approved`, or clear `needs-human` on your own work.

## When to stop

Stop and ask a human for Design, Security, cross-repo Breakage, or Merge
review. Gather evidence and report instead of acting when you are outside your
authority or the change would ship to every variant without review.
