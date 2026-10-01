# paperclip-mcp — the board's MCP-over-SSH wrapper

**Not vendored here — could not be read, and that is the correct outcome, not
a shortcut.** The wrapper lives at `~/.local/bin/paperclip-mcp` under the
board operator's own account on prod (`operator`), not the `paperclip` service
account this export runs as. `paperclip` has no read access to `/home/operator`
(confirmed: `ls /home/operator/.local/bin` → permission denied) — the same
account boundary that keeps the confined agents from reaching the operator's
shell, SSH keys, or browser session. Vendoring it would require the board to
either paste its contents onto a ticket or loosen that boundary; neither is
this ticket's call to make.

## What is documented, for the rebuild-from-README test (Phase 2/3)

- Purpose: lets the board's local MCP client (Claude Desktop or equivalent)
  reach Paperclip's MCP server running on prod, over SSH, without exposing the
  MCP port to the network directly.
- Invocation shape: an MCP client config entry whose `command` is `ssh` into
  prod, running `paperclip-mcp` (or piping to it) on the remote end — the
  general "stdio-over-SSH" MCP pattern, not a prod-specific protocol.
  **Key path only, never the key itself**: the SSH identity file path belongs
  in the board operator's own MCP client config on their machine, not in this
  repo. If a future ticket documents this properly, the deliverable is the
  *path convention* the wrapper expects (e.g. an env var or flag naming the
  key file), not the key.
- Owner: the board (`operator`), not an Aleph agent. No agent should ever hold
  this key.

## Rebuild action for whoever restores this host

`paperclip-mcp` will not come back from this repo. After a rebuild, the board
must re-create `~/.local/bin/paperclip-mcp` and their local MCP client entry
from their own records. If that script only exists on prod today, that is a
single point of failure worth its own backup — flagged here, not fixed here.
