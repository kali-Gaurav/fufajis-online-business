---
name: agentic-dev-loop
description: >-
  Run a complete autonomous development loop: Spec → Implement → Code Review → Fix →
  Verify (in-browser/tests) → PR → Monitor for errors → fix and repeat until genuinely done.
  The unit of work is the LOOP, not the prompt — state lives on disk so any session can
  resume it. ALWAYS use this skill when the user says: "run the loop", "start a loop",
  "dev loop", "spec to PR", "build this end to end", "implement and verify", "take this
  to a merged PR", "check the loop", "loop check", "monitor the PR", "resume the loop",
  gives a feature/bugfix request they want driven all the way through review + verification
  + PR, or asks to continue/check any previously started loop. Also trigger when a
  scheduled task fires with a loop-check prompt.
---

# Agentic Dev Loop

You are the automated driver in the middle of a development loop. The unit of work is not a prompt — it is the whole loop: **Spec (input) → Merged, monitored PR (output)**. The loop is a disposable unit of work: any session (including a fresh one with zero conversation history) must be able to pick it up, because all state lives in files, not in your context window.

## The Six Settled Elements

Before running, every loop must have these six things settled. The first five run autonomously; **Surface** is where the human meets the loop.

| Element | In this skill |
|---|---|
| **Inputs** | The spec file — what fires the loop and defines "done" |
| **Action** | Implement / fix code |
| **Check** | Code review + verification — something *other than the implementer's optimism* checks whether it's done |
| **Memory** | `.loop/<slug>/state.md` on disk — where the loop writes = where you read |
| **Exit** | Exit criteria in the spec, met with *evidence* — the loop cannot be sweet-talked into declaring victory early |
| **Surface** | Chat for fast turns; scheduled-task reports for the slow monitoring phase |

If the task is too vague to fill in Inputs and Exit, do NOT start implementing. Push back and co-design the spec with the user first. **The conversation about the spec IS the work — don't skip it.**

## Memory: the loop's notebook

All loop state lives in `.loop/<slug>/` inside the repo (slug = short kebab name for the task):

```
.loop/<slug>/
├── spec.md        # Inputs + Exit criteria (immutable once approved)
├── state.md       # Current phase, cycle count, log of every turn
├── review.md      # Review findings per cycle (open/fixed status)
├── evidence/      # Verification proof: test output, screenshots, console logs
└── handoff.md     # Git/PR commands for the user + PR URL once created
```

Rules for memory:
- **Write state BEFORE and AFTER every phase transition.** If the session dies mid-loop, the next session must recover from files alone (grep trail, diff runs, recover state).
- Files are for fast turns (seconds/minutes between steps). For slow waits (PR review taking hours/days), the surface shifts to scheduled-task check-ins — see Phase 7.
- On ANY invocation of this skill, FIRST check for existing `.loop/*/state.md` files. If one exists and is not `done`/`abandoned`, ask whether to resume it or start a new loop — unless the user's request obviously refers to it ("check the loop", a scheduled check firing), in which case resume directly at the phase recorded in state.md.

`state.md` format — keep it terse and append-only in the log:

```markdown
# Loop: <slug>
phase: implement          # spec|implement|review|fix|verify|pr|monitor|done|abandoned
cycle: 2                  # review-fix cycles completed
started: 2026-07-04T10:00
spec_approved: yes
pr_url: (none yet)
monitor_until: (not started)

## Log
- 2026-07-04 10:05 SPEC approved by user
- 2026-07-04 10:40 IMPLEMENT done: 3 files changed (list)
- 2026-07-04 10:55 REVIEW cycle 1: 4 findings (2 blocking)
```

## The Loop

```
0 SPEC → 1 IMPLEMENT → 2 REVIEW ⇄ 3 FIX → 4 VERIFY → 5 PR (handoff) → 6 MONITOR ~1hr
              ↑______________ issue found during monitor: new inner cycle ______________|
Exit: PR merged + monitoring window clean
```

### Phase 0 — SPEC (the gate everything hangs on)

Co-design with the user. Iterate: sketch, get vague pushback, refine. Produce `spec.md` containing:
- **Problem / goal** — one paragraph
- **Scope** — files/areas expected to change; explicit non-goals
- **Exit criteria** — 3–7 objectively checkable statements ("the /orders page loads without console errors", "test X passes", "clicking Y shows Z"). These become the Check. Vague criteria = a loop that can be sweet-talked; make them binary.
- **Verification plan** — which verify mode applies (see Phase 4)

Get explicit user approval, mark `spec_approved: yes`. After approval the spec is frozen — scope changes mean a new loop or an explicit user-approved spec amendment logged in state.md.

If the user gives a crisp, small task ("fix this null check in file X"), write a minimal spec yourself, show it in one message, and proceed unless they object. Don't bureaucratize small work — but never skip the exit criteria.

### Phase 1 — IMPLEMENT

