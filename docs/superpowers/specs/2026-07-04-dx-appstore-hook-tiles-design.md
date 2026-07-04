# DX app-store tiles with Homebrew hook installs

## Goal

Transform the Bazaar DX page into an app-store style page with native app tiles only, and route installs to Homebrew via Bazaar hooks instead of Flatpak installs.

## Approved constraints

- Include GUI apps from both `ublue-os/tap` and `ublue-os/experimental-tap`.
- Include AI GUI apps under the same rules.
- Use native Bazaar app tiles only (real `appstream://` IDs).
- Do not keep command-line app sections on the DX page.
- Keep page copy minimal (tile-first, very little text).

## Selected approach

Hybrid:

1. Rework the page now with manual curation.
2. Structure mapping cleanly so generation automation can be added in a follow-up PR.

## Information architecture

DX page becomes minimal and tile-dominant:

1. IDEs (stable + experimental GUI apps that have real app IDs)
2. AI desktop apps (GUI apps that have real app IDs)

Each section is rendered with native Bazaar tiles using image syntax:

`![Label](appstream://id1,appstream://id2,...)`

## Hook model

For each selected app ID:

1. Tile click initiates Flatpak install transaction for that app ID.
2. `before-transaction` hook intercepts.
3. Dialog offers Homebrew install path.
4. Hook action runs mapped `brew install` command (tap/cask mapping).
5. Hook teardown denies the Flatpak install.

Implementation surfaces:

- `system_files/bluefin/etc/bazaar/hooks.py`
- `system_files/bluefin/usr/libexec/bazaar-hook` (mirror)
- `system_files/bluefin/etc/bazaar/bazaar.yaml` (hook dialog wiring)
- `system_files/bluefin/etc/bazaar/article-devtools.md` (tile-only content)

## App selection rules

Candidate sources:

- `system_files/shared/usr/share/ublue-os/homebrew/ide.Brewfile`
- `system_files/shared/usr/share/ublue-os/homebrew/experimental-ide.Brewfile`
- `system_files/shared/usr/share/ublue-os/homebrew/ai-tools.Brewfile`

Inclusion gate:

- GUI cask + verified real app ID.

Exclusion:

- Formula-only CLI entries.
- GUI casks without a real app ID (cannot be native Bazaar tiles or hookable from tile flow).

## Testing and acceptance

Tests:

- Extend mappings and cases in:
  - `tests/test_hooks.py`
  - `tests/test_bazaar_hook.py`

Acceptance criteria:

1. DX page is tile-first with minimal text and no CLI app tables.
2. Every shown tile corresponds to a verified app ID.
3. Clicking any shown tile follows Homebrew hook flow and executes mapped brew install command.
4. Existing hook behavior remains intact for already-supported apps.
