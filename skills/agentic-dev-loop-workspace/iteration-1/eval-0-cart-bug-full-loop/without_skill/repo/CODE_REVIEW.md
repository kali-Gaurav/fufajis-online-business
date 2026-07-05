# Code Review: cart total quantity fix

Reviewed diff: `app.js` (computeTotal), `README.md` (known-issue note removed).

## Verdict: APPROVE (after one round of self-review, no blocking issues)

## What was checked

1. **Correctness of the core fix** — `total += price * qty;` now multiplies
   price by quantity. Matches SPEC requirement 1. PASS.
2. **NaN safety** — `parseInt("")` and `parseInt("abc")` return NaN. The clamp
   `Number.isNaN(parsedQty) || parsedQty < 1 ? 1 : parsedQty` guarantees a
   finite qty >= 1, so the rendered total can never be NaN from the qty field.
   Matches SPEC requirement 3. PASS.
3. **Clamping semantics** — values below `min="1"` (0, negatives) are treated
   as 1, consistent with the HTML input constraint. Deliberate spec decision;
   documented in an inline comment. PASS.
4. **Event wiring untouched** — the `input` listeners and `render()` are
   unchanged, so live updates keep working. PASS.
5. **Test hook untouched** — `module.exports = { computeTotal }` retained. PASS.
6. **HTML default total** — the hardcoded `165` in `index.html` is overwritten
   by `render()` on load and still equals the computed default, so no change
   needed. PASS.

## Non-blocking observations (not fixed, out of spec scope)

- `parseInt(item.dataset.price, 10)` would yield NaN if an item ever omitted
  `data-price`. Both current items define it; guarding this is out of scope.
- `parseInt` truncates decimal quantities (e.g. "2.7" → 2). Acceptable for an
  integer qty input with `type="number" min="1"`.
- No `change`/`blur` normalization writes the clamped value back into the
  input; the field can display "0" while the total treats it as 1. Cosmetic,
  out of scope per SPEC.

## Architecture note

Static client-only demo; no backend, payments, or inventory involved, so the
Fufaji backend-only mutation rules do not apply here. If this cart logic ever
feeds a real checkout, the authoritative total must be recomputed server-side
(Supabase Edge Function → PostgreSQL) per CLAUDE.md — never trust the client
total.
