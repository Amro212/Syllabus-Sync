---
trigger: always_on
description: This rule exists because the user may describe ideas loosely. The agent must clarify intent before making changes that could drift, break flows, or waste time.
---

# Rule: Clarifying Questions + Back-and-Forth (Syllabus Sync)

## 1) Default behavior
- If the request has any meaningful ambiguity, ask focused questions first.
- Do not start coding until the key unknowns are resolved, unless the task is low-risk and reversible (pure UI polish, copy edits, small layout tweaks).

## 2) What counts as “ambiguous” (ask questions)
Ask questions when ANY of these are unclear:
- Desired user flow (what happens first, next, last)
- Success criteria (“what does ‘done’ look like?”)
- Data sources (PDF parsing output, backend schema, API endpoints)
- Auth/session behavior (who can do what, how long sessions last, sign-out rules)
- Edge cases (multiple syllabi, missing dates, time zones, duplicates)
- UI constraints (exact screen, components, navigation, what must stay the same)
- Non-functional constraints (performance, offline behavior, privacy, security)
- Any third-party integration or SDK usage details

## 3) Ask the right kind of questions
Rules for good questions:
- Keep it short and surgical.
- Ask in batches of 3 to 7, not 20.
- Prefer multiple-choice or “pick one of these” options when possible.
- Ask for concrete examples (“show me one syllabus line that should parse into X”).

## 4) The “Clarify then Plan then Build” sequence (mandatory)
When a request is ambiguous, respond in this exact order:
1. **My understanding so far** (2–4 sentences)
2. **Clarifying questions** (3–7 bullets)
3. **Proposed approach** (very short, conditional on answers)
4. **What I will do next** (one sentence)

Only after the user answers:
1. Confirm final understanding (1 short paragraph)
2. Provide plan + files to touch + test plan
3. Then implement

## 5) Don’t block progress unnecessarily
If the request is partially clear:
- Proceed with the parts that are 100% clear.
- Stub the unclear parts with TODO markers.
- Clearly label assumptions and what needs confirmation.

## 6) Safe assumptions policy
Allowed assumptions (if not specified):
- Follow existing app theme and component patterns.
- Keep changes minimal and reversible.
- Preserve existing navigation structure.
Not allowed assumptions:
- API fields, endpoints, auth provider behavior, schema names, or token storage approach.

## 7) Examples of good clarifying questions
- “Is this for the Dashboard view or the Syllabus Upload flow?”
- “Should this be stored locally only, or synced to Supabase?”
- “When parsing a date range like ‘Sept 5–Dec 10’, do you want recurring weekly events or one long event?”
- “If a user uploads a second syllabus for the same course, should we merge, replace, or keep both?”

## 8) “Stop and ask” triggers (hard stop)
Do not proceed without answers if:
- It involves authentication/session changes
- It changes data contracts, schemas, or API shapes
- It affects payments/subscriptions
- It touches calendar writes and date/time logic without clear expected behavior
- It introduces new dependencies or services

## 9) Output format after clarification is complete
When executing, always output:
- summary of decisions (based on answers)
- plan
- file list
- risks
- test plan