#!/usr/bin/env bash
# Per-platform ACL helpers for granting/revoking read (or read+write) access on paths.

# shellcheck source=./platform.sh
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh"

# macOS ACE granting read + traverse, with file_inherit/directory_inherit so new
# children pick up the ACE automatically. BSD chmod uses underscored names for
# directory-write perms (add_file, add_subdirectory, delete_child) — not Linux-style.
_MACOS_ACE="read,readattr,readextattr,readsecurity,list,search,execute,file_inherit,directory_inherit"

# macOS ACE granting full read + write (used for the workspace directory).
_MACOS_WRITE_ACE="read,readattr,readextattr,readsecurity,list,search,execute,write,writeattr,writeextattr,writesecurity,append,delete,delete_child,add_file,add_subdirectory,file_inherit,directory_inherit"

# Grant sandbox user read + traverse on a path. Recursive on both platforms so
# existing files in the tree pick up the ACE; inherit flags (macOS) and default ACL
# (Linux) handle future children.
# Usage: acl_grant_read <user> <path>
acl_grant_read() {
    local user="$1" path="$2"
    if platform_is_macos; then
        # `find … -type d -o -type f` skips symlinks so dangling links don't error.
        # BSD chmod does not support `--`; absolute paths from _canonicalize are safe.
        find "$path" \( -type d -o -type f \) -exec \
            chmod +a "user:${user} allow ${_MACOS_ACE}" {} +
    else
        setfacl -R    -m "u:${user}:rX" -- "$path"
        setfacl -R -d -m "u:${user}:rX" -- "$path"   # default ACL covers new files
    fi
}

# Revoke read access previously granted by acl_grant_read. Best-effort (no-op if absent).
# Removes both the access ACL and the default ACL on Linux — otherwise newly created
# files in the tree would still inherit the default entry after a revoke.
# Usage: acl_revoke_read <user> <path>
acl_revoke_read() {
    local user="$1" path="$2"
    if platform_is_macos; then
        find "$path" \( -type d -o -type f \) -exec \
            chmod -a "user:${user} allow ${_MACOS_ACE}" {} + 2>/dev/null || true
    else
        setfacl -R    -x "u:${user}" -- "$path" 2>/dev/null || true
        setfacl -R -d -x "u:${user}" -- "$path" 2>/dev/null || true
    fi
}

# Grant sandbox user read + write on a path (recursive, with default ACL on Linux).
# Used for the per-invocation workspace grant in the exec wrapper.
# Usage: acl_grant_readwrite <user> <path>
acl_grant_readwrite() {
    local user="$1" path="$2"
    if platform_is_macos; then
        find "$path" \( -type d -o -type f \) -exec \
            chmod +a "user:${user} allow ${_MACOS_WRITE_ACE}" {} +
    else
        setfacl -R    -m "u:${user}:rwX" -- "$path"
        setfacl -R -d -m "u:${user}:rwX" -- "$path"
    fi
}

# Revoke read+write access previously granted by acl_grant_readwrite. Best-effort.
# Usage: acl_revoke_readwrite <user> <path>
acl_revoke_readwrite() {
    local user="$1" path="$2"
    if platform_is_macos; then
        find "$path" \( -type d -o -type f \) -exec \
            chmod -a "user:${user} allow ${_MACOS_WRITE_ACE}" {} + 2>/dev/null || true
    else
        setfacl -R    -x "u:${user}" -- "$path" 2>/dev/null || true
        setfacl -R -d -x "u:${user}" -- "$path" 2>/dev/null || true
    fi
}
