# Confinement: how the OpenCode Go tier is sandboxed

Seven of Aleph's twelve agents run on third-party models via OpenCode Go
(Adversary, Coder, Dreamer, QA, Reader, Researcher, Scout — see
[`README.md`](./README.md#model-tiers)). Those are the seats treated as
untrusted for filesystem purposes: whatever the model generates could be
wrong, and the confinement layer is what limits the damage of that, not
instruction text alone.

## The tool: `agent-bwrap`

Aleph vendors [`agent-bwrap`](https://github.com/aleph-scm/agent-bwrap)
(`v0.1.0`, vendored not submoduled — a submodule needs an extra
`git submodule update` step every checkout has to get right; a vendored
copy is just files) into `host/agent-bwrap/`. It's a thin
[Bubblewrap](https://github.com/containers/bubblewrap) wrapper: instead of
an agent CLI inheriting whatever filesystem access its invoking process
happens to have, `agent-bwrap` execs it inside a Linux user-namespace
sandbox with an explicit, short allowlist of paths.

### What it confines

- **Filesystem, read-write:** the agent's workspace directory, plus any
  extra read-write paths named explicitly (config/cache/state directories,
  package-manager caches, scratch space).
- **Filesystem, read-only:** git/SSH credentials, if bound in — usable to
  fetch, push, or open a PR, but not overwritable.
- **Everything else on the host:** not mounted, so not visible at all. A
  write to an unbound path succeeds and goes nowhere — the sandbox root is a
  fresh tmpfs, so `echo x > ~/unrelated-file` returns exit 0 inside the
  sandbox and leaves nothing on the real host.

### What it does not confine

- **Network.** No network namespace isolation. A sandboxed process can reach
  anything the host can reach, and any credential it holds is exactly as
  usable inside the sandbox as outside it.
- **The agent's next invocation**, if something outside the sandbox — an
  orchestrator, a control plane — lets the agent influence how it gets
  invoked *next time*. `agent-bwrap` only constrains the filesystem visible
  to the one process it launches, for the duration of that process. This is
  a known upstream limitation, tracked privately, and it is the boundary of
  what this tool claims to do — not a defect in this deployment specifically.

## What's actually live on Aleph's host

Confirmed live, not just configured: Coder runs confined through a
dedicated, profiled copy of `bwrap` (root-owned, mode 0750, restricted to a
group scoped to the agents meant to be confined — the system's default
`bwrap` binary stays denied unprivileged user-namespace creation for
everyone else). QA, Adversary, and the rest of the OpenCode Go tier run
confined the same way and cannot see the board's private material at all.

The three (now five — see the drift note in `README.md`) Claude-tier seats
are **not** filesystem-confined. That is a deliberate, board-reviewed
choice, not an oversight: the board considered extending confinement to
those seats and chose, in writing, to leave them unconfined, accepting the
resulting access as a named risk with five explicit conditions that would
reopen the question (a new Claude-backed hire; an existing seat's access
widening; non-recoverable material — live credentials, anything where a
single unauthorized read is the damage — entering the material those seats
can reach; evidence that a wrong edit from one of those seats has reached a
shared record uncaught; or a fixed calendar backstop date). None of those
five conditions had fired as of this export. This is why the Librarian's own
instructions call its data boundary "instruction text in its `AGENTS.md`,
and nothing else, by deliberate, written board choice" — a trust boundary
the company chose knowingly, not one it forgot to enforce.

## The AppArmor layer underneath

On hosts that restrict unprivileged user-namespace creation by default
(Ubuntu 24.04's `kernel.apparmor_restrict_unprivileged_userns=1`, and
GitHub's `ubuntu-latest` CI runners), plain Bubblewrap can't create the
namespace it needs at all. Aleph's fix was **not** to flip that sysctl
host-wide — that would grant unprivileged userns creation to every user and
process on the box, "much closer to the host-wide option than it reads" even
when framed as "just profile the existing binary." Instead: install a
second, dedicated, root-owned copy of `bwrap` at a private path, and grant
*only that copy* an AppArmor profile permitting userns creation. The
system's own `/usr/bin/bwrap` and every other user on the host remain
restricted exactly as before. The wrapper binary is root-owned on purpose,
and the reason is in the tool's own published threat model rather than
restated here: see the "Threat model" section of
`host/agent-bwrap/README.md` for what that ownership defends against and
which adjacent gap the sandbox explicitly does not close.

## Threat model, in plain terms

`agent-bwrap`'s own README states its scope directly: it is a filesystem
boundary, not a full sandbox. It does not defend against a compromised
`bwrap` binary or kernel, does not confine the network, and does not stop a
credential bound in read-only from being *used* with its full existing
scope — read-only means the agent can't overwrite the credential file, not
that the credential can't authenticate. Bind only what a task actually
needs; every additional read-write or read-only path is a widening QA is
instructed to flag as a security finding on review.

## Sources

- `host/agent-bwrap/README.md`, `host/agent-bwrap/PIN.md` (vendored copy,
  this repo).
- `host/README.md` (this repo) — AppArmor profile, live host table.
- aleph-brain `decisions/log.md`: "Bubblewrap userns block" entry (`ALE-61`,
  `ALE-62`); "Librarian confinement" entry (`ALE-107`, `ALE-108`, `ALE-113`)
  for the board's confined-vs-unconfined decision and its review conditions;
  "Bubblewrap confinement: partially live" open-discrepancy entry for current
  status.
- `agents/librarian/AGENTS.md` (this repo) — the Librarian's own stated data
  boundary.
