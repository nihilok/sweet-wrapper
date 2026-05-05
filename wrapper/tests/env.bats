#!/usr/bin/env bats
# Tests for lib/env.sh

LIB="${BATS_TEST_DIRNAME}/../lib"

setup() {
    # shellcheck source=/dev/null
    source "${LIB}/env.sh"
    unset COLORTERM FORCE_COLOR NO_COLOR LC_ALL LC_CTYPE
}

# Helper: assert output contains a fixed string
_has() { echo "$1" | grep -qF "$2"; }

# ── static allowlist ──────────────────────────────────────────────────────────

@test "PATH is included" {
    export PATH=/usr/bin:/bin
    _has "$(env_passthrough)" "PATH=/usr/bin:/bin"
}

@test "TERM is included when set" {
    export TERM=xterm-256color
    _has "$(env_passthrough)" "TERM=xterm-256color"
}

@test "FORCE_COLOR is included when set" {
    export FORCE_COLOR=1
    _has "$(env_passthrough)" "FORCE_COLOR=1"
}

@test "unset allowlisted var is omitted" {
    unset COLORTERM
    ! env_passthrough | grep -q '^COLORTERM='
}

# ── LC_* glob ─────────────────────────────────────────────────────────────────

@test "exported LC_ALL is included" {
    export LC_ALL=en_GB.UTF-8
    _has "$(env_passthrough)" "LC_ALL=en_GB.UTF-8"
}

@test "unexported LC_ALL is excluded" {
    # env | grep '^LC_' only sees exported vars
    unset LC_ALL
    ! env_passthrough | grep -q '^LC_ALL='
}

# ── sensitive vars are excluded ───────────────────────────────────────────────

@test "arbitrary var is not included" {
    export MY_SECRET=hunter2
    ! env_passthrough | grep -q '^MY_SECRET='
}

@test "HOME is not included" {
    # HOME is set by the exec wrapper to the sandbox home, not passed through
    export HOME=/root
    ! env_passthrough | grep -q '^HOME='
}

@test "SSH_AUTH_SOCK is not included" {
    export SSH_AUTH_SOCK=/tmp/ssh.sock
    ! env_passthrough | grep -q '^SSH_AUTH_SOCK='
}

# ── caller-supplied extras ────────────────────────────────────────────────────

@test "VAR=value extra is passed verbatim" {
    _has "$(env_passthrough "ANTHROPIC_API_KEY=sk-test")" "ANTHROPIC_API_KEY=sk-test"
}

@test "bare VAR extra is resolved from env" {
    export ANTHROPIC_API_KEY=sk-resolved
    _has "$(env_passthrough "ANTHROPIC_API_KEY")" "ANTHROPIC_API_KEY=sk-resolved"
}

@test "unset bare VAR extra is omitted" {
    unset ANTHROPIC_API_KEY
    ! env_passthrough "ANTHROPIC_API_KEY" | grep -q '^ANTHROPIC_API_KEY='
}

@test "multiple extras are all included" {
    out=$(env_passthrough "FOO=1" "BAR=2")
    _has "$out" "FOO=1"
    _has "$out" "BAR=2"
}

# ── extras win over the allowlist (no duplicate keys) ─────────────────────────

@test "VAR=value extra overrides allowlisted var" {
    export PATH=/usr/bin:/bin
    out=$(env_passthrough "PATH=/sandbox/bin")
    _has "$out" "PATH=/sandbox/bin"
    # Only one PATH= line in the output, not both.
    [[ "$(echo "$out" | grep -c '^PATH=')" -eq 1 ]]
}

@test "VAR=value extra overrides exported LC_*" {
    export LC_ALL=en_GB.UTF-8
    out=$(env_passthrough "LC_ALL=C")
    _has "$out" "LC_ALL=C"
    [[ "$(echo "$out" | grep -c '^LC_ALL=')" -eq 1 ]]
}

# ── output shape ─────────────────────────────────────────────────────────────

@test "every output line is VAR=value" {
    out=$(env_passthrough "X=1")
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *=* ]] || { echo "Malformed line: ${line}"; return 1; }
    done <<< "$out"
}
