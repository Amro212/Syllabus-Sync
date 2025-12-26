---
trigger: model_decision
description: This rule keeps external integrations correct and predictable.
---

# Rule: API Integrations + Auth (Supabase and others)

## 1) Treat external docs as law
- Use official docs for the exact provider and SDK version in the repo.
- If docs and repo disagree, the repo wins unless the user asks for an upgrade.

## 2) Integration workflow (mandatory)
1. Identify provider, SDK version, and current integration state in the repo.
2. Identify the exact user-facing flow:
   - sign up
   - sign in
   - session restore
   - refresh
   - sign out
   - password reset
3. Identify environment variables and secrets needed.
4. Identify error cases and how they show in UI.
5. Implement in small steps with compilation checkpoints.

## 3) Supabase Auth specifics (guardrails)
- Never store access tokens in plaintext UserDefaults.
- Prefer:
  - Supabase SDK session management if already present, or
  - Keychain-backed storage
- Session restore must happen on app launch:
  - App decides initial route based on session validity.
- Sign out must clear:
  - local session
  - cached user-specific data that could leak between accounts

## 4) Networking rules
- Centralize requests through one API client.
- Use typed models for request and response bodies.
- Validate JSON decoding and handle failures.
- Timeouts and retries should be explicit, not accidental.

## 5) Schema and data contracts
- If the backend schema is referenced:
  - check schema files in repo first
  - if missing, request the schema or show a placeholder with TODO
- No guesswork on table/column names.

## 6) Logging and privacy
- Never log secrets, tokens, or PII.
- Mask sensitive fields if logging is needed for debugging.

## 7) “Done” criteria for an integration change
- Builds clean
- Auth flows work end-to-end (at least sign in, restore session, sign out)
- UI has loading and error states
- No token leakage
