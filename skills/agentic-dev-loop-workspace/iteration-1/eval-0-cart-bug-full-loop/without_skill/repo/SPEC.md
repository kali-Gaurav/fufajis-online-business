# Spec: Cart total must respect item quantity

## Problem
Changing an item's quantity input does not change the displayed total. The total
always reflects qty = 1 for every item, so customers are charged as if they
bought one of each.

## Root cause
In `app.js` `computeTotal()`, the quantity is parsed (`qty`) but the accumulator
uses only the price: `total += price;` instead of `total += price * qty;`.

## Requirements
1. `computeTotal()` returns the sum of `price * qty` across all `.item` elements.
2. Total updates live on the `input` event of any `.qty` field (already wired; must keep working).
3. Robustness: while the user is typing, a `.qty` field can be empty or invalid
   (`parseInt` → NaN) or below the `min="1"` bound (e.g. pasted "0" or "-2").
   Any NaN or value < 1 is treated as 1, matching the input's `min="1"`.
   The total must never render as `NaN`.
4. No behavior change for the default state: with both items at qty 1,
   total remains 165 (120 + 45).
5. Keep the `module.exports` test hook intact.

## Out of scope
- Adding/removing items, currency formatting, persistence, styling.
- Any backend involvement (static demo app, no server).

## Acceptance criteria
- Rice qty 2, Milk qty 1 → total 285.
- Rice qty 2, Milk qty 3 → total 375.
- Rice qty emptied mid-typing (""), Milk qty 1 → total 165 (no NaN).
- Rice qty "0" or negative, Milk qty 1 → total 165 (clamped to min 1).
- Defaults (1, 1) → 165.

## Verification plan
- Unit-level: run `computeTotal()` under Node with a minimal DOM stub covering
  the acceptance cases above (`verify.test.js`).
- In-browser: open `index.html`, change quantities, confirm the total updates.
