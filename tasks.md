# Syllabus Sync — Unified MVP Tasks (iOS + Server)

> Scope: End-to-end MVP covering **front-end (Swift/SwiftUI)** and **back-end (serverless API)**.  
> Constraint: Budget-friendly, secure. **OpenAI is used server-side only** for parsing.  
> Test style: Each task is **tiny, testable, single-concern** with **Start / End / Done When**.  
> Target: iOS 17+, Cloudflare Workers (or Vercel Functions) + Cloudflare R2/S3 (optional).

---

## Milestone 0 — Repos, Config & CI

### 0.2 iOS project init
- **Start:** Xcode new project (iOS App, Swift/SwiftUI), bundle id, iOS 17+ target.
- **End:** App runs on Simulator.
- **Done When:** Blank template compiles.

### 0.3 Server project init
- **Start:** `npm create cloudflare` (or Vercel) → TypeScript Worker.
- **End:** Local dev server responds to `/health` with 200 JSON.
- **Done When:** `curl localhost/.../health` returns `{ "ok": true }`.

### 0.4 Shared DTO + JSON Schema
- **Start:** In `server/`, add `schemas/eventItem.schema.json` and TypeScript types (EventItemDTO).
- **End:** Export types for clients; include AJV validation tests.
- **Done When:** `npm test` validates a sample events array.

### 0.5 CI basics
- **Start:** GitHub Actions for `ios/` build (xcodebuild) and `server/` typecheck/test.
- **End:** Status badges in READMEs.
- **Done When:** PRs run CI and pass.

### 0.6 Secrets & env files
- **Start:** Create `server/.dev.vars.example` (OPENAI_API_KEY, R2 bucket names, RATE_LIMITS).
- **End:** Document how to set `wrangler secret put` (or Vercel env).
- **Done When:** No secrets committed; README instructions verified.

---

## Milestone 1 — iOS Design System (Foundation)

### 1.1 Color tokens
- **Start:** Add `AppColors.swift` (dark/light palettes).
- **End:** Semantic colors: Background, Surface, Accent, TextPrimary, TextSecondary.
- **Done When:** Preview shows both themes.

### 1.2 Typography
- **Start:** `AppTypography.swift` with TitleXL, TitleL, Body, Caption.
- **End:** Font extensions wired.
- **Done When:** Text previews match sizes/weights.

### 1.3 Layout tokens
- **Start:** `Layout.swift` for Spacing/Corner/Shadow tokens.
- **End:** Apply to a sample card.
- **Done When:** Consistent spacing on sample.

### 1.4 Theme manager + toggle
- **Start:** `ThemeManager` (ObservableObject) + `ThemeToggle` with spring animation.
- **End:** Global `.environmentObject` wiring.
- **Done When:** Toggle animates app-wide cross-fade.

### 1.5 Core components
- **Start:** Implement `PrimaryCTAButton`, `SecondaryButton`, `ChipView`, `CardView`, `AppIcon`, `ShimmerView`, `SegmentedTabs`.
- **End:** Each has a dedicated Preview with states.
- **Done When:** All components compile and preview.

### 1.6 Haptics wrapper
- **Start:** `HapticFeedbackManager` (success, warning, selection).
- **End:** Buttons can trigger feedback in Previews.
- **Done When:** Taps play expected haptic.

---

## Milestone 2 — iOS Navigation Shell

### 2.1 App root + routes
- **Start:** `AppRoot.swift` with `NavigationStack` and route enum (Onboarding, Auth, Dashboard, Import, Preview, CourseDetail, Settings).
- **End:** Programmatic navigation between placeholders.
- **Done When:** Basic routing works.

### 2.2 Page transitions
- **Start:** Define slide/dissolve transitions + `matchedGeometryEffect` helper.
- **End:** Apply to sample push + modal.
- **Done When:** Transitions feel cohesive.

---

## Milestone 3 — iOS Screens (Mock-First)

### 3.1 Onboarding
- **Start:** `OnboardingView` with 3–4 swipe cards + microinteractions.
- **End:** “Get Started” → Auth with success haptic.
- **Done When:** Smooth swipe + CTA navigates.

### 3.2 Auth (UI only)
- **Start:** `AuthView` (tabs: Login / Sign Up), Apple button (mock), fields with validation hinting.
- **End:** On “Login,” simulate loading → Dashboard.
- **Done When:** Flow transitions reliably.

### 3.3 Dashboard (empty)
- **Start:** `DashboardEmptyView` + CTA “Import Syllabus PDFs” + pull-to-refresh shimmer.
- **End:** Section headers ready.
- **Done When:** Empty state looks polished.

### 3.4 Import UI (stub)
- **Start:** `ImportView` (drag target + file picker button).
- **End:** Show fake progress then navigate to Preview.
- **Done When:** Progress animation plays.

