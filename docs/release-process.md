# Release machinery: the direct-push + CTO-review contract

How changes to this repo's release machinery land and get reviewed. Written
2026-10-05 (sizing decision on `ALE-389`, after the `ALE-552` incident showed
the gap). Rules, not features — read like `docs/operating-model.md`.

## The paths this applies to

- `.github/workflows/**` — live CI
- `ci-staged/**` — staged copies of the same workflows
- `scripts/sanitise.sh` — the sanitiser (public mirror build)
- `scripts/rebuild-test.sh` — the rebuild test (import idempotence gate)

These four are **release machinery**: they decide what gets published, what
gets proved, and what blocks a push. A defect here ships silently to the
public mirror or falsely passes the backup's rebuild proof, which is why
they get a review contract the rest of the repo doesn't need.

## The contract

**Direct push is the accepted model for these paths.** Coder has no PR
mechanism against this repo, so there is no gate *before* the push. Instead
the gate is *after* it, and it is real:

1. **The pushing agent pushes directly to `main`**, then immediately posts
   the commit hash on the relevant issue and names CTO as reviewer. The
   comment is what wakes the review — prose in a ticket body never wakes
   anyone (see `docs/operating-model.md`), but an issue comment to a named
   reviewer does.
2. **CTO reviews within 24 hours of the push**, extended to the next London
   business day when the window would close on a weekend or UK public
   holiday.
3. **If CTO raises a concern inside the window, the pushing agent reverts.
   No debate.** The revert is a plain `git revert` of the push commit(s) —
   never a force-push or history rewrite (deletions and history rewrites are
   §4.2 never-list territory and would need a board card). The concern is
   then fixed as new work and lands as a new direct push under the same
   contract.
4. **If no concern is raised inside the window, the push stands.** The
   window closing with silence is approval, and the review comment saying
   so (or the ticket's closure) is the record.

In practice the window is a backstop, not the norm: the pushing agent's
comment wakes CTO the same day, and review usually lands within hours. The
24-hour number is the ceiling, not the target.

## Why 24 hours

No board-set post-push review window existed before this doc, so the number
was anchored to the closest comparable cadences on record rather than
invented:

- **Reviewer's PR second-review sweep runs on a 6-hour cadence** (cut from
  2-hourly on 2026-10-04, `ALE-531`, to arrest a budget overage). 24 hours
  spans four full review-sweep cycles.
- **The nightly export runs daily** at 02:30 Europe/London — one business
  day is the repo's natural operational cycle.
- **Deliberately tighter than the autonomy envelope's 48-hour default-yes
  window** (`ALE-4` §4): a default-yes card only *acts* after its window
  closes, while a direct push carries its review debt from the moment it
  lands — so its review window is the shorter.

## Why not branch protection

The obvious alternative — GitHub branch protection on `main` for these
paths — was considered and **rejected** on `ALE-389`: it requires GitHub
repo-admin/auth configuration changes, which sit on the autonomy envelope's
never-list (`ALE-4` §4.2: "secrets, auth, sandbox or edge config") and would
need a board card to enact. The direct-push pattern is this repo's working
model and had been exercised cleanly five times before this doc existed
(`ALE-170`, `ALE-173`, `ALE-277`, `ALE-340`, `ALE-552`). This document is
the standing CTO approval that lets release-machinery changes land by
direct push without a per-change board card, with the post-push review as
the compensating control.

## Boundary

This contract covers the **mechanism** (direct push + post-hoc review). It
does not pre-approve the **content** of any change: a diff that would
itself be a §4.2 never-list action (a new outbound endpoint, a secret, an
auth change) still needs its own board card before it is pushed. Out of
scope entirely: GitHub branch-protection rules, collaborator/admin
settings, and any other repo auth/access config — the rejected option,
which needs a board card if ever revisited.
