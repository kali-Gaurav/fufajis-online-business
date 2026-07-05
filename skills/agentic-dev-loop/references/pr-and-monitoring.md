# PR Handoff & Monitoring (Phases 5–6)

## Phase 5 — PR handoff

### Why handoff instead of pushing directly

In sandboxed environments, git *write* operations against a mounted repo can corrupt `.git` (index locks, cross-filesystem writes). Reading git (`git status`, `git diff`, `git log`) is safe and encouraged — use it to build the handoff. Writing is the user's terminal's job, unless you positively know this environment supports git writes AND the user has okayed it (e.g. a CI runner, a cloud dev box).

### Build `handoff.md`

Use real values from `git status`/`git diff` — never placeholders the user has to fill in.

````markdown
# Handoff: <slug> (cycle <n>)

Run these in your terminal from the repo root:

```bash
git checkout -b <type>/<slug>          # skip if branch exists (cycle 2+: just add/commit/push)
git add <explicit file list>           # explicit paths, never `git add .`
git commit -m "<type>(<scope>): <summary>"
git push -u origin <type>/<slug>
```

Then create the PR (pick one):

```bash
gh pr create --title "<title>" --body-file .loop/<slug>/pr-body.md
```
or open: https://github.com/<org>/<repo>/compare/<branch>?expand=1 and paste the body from `.loop/<slug>/pr-body.md`.

**When done, tell me the PR URL and I'll start monitoring.**
````

Write `pr-body.md` alongside it:

```markdown
## Summary
<2-4 sentences: problem + approach>

## Changes
- <file>: <what and why>

## How it was verified
- Mode(s): <A/B/C>. Evidence in .loop/<slug>/evidence/
- <key results: "42 tests pass", "clicked through checkout in Chrome, no console errors">

## Exit criteria
- [x] <criterion 1> — <evidence file>
- [x] <criterion 2> — <evidence file>
```

Surface handoff.md to the user, set `phase: pr` in state.md, and stop. The loop resumes when the user provides the PR URL (record it in state.md as `pr_url:`).

Conventional commit types: feat, fix, refactor, perf, test, docs, chore.

## Phase 6 — Monitoring (the slow surface)

A chat session can't sleep for an hour, and shouldn't — waiting hours is what schedules are for. Fast turns use files; slow waits use a re-firing trigger.

### Set up the scheduled task

If a scheduled-task tool is available, create one:
- **Cadence:** every 15 minutes, for the next hour (or a one-shot at +15/+30/+45/+60 if repeat-with-expiry isn't supported — prefer whatever the scheduler natively expires).
- **Prompt template:**

```
Loop check: repo <path>, loop <slug>.
1. Read .loop/<slug>/state.md. If phase is `done` or `abandoned`, delete/disable this task and stop.
2. Check the PR at <pr_url>: CI status, new review comments, merge conflicts, requested changes.
3. If error monitoring is reachable (CI logs, deployment logs, error dashboards, GitHub checks), scan for new errors since <timestamp>.
4. Append findings to state.md log with timestamp.
5. If an issue was found: report it and start a fix cycle per the agentic-dev-loop skill (Fix → Review → Verify → new handoff).
6. If clean AND more than 1 hour has passed since monitor start: set phase done, write closing summary, report all-clear, disable this task.
```

If NO scheduler is available: tell the user to ping "check the loop" periodically (or set their own reminder) — the state file makes any future session able to run the check cold.

### What a check actually inspects

Priority order, use whatever access exists (GitHub MCP/connector, `gh` CLI read commands, browser tools on the PR page):
1. **CI status** — failing checks are the most common post-PR error source. Get the failing job's log excerpt, not just "red".
2. **Review comments / requested changes** — each becomes a fix-cycle input ("Hey fix these issues").
3. **Merge conflicts** — flag to user; resolving may need their call.
4. **Runtime/deploy errors** — if the project deploys on merge and logs are reachable, scan the window since deploy.

### Issue identified → "okay cool, fix this"

An issue found during monitoring re-enters the inner loop against the SAME spec:
1. Log the issue in state.md, `cycle++`, phase → `fix`.
2. Fix → re-review (Phase 2, findings-scoped) → re-verify (affected criteria only) → new handoff (add/commit/push to the same branch; PR updates automatically).
3. Return to monitoring; the window restarts from the new push.

### Exit

The loop is `done` when: PR merged (or user says ship it) AND the last monitoring window is clean. Write a closing summary in state.md (what shipped, cycles used, issues caught in monitoring), disable the scheduled task, and tell the user the loop is closed. Offer to archive `.loop/<slug>/` or keep it as an audit trail.
