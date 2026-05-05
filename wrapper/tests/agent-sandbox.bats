#!/usr/bin/env bats
# Integration tests for wrapper/agent-sandbox subcommand dispatch.
# Mocks sudo, setfacl, chmod — no real sandbox user or root access required.
bats_require_minimum_version 1.5.0

load 'helpers/mocks'

WRAPPER="${BATS_TEST_DIRNAME}/.."
_TMPDIR=""

setup() {
    mocks_setup
    mock_cmd sudo
    mock_cmd setfacl

    _TMPDIR="$(mktemp -d)"
    export HOME="$_TMPDIR"
    export PLATFORM=linux
    export ALLOWLIST_FILE="${HOME}/.config/agent-sandbox/allowlist"
    export API_KEYS_FILE="${HOME}/.config/agent-sandbox/api-keys"

    # Create a dummy agent CLI so `command -v` resolves it.
    printf '#!/usr/bin/env bash\n' > "${MOCK_BIN}/test-agent"
    "${REAL_CHMOD}" +x "${MOCK_BIN}/test-agent"
}

teardown() {
    [[ -n "${_TMPDIR:-}" ]] && rm -rf "$_TMPDIR"
    mocks_teardown
}

# ── no-args / --help ──────────────────────────────────────────────────────────

@test "no args exits non-zero and prints usage" {
    run "${WRAPPER}/agent-sandbox"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Usage"* ]]
}

# ── allow subcommand ──────────────────────────────────────────────────────────

@test "allow adds path to allowlist" {
    run "${WRAPPER}/agent-sandbox" allow "${HOME}/code"
    grep -qF "${HOME}/code" "$ALLOWLIST_FILE"
}

@test "allow calls acl_grant_read (setfacl -m)" {
    run "${WRAPPER}/agent-sandbox" allow "${HOME}/code"
    mock_assert_called_with setfacl "-m"
}

@test "allow rejects \$HOME/.ssh" {
    run "${WRAPPER}/agent-sandbox" allow "${HOME}/.ssh"
    [[ "$status" -ne 0 ]]
}

@test "allow rejects \$HOME" {
    run "${WRAPPER}/agent-sandbox" allow "$HOME"
    [[ "$status" -ne 0 ]]
}

@test "allow with no path argument exits non-zero" {
    run "${WRAPPER}/agent-sandbox" allow
    [[ "$status" -ne 0 ]]
}

# ── deny subcommand ───────────────────────────────────────────────────────────

@test "deny removes path from allowlist" {
    "${WRAPPER}/agent-sandbox" allow "${HOME}/code"
    "${WRAPPER}/agent-sandbox" deny "${HOME}/code"
    ! grep -qF "${HOME}/code" "$ALLOWLIST_FILE" 2>/dev/null
}

@test "deny calls acl_revoke_read (setfacl -x)" {
    run "${WRAPPER}/agent-sandbox" deny "${HOME}/code"
    mock_assert_called_with setfacl "-x"
}

@test "deny with no path argument exits non-zero" {
    run "${WRAPPER}/agent-sandbox" deny
    [[ "$status" -ne 0 ]]
}

# ── status subcommand ─────────────────────────────────────────────────────────

@test "status prints sandbox user name" {
    run "${WRAPPER}/agent-sandbox" status
    [[ "$output" == *"agent-sandbox"* ]]
}

@test "status prints allowlist file path" {
    run "${WRAPPER}/agent-sandbox" status
    [[ "$output" == *"${ALLOWLIST_FILE}"* ]]
}

@test "status shows (none) when allowlist is empty" {
    run "${WRAPPER}/agent-sandbox" status
    [[ "$output" == *"(none)"* ]]
}

@test "status lists an allowlisted path" {
    "${WRAPPER}/agent-sandbox" allow "${HOME}/code"
    run "${WRAPPER}/agent-sandbox" status
    [[ "$output" == *"${HOME}/code"* ]]
}

# ── exec form ────────────────────────────────────────────────────────────────

@test "exec form invokes sudo with -u agent-sandbox" {
    run "${WRAPPER}/agent-sandbox" test-agent
    mock_assert_called_with sudo "agent-sandbox"
}

@test "exec form passes HOME=sandbox_home to sudo" {
    run "${WRAPPER}/agent-sandbox" test-agent
    mock_assert_called_with sudo "HOME=/var/agent-sandbox-home"
}

@test "exec form grants workspace ACL before running" {
    run "${WRAPPER}/agent-sandbox" test-agent
    mock_assert_called_with setfacl "rwX"
}

@test "exec form revokes workspace ACL on exit" {
    run "${WRAPPER}/agent-sandbox" test-agent
    # grant uses rwX; revoke uses -x; both must appear
    mock_assert_called_with setfacl "-x"
}

@test "exec form exits 127 when CLI not on PATH" {
    run -127 "${WRAPPER}/agent-sandbox" no-such-agent-xyz
}

@test "exec form does not leak SSH_AUTH_SOCK to sudo" {
    export SSH_AUTH_SOCK=/tmp/fake.sock
    run "${WRAPPER}/agent-sandbox" test-agent
    ! grep -q "SSH_AUTH_SOCK" "${MOCK_BIN}/sudo.calls" 2>/dev/null
}

# ── API key config file ───────────────────────────────────────────────────────

@test "exec form passes key from api-keys file when var is set" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    echo "GITHUB_TOKEN" > "$API_KEYS_FILE"
    export GITHUB_TOKEN=ghp-test
    run "${WRAPPER}/agent-sandbox" test-agent
    mock_assert_called_with sudo "GITHUB_TOKEN=ghp-test"
}

@test "exec form does not include key from api-keys file when var is unset" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    echo "GITHUB_TOKEN" > "$API_KEYS_FILE"
    unset GITHUB_TOKEN
    run "${WRAPPER}/agent-sandbox" test-agent
    ! grep -q "GITHUB_TOKEN" "${MOCK_BIN}/sudo.calls" 2>/dev/null
}

@test "status shows API keys file path" {
    run "${WRAPPER}/agent-sandbox" status
    [[ "$output" == *"${API_KEYS_FILE}"* ]]
}
