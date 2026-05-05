# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`sweet-wrapper` is a cross-platform sandboxing wrapper for agent CLIs (e.g. Claude Code, Cursor agents). It runs the agent as a low-privileged OS user with:

- **Read access** to an allowlisted set of paths (not blanket home access — see design rationale below)
- **Write access** only within a specified workspace directory
- **No persistent state** leakage between sessions (sandbox user has its own `$HOME`)

Target platforms: **macOS**, **Linux**, **WSL2**.

## Design decisions (captured from initial planning)

**Allowlist over blanket read**: Granting the sandbox user read access to everything `$USER` can read is the wrong default. macOS TCC (privacy framework) fights blanket access to `~/Documents`, `~/Desktop`, `~/Downloads` for non-GUI users, and the security gain is negative anyway. Use an explicit allowlist of project directories instead.

**Dual-user approach over bwrap/namespaces**: `bwrap` is Linux-only. `sandbox-exec` is macOS-deprecated. The dual-user approach (create `agent-sandbox` user, manage permissions explicitly) is the only mechanism that works consistently across macOS, Linux, and WSL2 — so that's what this project uses.

**Sensitive path deny list**: Even within an allowlisted read scope, certain paths must be explicitly denied: `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config/gcloud`, `~/.kube`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`, browser profile dirs, and any `*.env`/`*.pem`/`*.key` files.

**Network egress**: The wrapper does not attempt to restrict outbound network access in v1. This is accepted scope, not an oversight.

**Platform scripts are separate**: Don't try to make setup logic identical across platforms. Maintain separate setup paths for macOS and Linux/WSL2 with a shared user-facing interface (`agent-sandbox <cli> [args]`).

## Platform-specific notes

### macOS
- User creation via `sysadminctl -addUser` or `dscl`
- ACLs via `chmod +a "user:agent-sandbox allow read" <path>`
- TCC is a real headache: the terminal app running the wrapper may need Full Disk Access granted in System Settings to avoid silent denials on `~/Documents` etc. Test this early.

### Linux / WSL2
- User creation via `useradd -m agent-sandbox`
- ACLs via `setfacl`
- On WSL2: keep the workspace in the Linux filesystem (`~/workspace`, not `/mnt/c/...`). Windows-side paths have broken permission semantics and ACLs may not apply.

## Development

Requires [bats-core](https://bats-core.readthedocs.io/) (`brew install bats-core` on macOS; `apt install bats` on Linux).

```bash
# Run all tests
run test

# Run a single lib's tests
run test:one platform   # or env, acl

# Without run:
bats wrapper/tests/platform.bats wrapper/tests/env.bats wrapper/tests/acl.bats
```

## Wrapper structure

```
wrapper/
  lib/
    platform.sh     # Platform detection; override via PLATFORM=macos|linux|wsl
    env.sh          # env_passthrough — allowlist for the sandbox user
    acl.sh          # acl_grant_read / acl_revoke_read, platform-aware
  tests/
    platform.bats
    env.bats
    acl.bats
    helpers/
      mocks.bash    # mocks_setup/teardown, mock_cmd, mock_assert_*
  setup.sh          # (TODO) one-time setup: user creation, ACL grants, sudoers
  agent-sandbox     # (TODO) exec wrapper: env filtering, sudo -u agent-sandbox
```

The setup subcommand is run once per machine. The exec wrapper is what users invoke daily.

## Environment handling

The sandbox user gets an explicit env allowlist, not a full env passthrough. `PATH`, `TERM`, and `LC_*` vars are always included. API key var names are configured in `~/.config/agent-sandbox/api-keys` (one name per line; comments allowed). Defaults when that file is absent: `CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY CURSOR_AGENT_TOKEN`. Set `HOME` to a sandbox-owned directory (e.g. `/var/agent-sandbox-home`), not the real user's home.

## Git / auth for agents

If the agent needs to commit or push: prefer a scoped GitHub token in the workspace over SSH agent forwarding (forwarding reintroduces the credential-access risk the wrapper is meant to contain).
