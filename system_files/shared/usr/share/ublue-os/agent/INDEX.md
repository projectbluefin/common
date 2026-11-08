# Context Index — On-Device Agent Bundle

**Summary:** This file lists the variant context present in the drop-in
`context.d/` directory of this bundle. It starts empty; each variant image
(Utah, ...) adds its own context file there, and lists it here. Read the files
listed below in addition to `AGENTS.md` when you are working on that variant.

## Present now

`context.d/` is empty in the shared bundle. No variant context is loaded yet.

## How a variant adds context

A derived image drops a Markdown file into `system_files/shared/usr/share/ublue-os/agent/context.d/`
during its own build (for example `10-utah.md`). Files are read in lexical
order, so a numeric prefix sets the order. Each file should be plain Markdown
and should say which variant it is for and what it adds on top of the shared
contract in `AGENTS.md`.

Keep the files plain and read-only — no new recipes or runtime code, just
context an on-device agent needs for that variant. Update this index when you
add or remove a file so the agent knows what is present.
