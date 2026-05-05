#!/usr/bin/env bash
# Shared constants and pure helpers used by both setup.sh and agent-sandbox.

# shellcheck source=./platform.sh
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

SANDBOX_USER="${SANDBOX_USER:-agent-sandbox}"

if platform_is_macos; then
    # /var is read-only on modern macOS for non-system users; /Users/Shared is the
    # conventional location for shared system accounts.
    SANDBOX_HOME="${SANDBOX_HOME:-/Users/Shared/agent-sandbox-home}"
else
    SANDBOX_HOME="${SANDBOX_HOME:-/var/agent-sandbox-home}"
fi

# Caller's config dir — note: $HOME here is the *real* user's home, not the sandbox home.
ALLOWLIST_FILE="${ALLOWLIST_FILE:-${HOME}/.config/agent-sandbox/allowlist}"
API_KEYS_FILE="${API_KEYS_FILE:-${HOME}/.config/agent-sandbox/api-keys}"

SUDOERS_FILE="/etc/sudoers.d/agent-sandbox"

# Default API key var names — used when $API_KEYS_FILE does not exist.
_SANDBOX_API_KEYS_DEFAULTS=(CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY CURSOR_AGENT_TOKEN)

# Emit the list of API-key env-var names to pass through (one per line).
# If $API_KEYS_FILE exists its contents win entirely (override, not extend);
# otherwise the defaults above are used. Comments and blank lines are stripped.
api_keys_read() {
    if [[ -f "$API_KEYS_FILE" ]]; then
        grep -v '^[[:space:]]*#' "$API_KEYS_FILE" | grep -v '^[[:space:]]*$' || true
    else
        printf '%s\n' "${_SANDBOX_API_KEYS_DEFAULTS[@]}"
    fi
}

# Canonicalize a path to an absolute form without requiring GNU realpath.
# Uses logical pwd (not -P) so symlinks in paths are preserved — this keeps
# $HOME comparisons consistent when /tmp is a symlink (e.g. macOS → /private/tmp).
_canonicalize() {
    local p="$1"
    if [[ -d "$p" ]]; then
        (cd "$p" && pwd)
    else
        echo "$p"
    fi
}

# Sensitive dirs relative to $HOME — paths inside these must never be allowlisted.
_DENY_SUBDIRS=(
    .ssh .gnupg .aws .kube .netrc .npmrc .pypirc
    ".config/gcloud"
    "Library/Keychains"
    "Library/Application Support/Google/Chrome"
)

# Validate a path is safe to allowlist. Prints an error and returns 1 if not.
# Usage: deny_check_path <path>
deny_check_path() {
    local path="$1"

    [[ "$path" == "/" ]] && {
        echo "error: cannot allowlist /" >&2
        return 1
    }
    [[ "$path" == "$HOME" ]] && {
        echo "error: cannot allowlist \$HOME directly" >&2
        return 1
    }

    local subdir sensitive
    for subdir in "${_DENY_SUBDIRS[@]}"; do
        sensitive="${HOME}/${subdir}"
        if [[ "$path" == "$sensitive" || "$path" == "$sensitive"/* ]]; then
            echo "error: ${path} is inside a sensitive path (${sensitive})" >&2
            return 1
        fi
    done

    return 0
}

# Print all allowlisted paths (one per line); comments and blank lines stripped.
allowlist_read() {
    [[ -f "$ALLOWLIST_FILE" ]] || return 0
    grep -v '^[[:space:]]*#' "$ALLOWLIST_FILE" | grep -v '^[[:space:]]*$' || true
}

# Add a path to the allowlist (idempotent — no-op if already present).
# Usage: allowlist_add <path>
allowlist_add() {
    local path="$1"
    mkdir -p "$(dirname "$ALLOWLIST_FILE")"
    if [[ -f "$ALLOWLIST_FILE" ]] && grep -qF "$path" "$ALLOWLIST_FILE"; then
        return 0
    fi
    local tmp
    tmp="$(mktemp "${ALLOWLIST_FILE}.XXXXXX")"
    { [[ -f "$ALLOWLIST_FILE" ]] && cat "$ALLOWLIST_FILE"; echo "$path"; } > "$tmp"
    mv -f "$tmp" "$ALLOWLIST_FILE"
}

# Remove a path from the allowlist. No-op if absent.
# Usage: allowlist_remove <path>
allowlist_remove() {
    local path="$1"
    [[ -f "$ALLOWLIST_FILE" ]] || return 0
    local tmp
    tmp="$(mktemp "${ALLOWLIST_FILE}.XXXXXX")"
    grep -vF "$path" "$ALLOWLIST_FILE" > "$tmp" || true
    mv -f "$tmp" "$ALLOWLIST_FILE"
}
