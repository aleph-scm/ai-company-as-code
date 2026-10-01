# The sanitiser

How `scripts/sanitise.sh` turns this private repo into the public mirror,
[`aleph-scm/ai-company-as-code`](https://github.com/aleph-scm/ai-company-as-code)
(board decision 2026-09-25, created private — see ALE-173). Read this next
to the script itself; if the two disagree, the script is what actually ran
and this file is stale and needs fixing.

## Why allowlist, not denylist, for *what* gets copied

A denylist on paths ("copy everything except X") fails open: a new private
file added to this repo later gets published by default unless someone
remembers to add it to the denylist. An allowlist fails closed — a new file
needs a deliberate decision to add it here before it can ever reach the
mirror. Given this repo's whole purpose is "never publish something nobody
reviewed," failing closed is the only acceptable default.

## Allowlist: paths copied into the mirror

| Path | Treatment |
|---|---|
| `agents/` | Copied wholesale. Every agent's instructions are design, not secrets. |
| `skills/` | Copied wholesale. Pinned skill references, same reasoning. |
| `projects/aleph/`, `projects/blog/` | Only these two projects. **ETW and Life are excluded entirely** (board decision) — not redacted, not present at all, anywhere in the build. |
| `.paperclip.yaml` | Filtered, not copied raw — see "The sidecar" below. |
| `host/` | Copied, then substituted — see "host/ is the one exception" below. |
| `docs/` | Copied wholesale, then substituted like everything else. |
| `COMPANY.md` | Copied as-is. Name/schema/slug only, nothing sensitive — added to the allowlist beyond the ticket's original list because `paperclipai company import --include company,...` needs it present to create the company at all; without it the mirror's own "one-command import" promise would fail on the first step. |

Not in the allowlist, therefore never in the mirror: `routines.json`,
`scripts/`, `ci-staged/`, this repo's own root `README.md` (the mirror gets
its own, generated from `scripts/mirror-readme.md`), and the five other
Paperclip projects (`ai-company-as-code`, `etw`, `life`, `onboarding`,
`public-code`). `routines.json` in particular is excluded on purpose, not
by oversight: it describes Aleph's live operating cadence, and its one
`env` entry (`Prod repo drift check`'s `EXAMPLE_PUSH_URL`) is a secret
reference that can never be made public-safe — see `docs/fidelity.md`.
`scripts/rebuild-test.sh` treats a missing `routines.json` as a known valid
tree shape (a `SKIPPED` row, not a `MISMATCH`) for exactly this reason.

## The sidecar: `.paperclip.yaml`

`scripts/sanitise_filter_paperclip_yaml.py` loads the private sidecar and
writes a filtered copy:

- Drops every `budgetMonthlyCents` key under `agents`, and every `model`
  key under a `claude_local` agent's `adapter.config` (board decision: what
  a seat costs and which vendor it runs are operating decisions, not part
  of the design this mirror exists to share).
- An `opencode_local` agent's `adapter.config.model` cannot simply be
  dropped the same way: Paperclip's own import validation rejects an
  OpenCode agent with no `adapterConfig.model`, since the field must be
  present in `provider/model` format. Dropping it would make the mirror
  fail its own rebuild-test — the exact "ship only what we can prove
  rebuilds" rule this phase exists to enforce. It is replaced with the
  fixed placeholder `example-provider/example-model` instead, which is
  real-format but obviously fake.
- Keeps only the `aleph` and `blog` entries under `projects`, and trims
  `sidebar.projects` to match.

This is a structural filter (parse YAML, drop keys, re-serialise), not a
text substitution — the budget/model keys can appear in any order and the
project list can grow, and a line-oriented `sed` delete would be one rename
away from silently keeping a field it should have dropped.

## The substitution table

Real identifiers that appear inside otherwise-worth-publishing prose — the
confinement boilerplate repeated in every agent's `AGENTS.md`, the `host/`
capture, the Aleph/Blog project descriptions — get swapped for an
obviously-fake placeholder before anything is scanned. Applied to every
text file in the build, in one `sed -E` pass (`scripts/sanitise.sh`,
"substitution pass"):

| Real | Placeholder | Why |
|---|---|---|
| `/var/repos` | `/var/repos` | The real host's repo-checkout convention. |
| `Prod` / `prod` (word-bounded) | `Prod` / `prod` | The real host's name, used both as a hostname and as the private `aleph-scm/prod` repo's name. |
| `example.com` | `example.com` | The board operator's personal domain (the blog is served from a subdomain of it). |
| `operator` (word-bounded) | `operator` | The board operator's real first name — the only one used literally in this repo, confined to `host/mcp/paperclip-mcp.md`. |
| `EXAMPLE_PUSH_URL` (word-bounded) | `EXAMPLE_PUSH_URL` | The real env-var name of the one routine `secret_ref` (board call, ALE-277). The secret's *value* and id never leave the private tree — `routines.json` is not allowlisted — so what this substitutes is the naming convention alone, in the two published files that discuss the redaction (`docs/fidelity.md`, this file). |

