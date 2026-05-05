#!/usr/bin/env bats
# Tests for lib/sandbox.sh pure functions (deny_check_path, allowlist_*).
# No real user creation, ACLs, or sudo required.

LIB="${BATS_TEST_DIRNAME}/../lib"
_TMPDIR=""

setup() {
    _TMPDIR="$(mktemp -d)"
    export HOME="$_TMPDIR"
    export ALLOWLIST_FILE="${HOME}/.config/agent-sandbox/allowlist"
    export PLATFORM=linux
    # shellcheck source=/dev/null
    source "${LIB}/platform.sh"
    source "${LIB}/sandbox.sh"
}

teardown() {
    [[ -n "${_TMPDIR:-}" ]] && rm -rf "$_TMPDIR"
}

# ── deny_check_path ────────────────────────────────────────────────────────────

@test "deny_check_path rejects /" {
    ! deny_check_path "/"
}

@test "deny_check_path rejects \$HOME" {
    ! deny_check_path "$HOME"
}

@test "deny_check_path rejects \$HOME/.ssh" {
    ! deny_check_path "${HOME}/.ssh"
}

@test "deny_check_path rejects \$HOME/.aws" {
    ! deny_check_path "${HOME}/.aws"
}

@test "deny_check_path rejects path inside \$HOME/.gnupg" {
    ! deny_check_path "${HOME}/.gnupg/private-keys"
}

@test "deny_check_path rejects \$HOME/.kube/config" {
    ! deny_check_path "${HOME}/.kube/config"
}

@test "deny_check_path allows \$HOME/code" {
    deny_check_path "${HOME}/code"
}

@test "deny_check_path allows /tmp/workspace" {
    deny_check_path "/tmp/workspace"
}

@test "deny_check_path allows an absolute path outside HOME" {
    deny_check_path "/opt/myproject"
}

# ── allowlist_read / allowlist_add / allowlist_remove ──────────────────────────

@test "allowlist_read returns nothing when file absent" {
    [[ -z "$(allowlist_read)" ]]
}

@test "allowlist_add creates the allowlist file" {
    allowlist_add "/tmp/proj"
    [[ -f "$ALLOWLIST_FILE" ]]
}

@test "allowlist_add stores the path" {
    allowlist_add "/tmp/proj"
    grep -qF "/tmp/proj" "$ALLOWLIST_FILE"
}

@test "allowlist_read returns added path" {
    allowlist_add "/tmp/proj"
    [[ "$(allowlist_read)" == "/tmp/proj" ]]
}

@test "allowlist_add is idempotent" {
    allowlist_add "/tmp/proj"
    allowlist_add "/tmp/proj"
    [[ "$(allowlist_read | wc -l | tr -d ' ')" -eq 1 ]]
}

@test "allowlist_add preserves existing entries" {
    allowlist_add "/tmp/a"
    allowlist_add "/tmp/b"
    allowlist_read | grep -qF "/tmp/a"
    allowlist_read | grep -qF "/tmp/b"
}

@test "allowlist_remove deletes an entry" {
    allowlist_add "/tmp/proj"
    allowlist_remove "/tmp/proj"
    ! allowlist_read | grep -qF "/tmp/proj"
}

@test "allowlist_remove leaves other entries intact" {
    allowlist_add "/tmp/a"
    allowlist_add "/tmp/b"
    allowlist_remove "/tmp/a"
    allowlist_read | grep -qF "/tmp/b"
}

@test "allowlist_remove is a no-op when file absent" {
    allowlist_remove "/tmp/nonexistent"
}

@test "allowlist_remove is a no-op when path not in list" {
    allowlist_add "/tmp/a"
    allowlist_remove "/tmp/b"
    allowlist_read | grep -qF "/tmp/a"
}

# ── api_keys_read ──────────────────────────────────────────────────────────────

@test "api_keys_read returns defaults when file absent" {
    out="$(api_keys_read)"
    echo "$out" | grep -qF "CLAUDE_CODE_OAUTH_TOKEN"
}

@test "api_keys_read default does not include ANTHROPIC_API_KEY" {
    out="$(api_keys_read)"
    ! echo "$out" | grep -qF "ANTHROPIC_API_KEY"
}

@test "api_keys_read returns file contents when file present" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    echo "GITHUB_TOKEN" > "$API_KEYS_FILE"
    [[ "$(api_keys_read)" == "GITHUB_TOKEN" ]]
}

@test "api_keys_read file overrides defaults entirely" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    echo "GITHUB_TOKEN" > "$API_KEYS_FILE"
    out="$(api_keys_read)"
    ! echo "$out" | grep -qF "CLAUDE_CODE_OAUTH_TOKEN"
}

@test "api_keys_read strips comments from file" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    printf '# this is a comment\nGITHUB_TOKEN\n' > "$API_KEYS_FILE"
    out="$(api_keys_read)"
    [[ "$out" == "GITHUB_TOKEN" ]]
}

@test "api_keys_read strips blank lines from file" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    printf '\nGITHUB_TOKEN\n\n' > "$API_KEYS_FILE"
    [[ "$(api_keys_read | wc -l | tr -d ' ')" -eq 1 ]]
}

@test "api_keys_read empty file produces empty list not defaults" {
    mkdir -p "$(dirname "$API_KEYS_FILE")"
    : > "$API_KEYS_FILE"
    [[ -z "$(api_keys_read)" ]]
}
