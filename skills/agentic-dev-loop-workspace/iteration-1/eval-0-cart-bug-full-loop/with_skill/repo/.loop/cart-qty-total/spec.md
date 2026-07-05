# Spec: cart-qty-total

## Problem / goal
In the Mini Cart web app, changing the quantity of an item does not change the
displayed total — the total is always computed as if every item has qty 1
(price is summed, quantity is read but never multiplied in). Fix
`computeTotal()` so the total is the sum of `price × qty` across all items,
and make sure the UI updates live when a quantity input changes.

## Scope
- `app.js` — fix the total computation in `computeTotal()`.
- `index.html` — only if needed to keep the initial rendered total consistent
  (the hardcoded `165` placeholder is overwritten by `render()` on load, so
  likely no change needed).
- Non-goals: no redesign, no framework, no build step, no new features
  (discounts, currency formatting, item add/remove), no changes to the
  README beyond optionally removing the "Known issue" line.

## Exit criteria
1. `computeTotal()` returns `sum(price × qty)` for all `.item` elements
   (e.g. Rice qty 2 + Milk qty 1 → 285; both qty 1 → 165).
2. In the browser, changing Rice qty from 1 to 3 updates the displayed total
   to ₹405 without a page reload.
3. In the browser, changing Milk qty from 1 to 2 (Rice back at 1) shows ₹210.
4. Page loads with total ₹165 (both qty 1) and no console errors.
5. Non-numeric/empty qty input does not produce `NaN` in the total display
   (a cleared input is treated as 0 or otherwise handled gracefully).

## Verification plan
Mode 1 (in-browser) is preferred per verify.md, but this sandbox has no
browser tools attached — so combine:
- Node-based unit check of `computeTotal()` via the `module.exports` hook
  using jsdom-style DOM stubbing or a minimal DOM shim (evidence to
  `.loop/cart-qty-total/evidence/`).
- If browser tooling is unavailable, a headless DOM simulation of the input
  event covers criteria 2–3, and a static check covers criterion 4.
