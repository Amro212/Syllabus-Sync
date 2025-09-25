# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI app lives in `Syllabus Sync/` with supporting test targets in `Syllabus SyncTests/` and `Syllabus SyncUITests/`. Cloudflare Worker code and shared TypeScript utilities sit in `server/src/`, while Worker-focused specs reside in `test/`. JSON schemas sit alongside the worker at `schemas/`, and higher-level design notes are captured in `architecture.md` and `tasks.md`. Keep build artefacts in `build/` and avoid committing local Xcode user data.

## Build, Test, and Development Commands
```bash
# Server Worker	npm install && npm run start
# Vitest suite	npm test
# Type re-generation	npm run cf-typegen
# iOS build	  xcodebuild -project "Syllabus Sync.xcodeproj" -scheme "Syllabus Sync" build
```
Run server commands from the repo root (Wrangler reads `wrangler.jsonc`). Use Xcode’s preview canvas for UI iteration and prefer `npm run deploy` only after tests pass.

## Coding Style & Naming Conventions
TypeScript follows Prettier (`.prettierrc`) with tabs, 140-character line width, and single quotes; run `npx prettier --write` on touched files. Swift files use Xcode’s default 4-space indentation and mark view models with `*ViewModel` suffix. Keep TypeScript module names descriptive (`parseSyllabus.ts`) and align DTOs with schema names (`EventItem`).

## Testing Guidelines
All Worker changes need Vitest coverage in `test/`, with new suites mirroring the route or module name (`rateLimit.spec.ts`). When adding Swift logic, update `Syllabus SyncTests/` and UI flows inside `Syllabus SyncUITests/`; stub network calls via dependency injection. Failing tests block CI, so run `npm test` (and relevant Xcode schemes) before opening a PR.

## Commit & Pull Request Guidelines
Git history favors imperative, milestone-aware subject lines (e.g., `Milestone 8 - refine OpenAI parsing`); keep to 72 characters and expand detail in the body when behavior changes. Reference items from `tasks.md` or GitHub issues, list manual test evidence, and attach iOS screenshots when UI shifts. PRs should describe scope, risks, and rollback steps, and call out any required environment changes.

## Security & Configuration Tips
Never commit `.dev.vars`; copy from `server/.dev.vars.example` and populate secrets locally, then set production credentials with `wrangler secret put`. Review `ensureOpenAIKey` flows before touching secret handling, and confirm new endpoints enforce CORS and rate limits consistent with existing helpers.
