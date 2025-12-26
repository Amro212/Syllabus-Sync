---
trigger: model_decision
description: This rule ensures changes ship without surprises.
---

# Rule: Testing + QA (Syllabus Sync)

## 1) Always include a test plan
Even if no automated tests are added, include:
- what to click
- expected results
- edge cases

## 2) When to add automated tests
Add or update tests when touching:
- parsing correctness
- date/time logic
- sorting and grouping logic
- auth/session routing logic
- API client decoding

## 3) Minimum QA checklist per change
- Build succeeds (simulator)
- Launch works from cold start
- Navigate through the changed flow
- Trigger at least one error case
- Confirm no UI regression (spacing, fonts, theme)

## 4) Date and timezone gotchas
For anything calendar-related:
- test a course that spans:
  - a daylight savings boundary if relevant
  - different time zones (device setting)
- verify recurring events behavior if used

## 5) Logging discipline
- Debug logs allowed
- Remove noisy logs before shipping
- Never log secrets or PII
