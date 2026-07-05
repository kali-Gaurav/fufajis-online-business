# Spec: coupon-cap

## Problem / goal
Coupons must apply a percentage discount capped at coupon.maxDiscount.

## Scope
- src/discount.js
Non-goals: coupon validation, stacking rules.

## Exit criteria
1. applyCoupon(1000, {percent:10, maxDiscount:150}) === 900
2. applyCoupon(5000, {percent:20, maxDiscount:200}) === 4800
3. node test/discount.test.js exits 0

## Verification plan
Mode B: run test/discount.test.js
