#!/usr/bin/env bash
# Platform detection.
# Tests (and callers) can override by setting PLATFORM=macos|linux|wsl before
# sourcing, bypassing uname/proc entirely.

_platform_detect() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *) echo "unsupported" ;;
    esac
}

# Returns the active platform string. Reads $PLATFORM if set, detects otherwise.
platform_current()         { echo "${PLATFORM:-$(_platform_detect)}"; }

platform_is_macos()        { [[ "$(platform_current)" == "macos"  ]]; }
platform_is_linux()        { [[ "$(platform_current)" == "linux"  ]]; }
platform_is_wsl()          { [[ "$(platform_current)" == "wsl"    ]]; }
platform_is_linux_or_wsl() { platform_is_linux || platform_is_wsl; }
