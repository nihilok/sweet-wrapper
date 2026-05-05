#!/usr/bin/env bash
# Env-var passthrough for the sandbox user.
#
# Keeps terminal and locale vars needed by CLI tools; drops everything else.
# Callers supply API keys and other extras as VAR=value or bare VAR arguments.
# HOME is intentionally excluded — the exec wrapper sets it to the sandbox home.

_ENV_PASSTHROUGH_KEYS=(PATH TERM LANG COLORTERM FORCE_COLOR NO_COLOR)

# Emit VAR=value lines for the allowlist plus any caller-supplied extras.
# Extras win over the allowlist: if a caller passes PATH=/custom, the allowlist's
# PATH is suppressed so the consumer never sees a duplicate key.
#
#   Extras can be  VAR=value  (passed through verbatim)
#               or VAR        (resolved from current env; omitted if unset)
#
# Usage: env_passthrough [VAR=value|VAR ...]
env_passthrough() {
    local -a out=()
    local -A extra_keys=()
    local extra key line

    for extra in "$@"; do
        if [[ "$extra" == *=* ]]; then
            extra_keys["${extra%%=*}"]=1
        else
            extra_keys["$extra"]=1
        fi
    done

    for key in "${_ENV_PASSTHROUGH_KEYS[@]}"; do
        [[ -n "${extra_keys[$key]:-}" ]] && continue
        [[ -v "$key" ]] && out+=("${key}=${!key}")
    done

    # LC_* variables — read from the exported environment.
    # `env | grep` rather than `${!LC_@}` so this works under macOS bash 3.2.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ -n "${extra_keys[${line%%=*}]:-}" ]] && continue
        out+=("$line")
    done < <(env | grep '^LC_')

    for extra in "$@"; do
        if [[ "$extra" == *=* ]]; then
            out+=("$extra")
        else
            [[ -v "$extra" ]] && out+=("${extra}=${!extra}")
        fi
    done

    printf '%s\n' "${out[@]}"
}