### 3.5 Preview (mock data)
- **Start:** Seed `MockCourse` (3) + `MockEvent` (~15). Build List & Calendar tabs.
- **End:** Expandable `TimelineEventCard` + context menu; month navigation.
- **Done When:** Interactions smooth and stable.

### 3.6 Course Detail
- **Start:** Header with `matchedGeometryEffect`; tabs by type; reorder via drag.
- **End:** Quick edit sheet (mock save + haptic).
- **Done When:** Edits persist in local state.

### 3.7 Settings
- **Start:** Theme toggle (global), Haptic test, Reset (mock) to empty state.
- **End:** Route accessible from Dashboard.
- **Done When:** Toggles work immediately.

---

## Milestone 4 — Server Scaffold (API, Security, Logging)

### 4.1 Routing & handlers
- **Start:** Add `GET /health`, `POST /parse`, (optional) `POST /upload` stubs.
- **End:** Each returns JSON with unified error shape.
- **Done When:** `curl` verifies response codes and bodies.

### 4.2 CORS + content limits
- **Start:** CORS allow-list (iOS app scheme) + `Content-Length` guard + `Content-Type` checks (JSON only for /parse).
- **End:** Rejects non-conforming requests.
- **Done When:** Negative tests get 4xx.

### 4.3 Rate limiting (basic)
- **Start:** Add IP-based token bucket (edge memory or Durable Object). Configurable limits in env.
- **End:** Exceeding requests return 429 with `retry-after`.
- **Done When:** Manual flood test blocks correctly.

### 4.4 Structured logging
- **Start:** JSON logs (requestId, route, duration, code). Redact PII.
- **End:** Error logging middleware.
- **Done When:** Logs appear in local dev console.

### 4.5 Env & secrets
- **Start:** Read OPENAI_API_KEY from secrets. No keys in code.
- **End:** Fail-fast if missing.
- **Done When:** Boot fails with helpful message when unset.

---

## Milestone 5 — Server OpenAI Parser

### 5.1 Normalization
- **Start:** Implement text cleaning: Unicode normalize, trim whitespace, collapse multiple spaces, line merges.
- **End:** Export `normalizeText()` with tests.
- **Done When:** Unit tests pass with sample syllabi.

### 5.2 Date/time extractors
- **Start:** Regex for common date formats (e.g., “Sept 12, 2025”, “09/12/25”, “Week of …”), weekday mapping, range handling.
- **End:** `extractDates(text)` returning candidate spans with indices.
- **Done When:** Tests cover variants & time zones (assume local).

### 5.3 Keyword classifiers
- **Start:** Patterns for Assignment/Quiz/Midterm/Final/Lab/Exam, “due”, “submission”, “weight”, etc.
- **End:** `classifyLine(line)` returns type + score.
- **Done When:** Precision/recall acceptable on samples.

### 5.4 Event builder
- **Start:** Combine date hits + keyword types per line/block to draft EventItem candidates.
- **End:** Deduplicate and fill title defaults (e.g., “Assignment 1”).  
- **Done When:** Returns array of candidate events with confidence.

### 5.5 JSON validation
- **Start:** Validate with AJV against `EventItemDTO` schema.
- **End:** Map to camelCase, fill defaults (allDay true if no time), clamp dates to term window if provided.
- **Done When:** Schema-valid JSON returns from `/parse` (heuristics-only path).

---

## Milestone 6 — Server OpenAI Fallback (Secure + Budgeted)

### 6.1 Prompt + schema
- **Start:** Create `prompts/parseSyllabus.ts` using system prompt + function/JSON schema.
- **End:** Include few-shot examples for ambiguous cases.
- **Done When:** Prompt outputs valid JSON in isolation.

### 6.2 OpenAI client
- **Start:** Minimal client using fetch with bearer from secret; 10–20s timeout; retry with jitter x2.
- **End:** Support `response_format: json` when available.
- **Done When:** Unit test hits mock server and parses JSON.

### 6.3 Confidence router
- **Start:** In `/parse`, call OpenAI directly for parsing.
- **End:** Return results with source = `openai` and overall confidence.
- **Done When:** Endpoint returns selected path with diagnostics.

### 6.4 Cost guardrails
- **Start:** Add daily OpenAI budget cap (env), per-IP cap, and short-circuit when exceeded.
- **End:** Log denials with reason.
- **Done When:** Simulated high-traffic day triggers guard.

---

## Milestone 7 — (Optional) Storage for PDFs

### 7.1 R2/S3 bucket
- **Start:** Create bucket, lifecycle to auto-delete after 7–14 days.
- **End:** IAM key scoped to bucket; store in secrets.
- **Done When:** Listing bucket works in dev.

