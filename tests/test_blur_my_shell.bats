#!/usr/bin/env bats
# Regression coverage for the Blur My Shell GSettings defaults and the
# gnome-rounded-blur runtime contract they depend on.
#
# common ships the defaults only; the library itself is installed by the base
# image (ublue-os/bluefin build_files/base/04-packages.sh, merged via
# ublue-os/bluefin#4899). These tests pin both halves of that contract so a
# future edit cannot silently ship a popup blur that has no rounded corners.
#
# Run: bats tests/test_blur_my_shell.bats

REPO_ROOT="$BATS_TEST_DIRNAME/.."
OVERRIDE="${REPO_ROOT}/system_files/bluefin/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override"
LOCKS="${REPO_ROOT}/system_files/bluefin/etc/dconf/db/distro.d/locks/01-bluefin-locked-settings"
SKILL="${REPO_ROOT}/docs/skills/gnome-rounded-blur.md"

# Read a single key out of a GSettings section of the override file.
override_value() {
    local section="$1" key="$2"
    awk -v section="${section}" -v key="${key}" '
        $0 == "[" section "]" { in_section = 1; next }
        in_section && /^\[/ { exit }
        in_section && $0 ~ "^" key "=" {
            sub("^" key "=", "", $0)
            print
            exit
        }
    ' "${OVERRIDE}"
}

@test "override enables blur on the dock" {
    run override_value "org.gnome.shell.extensions.blur-my-shell.dash-to-dock" "blur"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "override enables blur on the shell popups" {
    # Quick Settings, the calendar and the OSDs. Blur My Shell only rounds the
    # corners of that blur when libgnome-rounded-blur.so is present.
    run override_value "org.gnome.shell.extensions.blur-my-shell.popup" "blur"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "blur-my-shell stays in the enabled-extensions default list" {
    run grep -c "blur-my-shell@aunetx" "${OVERRIDE}"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "neither blur-my-shell key is dconf-locked" {
    # Users are expected to be able to turn popup blur off, so no lock entry
    # may exist for these schemas. See docs/skills/dconf-consistency.md.
    run grep -c "blur-my-shell" "${LOCKS}"
    [ "$status" -ne 0 ]
    [ "$output" -eq 0 ]
}

@test "the popup override documents the gnome-rounded-blur dependency" {
    run grep -c "gnome-rounded-blur" "${OVERRIDE}"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "common does not try to install the library itself" {
    # The shared layer ships config, not RPMs. A package-manager call here
    # would be a no-op at best; see docs/skills/gnome-rounded-blur.md.
    run grep -q "gnome-rounded-blur" "${REPO_ROOT}/Containerfile"
    [ "$status" -ne 0 ]
    run grep -q "gnome-rounded-blur" "${REPO_ROOT}/Justfile"
    [ "$status" -ne 0 ]
}

@test "the gnome-rounded-blur skill is indexed" {
    run python3 -c "
import json, sys
index = json.load(open('${REPO_ROOT}/docs/skills/index.json'))
sys.exit(0 if any(s['id'] == 'gnome-rounded-blur' for s in index['skills']) else 1)
"
    [ "$status" -eq 0 ]
}

@test "the gnome-rounded-blur skill records the base-image ownership split" {
    [ -f "${SKILL}" ]
    run grep -c "04-packages.sh" "${SKILL}"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
    run grep -c "BuildStream" "${SKILL}"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}
