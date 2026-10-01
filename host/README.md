# host/ — the layer the export can't see

`scripts/export.sh` backs up the company as Paperclip knows it: agents,
projects, skills, config. It cannot back up the machine that runs Paperclip.
This directory is that machine, captured by hand, real values included —
this whole repo is private, so there is nothing to redact here (that's
Phase 4's job, on the public mirror).

| Path | What it is | Live on prod at |
|---|---|---|
| `agent-bwrap/` | Bubblewrap confinement wrapper for coding-agent CLIs. Vendored copy of `aleph-scm/agent-bwrap` tag `v0.1.0` — see `agent-bwrap/PIN.md` for why vendored-not-submodule. | consumed via prod's own vendored copy, see the PR linked in PIN.md |
| `apparmor/paperclip-bwrap` | AppArmor profile for the bwrap binary Paperclip's own sandboxing uses. | `/etc/apparmor.d/paperclip-bwrap` |
| `sudoers.d/paperclip-restart` | Scoped NOPASSWD grant letting the `paperclip` service account restart (only restart) `paperclip.service`. Full rationale and the safety precondition (config files must stay `chattr +i`) are in the file. | `/etc/sudoers.d/paperclip-restart` |
| `systemd/paperclip.service` + `paperclip.service.d/*.conf` | The control-plane unit and its two drop-ins (PATH fix, memory ceiling). **These were not version-controlled anywhere before this export** — captured verbatim from the live host via `systemctl cat` on 2026-09-25. That gap is exactly what this repo exists to close. | `/etc/systemd/system/paperclip.service{,.d/*.conf}` |
| `mcp/paperclip-mcp.md` | Documents, but cannot vendor, the board's MCP-over-SSH wrapper — see that file for why. | `~/.local/bin/paperclip-mcp` (board operator's account, not readable from here) |

## `scripts/export.sh`'s host dependencies

Not a file this directory can vendor (they're standard packages, not
Aleph-specific config), but a silent dependency the export routine would
fail on every night if missing, so recorded here rather than only
discoverable by a 2am failure:

| Binary | Why | Verified present on prod |
|---|---|---|
| `gitleaks` >= 8.30.1 | `export.sh` hard-fails (exit 2) rather than commit an unscanned diff if this is missing from `$PATH` (or `$GITLEAKS_BIN`). | `~/.local/bin/gitleaks`, installed 2026-09-25 during this ticket — **not** part of the runner image; a fresh runner needs it installed explicitly. |
| `jq` >= 1.7 | Normalises the `routines.json` capture (see `docs/fidelity.md`) — whitelists fields, resolves agent/project ids to slugs, sorts for a stable diff. `export.sh` hard-fails if missing. | `/usr/bin/jq`, part of this host's base image. |
| `curl`, `git`, `npx`/`node` | Fetch routines/agents/projects, run `paperclipai company export`, and commit/push. | present as baseline tooling; not separately verified since nothing in this ticket found them missing. |

None of these are pinned by version anywhere except this table. If a rebuilt
runner lacks `gitleaks` or `jq`, every nightly export fails loudly (correct
per the ALE-145 no-false-green contract) rather than silently skipping the
check it depends on.

## No systemd timers here

Scheduled company work (this export, the Prod repo drift check, the daily
summary) runs as **Paperclip routines**, not systemd timers — Paperclip's own
scheduler wakes the assigned agent. There is currently no systemd timer that
is part of running this company; if one is added later, it belongs in this
directory next to its `.service` unit.

## Restoring this layer

1. Provision a host with `bwrap` installed and this repo checked out.
2. Install `apparmor/paperclip-bwrap`, load it (`apparmor_parser -r`).
3. Install `sudoers.d/paperclip-restart` per the header instructions in that file.
4. Vendor or symlink `agent-bwrap/` where the adapter config expects it, and
   set `AGENT_BWRAP_*` per `agent-bwrap/config/agent-bwrap.env.example`.
5. Install Paperclip itself (`npx paperclipai install`, out of this repo's
   scope), then install `systemd/paperclip.service` and its drop-ins, apply
   the `chattr +i` precondition the sudoers grant depends on, `daemon-reload`,
   `enable --now`.
6. Re-create `~/.local/bin/paperclip-mcp` from the board's own records (see
   `mcp/paperclip-mcp.md`) if remote MCP access is needed.
7. Run `paperclipai company import` — see `../docs/fidelity.md` for the exact
   command and what still needs manual attention after it.

Phase 2 turns steps 1–7 into an asserted CI job; until then this is the
runbook, and it has not yet been executed start-to-finish by anyone other than
the person who built prod by hand originally.
