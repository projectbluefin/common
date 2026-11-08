# fish completion for ujust
#
# Flags come from the ujust-flags data file shipped next to the entry
# justfile (one flag per line). When `just --help` gains flags, update the
# data file — the completions read it at TAB time, no per-shell edits needed.

function __ujust_justfile
    # UJUST_JUSTFILE override exists for testing; default is the image entry justfile.
    if set -q UJUST_JUSTFILE
        echo $UJUST_JUSTFILE
    else
        echo /usr/share/ublue-os/just/00-entry.just
    end
end

function __ujust_flags_file
    # UJUST_FLAGS_FILE override exists for testing; default sits next to the entry justfile.
    if set -q UJUST_FLAGS_FILE
        echo $UJUST_FLAGS_FILE
    else
        echo (string replace -r '/[^/]*$' '' (__ujust_justfile))/ujust-flags
    end
end

function __ujust_recipes
    just --summary --justfile (__ujust_justfile) 2>/dev/null | tr ' ' '\n'
end

function __ujust_flags
    if test -f (__ujust_flags_file)
        cat (__ujust_flags_file)
    end
end

complete -c ujust -f -a '(__ujust_recipes)'
complete -c ujust -f -a '(__ujust_flags)'
