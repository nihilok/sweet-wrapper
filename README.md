# sweet-wrapper

A cross-platform sandboxing wrapper for agent CLIs (Claude Code, Cursor agents, etc.). Runs the agent as a low-privileged OS user with read access to allowlisted paths and write access only to the current workspace — without containers, namespaces, or deprecated APIs.

Works on macOS, Linux, and WSL2.

## How it works

sweet-wrapper creates a dedicated `agent-sandbox` OS user and runs your agent CLI as that user via `sudo`. Filesystem access is controlled with platform-native ACLs (`chmod +a` on macOS, `setfacl` on Linux/WSL). A clean env passthrough keeps your shell secrets and SSH agent socket out of the sandboxed process.

## Install

Requires bash 4+ and `bats-core` for tests (`brew install bats-core` / `apt install bats`).

```bash
git clone https://github.com/nihilok/sweet-wrapper.git
cd sweet-wrapper
./wrapper/setup.sh                                     # creates the sandbox user + sudoers
ln -s "$PWD/wrapper/agent-sandbox" ~/.local/bin/       # or wherever you keep CLI tools
```

## Usage

```bash
agent-sandbox allow ~/code              # one-time: grant the sandbox user read access
agent-sandbox status                    # show the configuration
cd ~/code/myproject
agent-sandbox claude                    # run claude as the sandbox user
```

The exec form (`agent-sandbox <cli> [args...]`) works for any CLI on `$PATH`. The current directory is granted transient read+write for the duration of the run.

## Configuration

- `~/.config/agent-sandbox/allowlist` — directories the sandbox user can read.
- `~/.config/agent-sandbox/api-keys` — env-var names to forward into the sandbox, one per line. Defaults to `CLAUDE_CODE_OAUTH_TOKEN OPENAI_API_KEY CURSOR_AGENT_TOKEN`.

## Tests

```bash
bats wrapper/tests/*.bats
```

## Status

Functional but rough. See [docs/TODOS.md](docs/TODOS.md) for known gaps — most importantly, on a default macOS install the sandbox user can still read most files via standard 644 permissions until you `chmod 700 ~` (a fix to make this automatic is on the list).

Network egress is not restricted. This is v1 scope, not an oversight.