### 7.2 Presigned upload
- **Start:** `POST /upload` returns presigned URL for PDF.
- **End:** Verify file size/type constraints server-side.
- **Done When:** cURL PUT of sample PDF succeeds; URL expires on TTL.

### 7.3 Parse file path
- **Start:** Allow `/parse` to receive `{ fileUrl }` and read PDF (if runtime supports).  
- **End:** Fallback to text-only if not supported in your platform.
- **Done When:** End-to-end test parses a hosted PDF or gracefully rejects if unsupported.

---

## Milestone 8 — iOS: Real Import Flow (Client ↔ Server)

### 8.1 Client text extraction
- **Start:** Implement `PDFTextExtractor` on-device via PDFKit; fallback to Vision OCR if needed.
- **End:** Extracted text for the first page & whole doc (configurable).
- **Done When:** Sample syllabus produces non-empty text.

### 8.2 Parse service client
- **Start:** Add `APIClient` and `SyllabusParserRemote` in iOS.
- **End:** `parse(text:)` calls server `/parse`, handles errors/timeouts.
- **Done When:** Successful parse returns `[EventItem]` mapped to models.

### 8.3 ImportViewModel integration
- **Start:** Replace mock progress with real extract→POST→result.
- **End:** Show diagnostics string (heuristics/openai, confidence) in a small debug label.
- **Done When:** Preview screen is populated from server result.

### 8.4 Error paths
- **Start:** Handle 4xx/5xx: show friendly retry, or let user continue with empty list.
- **End:** Log errors via lightweight logger.
- **Done When:** Simulated failure renders UX gracefully.

---


## Milestone 9 — Full Event Editing UX

### 9.1 Auto-approval of Imported Events
- **Start:** Upon successful import and parsing, automatically approve all imported events for inclusion in the system.
- **End:** Events are immediately available in the user's event list without manual review/approval.
- **Done When:** Imported events appear in the Preview and Dashboard without requiring extra confirmation.

### 9.2 Event Card Editing Capabilities
- **Start:** Enable editing for each event card in the Preview and Dashboard views.
- **End:** Users can edit all event fields: title, type, date/time, recurrence, notes, location.
- **Done When:** Tapping an event allows full field editing, with changes reflected in the UI.

### 9.3 Editing UX Design & Implementation
- **Start:** Design and implement the event editing experience, either as a detail screen or bottom sheet/modal.
- **End:** Editing UI is accessible from event cards, with clear save/cancel actions and smooth transitions.
- **Done When:** Editing flows feel native, intuitive, and are fully interactive in previews and on device.

### 9.4 Persist Edits to Core Data/CloudKit
- **Start:** Update Core Data and CloudKit models to persist all edits made to events.
- **End:** Saving changes updates the local database and syncs to iCloud if enabled.
- **Done When:** Relaunching the app or switching devices reflects the latest edits for each event.

### 9.5 Edit Sync & EventKit Integration Prep
- **Start:** Ensure all event edits are tracked and ready to sync with EventKit in later milestones.
- **End:** Changes to events are flagged for later push to EventKit (local calendar integration).
- **Done When:** Edited events are stored and marked for EventKit sync, with no loss of data or state.

---

## Milestone 9.5 — CloudKit Backup/Sync (Core Data + iCloud)

### 9.5.1 Enable iCloud/CloudKit capability
- **Start:** In Xcode, add Signing & Capabilities → iCloud (CloudKit).
- **End:** Container `iCloud.com.your.bundle` exists.
- **Done When:** Build succeeds with iCloud entitlement.

### 9.5.2 Add Core Data model
- **Start:** Create `SyllabusSync.xcdatamodeld` with entities: Course, EventItem, UserPrefs (fields per architecture).
- **End:** Generate NSManagedObject subclasses if desired.
- **Done When:** Model compiles.

### 9.5.3 Wire NSPersistentCloudKitContainer
- **Start:** Implement `CoreDataStack` as in architecture; set CloudKit container options.
- **End:** Inject a `managedObjectContext` into SwiftUI environment.
- **Done When:** App launches without Core Data errors.

### 9.5.4 Repositories → Core Data
- **Start:** Implement `CourseRepository` and `EventRepository` using Core Data (CRUD + fetch).
- **End:** Replace in-memory mocks behind same protocols.
- **Done When:** Dashboard/Preview load from Core Data seed.

### 9.5.5 Write-through on Preview approve
- **Start:** On “Approve changes” in Preview, persist `Course`, `EventItem[]`, update `UserPrefs.lastImportHashByCourse`.
- **End:** Save context; show success haptic.
- **Done When:** Relaunching app shows the same data (even after simulator reinstall with same iCloud account).

