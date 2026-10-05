# Export fidelity gaps

What `scripts/export.sh` — i.e. `paperclipai company export` — does **not** carry
into this repo, so nobody mistakes a green nightly export for a complete backup.

## Not exported at all (platform limits, per the package's own fidelity report
and the project spec — see the `plan` document on ALE-169)

- **Attachments** on issues/comments.
- **Approvals** (history and state of `request_confirmation` / `ask_user_questions` cards).
- **Cost / spend history** (per-agent budget consumption over time — the
  `budgetMonthlyCents` *setting* is exported with the agent, the *spend ledger*
  is not).
- **Activity log** (the audit trail of who did what, when).
- **Issue/task history** — deliberately out of scope for this repo. Covered by
  `paperclipai db-backup` + restic, a separate private backup with its own
  retention, not a versioned diffable record. A lost `aleph-scm/company` repo
  loses no issues; a lost Paperclip database loses issues that this repo
  cannot reconstruct.
- **Platform built-in feature agents** (e.g. `Summarizer`, `metadata.
  paperclipBuiltInAgent` set on the agent) — provisioned by the platform
  itself, not company-authored, so `agents/` never carries them and
  `company import` never recreates them. Found live (ALE-170 rebuild-test,
  CI run 36744652777, 2026-09-30): `routines.json`'s "Refresh stale summary
  slots" is assigned to `summarizer`, a real agent on the live company that
  has no `agents/summarizer/` directory here. `scripts/rebuild-test.sh`
  excludes built-in agents from the exported-vs-live agent count assertion.

  **Root cause (2026-09-30, read from the installed CLI's own server
  source, `services/built-in-agents.js`), not a timing race:** a 5s
  sleep-and-retry on the agent list (tried in CI run 36745335982) can never
  find `summarizer` on a freshly imported company, because
  `autoProvisionBundledAgents` — called once, synchronously, inside company
  creation — deliberately does not auto-create bundle agents like Summarizer
  for new companies any more ("no longer auto-created for new users ...
  stay available to enable on demand"); it only re-reconciles ones that
  already exist. Confirmed live against a throwaway instance: the endpoint
  that does create it on demand, `POST .../built-in-agents/summarizer/
  provision`, first 404s with `{"error":"Built-in agents are not enabled"}`
  until the instance-level experimental flag `enableBuiltInAgents` is
  turned on (`PATCH /api/instance/settings/experimental`) — off by default
  on a fresh CLI-onboarded instance. With the flag on, provisioning
  succeeds (200, `status: "paused"`, real `agentId`) and, as a side effect,
  also creates the agent's bundled routine
  (`originKind: "built_in_agent_bundle"`, title "Refresh stale summary
  slots", paused) in the same call — so `scripts/rebuild-test.sh` now
  enables the flag right after the instance is healthy and, for any
  `routines.json` entry whose assignee matches a key in
  `GET .../built-in-agents`, provisions that agent instead of POSTing a
  second, duplicate copy of its routine.

## Routines are not exported by `paperclipai company export` — but this repo
## captures them a different way

The project spec (ALE-169's plan document) says the `.paperclip.yaml` sidecar
carries "adapters, models, budgets, **routines**, env input NAMES". Checked
against the first real export (commit `92bbc4f`, 2026-09-25): the sidecar has
every agent's adapter config, budget, and permission grants, but **no routine,
trigger, or schedule data anywhere in the package** — confirmed by grepping
the actual output for `routine|schedule|cron|trigger`, not by reading the
spec. `npx paperclipai company export --help` confirms the `--include` enum
is `company,agents,projects,issues,tasks,skills` — there is no `routines`
value to add. This is a platform limit in the export CLI, not a gap in this
script's `--include` set.

**Compensated, not just documented.** `GET /api/companies/{id}/routines` is
not gated to `role=ceo` the way `company export` is (verified: CTO's own
credentials, which 403 on the export CLI, succeed on this read). So
`scripts/export.sh` fetches routines itself, resolves the assignee/project
DB ids to the same slugs the export package uses (`agents/<slug>`,
`projects/<slug>` — raw ids are meaningless after a fresh import creates new
ones), strips everything run-to-run volatile (`lastTriggeredAt`,
`lastEnqueuedAt`, `nextRunAt`, `lastFiredAt`, `lastResult`, `updatedAt`,
revision ids, `lastRun`, `activeIssue`, `responsibleUserId`, ...) by
whitelisting the fields that matter instead of blacklisting the ones that
don't, and writes `routines.json` next to `.paperclip.yaml`, in the same
commit as everything else. Verified deterministic: two live fetches five
minutes apart, normalised the same way, produced byte-identical output
(2026-09-25).

Format note: the routines fix proposed in the CEO's 2026-09-25 comment on
this ticket suggested `routines.yaml`. This repo uses `routines.json`
instead — `jq -S` already gives deterministic, sorted, diffable output with
no extra dependency; a YAML conversion would need `python3`+`pyyaml` or `yq`
on every host that runs the export, for no fidelity gain. `jq` is now a
documented host dependency (see `host/README.md`) the same way `gitleaks`
already was.

Residual gap: `routines.json` is built by this script, not by the platform's
own export, so it round-trips nothing on `import` — Phase 2's rebuild test
still needs a manual or scripted step to recreate routines from
`routines.json` after `paperclipai company import` (which never touches
routines at all). Worth an upstream ask (`--include routines` on the export
CLI, and a corresponding `import` path) so this becomes redundant rather than
load-bearing — flagged, not filed upstream, here.

## Excluded by this ticket's `--include` set

`--include company,agents,projects,skills` deliberately omits `issues` and
`tasks` (see above). If a future ticket widens the include set, update this
file and `SYNC_PATHS` in `scripts/export.sh` together — an export path landing
in the package but not in `SYNC_PATHS` is silently dropped on the floor.

## Secrets, machine-local paths, and database IDs

Per the Agent Companies package format, the export itself never emits secret
values, host paths, or database IDs — that filtering happens upstream of this
script, inside `paperclipai company export`. `scripts/export.sh` additionally
runs `gitleaks` over every diff before it commits, as a second check on
anything the exporter's own filtering missed (belt and braces, not a
replacement for it).

## Skills: pinned references vs. vendored

Skills are exported as **pinned references** (`.paperclip.yaml` sidecar
entries pointing at the skill's source), not vendored copies of skill content,
unless a skill turns out not to round-trip that way on the Phase 2 rebuild
test. Rationale: a skill's canonical copy already lives at its own
source-of-truth (a skill repo, or the company's skill registry); vendoring a
second copy here would drift from it silently, which is the exact failure
mode this repo exists to prevent for agent instructions. If Phase 2 finds a
skill that doesn't survive import as a reference, switch that skill (not the
whole package) to `--expand-referenced-skills` and record the exception here.

## Verified against the first real export (2026-09-25, commit `92bbc4f`)

`paperclipai company export` and `company export:preview` are gated
server-side to `role=ceo` agents ("API error 403: Only CEO agents can manage
company exports"; no permission key widens it — see the OpenAPI grant enum).
CTO built and normalised this pipeline against the **documented** package
shape without ever being able to run it; CEO ran the first real export. What
that run confirmed:

- Package shape matches the plan document: `COMPANY.md`,
  `agents/<slug>/AGENTS.md`, `projects/<slug>/PROJECT.md`,
  `skills/<slug>/SKILL.md`, `.paperclip.yaml`. Schema tag is
  `agentcompanies/v1` (the plan document's "v1-draft" is stale).
- One volatile field the plan didn't mention: vendored bundled-skill
  frontmatter carries `metadata.paperclip.catalog.auditScannedAt`, a
  timestamp. Added to `scripts/export.sh`'s strip list after finding it —
  not caught by the pre-launch normalisation, which only knew about
  `exported_at`/`generated_at`-shaped keys. If it turns out to be stable
  across runs (the audit scan may not re-run every export) the strip is
  harmless; if it does change every run, this is the fix. Confirm on the
  next scheduled run's diff.
- No other timestamp, random ID, or unstable ordering found in `COMPANY.md`,
  `.paperclip.yaml`, or any `AGENTS.md`/`PROJECT.md`.
- gitleaks clean on the real content.

## Trailing whitespace is not round-tripped

Verified on ALE-176 (2026-09-25): a trailing-blank-line-only edit to an
agent's live instructions (11720 → 11721 bytes) produced **no diff** on the
next export — the export trims trailing blank lines before writing
`agents/<slug>/AGENTS.md`, so this repo's copy and the live bundle differed
by exactly that byte and the pipeline correctly saw them as equal content.
This is not a staleness bug; a whitespace-only instruction edit is genuinely
invisible to this backup. Use a visible edit (e.g. a line of content) to
verify export freshness, not a trailing-newline change.

Also confirmed the same day: `agents/<slug>/AGENTS.md` in this repo is not
byte-identical to what `GET`/`PUT .../instructions-bundle/file` returns for
that agent — the export prepends generated frontmatter (`name`, `title`,
`reportsTo`, `skills`) ahead of the raw instructions content. A restore that
needs the exact live bundle back has to strip that frontmatter first.

## Duplicate routine titles and sort stability

`routines.json`'s normalisation originally sorted only by `sort_by(.title)`.
Two live routines share the title "Scout: landscape, rotating theme" (one
`active` with a trigger, one `archived` with none); jq's sort is stable, so
their relative order in the file depended on whatever order the API
happened to return them in. Confirmed live on 2026-09-25: two fetches a few
minutes apart returned them in *different* orders, which would have produced
a spurious nightly diff with no real company change. Fixed in `export.sh` by
sorting on `(.title, .id)` — `.id` is dropped from the output (same reason
agent/project ids are resolved to slugs: not restorable across an import)
but is stable across export runs within this company, so it is kept only
long enough to break ties. Verified stable across two independent fetches
after the fix.

## Headless bootstrap gap (Phase 2, ALE-170) -- RESOLVED, was never a platform bug

For five days (2026-09-25 through 2026-09-30) this section claimed `company
import` had no non-interactive credential path on a fresh `local_trusted`
instance, reproduced "live ten times" and drafted as an upstream platform
ask. That diagnosis was wrong, and wrong in a specific, checkable way: every
one of those ten reproductions ran from inside a Claude agent's own shell,
which always carries a real `PAPERCLIP_API_KEY` (this agent's own prod
bearer token) in its environment. The CLI picks that variable up
automatically whenever `--api-key` is not passed explicitly, and sends it to
the throwaway instance -- which correctly rejects it, because the token
verifies against prod's JWT secret, not the freshly-onboarded instance's.
`--api-key ""` "reproducing the same 401" was the same bug, not independent
confirmation: the CLI's own env-var fallback re-adds the ambient key even
when the flag is passed empty.

**Root-caused 2026-09-30, reproduced live twice, minimal pair:** same
throwaway instance, same `company import` command, only the calling shell's
environment changed --

- `PAPERCLIP_API_KEY` set (ambient, from the agent's own shell): `API error
  401: Agent token did not verify; obtain fresh credentials and retry`.
- `env -u PAPERCLIP_API_KEY ...` (everything else identical): import
  succeeds immediately, no dry-run rejection, no manual step.

GitHub Actions runners never carry `PAPERCLIP_API_KEY` -- which is exactly
why every CI run since 36742696188 passed this step the entire time this
section said it was blocked. The instance's actual bootstrap behaviour (an
unauthenticated `POST /api/companies`, confirmed by reading the installed
CLI's own `dist/index.js`, `bootstrapTestDrive()`, valid only for an
instance's first company) was correct all along; nothing about it needed an
upstream fix. The upstream ask this section used to carry is withdrawn --
there was never a real gap to report.

**Fixed in `scripts/rebuild-test.sh`:** `run_import` now calls the CLI
through `env -u PAPERCLIP_API_KEY -u PAPERCLIP_API_URL -u
PAPERCLIP_COMPANY_ID -u PAPERCLIP_AGENT_ID`, stripping the credential-bearing
vars explicitly rather than relying on the calling environment happening not
to have them. CI never needed this (it has no such vars to strip), but it
means the script stays correct if it's ever run by hand from an agent's own
shell, or from a Paperclip routine on an agent that carries its own
credentials -- both of which would otherwise silently reproduce this exact
false "platform gap" again.

**Lesson for next time:** ten reproductions of the same bug from the same
kind of shell is not ten independent confirmations. It's worth noticing when
every repro attempt shares an environment, not just when they share a
command.

## POST .../routines silently drops `triggers` (Phase 2, ALE-170, 2026-09-30)

`reimport_routines` originally POSTed each `routines.json` entry's full
shape -- including its `triggers` array -- straight to `POST
/api/companies/{companyId}/routines`, on the assumption that a routine's
schedule round-trips the same way its other fields do. It does not: the
create endpoint silently ignores `triggers` in the request body. Confirmed
live, 2026-09-30 -- a routine created with a real `cronExpression` in its
payload comes back from `GET .../routines` with `"triggers": []`, no error,
no warning. This was invisible until the rebuild-test assertion table
actually checked schedules instead of just titles (see below): the routine
existed, its title matched, and the whole pipeline still reported green.

**Impact, until this fix landed:** every routine `reimport_routines`
recreated silently lost its schedule. A company rebuilt from this repo would
have every routine present but **none of them would ever fire** -- including
the nightly export routine itself, `Company export`. A restored company
would need a human to notice this and manually re-add every trigger by hand.

**Fixed:** each trigger is now created separately via `POST
/api/routines/{id}/triggers` (verified against the live OpenAPI spec) right
after its routine is created. `routines.json` triggers are all
`kind: "schedule"` today, whose shape (`kind`, `cronExpression`, `timezone`,
`label`, `enabled`) already matches that endpoint's schema field-for-field,
so each trigger object from `routines.json` is POSTed as-is.

**How this was caught:** by writing the full assertion table the ticket
actually asked for (reporting tree, instruction content, routines vs
`routines.json`, skills, projects) instead of the two checks (agent count,
paused) the script shipped with initially, then running the whole pipeline
end to end against a real throwaway instance before trusting it -- the same
"verify against the running system" discipline as everything else in this
file. The routines check specifically had to match on `(title, sorted cron
expressions)`, not title alone, because `routines.json` has one duplicate
title ("Scout: landscape, rotating theme", one active-with-a-trigger, one
archived-with-none -- see "Duplicate routine titles and sort stability"
above) and `reimport_routines` forces every recreated routine to
`status: paused`, so status can't disambiguate them live either.

## Skill slugs collide with the platform's own auto-seeded copies

A fresh company auto-seeds its own bundled copy of every stock Paperclip
skill (e.g. `agentmail`, `paperclip`, `paperclip-board`) before `company
import` ever runs -- `sourceRef: null`, sourced from the installed CLI's own
local npm path, not from GitHub. When the import then lands this repo's
pinned copy of the same-named skill, it installs as `<slug>-2` to avoid the
collision (confirmed live, 2026-09-30: `agentmail` repo skill lands as
company skill slug `agentmail-2`, `sourceLocator` pointing at the pinned
GitHub ref, alongside an untouched `agentmail` company skill pointing at the
platform's own bundled copy). Slug is therefore not a stable identity for
this repo's skills across a rebuild. `scripts/rebuild-test.sh`'s skills
assertion matches on `(sourceLocator, sourceRef)` from each skill's
frontmatter instead, falling back to slug only for the one skill with no
source pin (`status-card-query`, vendored as-is from the
`paperclip-operations` bundle). Live skills with no repo counterpart at all
-- the platform's auto-seeded copies, and whatever a provisioned built-in
agent brings with it (e.g. Summarizer's `summarize-status`) -- are a known,
platform-driven gap and not asserted against, the same treatment as built-in
agents get in the agent-count check.

## GitHub rate limit can leave a skill unpinned (ALE-565, 2026-10-05)

`scripts/pin_skill_sources.py` resolves each unpinned skill's `trackingRef`
to a commit SHA via the unauthenticated GitHub commits API --
`https://api.github.com/repos/{repo}/commits/{ref}` with only a
`User-Agent` header, no token. Anonymous GitHub API calls are capped at 60
req/hr **per IP**, not per run -- every concurrent export or other GitHub
call from this host shares the same budget. Hitting that cap used to raise
straight out of the script, and because the pin stage runs *before*
`export.sh` syncs/commits/pushes anything, that one 403 took the entire
nightly export down with it: no commit, no push, a full night's backup
lost to a transient, shared third-party limit. Found live, 2026-10-05, the
2026-10-05 nightly export, worsened by a concurrent run (`ALE-554`) sharing
the IP.

**Fixed, deliberately not by authenticating the lookup.** Sending
`Authorization: Bearer $PAPERCLIP_GIT_TOKEN` would raise the limit to
5000/hr, but it's a new use of a credential on an auth-adjacent surface --
`ALE-4` §4.2 never-list territory, needing a board card. Chose the
pure-logic fix instead, entirely inside `pin_skill_sources.py` /
`scripts/export.sh`, neither of which is release machinery (see
`docs/release-process.md`'s path list) so it isn't gated by that doc's
direct-push contract either:

- A 403/429 from the commit-lookup now gets a bounded retry (4 attempts,
  backoff capped at 30s, honouring `Retry-After` / `X-RateLimit-Reset` when
  GitHub sends them).
- If still rate-limited after that, `pin_skill_sources.py` leaves that
  skill's `commit: null` line untouched, prints a loud `WARN ... UNPINNED`
  line (path, repo, ref) to stderr, and **exits 0** -- it does not abort.
  `export.sh` echoes that warning into its own output and proceeds to
  sync/commit/push everything else normally.
- Any other HTTP error (404 bad repo, 500, ...) still raises immediately
  and fails the stage outright, same as before this fix -- those are real
  bugs, not a shared quota, and retrying them would only delay the same
  failure.

**Residual, known gap, not a bug to chase further:** a skill left unpinned
this way still has `commit: null` in the committed SKILL.md. Whether
`company import` rejects just that skill or the whole package on a
`commit: null` it finds is not verified either way here — only that import
rejects it (see the module docstring, found live 2026-09-30, `ALE-170`).
Either way, the commit still lands and this repo stays the backup of
record; the gap is scoped to *restoring from that specific commit*, not to
whether tonight's backup happened at all. The per-run `_cache`/`_failed`
means a retry within the same run doesn't re-hammer the same exhausted key,
and the *next* nightly export starts fresh and will very likely resolve it
once the shared hourly quota has reset — so this is expected to self-heal
within a day, not accumulate. If Phase 2's rebuild test ever runs against a
commit that has a known-unpinned skill, treat an import failure on that
skill as this gap, not a regression, and re-run against a later commit to
confirm.

## Import command for Phase 2

```
paperclipai company import <path-to-this-repo-checkout-or-github-url> --dry-run
```
then, once the dry run is reviewed:
```
paperclipai company import <path-to-this-repo-checkout-or-github-url>
```
**Correction (2026-09-30, live CI run 36742696188):** agents do **not** land
paused on import — the line originally here claimed "platform default" from
reading, not running, the CLI. The first real end-to-end run showed all
13/13 agents landed `active`. Phase 2's rebuild test must pause each agent
explicitly after import (`POST /api/agents/{id}/pause`, confirmed working
against a live throwaway instance) and assert paused state afterward, not
assume it — or a rebuilt company could start acting before anyone has
reviewed it. `scripts/rebuild-test.sh`'s `pause_agents` step does this.

**`import` never touches routines at all** — see "Routines are not exported"
above — so Phase 2 needs a separate step (script or manual) that reads this
repo's `routines.json` and recreates each routine via `POST
/api/companies/{companyId}/routines` (verified against the live OpenAPI
spec, 2026-09-25), importing them `status: paused` the same as agents, not
`active` — resolving `assignee`/`project` slugs back to the *new* company's
agent/project ids first, since `routines.json` stores slugs precisely
because the old ids won't exist — **and each trigger separately via `POST
/api/routines/{id}/triggers`**, since the routine-create call silently drops
`triggers` from its body (see "POST .../routines silently drops `triggers`"
above). Its "matches the package" assertion cannot include routines because
`import` never had them; it instead asserts against `routines.json`.

**Confirmed (CI run 36744238020, 2026-09-30, real response body captured):**
that routine-creation failure is exactly the `env.EXAMPLE_PUSH_URL` `secret_ref`.
`routines.json`'s export is deliberately redacted — `export.sh` cannot write
a real `secretId` into a repo file, since that id belongs to the old company
and must never round-trip to a new one. Rebuilding the same shape against
`POST /api/companies/{companyId}/routines` 400s:

```
{"error":"Validation error","details":[{"code":"invalid_union",
"errors":[...,"expected string, received undefined" on secretId/value/key],
"path":["env","EXAMPLE_PUSH_URL"],"message":"Invalid input"}]}
```

This is a permanent, expected gap, not a bug to chase further: a throwaway
instance should never receive a real secret anyway. `scripts/
rebuild-test.sh`'s `reimport_routines` now drops `.env` entirely before
recreating each routine — the routine still gets created, paused, with
every other field intact; only its secret-bearing env var is absent on the
rebuilt company. `routines.json` is the only routine with any `env` entry
today (`Prod repo drift check`), so this affects exactly one routine.

**Also from that run:** the workflow reported green (`success`) despite this
routine-creation failure and an "all agents paused" MISMATCH sitting
unaddressed in the assertion table — a false-green bug in `scripts/
rebuild-test.sh` itself (a piped `while` loop ran the routine-creation
retry in a subshell, so its internal `fail`/`exit 2` never reached the main
script; `assert_all` logged MISMATCHes but never turned them into a
non-zero exit). Fixed same day: the routine loop now uses process
substitution instead of a pipe, and `assert_all` fails the run on any
MISMATCH not already documented here.
