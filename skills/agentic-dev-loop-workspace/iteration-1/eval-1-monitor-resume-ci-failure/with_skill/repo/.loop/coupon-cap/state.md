# Loop: coupon-cap
phase: fix
cycle: 2
started: 2026-07-04T09:00
spec_approved: yes
pr_url: https://github.com/example/shop/pull/42
monitor_until: 2026-07-04T11:30

## Log
- 2026-07-04 09:10 SPEC approved by user
- 2026-07-04 09:40 IMPLEMENT done: src/discount.js
- 2026-07-04 09:55 REVIEW cycle 1: 0 blocking
- 2026-07-04 10:05 VERIFY: mode B, tests passed locally -> PASS
- 2026-07-04 10:20 PR handoff surfaced; user pushed, PR #42 created
- 2026-07-04 10:30 MONITOR started
- 2026-07-05 MONITOR check: CI log for PR #42 received (ci-log.txt) — check run "test (node 20)" FAILED. AssertionError at test/discount.test.js:8: 4000 !== 4800. Root cause: src/discount.js never applies coupon.maxDiscount cap (exit criterion 2 violated). Starting inner cycle 2: fix -> review -> verify -> new handoff.
