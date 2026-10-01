# AI company as code

Aleph is an AI company that runs on [Paperclip](https://github.com/paperclipai/paperclip):
every "employee" is an agent seat with its own instructions, model, budget and
reporting line, working Paperclip issues instead of a chat window. This repo
is a **generated, sanitised mirror** of Aleph's own private config —
org chart, agent instructions, skills, and a real (redacted) example of the
host layer Paperclip runs on.

**Never hand-edited.** This mirror is built and pushed by
[`scripts/sanitise.sh`](https://github.com/aleph-scm/company/blob/main/scripts/sanitise.sh)
in the private `aleph-scm/company` repo, on every change there. A PR against
this repo will be overwritten by the next sanitiser run without warning —
send changes to `aleph-scm/company` instead.

## Org chart

```
CEO (Claude, thinking tier)
├── CTO (Claude)
│   ├── Coder (OpenCode Go)
│   └── QA (OpenCode Go)
├── COO (Claude)
│   └── Librarian (Claude)
├── Navigator, "Head of Labs" (Claude)
│   ├── Researcher (OpenCode Go)
│   ├── Dreamer (OpenCode Go)
│   ├── Scout (OpenCode Go)
│   └── Reader (OpenCode Go)
└── Adversary (OpenCode Go)
```

See [`docs/README.md`](./docs/README.md) for what each seat owns, and
[`docs/operating-model.md`](./docs/operating-model.md) for the rules that
make it run without a human in the loop most of the time.

## Import this in one command

```
npx paperclipai company import https://github.com/aleph-scm/ai-company-as-code
```

This is the same command, against the same package shape
(`agentcompanies/v1`), that Aleph's own rebuild test
(`aleph-scm/company`'s `scripts/rebuild-test.sh`) runs in CI against the
private original. See [`docs/fidelity.md`](./docs/fidelity.md) for exactly
what does and doesn't survive an import, and what to do about each gap.

## What's deliberately left out, and why

- **Two client projects, entirely.** Board decision: customer work never
  appears in a public artefact, not even redacted.
- **Routines, schedules, and their triggers.** These describe Aleph's live
  operating cadence (what runs when, how often) rather than its design —
  and one routine's `env` carries a secret reference that can never be made
  public-safe. Not exported by the platform's own `company export` either
  (see `docs/fidelity.md`); this mirror doesn't attempt to recreate them a
  different way the way the private repo does.
- **Spend, budgets, and model choices.** Every agent's `model` and
  `budgetMonthlyCents` are stripped from `.paperclip.yaml` here. What a
  seat costs and which vendor it runs on is an operating decision, not part
  of the design this repo exists to share.
- **Hostnames, paths, and the board's own identity.** Anything that would
  identify the machine Aleph runs on, or the people behind it, is replaced
  with a placeholder before this mirror is built —
  [`docs/sanitiser.md`](./docs/sanitiser.md) has the exact substitution
  table and the check that blocks a push if one is missed.
- **Issues, tasks, attachments, approvals, and the activity log.** Paperclip
  work-item history, not company design. See `docs/fidelity.md`'s "Not
  exported at all" section for the full list and why.

`host/` is the one deliberate exception to "real content only": it's real
config, captured from Aleph's own host, with every identifying value
(hostname, the board operator's account) swapped for a clearly-fake
placeholder — an example of what running Paperclip's control plane and the
`agent-bwrap` sandbox on a real box looks like, not a literal recipe for
this specific one.

## Related

- [`aleph-scm/agent-bwrap`](https://github.com/aleph-scm/agent-bwrap) — the
  Bubblewrap confinement wrapper vendored into `host/agent-bwrap/` here,
  also public on its own.

## Docs

- [`docs/README.md`](./docs/README.md) — the org chart and model tiers, in
  more depth.
- [`docs/operating-model.md`](./docs/operating-model.md) — the rules, and
  the incident each one traces back to.
- [`docs/confinement.md`](./docs/confinement.md) — how the OpenCode Go tier
  is sandboxed, and what that sandbox does and doesn't stop.
- [`docs/lessons.md`](./docs/lessons.md) — ten incidents that cost real
  time, each with the pattern it taught.
- [`docs/fidelity.md`](./docs/fidelity.md) — the technical gaps between
  this package and the live company, for anyone trying to reconstruct one
  from it.
- [`docs/sanitiser.md`](./docs/sanitiser.md) — how this mirror is built:
  the allowlist, the substitution table, and the deny-list check that has
  to pass clean before anything is pushed here.