This table is deliberately short and literal, not a set of broad heuristics
— every entry corresponds to a specific real string found by grepping the
allowlisted paths during ALE-173, not a guess at what *might* be sensitive.
Extend it the same way: find the real string first, then add the line.

## The deny-list: the safety net, not the check

After substitution, `scripts/sanitise.sh` scans the **output** tree and
fails the build (exit 2) if any of these survive:

- `prod`, `/srv/`, `example.com`, `operator` (case-insensitive) — should be zero
  after the substitution table above; a hit here means the table missed an
  occurrence, not that the deny-list is doing the redacting itself.
- `essex`, `luke` (word-bounded, case-insensitive) — the excluded client's
  name and contact, as a defense-in-depth check in case a reference to them
  ever leaks into an allowlisted path outside `projects/etw`.
- `EXAMPLE_PUSH_URL` (word-bounded, case-sensitive) — should be zero after the
  substitution table. Worth noting why this one is *also* on the deny-list
  and not only in the table: this file is `--exclude`d from the scan, so for
  the `docs/fidelity.md` occurrences the deny-list is the only enforced
  check that the substitution actually ran.
- IPv4 literals, email addresses, UUIDs — generic PII/secret-shaped
  patterns, checked regardless of whether a specific known instance exists
  today.
- `/home/<name>` for any name other than `paperclip`, `agent-runner`, or
  `operator` — see "Why `/home/` isn't a blanket denylist" below.

A hit here is a **hard fail**, not a redaction step — the script does not
try to fix what it finds; it stops and says where, so a human fixes the
source (usually: add a row to the substitution table above) and re-runs.

### Why `/home/` isn't a blanket denylist

`/home/paperclip` (the Paperclip service account — the product's own
convention, not Aleph-identifying) and `/home/agent-runner` (an example
path inside `agent-bwrap`'s own vendored, already-public config example)
are both real, both harmless, and both would trip a bare `/home/` grep
forever. The deny-list scan allows exactly these two, plus
`/home/operator` (this script's own substitution output for the real
`/home/operator`), and fails on anything else under `/home/` — which is the
actual goal: block a username the substitution table doesn't know about
yet, not block a path shape that happens to start with `/home/`.

## `host/` is the one deliberate exception to "real content only"

Everywhere else in the mirror, content is either real (agent instructions,
project descriptions) or absent (ETW, Life, routines). `host/` is the one
place real values are replaced with placeholders rather than the whole
directory being excluded: the *shape* of a systemd unit, a sudoers grant, an
AppArmor profile, and the board's MCP-over-SSH wrapper is useful to anyone
trying to run Paperclip the same way — the specific hostname and the
board's own account are not. `host/README.md`'s own header used to say "this
whole repo is private, so there is nothing to redact here (that's Phase
4's job, on the public mirror)" — this is that job.

## gitleaks

The deny-list above is Aleph-specific (it knows what *this* company's real
values are). `gitleaks detect --no-git` on the built tree is the generic
check underneath it — the same tool `scripts/export.sh` runs, catching any
credential-shaped string regardless of whether it's on the deny-list by
name. Belt and braces, same as the private export's own gitleaks pass.

## Never published unless it also rebuilds

`ci-staged/sanitise-mirror.yml` runs four steps, not one script call:

1. `scripts/sanitise.sh --out ./.mirror-build` — build and scan, never push
   (even if the push env vars are set — `--out` mode ignores them).
2. `REBUILD_TEST_REPO_ROOT=$PWD/.mirror-build ./scripts/rebuild-test.sh` —
   the same assertion suite `scripts/rebuild-test.sh` runs against this
   repo's own checkout (ALE-170), pointed at the sanitised build instead. A
   missing `routines.json` is an expected `SKIPPED` row, not a mismatch —
   see the allowlist section above.
3. `scripts/sanitise.sh --push ./.mirror-build` — only reached if step 2
   passed. Re-scans the directory (cheap, and the same guarantee as a fresh
   build) before pushing.
4. After a successful push, a fresh full clone of the mirror itself gets
   `gitleaks detect` over its **entire commit history** (ALE-340). Every
   check above scans only the tree the current build produced; but each
   sync adds a commit on top of the mirror's history, so a secret leaked by
   a past (then-buggy) sync would still be sitting in that history even
   after later syncs are clean — only the mirror's own history knows. This
   step is skipped only when step 3 published nothing new ("no change to
   push"); any finding fails the job loudly, same "never a silent skip"
   contract as the script, with `--redact` so the leak's content never
   reaches the public Actions log.

A clean sanitiser run alone doesn't prove the published tree actually
imports and reconstructs into a working company — this gate does. The
mirror is fully generated and replaced wholesale on every push, never
merged or hand-edited.

## Testing this without the mirror repo existing yet

`scripts/sanitise.sh --out DIR` builds and scans without needing
`MIRROR_REPO_URL`/`MIRROR_GIT_TOKEN` and without pushing — this is how the
sanitiser was proven clean for ALE-173 before the board had created the
mirror repo for it to push to, and it's also how `REBUILD_TEST_REPO_ROOT`
was pointed at a real sanitised tree to prove `scripts/rebuild-test.sh`
passes against the mirror's (smaller) shape.