- Read the project's own conventions first: `CLAUDE.md`, contributing docs, existing patterns in neighboring files. The loop must produce code that looks native to the repo.
- Follow the spec's scope. If mid-implementation you discover the spec is wrong, stop, log it, and surface to the user — don't silently improvise scope.
- Log changed files in state.md.

### Phase 2 — CODE REVIEW (fresh eyes, not self-grading)

The implementer's judgment is not the Check. Get genuinely fresh eyes:
- **If subagents are available:** spawn a review subagent with a fresh context window (Ralph-style: the fresh context is the feature — it has no attachment to the implementation choices). Give it ONLY: the spec, the diff/changed files, and `references/review-checklist.md`. Not your reasoning.
- **If no subagents:** re-read the diff yourself against `references/review-checklist.md`, explicitly adversarial: "how would this break in production?"

Write findings to `review.md`, each tagged **blocking** or **nit**, each with file:line and a why.

### Phase 3 — FIX

Fix all blocking findings (nits at your judgment — log which were skipped and why). Then return to Phase 2 for re-review of the fixes only.

- Loop 2⇄3 until a review pass has zero blocking findings.
- **Circuit breaker:** if cycle count hits 3 with blocking findings still appearing, stop and surface to the user with the stuck findings — a loop that thrashes isn't converging and needs a human decision.

### Phase 4 — VERIFY (evidence or it didn't happen)

Pick the strongest verification the project supports — read `references/verify.md` for the decision tree and mechanics. In short:

1. **In-browser** (web apps, or anything with a web build): run/serve the app, open it via browser tools, click through every exit criterion, read the console for errors. Save screenshots + console output to `evidence/`.
2. **Static/tests** (backend, libraries, mobile without emulator): run the test suite, linter, analyzer, build. Save output to `evidence/`.
3. **Manual checklist** (device-only flows): write a precise per-exit-criterion checklist for the user, wait for their confirmation, log it.

Combine modes when the change spans layers. Every exit criterion must map to a piece of evidence. An exit criterion without evidence is NOT met — the state machine does not accept optimism. If verification fails → back to Phase 3 (this counts as a cycle).

### Phase 5 — PR (handoff)

Some environments (including this one) must not run git write operations directly — sandbox git writes can corrupt the working repo. Default to the handoff pattern; only run git directly if you know the environment safely supports it AND the user has said so.

Write `handoff.md` containing, exactly and copy-paste ready:
1. Branch, add, commit (conventional-commit message), push commands
2. `gh pr create` command (or web URL flow) with a full PR body: summary, changes, how it was verified (link the evidence), exit criteria checklist
3. A line telling the user: "Paste these in your terminal, then give me the PR URL."

Surface it, set phase to `pr`, and wait. When the user returns the PR URL, record it and move to monitor. Full details and templates: `references/pr-and-monitoring.md`.

### Phase 6 — MONITOR (~1 hour outer loop)

A session can't reliably sleep for an hour — so the monitoring turn moves to a slower surface: a **scheduled task**.

- Create a scheduled task that re-fires every ~15 minutes for the next hour with a prompt like: *"Loop check for <repo> loop <slug>: read .loop/<slug>/state.md, check the PR at <url> for CI failures, review comments, and merge conflicts; check error logs/monitoring dashboards if accessible; report findings and update state.md."*
- Each check that fires: read state → check PR/CI/errors → append findings to state.md log → report to the user only if something needs attention (or a final all-clear).
- **Issue identified → new inner cycle:** treat it as a fix task against the same spec — Fix → Review → Verify → push update via a fresh handoff. Log `cycle++`.
- After a clean hour (or the user says merged & fine): set `phase: done`, write a closing summary in state.md, and delete or offer to archive the scheduled task.

Mechanics, prompt templates, and what to check: `references/pr-and-monitoring.md`.

## Inner and Outer Loops

This whole skill is one **inner loop** (spec → merged PR). You can also be asked to run an **outer loop** around it: a recurring trigger (scheduled task, "check the backlog daily") that decides what to build next and fires a fresh inner loop with a fresh context each time. When asked for that:
- The outer loop's memory is a backlog file (e.g. `.loop/backlog.md`) + the per-loop state dirs.
- Each fired inner loop starts clean: read backlog → pick/confirm next item → run this skill from Phase 0.
- Run loops as a portfolio: multiple `.loop/<slug>/` dirs may be live at once; state files keep them independent.

## Failure discipline

- Never mark a phase done without its artifact (spec.md, review.md, evidence/, handoff.md).
- Never edit exit criteria to make them pass. If a criterion is genuinely wrong, that's a user-approved spec amendment, logged.
- If blocked (missing access, ambiguous spec, thrashing reviews), update state.md with the blocker FIRST, then surface. The next session must see why the loop stopped.
- Keep the user's time cheap: batch questions, surface only decisions that are truly theirs.

## References

- `references/review-checklist.md` — what the review pass checks (read at Phase 2)
- `references/verify.md` — verification decision tree + browser/test/manual mechanics (read at Phase 4)
- `references/pr-and-monitoring.md` — handoff templates, scheduled-task monitoring setup (read at Phases 5–6)
