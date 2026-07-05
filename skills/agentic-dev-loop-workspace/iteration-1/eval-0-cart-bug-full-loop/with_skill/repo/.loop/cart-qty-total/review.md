# Review: cart-qty-total

## Cycle 1 — 2026-07-05

Spec conformance check against exit criteria:

1. `computeTotal()` returns `sum(price × qty)` — app.js:4-6 multiplies `price * qty` per `.item`. With the HTML fixture (Rice 120, Milk 45): both qty 1 → 165; Rice 2 + Milk 1 → 285. Satisfied.
2. Live update on qty change — app.js:15-17 attaches an `input` listener on every `.qty` that calls `render()`, which rewrites `#total`. Rice 3 → 120×3+45 = 405. Satisfied (code path plausible; browser confirmation belongs to VERIFY).
3. Milk qty 2, Rice 1 → 120+45×2 = 210. Same code path. Satisfied.
4. Initial load — app.js:19 calls `render()` on load, overwriting the hardcoded `165` with the computed 165. The `module.exports` hook at app.js:22 is guarded by `typeof module !== 'undefined'`, so no `ReferenceError` in the browser. Satisfied.
5. NaN guard — app.js:5 uses `parseInt(...) || 0`, so an empty/non-numeric qty input contributes 0 instead of propagating NaN. Satisfied.

Scope check: only `app.js` changed plus removal of the README "Known issue" line, which the spec explicitly permits ("no changes to the README beyond optionally removing the 'Known issue' line"). `index.html` untouched, consistent with the spec's "likely no change needed". No new dependencies, no dead code, no debug output. Non-goals (discounts, formatting, add/remove) were not implemented.

Tests: no test file is included in the diff, but the spec's verification plan assigns Node-based unit checks (via the `module.exports` hook, which is present) to the VERIFY phase with evidence to `.loop/cart-qty-total/evidence/`. Not a blocking gap at review time; VERIFY must produce that evidence.

| # | Severity | File:Line | Finding | Why it matters |
|---|----------|-----------|---------|----------------|
| — | — | — | No findings | — |

Verdict: 0 blocking → VERIFY
