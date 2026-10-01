# agent-bwrap

A [Bubblewrap](https://github.com/containers/bubblewrap) confinement shim for
untrusted coding-agent CLIs. It wraps a real agent binary so it runs with the
host filesystem hidden except for a workspace directory and a short, explicit
allowlist of other paths — instead of the agent's only boundary being
whatever `cwd` convention its caller happens to follow.

## Why

Coding-agent CLIs are typically invoked with broad, unaudited filesystem
access: whatever the invoking process can read or write, the agent process
can too. That is a wide blast radius for a process whose job is to run
model-generated shell commands. `agent-bwrap` narrows that surface to what the
agent's task actually needs, using a Linux user-namespace sandbox rather than
relying on the agent's own good behavior.

## What it confines

- **Filesystem**, read-write: the workspace directory you name, plus any
  extra read-write paths you list (the agent's own config/cache/state
  directories, package-manager caches, a scratch directory).
- **Filesystem**, read-only: git and SSH credentials, if you choose to bind
  them in — the agent can use them to fetch/push/open a PR, but not to write
  to them or to anything outside the paths you named.
- Everything else on the host: not mounted into the sandbox, so not visible
  at all. Writes to unbound paths succeed and go nowhere — the sandbox root
  is a fresh tmpfs, so `echo x > ~/unrelated-file` returns exit 0 inside the
  sandbox and leaves nothing on the host.

## What it does not confine

- **Network.** There is no network namespace isolation here. A process
  inside the sandbox can reach any network destination the host can reach.
- **The agent's own future invocation**, if something outside the sandbox
  (a control plane, an orchestrator) lets the agent change how it will next
  be run. `agent-bwrap` only constrains the filesystem visible to the
  process it launches, for the duration of that process. If your deployment
  lets a confined agent edit the configuration that decides whether the next
  run is confined, that is a gap this tool does not close — see
  [Threat model](#threat-model).

## Host prerequisites

- **bubblewrap** (`bwrap`) installed and on `PATH`, or pointed to via
  `BWRAP_BIN`.
- **bash** and standard coreutils (`stat`, `mkdir`, `id`).
- On a host that restricts unprivileged user-namespace creation — Ubuntu
  24.04's default, `kernel.apparmor_restrict_unprivileged_userns=1` — an
  AppArmor profile granting `userns` to the `bwrap` binary you point
  `BWRAP_BIN` at. See [`apparmor/agent-bwrap.profile.example`](apparmor/agent-bwrap.profile.example)
  for a scoped profile and the install steps. Most other Linux distributions
  do not need this step. GitHub's `ubuntu-latest` (24.04) runners do; this
  repo's CI installs the profiled copy exactly as described.
- A uid/group model where the account running `bin/agent-bwrap` can execute
  `BWRAP_BIN`. If you install a dedicated profiled copy (recommended over
  profiling the system binary), restrict it to a group scoped to the agents
  you intend to confine.

## 60-second install

```bash
git clone https://github.com/aleph-scm/agent-bwrap.git
cd agent-bwrap
cp config/agent-bwrap.env.example config/agent-bwrap.env
# edit config/agent-bwrap.env: set AGENT_BWRAP_CMD and AGENT_BWRAP_WORKSPACE

AGENT_BWRAP_CONFIG=config/agent-bwrap.env ./bin/agent-bwrap --version
```

That runs your agent's `--version` (or whatever argv you give) inside the
sandbox. Point whatever launches your agent at `bin/agent-bwrap` instead of
the agent binary directly, with the same argv and env it would otherwise get,
plus the `AGENT_BWRAP_*` variables below.

## Configuration

All configuration is environment variables, settable directly or via a file
named by `AGENT_BWRAP_CONFIG` (sourced as shell before the wrapper validates
its config — see [`config/agent-bwrap.env.example`](config/agent-bwrap.env.example)
for a fully documented example).

| Variable | Required | Meaning |
| --- | --- | --- |
| `AGENT_BWRAP_CMD` | yes | Absolute path to the real agent binary to exec inside the sandbox. |
| `AGENT_BWRAP_WORKSPACE` | yes | Absolute path to the read-write workspace directory. Created if missing. |
| `BWRAP_BIN` | no (default `bwrap`) | Path to the bwrap binary. Point this at a profiled copy on hosts that need one — see Host prerequisites. |
| `AGENT_BWRAP_RW` | no | Colon-separated extra read-write bind paths. |
| `AGENT_BWRAP_RO` | no | Colon-separated extra read-only bind paths (e.g. git/SSH credentials). |
| `AGENT_BWRAP_SYSTEM_RO` | no | Colon-separated additions to the built-in read-only `/etc` allowlist. |
| `AGENT_BWRAP_NO_SYSTEM_DEFAULTS` | no | Set to `1` to skip the built-in `/etc` allowlist and use only `AGENT_BWRAP_SYSTEM_RO`. |
| `AGENT_BWRAP_CONFIG` | no | Path to a shell-sourceable file supplying any of the above. |

`bin/agent-bwrap` refuses to start — exits non-zero before touching
Bubblewrap at all — if `AGENT_BWRAP_CMD` is unset or not executable, or if
`AGENT_BWRAP_WORKSPACE` is unset. There is no implicit "run unconfined"
fallback.

## Testing

```bash
tests/run.sh
```

Runs in GitHub Actions on `ubuntu-latest` (see
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)) against the system
`bwrap` package. Each claim in this README that affects behavior is backed by
one of these tests:

- a write to a path outside the configured mounts returns exit 0 and leaves
  nothing on the host (the tmpfs-root behavior described above);
- a read of a path outside the sandbox boundary fails with "No such file or
  directory";
- a path listed in `AGENT_BWRAP_RO` is visible but not writable inside the
  sandbox;
- network access from inside the sandbox works (no network confinement);
- the wrapper exits non-zero and does not invoke bwrap at all when required
  configuration is missing.

## Threat model

`agent-bwrap` is a filesystem boundary, not a full sandbox. Specifically:

- **No network confinement.** Anything the sandboxed process can reach on
  the network, it can reach regardless of this tool. If the agent has an API
  key or credential that grants remote write access to something, that
  access exists inside the sandbox exactly as it did outside it.
- **Credentials you bind in are usable, not just visible.** Binding git/SSH
  credentials read-only means the agent cannot overwrite the credential
  files themselves, but it can still use them to authenticate — push,
  open PRs, fetch private repos — with whatever scope those credentials
  carry. This is not a regression versus an unconfined agent holding the
  same credentials, but it is not a reduction in what the agent can do with
  them either.
- **Self-un-confinement via an external control plane is out of scope.**
  If the process that decides how to invoke your agent (a control plane, an
  orchestrator, a scheduler) stores that decision somewhere the agent itself
  can write to — and the agent has been granted write access to that
  store — a confined agent can rewrite its own future invocation to drop the
  sandbox on the next run. `agent-bwrap` confines one process for one
  invocation; it has no way to see or constrain how the next invocation gets
  built. Closing this gap means constraining what the agent can write in
  whatever system decides its own invocation, which is specific to that
  system's design and out of scope for this tool.
- **The allowlisted `/etc` paths and system binaries are trusted.** This
  tool does not sandbox against a compromised `bwrap` binary, kernel, or the
  contents of anything you list in `AGENT_BWRAP_RO`/`AGENT_BWRAP_RW`/
  `AGENT_BWRAP_SYSTEM_RO`. Bind only what the agent's task actually needs.

If your use case needs network confinement or a defense against the
self-un-confinement gap above, this tool alone does not provide either;
treat it as one layer, not the whole boundary.

## License

MIT. See [`LICENSE`](LICENSE).
