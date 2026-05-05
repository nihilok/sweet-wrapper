#!/usr/bin/env bash
# One-time setup: creates the sandbox OS user, sandbox home, and sudoers drop-in.
# Idempotent — safe to re-run.
#
# Usage: ./wrapper/setup.sh
# (Prompts for sudo if not already root.)
set -euo pipefail

# Re-invoke under sudo when not root.
if [[ "$EUID" -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# Resolve symlinks so the script works when invoked via a link.
_src="${BASH_SOURCE[0]}"
while [[ -L "$_src" ]]; do
    _dir="$(cd -P "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    [[ "$_src" != /* ]] && _src="${_dir}/${_src}"
done
LIB="$(cd -P "$(dirname "$_src")/lib" && pwd)"
# shellcheck source=lib/platform.sh
source "${LIB}/platform.sh"
# shellcheck source=lib/sandbox.sh
source "${LIB}/sandbox.sh"

_create_user_macos() {
    if id "$SANDBOX_USER" &>/dev/null; then
        echo "  User '${SANDBOX_USER}' already exists, skipping."
        return 0
    fi
    # Pick the next available UID above current max.
    local uid
    uid="$(( $(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1) + 1 ))"
    dscl . -create "/Users/${SANDBOX_USER}"
    dscl . -create "/Users/${SANDBOX_USER}" UserShell /usr/bin/false
    dscl . -create "/Users/${SANDBOX_USER}" RealName "Agent Sandbox"
    dscl . -create "/Users/${SANDBOX_USER}" UniqueID "$uid"
    dscl . -create "/Users/${SANDBOX_USER}" PrimaryGroupID 20
    dscl . -create "/Users/${SANDBOX_USER}" NFSHomeDirectory "$SANDBOX_HOME"
    echo "  Created user '${SANDBOX_USER}' (UID ${uid})."
}

_create_user_linux() {
    if id "$SANDBOX_USER" &>/dev/null; then
        echo "  User '${SANDBOX_USER}' already exists, skipping."
        return 0
    fi
    useradd -r -m -d "$SANDBOX_HOME" -s /usr/sbin/nologin "$SANDBOX_USER"
    echo "  Created user '${SANDBOX_USER}'."
}

_ensure_sandbox_home() {
    mkdir -p "$SANDBOX_HOME"
    chown "${SANDBOX_USER}" "$SANDBOX_HOME"
    chmod 700 "$SANDBOX_HOME"
    echo "  Sandbox home: ${SANDBOX_HOME}"
}

_install_sudoers() {
    if [[ -f "$SUDOERS_FILE" ]]; then
        echo "  Sudoers drop-in already exists at ${SUDOERS_FILE}, skipping."
        return 0
    fi
    # Use $SUDO_USER (set by sudo) or fall back to $LOGNAME.
    local invoking_user="${SUDO_USER:-$LOGNAME}"
    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<EOF
# Installed by sweet-wrapper setup.sh.
# Allows ${invoking_user} to run any command as ${SANDBOX_USER} without a password.
${invoking_user} ALL=(${SANDBOX_USER}) NOPASSWD: ALL
EOF
    if visudo -cf "$tmp" >/dev/null 2>&1; then
        install -m 440 "$tmp" "$SUDOERS_FILE"
        rm -f "$tmp"
        echo "  Sudoers drop-in installed at ${SUDOERS_FILE}."
    else
        rm -f "$tmp"
        echo "error: visudo validation failed — sudoers not installed." >&2
        exit 1
    fi
}

echo "==> Creating sandbox user (${SANDBOX_USER})"
case "$(platform_current)" in
    macos)  _create_user_macos ;;
    linux|wsl) _create_user_linux ;;
    *)
        echo "error: unsupported platform '$(platform_current)'" >&2
        exit 1
        ;;
esac

echo "==> Ensuring sandbox home"
_ensure_sandbox_home

echo "==> Installing sudoers"
_install_sudoers

echo ""
echo "Setup complete. Next steps:"
echo "  agent-sandbox allow ~/code      # grant read access to a project directory"
echo "  cd ~/code/myproject && agent-sandbox claude"
