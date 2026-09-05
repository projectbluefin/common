#!/usr/bin/env bash
# hookrunner.sh — single source of truth for the ublue-*-setup hook dispatchers.
#
# /usr/bin/ublue-system-setup, /usr/bin/ublue-user-setup and
# /usr/bin/ublue-privileged-setup are the same dispatcher three times over: read
# a directory out of /etc/ublue-os/setup.json (falling back to a compiled-in
# default), honour the `verbose` flag, then run every file in that directory
# with bash. The only per-service variation is the config key and the default
# directory.
#
# Both halves of that dispatcher live here so a change to hook discovery,
# config parsing, or ordering lands on all three services at once. The entry
# points in /usr/bin are thin wrappers that supply their key and default and
# nothing else.
#
# The library path is overridable via $HOOKRUNNER so the wrappers can be
# exercised from a source checkout, matching the $LIBSETUP convention already
# used by the setup hooks in /usr/share/ublue-os/*-setup.hooks.d.

# get_config <jq-query> <fallback>
#
# Read a value out of $SETUP_CONFIG_FILE (default /etc/ublue-os/setup.json).
# Returns <fallback> when the file is missing, unreadable, unparseable, or when
# the query resolves to JSON null.
get_config() {
	SETUP_CONFIG_FILE="${SETUP_CONFIG_FILE:-/etc/ublue-os/setup.json}"
	QUERY="$1"
	FALLBACK="$2"
	shift
	shift
	OUTPUT="$(jq -r "$QUERY" "$SETUP_CONFIG_FILE" 2>/dev/null || echo "$FALLBACK")"
	if [ "$OUTPUT" == "null" ]; then
		echo "$FALLBACK"
		return
	fi
	echo "$OUTPUT"
}

# run_setup_hooks <config-key> <default-hooks-directory>
#
# Resolve the hooks directory for one setup service and execute every entry in
# it with bash, in glob (i.e. NN- prefix) order. A missing directory is not an
# error — downstream variants are expected to ship only the hook sets they need.
run_setup_hooks() {
	HOOKS_DIRECTORY="$(get_config ".\"$1\"" "$2")"
	HOOKS_VERBOSE="${HOOKS_VERBOSE:-$(get_config '."verbose"' "false")}"

	if [ "${HOOKS_VERBOSE}" == "true" ]; then
		set -x
	fi

	if [ -d "${HOOKS_DIRECTORY}" ]; then
		for script in "${HOOKS_DIRECTORY}"/*; do
			bash "$script"
		done
	fi
}
