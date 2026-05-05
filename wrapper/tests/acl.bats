#!/usr/bin/env bats
# Tests for lib/acl.sh
#
# Uses PLATFORM override + command mocks so no real chmod/setfacl is invoked
# and no root access is required.
#
# macOS functions use `find … -exec chmod`, so `find` runs for real and the path
# must exist. TEST_PATH is a real tmpdir; chmod is still mocked so no ACLs change.

load 'helpers/mocks'

LIB="${BATS_TEST_DIRNAME}/../lib"
TEST_PATH=""

setup() {
    mocks_setup
    mock_cmd chmod
    mock_cmd setfacl
    TEST_PATH="$(mktemp -d)"
    # Source with PLATFORM already set so platform.sh (re-)sourced inside acl.sh
    # never runs real uname detection.
    export PLATFORM=macos
    # shellcheck source=/dev/null
    source "${LIB}/acl.sh"
}

teardown() {
    [[ -n "${TEST_PATH:-}" ]] && rm -rf "$TEST_PATH"
    mocks_teardown
}

# ── macOS — grant ─────────────────────────────────────────────────────────────

@test "acl_grant_read on macOS calls chmod +a" {
    PLATFORM=macos acl_grant_read "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "+a"
}

@test "acl_grant_read on macOS includes user ACE" {
    PLATFORM=macos acl_grant_read "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "user:sandbox allow"
}

@test "acl_grant_read on macOS does not call setfacl" {
    PLATFORM=macos acl_grant_read "sandbox" "$TEST_PATH"
    mock_assert_not_called setfacl
}

# ── macOS — revoke ────────────────────────────────────────────────────────────

@test "acl_revoke_read on macOS calls chmod -a" {
    PLATFORM=macos acl_revoke_read "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "-a"
}

@test "acl_revoke_read on macOS does not call setfacl" {
    PLATFORM=macos acl_revoke_read "sandbox" "$TEST_PATH"
    mock_assert_not_called setfacl
}

# ── Linux — grant ─────────────────────────────────────────────────────────────

@test "acl_grant_read on linux calls setfacl -m" {
    PLATFORM=linux acl_grant_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-m"
}

@test "acl_grant_read on linux sets default ACL with -d" {
    PLATFORM=linux acl_grant_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-d"
}

@test "acl_grant_read on linux targets user:sandbox:rX" {
    PLATFORM=linux acl_grant_read "sandbox" "/proj"
    mock_assert_called_with setfacl "u:sandbox:rX"
}

@test "acl_grant_read on linux does not call chmod" {
    PLATFORM=linux acl_grant_read "sandbox" "/proj"
    mock_assert_not_called chmod
}

# ── Linux — revoke ────────────────────────────────────────────────────────────

@test "acl_revoke_read on linux calls setfacl -x" {
    PLATFORM=linux acl_revoke_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-x"
}

@test "acl_revoke_read on linux removes default ACL too" {
    # Without -d -x, files newly created in the tree would still inherit the
    # default u:sandbox:rX entry after a revoke.
    PLATFORM=linux acl_revoke_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-d -x"
}

@test "acl_revoke_read on linux does not call chmod" {
    PLATFORM=linux acl_revoke_read "sandbox" "/proj"
    mock_assert_not_called chmod
}

# ── WSL — same as Linux ───────────────────────────────────────────────────────

@test "acl_grant_read on wsl uses setfacl not chmod" {
    PLATFORM=wsl acl_grant_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-m"
    mock_assert_not_called chmod
}

@test "acl_revoke_read on wsl uses setfacl not chmod" {
    PLATFORM=wsl acl_revoke_read "sandbox" "/proj"
    mock_assert_called_with setfacl "-x"
    mock_assert_not_called chmod
}

# ── acl_grant_readwrite ───────────────────────────────────────────────────────

@test "acl_grant_readwrite on macOS calls chmod +a" {
    PLATFORM=macos acl_grant_readwrite "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "+a"
}

@test "acl_grant_readwrite on macOS includes write in ACE" {
    PLATFORM=macos acl_grant_readwrite "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "write"
}

@test "acl_grant_readwrite on macOS does not call setfacl" {
    PLATFORM=macos acl_grant_readwrite "sandbox" "$TEST_PATH"
    mock_assert_not_called setfacl
}

@test "acl_grant_readwrite on linux calls setfacl with rwX" {
    PLATFORM=linux acl_grant_readwrite "sandbox" "/proj"
    mock_assert_called_with setfacl "rwX"
}

@test "acl_grant_readwrite on linux sets default ACL" {
    PLATFORM=linux acl_grant_readwrite "sandbox" "/proj"
    mock_assert_called_with setfacl "-d"
}

# ── acl_revoke_readwrite ──────────────────────────────────────────────────────

@test "acl_revoke_readwrite on macOS calls chmod -a" {
    PLATFORM=macos acl_revoke_readwrite "sandbox" "$TEST_PATH"
    mock_assert_called_with chmod "-a"
}

@test "acl_revoke_readwrite on linux calls setfacl -x" {
    PLATFORM=linux acl_revoke_readwrite "sandbox" "/proj"
    mock_assert_called_with setfacl "-x"
}

@test "acl_revoke_readwrite on linux removes default ACL" {
    PLATFORM=linux acl_revoke_readwrite "sandbox" "/proj"
    mock_assert_called_with setfacl "-d -x"
}

@test "acl_revoke_readwrite on linux does not call chmod" {
    PLATFORM=linux acl_revoke_readwrite "sandbox" "/proj"
    mock_assert_not_called chmod
}
