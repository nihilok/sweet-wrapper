#!/usr/bin/env bats
# Tests for lib/platform.sh
#
# No real platform detection happens here — every test sets PLATFORM directly.
# This also serves as the spec for what values each function returns.

LIB="${BATS_TEST_DIRNAME}/../lib"

setup() {
    # shellcheck source=/dev/null
    source "${LIB}/platform.sh"
    unset PLATFORM
}

# ── platform_current ──────────────────────────────────────────────────────────

@test "platform_current echoes PLATFORM when set" {
    PLATFORM=macos
    [[ "$(platform_current)" == "macos" ]]
}

@test "platform_current echoes wsl when PLATFORM=wsl" {
    PLATFORM=wsl
    [[ "$(platform_current)" == "wsl" ]]
}

# ── platform_is_macos ─────────────────────────────────────────────────────────

@test "platform_is_macos succeeds when PLATFORM=macos" {
    PLATFORM=macos platform_is_macos
}

@test "platform_is_macos fails when PLATFORM=linux" {
    PLATFORM=linux
    ! platform_is_macos
}

@test "platform_is_macos fails when PLATFORM=wsl" {
    PLATFORM=wsl
    ! platform_is_macos
}

# ── platform_is_linux ─────────────────────────────────────────────────────────

@test "platform_is_linux succeeds when PLATFORM=linux" {
    PLATFORM=linux platform_is_linux
}

@test "platform_is_linux fails when PLATFORM=macos" {
    PLATFORM=macos
    ! platform_is_linux
}

@test "platform_is_linux fails when PLATFORM=wsl" {
    PLATFORM=wsl
    ! platform_is_linux
}

# ── platform_is_wsl ───────────────────────────────────────────────────────────

@test "platform_is_wsl succeeds when PLATFORM=wsl" {
    PLATFORM=wsl platform_is_wsl
}

@test "platform_is_wsl fails when PLATFORM=linux" {
    PLATFORM=linux
    ! platform_is_wsl
}

@test "platform_is_wsl fails when PLATFORM=macos" {
    PLATFORM=macos
    ! platform_is_wsl
}

# ── platform_is_linux_or_wsl ──────────────────────────────────────────────────

@test "platform_is_linux_or_wsl succeeds for linux" {
    PLATFORM=linux platform_is_linux_or_wsl
}

@test "platform_is_linux_or_wsl succeeds for wsl" {
    PLATFORM=wsl platform_is_linux_or_wsl
}

@test "platform_is_linux_or_wsl fails for macos" {
    PLATFORM=macos
    ! platform_is_linux_or_wsl
}
