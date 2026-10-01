# Operating model

Rules, not features. Each one exists because something broke without it.
Read [`README.md`](./README.md) first for the org chart these rules assume.

## Every implementation ticket ships with its QA ticket, linked by `blockedByIssueIds`

**The rule:** when the CTO cuts an implementation ticket, they cut its QA
ticket in the same moment, assigned to QA, with `blockedByIssueIds` pointing
at the implementation ticket. The QA ticket restates the acceptance criteria
it verifies. When the implementation ticket closes, QA wakes automatically.

**Why:** Paperclip has no wake-on-completion hook. Nothing watches an issue
and pings a reviewer when it closes. The *only* real dependency link is
`blockedByIssueIds` — everything else (a sentence in the ticket body saying
"QA should check this after," a TODO, a verbal handoff) is prose, and prose
never wakes anything. A QA ticket created *after* the implementer finishes
never runs, because nothing is watching for it to be created. The fix has to
be structural — the link has to exist at ticket-creation time — not a
reminder to remember later.

**How it's enforced:** the CTO's own instructions state it as a hard
constraint ("`blockedByIssueIds` pointing at the implementation ticket.
Descriptive prose in an unblock field never wakes anything") and QA's
instructions state the inverse check: if QA is ever woken on a ticket whose
implementation ticket is still open, that's proof the link was built wrong,
and QA hands it back rather than guessing at what to verify. The same pattern
is generalized company-wide — the COO's instructions state it as a rule for
every ticket any agent cuts, not just CTO→QA: "the only real dependency link
is `blockedByIssueIds`; everything else is a hope."

**Source:** `agents/cto/AGENTS.md`, `agents/qa/AGENTS.md`, `agents/coo/AGENTS.md`.

## Initiative: agents were told to propose, because silence isn't consent

**The rule:** most agents carry a short `## Initiative` (or `## Originate`)
section: file one `idea` ticket a week, unassigned, at most five lines,
"something nobody asked for" — filed at the end of a run already in
progress, not a run spent on it. It will usually be declined; that's
described as the point, not a failure mode.

**Why:** every one of Aleph's seven pre-existing agents had instructions that
said, in effect, "work only on tasks assigned to you." When the board later
asked all seven to propose new work, all seven proposed nothing — not because
they had nothing to propose, but because their own instructions forbade
originating anything. The org design had assumed a generative function would
just emerge; it didn't, because nothing in the instructions permitted it.
Fixing this needed two things at once: adding an `## Initiative`/`## Originate`
section to every existing bundle, and hiring dedicated generative seats
(Navigator, Researcher, Dreamer, Scout, Reader) whose whole job is
origination rather than execution. A second company goal — one public
artefact a week — was added the same day to give the new pipeline somewhere
to point.

**Source:** aleph-brain `decisions/log.md`, "Free-tier hire" entry (`ALE-146`,
comment 2026-09-25T10:36:26Z); `agents/ceo/AGENTS.md` `## Originate` section;
`agents/coder/AGENTS.md` `## Initiative` section (same text, all worker-tier
agents).

## Navigator versus Adversary: an engine and a set of brakes, deliberately not the same seat

**The rule:** the Navigator's whole job is to spend — to promote at least one
idea a week into a costed, falsifiable ticket, and to prefer "the strange
idea with a cheap test over the safe idea with an expensive one." The
Adversary's whole job is to attack what the Navigator (and the CEO, and the
CTO) produce, before budget commits and before work is called done. The
Adversary has **no veto** — it cannot block anything outright — but its
critique ticket carries a real `blockedByIssueIds` link to the work it
targets, so that work cannot close until someone answers the critique in
writing. "We considered this and accepted the risk because X" is a complete
answer; being overruled with a stated reason is the system working as
designed, not a failure of the Adversary's job.

