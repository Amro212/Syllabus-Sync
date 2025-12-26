---
trigger: always_on
---

# Rule: Code Execution (Syllabus Sync)

This rule is always on. It exists to keep changes correct, stable, and consistent.

## 1) Always start with sources before actions
- Prefer primary sources first:
  - Existing repo code (types, models, API clients, services, views)
  - Official docs for the exact technology in use (Apple, Swift, Supabase, Cloudflare Workers if used, etc.)
  - The project’s own README, architecture docs, and schema files
- Do not guess API shapes, auth flows, or SDK functions. If it is not in our repo or an official doc, treat it as unknown.

## 2) Required pre-flight checklist (before writing code)
1. Restate the user request as a concrete deliverable.
2. Locate the most relevant files in the repo. List them.
3. Identify constraints:
   - platform target (iOS version)
   - SwiftUI vs UIKit
   - async model (async/await, Combine)
   - storage (Keychain, UserDefaults, Supabase session)
4. Identify dependencies and their versions (Package.swift, Podfile, etc.)
5. Identify what could break:
   - auth/session handling
   - parsing pipeline
   - calendar writes
   - networking
   - build settings
6. Write a short plan with ordered steps and which files will change.
7. If anything critical is unknown, stop and ask for the missing info OR create a safe stub with TODO markers, but do not fabricate behavior.

## 3) Source-of-truth rules when using APIs and third-party tools
- For any external integration (Supabase auth, Apple Sign In, Google, calendar APIs, push notifications):
  - Use official documentation and link to exact endpoints or SDK calls when possible.
  - Match the SDK version present in the repo.
  - Mirror the exact expected response models (no imaginary fields).
- When updating auth flows:
  - Never store tokens in plain UserDefaults.
  - Prefer Keychain for refresh/access tokens or rely on the SDK’s secure storage if it exists and is already used.
  - Ensure sign out clears session and sensitive cached data.

## 4) Change discipline
- Make the smallest change that satisfies the request.
- Avoid drive-by refactors unless the user explicitly asks.
- If a refactor is necessary, do it in a separate commit-sized chunk and explain why.

## 5) Code quality bar
- No duplicate logic. Prefer a single source of truth (one AuthService, one APIClient, etc.)
- Prefer dependency injection for services used by views.
- Follow existing patterns in the repo even if you personally prefer another style.
- Add doc comments only where they clarify non-obvious behavior.

## 6) “Plan, then execute” is mandatory for every task
Before writing code, produce:
- “Files I will touch” list
- Step-by-step plan (5 to 12 steps)
- Risk list (what might break)
- Test plan (what will be verified)

Then execute.

## 7) Testing and verification requirements
- Always ensure:
  - project builds
  - tests pass (unit tests, snapshot tests if any, integration tests if any)
- Add tests when:
  - you touch parsing logic
  - you touch authentication/session state
  - you touch core model transformations
- If tests are not feasible, add at least one lightweight verification hook:
  - debug logging behind a flag
  - a small internal validation function
  - a manual QA checklist

## 8) Error handling rules
- Never ignore errors silently.
- User-facing failures should be surfaced as:
  - a clear SwiftUI alert/toast
  - retry affordance if the action is safe to retry
- Log errors in debug builds with enough context to reproduce.

## 9) Stop conditions (do not proceed)
Stop and request clarification if:
- The exact endpoint, schema, or SDK version is unknown and impacts correctness.
- The change requires secrets or credentials not present in environment variables.
- The change requires migrations or schema changes and we do not have access to the DB project details.

## 10) Output format
When finishing a task, include:
- summary of what changed
- file list
- how to test it locally
- any assumptions made
