# sweet-wrapper TODOs

Tracking known gaps and follow-ups, ordered roughly by impact.

## Real holes (security / correctness)

### 1. Close the read-access gap on home dirs

The dual-user mechanism only works as advertised once `chmod 700 ~` is in place
AND `acl_grant_read` adds traverse-only ACEs on parent dirs up to `~`. Without
that, files at 644 (default macOS) are readable by any OS user including
`agent-sandbox` — the project's stated guarantee ("read access to an
allowlisted set of paths") doesn't hold on a default install.

**Concrete work:**
- `setup.sh` should `chmod 700 ~` (with a confirm prompt, since it's user data).
- `acl_grant_read <path>` should walk parent dirs up to `~` and add a
  traverse-only ACE (`search,execute` on macOS; `setfacl u:agent-sandbox:--x`
  on Linux) on each.
- `acl_revoke_read` should NOT remove parent traverse ACEs (other allowlisted
  paths may still need them) — needs a refcount or recompute-from-allowlist
  approach.

### 2. Real-behavior tests, not just mocks

Three bugs slipped through the test suite into manual use this session:
`env --` on BSD, `chmod --` on BSD, `find /proj` for non-existent paths. All
would have been caught by an end-to-end smoke suite that creates an actual
low-privilege test user and exercises grant → run-as → revoke for real.

**Concrete work:**
- `wrapper/tests/integration/` directory with bats tests that:
  - Create a temporary low-priv user (or reuse `nobody` where possible).
  - Run real `chmod`/`setfacl`/`sudo` against a tempdir.
  - Assert the test user actually can/can't access what we expect.
- Gate behind a `RUN_INTEGRATION=1` env var so they don't run by default.

### 3. Crash recovery for transient ACLs

The EXIT trap in `_cmd_exec` doesn't fire on `kill -9` or system crash, leaving
the workspace RW ACL granted indefinitely.

**Concrete work:**
- `acl_grant_readwrite` should revoke any pre-existing `agent-sandbox` ACE
  on the target before granting. Self-healing on next invocation.
- `agent-sandbox status` could detect and warn about workspace ACLs not in
  the allowlist (likely stale from a crash).

## Genuinely useful additions

### 4. `agent-sandbox shell`

Drop into a shell as the sandbox user with the same env and ACL setup the
agent would get. We used ad-hoc `agent-sandbox printenv` for debugging this
session; making this first-class makes future diagnostics trivial.

```
agent-sandbox shell           # interactive shell
agent-sandbox shell -c '...'  # one-liner
```

### 5. Resource limits

No CPU/memory/wall-time bounds. An agent stuck in a loop hits OOM rather than
a clean timeout. Add `ulimit` calls in the wrapper before `exec`, or use
`prlimit` (Linux) / `launchctl limit` (macOS). Configurable defaults via
`~/.config/agent-sandbox/limits` (mirroring `allowlist` and `api-keys`).

### 6. Uninstall

`setup.sh --uninstall` to remove the user, sudoers drop-in, and
`/Users/Shared/agent-sandbox-home`. Currently a manual cleanup.

## Worth thinking about, lower priority

### 7. Symlink-aware deny check

Current `deny_check_path` does string comparison only. Someone allows
`~/code/foo` which contains a symlink to `~/.ssh` and the deny check passes.
Should `realpath`-resolve the candidate AND scan the resulting tree for
symlinks pointing into sensitive territory.

### 8. Scoped sudoers

v1 picked `NOPASSWD: ALL` for robustness as new agent CLIs appear. A scoped
list of agent CLI binaries is tighter at the cost of needing maintenance.
Worth revisiting once the set of agent CLIs stabilizes.

### 9. TCC diagnostic on macOS

`CLAUDE.md` flags TCC as a footgun but `agent-sandbox status` doesn't warn if
the terminal lacks Full Disk Access. A quick check (try to `stat ~/Library` or
similar) and a clear "Grant Full Disk Access in System Settings" message would
save users a confusing debugging session.

### 10. CI

No GitHub Actions. Cross-platform shell scripts especially benefit from
running tests on macOS *and* Linux runners on every PR. Combined with #2,
this would make regressions like the BSD `--` bugs effectively impossible to
land.

## Polish / smaller items

- **Better error messages.** ACL/sudo failures fall through with the
  underlying tool's cryptic output. Wrap them with sweet-wrapper context.
- **Per-agent profiles.** `claude` and `cursor-agent` share everything; a
  profile mechanism (`~/.config/agent-sandbox/profiles/<cli>.conf`) would let
  them diverge cleanly.
- **Sandbox HOME hygiene.** `/Users/Shared/agent-sandbox-home` accumulates
  history, caches, and OAuth state forever. A `agent-sandbox clean-home`
  command (with confirmation, since it nukes the OAuth login) would help.
- **api-keys file mode.** Currently created with default umask (likely 644).
  Doesn't contain values, only var names, but `chmod 600` on creation would
  be consistent with other secrets-adjacent files.
- **Network egress.** Out of scope per `CLAUDE.md`, but worth a section in
  `README` clarifying what the sandbox does and doesn't restrict so users
  don't have false expectations.
