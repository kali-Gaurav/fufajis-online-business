# Review: coupon-cap

(review.md created at cycle 2 — cycle 1 review was logged in state.md only: "REVIEW cycle 1: 0 blocking")

## Cycle 2 — 2026-07-05 (scoped to CI-failure fix in src/discount.js)

Reviewer note: no review subagent available in this constrained test run; adversarial self-review against references/review-checklist.md, diff-scoped.

Diff under review:
- src/discount.js: `discount` now capped via `Math.min(rawDiscount, coupon.maxDiscount)` before subtraction.

| # | Severity | File:Line | Finding | Why it matters |
|---|----------|-----------|---------|----------------|
| 1 | nit | src/discount.js:5 | `Math.min(x, undefined)` yields NaN if a coupon lacks `maxDiscount` | Spec lists coupon validation as an explicit non-goal, so not blocking; flag for a future validation loop |

Checks performed:
- Spec conformance: criterion 1 → 10% of 1000 = 100 < cap 150 → 900 ✓; criterion 2 → min(1000, 200) = 200 → 4800 ✓. Scope: only src/discount.js changed; non-goals (validation, stacking) untouched.
- Correctness: cap-below/cap-above paths both covered by existing tests; `Math.round` behavior unchanged.
- Tests: existing test/discount.test.js covers both criteria; not weakened.
- Security/concurrency: pure function, no client-trust or state issues introduced.

Verdict: 0 blocking → VERIFY