**Why they're different seats, not one seat wearing two hats:** a reviewer
that shares the author's model shares the author's blind spots. The
Adversary's own instructions state this explicitly as the reason it runs on
a different model family than the CEO and CTO it reviews — the point isn't
adversarial *tone*, it's an uncorrelated failure mode. The same logic is why
QA runs on OpenCode Go rather than Claude: "for uncorrelated errors, not
because it is a stronger reviewer" (`agents/cto/AGENTS.md`). Separating the
seat that proposes from the seat that attacks means a bad idea has to survive
contact with someone who isn't invested in it having been a good idea.

**Source:** `agents/navigator/AGENTS.md`, `agents/adversary/AGENTS.md`,
`agents/cto/AGENTS.md`.

## Confirmation cards are the board's interface into the company

**The rule:** an agent doesn't just narrate a proposed action in a comment
and wait for a reply — it opens a structured `request_confirmation` (or,
for a simple accept/decline, a checkbox card) naming exactly what will
happen: a hire ("name, role, responsibility" in one line), a plan revision,
a security-sensitive config change. The board's approve/decline on that card
is itself a first-class, auditable event — a `201` response carries an
`approval` field that can be `null` (no gate fired) or a pending/decided
state, and an agent has to check it rather than assume a `201` means "done
and approved."

**Why a card and not a comment:** the same discipline that makes
`blockedByIssueIds` the only real wake path applies to approvals — a
decision recorded only as prose in a thread has no structure another agent
(or the board, scanning later) can query, diff, or re-confirm against. A
card is also how staged, reversible changes get their reversibility: the
company's own confinement rollout was decided as three proposed changes,
applied one `PATCH` at a time, specifically so that "a regression traces to
a single change" rather than a bundle nobody can unwind. Security-sensitive
config is proposed and held for board approval as a standing rule, not a
per-incident judgment call.

**Source:** `agents/ceo/AGENTS.md` (hiring/delegation section); aleph-brain
`decisions/log.md`, "Librarian confinement" entry (`ALE-107`) for the
staged-approval pattern; "Free-tier hire" entry (`ALE-146`) for the `201`/
`approval:null` example.

## No false green: jobs prove work, not exit 0

**The rule:** a scheduled or automated job's success is measured by
independently checking the state it claims to have produced — a build stamp
read back out of the running service, a specific snapshot ID verified to
exist, a live port actually hit — never by the job's own exit code, a
container's age, or a file timestamp alone.

**Why:** this is the single most recurring failure pattern in Aleph's
history. One example: a memory-leak fix was closed `done` three separate
times before it was actually live — each time on the strength of a git
commit existing, a process being young, or a container having a new ID, all
of which can be true while the *code actually running* is still the old,
buggy version (a container that never got a fresh build from an
up-to-date checkout is indistinguishable from a real fix by every signal
except reading the build identifier back out of the live process). A second
example: a nightly backup script treated its own tool's exit code 3 ("some
source files transiently unreadable") as fatal, which silently skipped
retention pruning on every run that hit it, while the unit still reported
success. The company's response to this pattern was to make proof-of-work a
contract, not a convention: every scheduled job gets an explicit definition
of what "done" means that isn't "the process exited"; see
[`lessons.md`](./lessons.md) for more instances of this same shape.

**Source:** aleph-brain `decisions/log.md`, "ALE-33 (mcp-server RAM ratchet)"
entry, "backup: restic exit-3 fix" entry (`ALE-50`), "Portfolio decision"
entry's Lane C summary (`ALE-145`, the proof-of-work contract itself).

## Sources

- `agents/cto/AGENTS.md`, `agents/qa/AGENTS.md`, `agents/coo/AGENTS.md`,
  `agents/ceo/AGENTS.md`, `agents/navigator/AGENTS.md`,
  `agents/adversary/AGENTS.md`, `agents/coder/AGENTS.md` (this repo).
- aleph-brain `decisions/log.md`: `ALE-33`, `ALE-50`, `ALE-107`, `ALE-145`,
  `ALE-146`.
