# Bluefin CLI Design Language

Bluefin ships interactive terminal UIs via `ujust` + [Charm's gum](https://github.com/charmbracelet/gum).
This document is the single source of truth for how they look and behave. Recipes that match
these conventions feel like one product; those that don't feel like shell scripts.

**Canonical reference implementation:** `devmode` in
`system_files/bluefin/usr/share/ublue-os/just/system.just` — read it before writing a new recipe.

---

## Design tokens

| Token | Value | Use |
|---|---|---|
| Brand color | `212` | Headers, borders, primary actions |
| Success | `42` | ✓ completion messages |
| Error | `196` | ✗ failure messages |
| Caution | `214` | Warnings that don't block |
| Muted | `245` | Secondary / helper text |
| Header width | `60` | `--width 60` on main headers |
| Card width | `50` | `--width 50` on summary cards |
| Header padding | `"1 4"` | `--padding "1 4"` on headers |
| Card padding | `"1 3"` | `--padding "1 3"` on cards |

---

## Header

Every recipe that has interactive UI starts with this exact pattern:

```bash
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --padding "1 4" \
    "Title of This Recipe"
echo ""
```

Multi-line headers (title + subtitle):

```bash
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 60 --padding "1 4" \
    "NVIDIA AI Workspaces" \
    "RTX 4090 · 24564 MiB · NGC 25.06"
echo ""
```

Rules:
- Border: **double** (cards use rounded; headers always double)
- Align: **center**
- Width: **60**
- Always `echo ""` after the header block

---

## Menus

### Single-select

```bash
ACTION="$(gum choose \
    --height 10 \
    --cursor "▸  " \
    "  Option A" \
    "  Option B" \
    "  Cancel")" || exit 0
[[ "${ACTION}" == "  Cancel" || -z "${ACTION}" ]] && exit 0
```

### Multi-select

```bash
CHOICES="$(gum choose --no-limit \
    --height 22 \
    --selected-prefix "◉  " \
    --unselected-prefix "○  " \
    --cursor "▸  " \
    --selected "  Default Item" \
    "── Section Name ─────────────────────────────────────" \
    "  Default Item" \
    "  Other Item")" || exit 0
```

To test if something was selected:

```bash
_wants() { echo "${CHOICES}" | grep -q "$@"; }
_wants -F "  Docker" && INSTALL_DOCKER=1
```

### Never use `gum filter` for menus

`gum filter` breaks on terminal resize. `gum choose` is stable. Use `gum filter` only
when the list has 20+ items and search is genuinely necessary — and even then, test resize.

---

## Section separators

Inside `gum choose`, use `──` (U+2500) separators to group items. They must be
non-actionable — filter them out after selection:

```bash
[[ "${CHOSEN}" == "──"* || -z "${CHOSEN}" ]] && exit 0
```

Section separator format — aim for ~53 characters total:
```
"── Section Name ─────────────────────────────────────"
"── Another Section ──────────────────────────────────"
```

Do not use emoji in section separators.

---

## Menu item format

Two leading spaces. No emoji in structural items (emoji in content is fine):

```bash
"  item-key        Item Display Name - brief description      ○"
```

For state indicators at the end of an item:

| Symbol | Meaning |
|---|---|
| `○` | Not deployed / inactive |
| `● active` | Running |
| `◎ deployed` | Deployed but stopped |

---

## Summary card

Used to confirm what's about to happen before a destructive or slow action:

```bash
SUMMARY_BODY=$(
    gum style --bold "Ready to install:"
    for item in "${WILL_INSTALL[@]}"; do
        echo "  ● ${item}"
    done
)
gum style \
    --border rounded --border-foreground 212 \
    --padding "1 3" --width 50 \
    "${SUMMARY_BODY}"
echo ""

gum confirm "Install now?" || exit 0
echo ""
```

Rules:
- Border: **rounded** (not double — that's for headers)
- Always followed by `gum confirm` and `echo ""`

---

## Confirmation

```bash
gum confirm "Phrased as an action?" || exit 0
echo ""
```

Use imperative voice. No "would you like to" — just the action: "Install now?",
"Remove the VM stack?", "Reboot into BIOS?".

Custom affirmative/negative only when the default Yes/No is genuinely confusing:

```bash
gum confirm --affirmative="Install" --negative="Uninstall" "OpenTabletDriver"
```

---

## Feedback

```bash
# Success
gum style --foreground 42 "✓ Thing was done"

# Error
gum style --foreground 196 "✗ Thing failed" >&2

# Caution (non-blocking warning)
gum style --foreground 214 "⚠  This is experimental"

# Muted helper text
gum style --foreground 245 "  Secondary information here"
```

---

## Spinner

For single-step operations:

```bash
gum spin --spinner dot --title "  Doing the thing..." -- some-command arg1 arg2
gum style --foreground 42 "✓ Done"
```

The spinner clears its own line on success. Print the checkmark immediately after.

---

## Progress bar

For multi-step installs, copy this pattern verbatim from `devmode`:

```bash
_bar() {
    local done=$1 total=$2 width=28 bar="" i
    local filled=$(( done * width / total ))
    for ((i=0; i<filled; i++));          do bar+="█"; done
    for ((i=0; i<(width-filled); i++)); do bar+="░"; done
    printf '%s' "${bar}"
}

_step() {
    local idx=$1 total=$2 name=$3; shift 3
    local bar; bar="$(_bar "${idx}" "${total}")"
    local digits=${#total} label
    printf -v label "%*d/%*d" "${digits}" "$((idx+1))" "${digits}" "${total}"
    if gum spin --spinner dot \
            --title " ${bar}  ${label}  ${name}" -- "$@"; then
        gum style --foreground 42 "✓ ${name}"
    else
        gum style --foreground 196 "✗ ${name}" >&2
        return 1
    fi
}

NAMES=("Step One" "Step Two" "Step Three")
CMDS=("cmd1" "cmd2" "cmd3")
N=${#NAMES[@]}
for i in "${!NAMES[@]}"; do
    _step "${i}" "${N}" "${NAMES[$i]}" bash -c "${CMDS[$i]}"
done
```

---

## Copy voice

- **Direct and technical.** No exclamation marks. No "would you like to".
- **Present tense for status:** "is running", "is deployed"
- **Past tense for completion:** "stopped", "removed", "deployed"
- **Imperative for actions:** "Deploy and start", "Remove", "View logs"
- **Lowercase for everything except proper nouns and acronyms**

Examples:
```
✓ pytorch-lab deployed          (not "Successfully deployed pytorch-lab!")
✗ CDI not ready                 (not "Error: CDI is not ready.")
Deploy and start                (not "Deploy & Start Now")
```

---

## Anti-patterns

| Don't | Do instead |
|---|---|
| `gum filter` for menus | `gum choose` |
| `--border rounded` on headers | `--border double` |
| `--border double` on cards | `--border rounded` |
| Emoji in section separators | Plain `──` separators |
| Multi-column `printf` in menu items | Flat display string with key embedded |
| Nested `gum style` inside bordered `gum style` | Compute content in a subshell, pass as var |
| `gum style --bold` for body copy | Reserve bold for labels/titles |
| Sentences in status messages | Short past-tense phrases |

---

## Development workflow — `just preview-tui`

Iterate on TUI recipes without a full image build or target hardware.

```bash
# Preview any recipe in a new Ghostty window with hardware mocked
just preview-tui system_files/nvidia/usr/share/ublue-os/just/nvidia.just aimode
```

The launcher:
- Sets `UJUST_PREVIEW=1` so recipes know to mock hardware calls
- Points `UJUST_PREVIEW_STACKS_DIR` at the source tree (not the installed path)
- Writes a self-deleting temp script (no quoting issues)
- Opens a new Ghostty window via `ghostty -e`
- Drops into bash after the recipe exits so you can poke around

### Making a recipe preview-compatible

Add this block at the top of any recipe that calls hardware-specific commands:

```bash
# ── Preview mode: mock hardware for development on non-target machines ────────
if [[ "${UJUST_PREVIEW:-}" == "1" ]]; then
    # Override paths
    MY_DATA_DIR="${UJUST_PREVIEW_DATA_DIR:-/usr/share/ublue-os/my-data}"
    MY_QUADLET_DIR="${UJUST_PREVIEW_QUADLET_DIR:-$(mktemp -d /tmp/quadlets-XXXXXX)}"
    # Mock hardware commands — bash functions shadow the real binaries
    nvidia-ctk() { case "${1:-}" in cdi) echo "nvidia.com/gpu=0  NVIDIA RTX 4090 (mocked)";; esac; }
    nvidia-smi() { printf 'NVIDIA GeForce RTX 4090, 24564\n'; }
    systemctl() {
        case "${*}" in
            *"is-active"*)              return 1 ;;
            *"daemon-reload"*|*"start"*|*"stop"*) echo "(preview: systemctl ${*})" ;;
            *) command systemctl "$@" ;;
        esac
    }
    podman() {
        case "${*}" in
            *"secret exists"*)          return 1 ;;
            *"secret create"*|*"login"*) echo "(preview: podman ${*})" ;;
            *) command podman "$@" ;;
        esac
    }
fi
```

Replace `MY_DATA_DIR` and `MY_QUADLET_DIR` with the actual variable names your recipe uses.
Add mocks for any other hardware/system commands your recipe calls.
