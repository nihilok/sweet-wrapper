# BATS mock helpers.
# Call mocks_setup in setup() and mocks_teardown in teardown().

MOCK_BIN=""
REAL_CHMOD=""

mocks_setup() {
    # Capture the real chmod before prepending MOCK_BIN — mock_cmd uses it
    # directly so that mocking chmod doesn't break subsequent mock_cmd calls.
    REAL_CHMOD="$(command -v chmod)"
    MOCK_BIN="$(mktemp -d)"
    export MOCK_BIN REAL_CHMOD
    export PATH="${MOCK_BIN}:${PATH}"
}

mocks_teardown() {
    [[ -n "${MOCK_BIN:-}" ]] && rm -rf "${MOCK_BIN}"
}

# Create a stub that records each invocation as a single line of space-joined args.
# Usage: mock_cmd <name>
mock_cmd() {
    local cmd="$1"
    local calls="${MOCK_BIN}/${cmd}.calls"
    # $* is intentionally unquoted here so args are space-joined per invocation.
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$calls" \
        > "${MOCK_BIN}/${cmd}"
    # Use the real chmod (captured before PATH was modified) so that mocking
    # chmod itself doesn't prevent subsequent stubs from becoming executable.
    "${REAL_CHMOD}" +x "${MOCK_BIN}/${cmd}"
    # Clear any cached path for this command so PATH lookup finds the mock first.
    hash -d "$cmd" 2>/dev/null || true
}

# Print all recorded call lines for <cmd>.
mock_calls() { cat "${MOCK_BIN}/${1}.calls" 2>/dev/null || true; }

# Assert <cmd> was called at least once with a line containing <substr>.
mock_assert_called_with() {
    local cmd="$1"; shift
    local needle="$*"
    # -e "$needle" tells grep the argument is a pattern, not an option flag — handles
    # needles like "-m" or "-d" that grep would otherwise interpret as its own options.
    if ! grep -qF -e "$needle" "${MOCK_BIN}/${cmd}.calls" 2>/dev/null; then
        printf 'Expected `%s` called with substring: %s\nActual calls:\n%s\n' \
            "$cmd" "$needle" "$(mock_calls "$cmd")" >&2
        return 1
    fi
}

# Assert <cmd> was never called.
mock_assert_not_called() {
    local cmd="$1"
    if [[ -s "${MOCK_BIN}/${cmd}.calls" ]]; then
        printf 'Expected `%s` not to be called, but recorded:\n%s\n' \
            "$cmd" "$(mock_calls "$cmd")" >&2
        return 1
    fi
}
