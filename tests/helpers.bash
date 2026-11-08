# Shared bats helpers. Use: load helpers

# fake_dmi <root> key=value... — write fake /sys DMI id files under <root>.
fake_dmi() {
    local dir="$1/sys/devices/virtual/dmi/id" kv
    shift
    mkdir -p "${dir}"
    for kv in "$@"; do
        printf '%s\n' "${kv#*=}" > "${dir}/${kv%%=*}"
    done
}
