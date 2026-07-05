# Verification (Phase 4)

The rule: **every exit criterion maps to a piece of evidence in `.loop/<slug>/evidence/`**. Optimism is not evidence. A criterion without evidence is unmet, and the loop cannot exit.

## Decision tree — pick the strongest mode available

```
Is the change user-visible in a web UI, or does the project have a web build
(e.g. `flutter build web`, `npm run dev`, static HTML)?
├─ YES → Mode A: In-browser (strongest — do this even if tests also exist)
└─ NO
   Does the project have runnable tests / linters / analyzers / a compiler?
   ├─ YES → Mode B: Static + tests
   └─ NO, or the behavior only exists on a physical device / external service
      → Mode C: Manual checklist for the user
```

Changes spanning layers combine modes: e.g. Mode B for the backend function + Mode A for the UI that calls it. When Mode A applies but the environment has no browser tooling, fall back to B + C and say so in the evidence log.

## Mode A — In-browser

1. Get the app running:
   - Dev server: run the project's dev command in the background (`npm run dev`, `flutter run -d web-server`, `python -m http.server` for static files). Note the port.
   - If the sandbox can't expose the server to a browser, build static output and open the file directly, or fall back to Mode B/C.
2. Open it with browser tools (Claude-in-Chrome or equivalent): navigate to the page(s) the spec touches.
3. For EACH exit criterion: perform the user action (click, type, submit), observe the result, and capture:
   - a screenshot → `evidence/criterion-<n>.png`
   - the console output → check for errors/warnings introduced by the change; save relevant excerpts to `evidence/console.txt`
   - failed network requests relevant to the change
4. Also probe one level beyond the happy path: reload mid-flow, submit empty form, click twice fast. Cheap, catches much.

Console errors caused by the change = verification failure even if the UI "looks right".

## Mode B — Static + tests

Run everything the repo offers, in rough order of signal:

1. Test suite (`npm test`, `flutter test`, `pytest`, `go test ./...` — read package.json/Makefile/CI config to find the real commands)
2. Analyzer/linter (`flutter analyze`, `eslint`, `tsc --noEmit`, `ruff`)
3. Build (`npm run build`, `flutter build`, `cargo build`) — a change that doesn't compile is not done
4. If the spec added behavior with no covering test, write one now and run it.

Save full command output to `evidence/tests.txt`. Pre-existing failures unrelated to the change: note them explicitly so they aren't attributed to this loop, but don't fix them (out of scope — suggest a future loop).

## Mode C — Manual checklist

When only a human with the device/account can verify:

1. Write `evidence/manual-checklist.md`: one row per exit criterion, with exact steps ("open app → Cart → tap Pay with wallet with balance ₹0 → expect inline error, not a crash").
2. Surface it to the user and WAIT. Do not proceed to Phase 5 on assumption.
3. Record their responses in the checklist file with a timestamp. Any failed item → Phase 3 (Fix).

## Recording the verdict

Append to state.md log, e.g.:

```
- 2026-07-04 12:10 VERIFY: mode A+B. 5/5 exit criteria evidenced. tests 42 passed.
  evidence/: criterion-1..5.png, console.txt, tests.txt → PASS, advancing to PR
```

If FAIL: list which criteria failed and why, set phase back to `fix`, increment cycle.