### 9.5.6 iCloud sync sanity check
- **Start:** Install on two simulators/devices with different Apple IDs; use the primary one for sync check.
- **End:** Confirm records appear in CloudKit Dashboard (Development schema).
- **Done When:** Data reappears after delete/reinstall on the same Apple ID device.

### 9.5.7 Delete my Cloud Data (safety valve)
- **Start:** Add Settings → “Delete Cloud Backup” button.
- **End:** Deletes Core Data objects (which mirrors to CloudKit); confirm alert.
- **Done When:** Cloud data disappears on next sync.

### 9.5.8 Docs update
- **Start:** Add a short “Cloud Backup” note to `README_DEMO.md`.
- **End:** Mention Private DB, what’s stored, how to wipe.
- **Done When:** README committed.

---

## Milestone 10 — Calendar & Notifications (Local Only)

### 10.1 EventKit integration
- **Start:** Request permission; create/find “Syllabus Sync” calendar.
- **End:** Create events for approved items; attach alerts (e.g., 1 day, 1 hour before).
- **Done When:** Calendar app shows events after sync.

### 10.2 Local notifications
- **Start:** Ask permission post-value; schedule weekly reminders + exam countdowns.
- **End:** Use `UNUserNotificationCenter` with identifiers tied to event ids.
- **Done When:** Test notification fires on schedule (use accelerated test dates).

---

## Milestone 11 — Authentication (Lean Path)

### 11.1 Client stub
- **Start:** Keep “force login” UX but generate anonymous client id (UUID) for rate limiting.
- **End:** Send `x-client-id` header to server on `/parse`.
- **Done When:** Server logs show id received.

### 11.2 Apple Sign-In (optional)
- **Start:** Implement “Sign in with Apple” on iOS; get identity token.
- **End:** Store opaque user id locally (Keychain) to persist session.
- **Done When:** Round-trip works in sandbox (no server verify yet).

### 11.3 Server token (optional)
- **Start:** Add `/auth/apple` to verify Apple token → issue short-lived JWT.
- **End:** iOS stores JWT in Keychain; sends `Authorization: Bearer` to server.
- **Done When:** Server rate-limits by subject id instead of IP.

---

## Milestone 12 — Security & Budget Controls

### 12.1 CORS strictness
- **Start:** Limit origins to production/test app schemes; drop others.
- **End:** Add unit tests for allowed vs denied origins.
- **Done When:** Denied origin returns 403/400.

### 12.2 Input caps
- **Start:** Enforce max text length (e.g., 250k chars), reject binary in JSON.
- **End:** Return error with helpful message.
- **Done When:** Oversized payload test returns 413.

### 12.3 Budget guard
- **Start:** Implement per-day token spend cap and per-client parse cap.
- **End:** Expose diagnostic header `x-parser-path: openai`.
- **Done When:** Cap triggers and returns appropriate error.

### 12.4 Observability
- **Start:** Add simple metrics: requests, parse path chosen, token spend, error rate.
- **End:** Export counters to logs; optional dashboard later.
- **Done When:** Logs show counters incrementing.

---

## Milestone 13 — QA, Demos, and Packaging

### 13.1 End-to-end smoke test
- **Start:** Use two sample syllabi (clean + messy). Test: Import → Parse → Preview → Sync.
- **End:** Record issues and fix blockers.
- **Done When:** Both samples complete successfully.

### 13.2 Demo toggle
- **Start:** In iOS, add debug menu to switch empty vs seeded data; show diagnostics badge (openai).
- **End:** Accessible via 3-tap gesture on title.
- **Done When:** Demo flows reproducible live.

### 13.3 App/Server readmes
- **Start:** Update `README_DEMO.md` and server README with curl examples.
- **End:** Include environment setup, scripts, known limitations.
- **Done When:** A new dev can run both ends in <15 minutes.

### 13.4 Release checklist
- **Start:** ATS checks (HTTPS only), privacy strings, permission copy, icons/splash.
- **End:** App archive builds; server deploy script works.
- **Done When:** TestFlight build + server staging deployed.

---

## Milestone 14 — Stretch (Post-MVP Candidates)

- **Re-import diff server-side** with a more robust matcher.  
- **Team plans**: Export ICS or shared calendar link.  
- **Paywall** with StoreKit 2 and server receipt validation.  
- **LMS connectors**: ICS ingestion first.  
- **Full PDF ingest on server** where platform supports it.

---

## Acceptance Criteria Summary

- iOS app demonstrates full UI/UX with **real parse** from server (text → events), and **EventKit** sync.  
- Server provides **/parse** with OpenAI-powered parsing, protected by **rate limits, CORS, and budget caps**.  
- No secrets in client; **OPENAI_API_KEY** stored server-side only.  
- Clear logs/diagnostics to confirm parser path and confidence.  
- Two sample syllabi run end-to-end with expected results.

