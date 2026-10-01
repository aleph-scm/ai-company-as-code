# Ten expensive lessons

Drawn from aleph-brain's `decisions/log.md` — company-internal only, no
vault, no client or infrastructure identifiers. Each entry is the pattern the
incident taught, generalized past the specific service it happened to hit,
because the pattern is what's worth a stranger copying.

## 1. A closed ticket is not a verified fix — verify by reading state back, not by the artifacts around it

A fix landed and closed a ticket three separate times before it was actually
running: each time, the closer trusted a commit existing, a process being
young, or a container having a fresh ID — all of which can be true while the
code actually executing is still the old, broken version. The failure mode
recurred because a build context (the source checkout a rebuild reads from)
had silently drifted behind the remote it was assumed to match, so
"rebuilding" reliably reproduced the same bug under a new process ID. The fix
that finally held: verify by reading an identifier back out of the *running*
service, not by any signal that merely correlates with freshness.

## 2. A job's exit code is not proof it did its job

A backup script treated one specific, non-fatal exit code from its own
underlying tool as failure, which aborted the script before its retention
step ran — so pruning was silently skipped on every run that hit this, while
the service still reported success. The general form: "the process exited 0"
and "the process did what it claims to have done" are different claims, and
only automated verification of the second one is a real proof of work. This
became a company-wide rule (see `operating-model.md`, "No false green").

## 3. A config file being correct is not evidence the running process picked it up

After correcting a service's bind address in its environment file, the
agents talking to that service kept using the old address — not because the
edit was wrong, but because the running process predated the edit and hadn't
reread its environment. The fix needed an explicit restart, a control-plane
action some agent seats can't perform themselves. Generalizable: config
correctness and runtime behavior are two separate claims, and only checking
the live behavior closes the loop.

## 4. A sandbox covers what its own threat model claims and no more, and the gaps it names stay yours

A sandboxing rollout correctly narrowed what a process can read and write
*during one run*, and by its own design stops there. The tool's published
threat model (`host/agent-bwrap/README.md`, "Threat model") names its
out-of-scope gaps directly, including one that depends on the orchestrating
system rather than the sandbox — so closing it is the orchestrator's job, not
the sandbox's. Generalizable: treating a filesystem sandbox as a complete
boundary, when its own documentation says the real boundary is wider,
overstates what was actually bought. Read the tool's threat model as part of
the deliverable, not as an appendix. See `confinement.md` for how Aleph
scoped this.

## 5. A documented boundary and an enforced one are different claims, and confusing them is easy

A written design said a sensitive seat "stays on [a particular adapter]
precisely so the sensitive material sits where the controls are real." On the
live host, that adapter had no scope restrictions applied — the seat's actual
boundary was instruction text, not sandbox configuration. The board later
reviewed this and *chose*, explicitly and in writing, to accept the gap
rather than close it — which is a legitimate outcome, but only because it was
made a deliberate, reviewable decision instead of staying an unnoticed
mismatch between the design doc and reality.

## 6. Shared infrastructure creates boundaries that look like security incidents and aren't

A cross-agent memory write was initially read as evidence that a seat could
reach across a boundary into another agent's private state. The real cause
was structural, not a containment failure: the memory system keyed its
storage by *working directory*, and two agent seats shared a working
directory whenever both worked the same project — so both wrote into what
was, by construction, a shared scratchpad, not a boundary either had
crossed. The lesson generalizes past this one incident: before treating
unexpected access as a compromise, check whether the access is explained by
how the underlying system actually partitions state, which is sometimes
coarser than it looks from the outside.

## 7. A stored credential value and a live system accepting that credential are different claims

A ticket was marked resolved on the premise that writing a value into a
config file's credential field would make an automated script able to log
in. It didn't — the file's value and the account's actual stored password
were never the same thing, and nobody had exercised the login path before
calling it fixed. The eventual fix needed the account's real password
changed to match the file, and the closing criterion that actually held was
"the login path was exercised and succeeded," not "the field is
non-placeholder." Same shape as lessons 1–3: a static artifact is not a
substitute for exercising the live path it claims to describe.

## 8. A host checkout can silently diverge from the branch everyone assumes it matches

Twice, independently, a service's on-disk checkout was found several commits
ahead of or behind the remote branch everyone assumed it tracked — once
holding live production configuration that existed only on the host and
nowhere in version control, invisible to anyone reading the repository. Both
times, the automated check that was supposed to catch this kind of drift was
itself found to be measuring the wrong thing. The generalizable habit: verify
a checkout's actual state before trusting it as current, and periodically
verify the *verifier* too, not just the thing it checks.

## 9. Work can exist on an unmerged branch, invisible to anyone who only checks the default branch

An audit concluded a piece of work "was never written," based on it being
absent from the default branch. It existed in full — nineteen files,
committed — on a branch that had been stranded when a pull request was
squash-merged only partially. The branch wasn't deleted (deliberately, once
found), but the false "never written" conclusion nearly caused the same work
to be redone from scratch. The rule this produced: a path missing from the
default branch is evidence of nothing until `git log --all` (or the
equivalent full-history search) has also come up empty.

## 10. A recurring standing issue that never reaches "done" is a sign it should be a schedule, not a ticket

One periodic check kept getting reopened, indefinitely, because its nature
was "run this again next week," not "finish this once." Treating it as a
regular issue meant it either sat closed-but-not-really or stayed
perpetually reopened, neither of which is an honest status. Converting it
into a recurring scheduled routine — with the same scope carried forward,
but a real trigger instead of a human remembering to reopen it — was
recognized as a governance change requiring explicit approval before being
made, not something to enact unilaterally just because "someone said go
ahead" in a different context.

## Sources

All entries: aleph-brain `decisions/log.md`. In the order above: "ALE-33
(mcp-server RAM ratchet)"; "backup: restic exit-3 fix" entry (`ALE-50`);
"Agents' own `PAPERCLIP_API_URL` had to follow the bind pin" entry (`ALE-66`);
"Librarian confinement: decided as three changes" entry (`ALE-107`, "What
this decision explicitly does not claim to buy"); "Bubblewrap confinement:
partially live" entry (open discrepancies); "Librarian confinement… §10
correction" entry (`ALE-107`); "Uptime Kuma admin credential: resolved, but
closed prematurely once already" entry (`ALE-51`/`ALE-67`/`ALE-24`); "ALE-33"
and "repo drift" entries (`ALE-38`/`ALE-42`, the two independent occurrences
of the same pattern); "`ALE-32` — three aleph-apps scope calls" entry
(item 2); "infra health check: converted from a standing issue to a weekly
routine" entry (`ALE-14`).
