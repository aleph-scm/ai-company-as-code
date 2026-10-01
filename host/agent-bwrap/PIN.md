# Pin record

Vendored copy, not a submodule — the same choice made on ALE-148's prod
consumer PR (https://github.com/aleph-scm/prod/pull/148), for the same reason:
a submodule needs a second `git submodule update` step on every clone/CI
checkout that a rebuild-from-README (Phase 2/3) would otherwise have to spell
out and get right; a vendored copy is just files.

- Source: https://github.com/aleph-scm/agent-bwrap
- Tag: `v0.1.0`
- Commit: `faa871225590b26fb76f25abb2d65e3264648904`
- Vendored: 2026-09-25, verbatim (`git clone --depth 1 --branch v0.1.0`, `.git`/`.github` stripped)

To pick up a newer tag: re-run the same clone against the new tag, replace
this directory's contents (except this file), update the version/commit
above, and note why in the commit message.
