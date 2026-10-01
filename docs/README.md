# Aleph, in one screen

Aleph is an AI company that runs on [Paperclip](https://github.com/paperclipai/paperclip):
every "employee" is an agent seat with its own instructions, model, budget and
reporting line, working Paperclip issues instead of a chat window. This repo
is Aleph's own config, exported nightly from the live company (see the root
[`README.md`](../README.md) for the export mechanism). These four `docs/`
pages are the prose version, written for a stranger who found the public
mirror and wants to run something like this themselves.

## Org chart

```
CEO (Claude, thinking tier)
├── CTO (Claude)
│   ├── Coder (OpenCode Go)
│   └── QA (OpenCode Go)
├── COO (Claude)
│   ├── Librarian (Claude)
│   └── Summarizer*
├── Navigator, "Head of Labs" (Claude)
│   ├── Researcher (OpenCode Go)
│   ├── Dreamer (OpenCode Go)
│   ├── Scout (OpenCode Go)
│   └── Reader (OpenCode Go)
└── Adversary (OpenCode Go)
```
*Summarizer is named as the COO's report in the COO's own instructions
(`agents/coo/AGENTS.md`) and in the CTO/Librarian instructions' confidentiality
list, but has no `agents/summarizer/` bundle and no entry in `.paperclip.yaml`
in this export — it appears to be a Paperclip platform capability (see the
company-wide `summarize-status` skill in the root `.paperclip.yaml`/skills
list) rather than a hired agent seat. Uncertain; flagged rather than guessed.

- **CEO** — sets goals, owns spend visibility, approves hires and
  security-sensitive config. The only agent whose runs bill against the
  shared Claude subscription "for free" by design (`budgetMonthlyCents`
  cannot constrain it) — see [Model tiers](#model-tiers).
- **CTO**, reports to CEO — architecture, ticket breakdown, deploys,
  runtime health, secrets hygiene. Owns [Coder] (implementation) and [QA]
  (verification) as direct reports.
- **COO**, reports to CEO — owns the information supply chain: routes
  research, records and reporting work across Researcher, Librarian and
  Summarizer, and holds the quality bar on their output before it reaches
  the CEO.
- **Librarian**, reports to COO — the company's memory. Captures decisions
  with reasoning (not just outcomes), maintains documentation standards,
  answers other agents' context questions with citations, surfaces
  contradictions between records. The only agent trusted with the board's
  private material — see [`confinement.md`](./confinement.md).
- **Navigator ("Head of Labs")**, reports to CEO — owns where Aleph goes
  next: reads the ideas pipeline (Researcher, Dreamer, Scout, Reader, `idea`
  tickets), promotes at least one idea a week into a costed, falsifiable
  ticket, disposes of the rest in one line. Does not build; hands promoted
  work to the CTO or the board.
- **Researcher, Dreamer, Scout, Reader**, report to Navigator — the ideas
  pipeline. Researcher produces evidence-based briefs the Navigator commissions.
  Dreamer generates outward-facing "what-ifs" (originates nothing, decides
  nothing). Scout runs a weekly landscape scan on a rotating theme. Reader
  produces a weekly release-notes digest. All four are free-tier hires added
  2026-09-25 specifically to give the company generative seats — see
  [`operating-model.md`](./operating-model.md#initiative).
- **Adversary**, reports to CEO — attacks plans before budget commits and
  outputs before they're called done. Deliberately runs on a different model
  family than the CEO/CTO it reviews, "so a reviewer doesn't share the
  author's blind spots" (`agents/adversary/AGENTS.md`). Has no veto — only
  the power to force a written answer on the record.

## Model tiers

Two tiers, split by cost structure, not by seniority:

- **Claude subscription tier** — CEO (`claude-opus-5`), CTO, COO, Navigator
  and Librarian (`claude-sonnet-5`). These runs bill against a shared Claude
  subscription; the constraining resource is run count and token volume, not
  dollars. `budgetMonthlyCents` does not apply to this tier the way it does
  to the other.
- **OpenCode Go tier** — Adversary, Coder, Dreamer, QA, Reader, Researcher,
  Scout, each on a different third-party model
  (`opencode-go/glm-5.3-flash`, `opencode-go/deepseek-v4.1-flash`,
  `opencode-go/qwen3.7-plus`, `opencode-go/mimo-v2.5[-pro]`), each with a
  `budgetMonthlyCents` cap the board sets. This tier is also the one confined
  by `agent-bwrap` — see [`confinement.md`](./confinement.md).

The tier split was itself a correction: an earlier design put more agents on
the shared Claude seat than the CEO's own usage, which defeated the point of
reserving the thinking tier for the CEO. Source: aleph-brain
`decisions/log.md`, "Claude-subscription tier split" entry (`ALE-59`/`ALE-60`).

**A note on drift:** that same decision entry, written 2026-09-19, describes
"three Claude seats." This export (2026-09-25) shows five — COO and Navigator
were added to the Claude tier later, as part of the same free-tier hiring
round that added Dreamer/Scout/Reader on the Go tier. The decision log entry
is stale on the count; treat `.paperclip.yaml` (this repo) as the current
source of truth for who is on which tier, and the decision log as the record
of *why* the split exists at all.

## How to read the rest

- [`operating-model.md`](./operating-model.md) — the rules that make this run
  without a human in the loop most of the time: the QA-linked-ticket wake
  pattern, why agents were told to propose work, Navigator vs. Adversary,
  confirmation cards, and "no false green."
- [`confinement.md`](./confinement.md) — how the OpenCode Go tier is
  sandboxed from the filesystem, and what that sandbox does and doesn't stop.
- [`lessons.md`](./lessons.md) — ten incidents that cost real time, each with
  the pattern it taught.
- [`fidelity.md`](./fidelity.md) — not the operating model; the technical
  gaps between "what this repo exports" and "the live company," for anyone
  trying to reconstruct a company from this repo's shape.

## Sources

- `agents/*/AGENTS.md`, `.paperclip.yaml` (this repo, exported 2026-09-25).
- aleph-brain `decisions/log.md`: "Claude-subscription tier split" entry
  (`ALE-59`, `ALE-60`); "Free-tier hire" entry (`ALE-146`).
