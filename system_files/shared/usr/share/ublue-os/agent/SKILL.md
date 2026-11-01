# On-Device Skill Router (Bluefin)

**Summary:** This file points an on-device agent to the skill that matches its
task, then tells it to load only that skill and stop. Every task a agent is
likely to face on a finished Bluefin machine is covered here. Load the named
skill and act within the read-only limits described in `AGENTS.md`.

**Read order**

1. `AGENTS.md` — what this bundle is, what you may touch, and how to report.
2. This file — pick the skill for your task.
3. The skill file named in the table.

## Skills

| I need to... | Load |
|---|---|
| Work with bootc image build, update, rollback, or the Containerfile | [`skills/bootc.md`](skills/bootc.md) |
| Manage OS-managed Homebrew packages and RPM vs brew placement | [`skills/brew-lifecycle.md`](skills/brew-lifecycle.md) |
| Configure Bluefin Developer Mode | [`skills/devmode.md`](skills/devmode.md) |
| Look up projectbluefin image registry paths and tags | [`skills/image-registry.md`](skills/image-registry.md) |
| Understand what an image calls itself and who owns that | [`skills/image-identity.md`](skills/image-identity.md) |
| Edit Bazaar config, curated content, or app blocklists | [`skills/bazaar.md`](skills/bazaar.md) |
| Add or understand OEM first-boot setup hooks | [`skills/oem-hardware-hooks.md`](skills/oem-hardware-hooks.md) |
| Keep workflow authentication inside the security boundary | [`skills/secrets-policy.md`](skills/secrets-policy.md) |

## How to use a skill

Each skill in this bundle is an on-device edition of a source skill in
`projectbluefin/common`. Steps that edit the source tree assume a checkout and
do not apply on a running machine — gather evidence and report instead. A
banner at the top of every skill file says so.

The catalog of skills here is generated from the source skills. If a skill is
flagged for this bundle but is missing, or a file here is not flagged, the
bundle is stale — regenerate from the source in a checkout.
