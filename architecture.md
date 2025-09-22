# Syllabus Sync — Architecture

> Version: 0.1 (Front‑end MVP + Practical Back‑end plan)  
> Target: iOS 17+, Swift 5.x, SwiftUI, low-cost + secure, OpenAI-assisted parsing (server-side), EventKit for calendar.

---

## 1) Product Overview

**Syllabus Sync** lets students import course syllabi (PDFs), extract key dates, preview a clean timeline/calendar, and one‑tap sync to Apple Calendar with reminders. The app favors **delightful motion, microinteractions, and clarity** over heavy configuration.

**Primary flows**
1. Onboard → Auth → Dashboard (empty) → Import PDFs → Preview (list/calendar) → Sync to Calendar.
2. Re‑import updated syllabi → Diff changes → Approve → Update Calendar.
3. Daily loop → Weekly reminders, exam countdowns, slip‑date updates.

**Non-goals (MVP)**  
- No real-time collaboration.  
- No native PDF annotation.  
- No deep LMS integration (Canvas/Brightspace) in MVP.

---

## 2) High-Level Architecture

```
+-------------------------+           +---------------------------+
|        iOS App          |           |     Server (Serverless)   |
|  SwiftUI (MVVM/TCA-lite)|           |  Minimal API, low-cost    |
+-------------------------+           +---------------------------+
| Features (SwiftUI Views)|           |  /parse (OpenAI)          |
| ViewModels (Observable) | <-------> |  /upload (PDF storage)    |
| Services (facades)      |    HTTPS  |  /auth (JWT mgmt)         |
| Local Store (Core Data) |           |  /webhooks (optional)     |
| Keychain (tokens)       |           +---------------------------+
| EventKit / Notifications|
+-------------------------+
```

**Principles**
- **Thin client business logic**, thick UI; heavy/secret work (OpenAI) done server-side.
- **Composable services** under a clear protocol boundary.
- **Mock-first**: all services can run with local mocks for front‑end dev and previews.
- **Budget-aware**: OpenAI-powered parsing with cost controls.

---

## 3) File & Folder Structure (Xcode Project)

```
SyllabusSync/
├─ App/
│  ├─ SyllabusSyncApp.swift
│  ├─ AppRoot.swift               // NavigationStack root
│  └─ Environment/
│     ├─ ThemeManager.swift       // Dark/Light state
│     ├─ AppConfig.swift          // Build-time flags, endpoints
│     └─ HapticFeedbackManager.swift
│
├─ DesignSystem/
│  ├─ AppColors.swift             // Semantic tokens (bg/surface/text/accent)
│  ├─ AppTypography.swift
│  ├─ Layout.swift                // Spacing/radius/shadows
│  ├─ Components/
│  │  ├─ PrimaryCTAButton.swift
│  │  ├─ SecondaryButton.swift
│  │  ├─ ChipView.swift
│  │  ├─ CardView.swift
│  │  ├─ AppIcon.swift            // SF Symbols wrapper
│  │  ├─ ShimmerView.swift
│  │  ├─ SegmentedTabs.swift
│  │  └─ ThemeToggle.swift
│  └─ Animations/
│     ├─ AnimationTokens.swift    // Durations/curves
│     └─ Effects.swift            // matchedGeometry helpers, glow
│
├─ Features/
│  ├─ Onboarding/
│  │  ├─ OnboardingView.swift
│  │  └─ OnboardingCardView.swift
│  ├─ Auth/
│  │  ├─ AuthView.swift           // UI only (Apple/Email mock)
│  │  └─ AuthViewModel.swift      // Mock login success
│  ├─ Dashboard/
│  │  ├─ DashboardView.swift
│  │  ├─ DashboardEmptyView.swift
│  │  └─ CourseCardView.swift
│  ├─ Import/
│  │  ├─ ImportView.swift         // Drag & Drop + Picker UI
│  │  └─ ImportViewModel.swift    // Progress mock → calls ParseService later
│  ├─ Preview/
│  │  ├─ PreviewView.swift        // Segmented (List/Calendar)
│  │  ├─ EventListView.swift
│  │  ├─ EventCalendarView.swift  // Simple month grid
│  │  └─ TimelineEventCard.swift
│  ├─ CourseDetail/
│  │  ├─ CourseDetailView.swift
│  │  └─ CourseDetailViewModel.swift
│  └─ Settings/
│     ├─ SettingsView.swift
│     └─ SettingsViewModel.swift
│
├─ Models/
│  ├─ Domain/
│  │  ├─ Course.swift
│  │  ├─ EventItem.swift          // id, courseId, type, title, start, end, notes
│  │  └─ Enums.swift              // EventType, ReminderPolicy, etc.
│  └─ Mock/
│     └─ MockData.swift           // Seed 3 courses + ~15 events
│
├─ Services/
│  ├─ Protocols/
│  │  ├─ PDFTextExtractor.swift   // extractText(from: Data) -> String
│  │  ├─ SyllabusParser.swift     // parse(text) -> [EventItem]
│  │  ├─ CalendarService.swift    // create/update/delete via EventKit
│  │  ├─ NotificationService.swift
│  │  ├─ AuthService.swift
│  │  ├─ StorageService.swift     // upload/list PDFs (optional)
│  │  └─ APIClient.swift          // generic HTTP client
│  ├─ Implementations/
│  │  ├─ PDFKitExtractor.swift    // PDFKit + Vision OCR fallback
│  │  ├─ SyllabusParserRemote.swift // OpenAI-powered parsing (server-side)
│  │  ├─ OpenAIParserRemote.swift // server endpoint that uses OpenAI
│  │  ├─ EventKitCalendarService.swift
│  │  ├─ UserNotificationService.swift
│  │  ├─ AuthServiceMock.swift
│  │  ├─ StorageServiceMock.swift
│  │  └─ URLSessionAPIClient.swift
│  └─ Mocks/
│     ├─ PDFTextExtractorMock.swift
│     ├─ SyllabusParserMock.swift
│     └─ CalendarServiceMock.swift
│
├─ Persistence/
│  ├─ CoreDataStack.swift         // Optional for cache
│  ├─ Repositories/
│  │  ├─ CourseRepository.swift
│  │  └─ EventRepository.swift
│  └─ Keychain/
│     └─ KeychainStore.swift      // tokens, small secrets
│
├─ Util/
│  ├─ Date+Utils.swift
│  ├─ Formatters.swift
│  └─ Logging.swift               // unified logging wrapper
│
├─ Config/
│  ├─ Config.debug.json           // dev endpoints/flags
│  └─ Config.release.json
│
└─ Tests/ (optional for MVP)
   ├─ Snapshot/
   └─ Unit/
```

**What each part does**
- **App/**: Entry points, Navigation root, global environment (theme, haptics, config).
- **DesignSystem/**: Visual tokens + reusable components/animations.
- **Features/**: Screen-specific UI + ViewModels (MVVM). Each feature owns its state and composes services.
- **Models/**: Domain models and mock seeds for front‑end dev.
- **Services/**: Protocols (boundaries) + implementations (real/mocks). Easy to swap at composition time.
- **Persistence/**: Local cache (optional in MVP), Keychain for secrets.
- **Util/**: Date/format helpers, lightweight logging wrapper.
- **Config/**: Build-time configuration per environment.
- **Tests/**: Unit/snapshot tests (optional early).

---

## 4) State Management & Data Flow

**Pattern:** MVVM with ObservableObject for each feature, `@State`/`@StateObject`/`@EnvironmentObject` for view bindings.

- **Global state**: `ThemeManager` (dark/light), optional `AppSession` (user auth state once backend exists).
- **Feature state** lives in the feature’s ViewModel:  
  - *OnboardingViewModel*: current page index.  
  - *AuthViewModel*: form input states; for MVP, mock success.  
  - *DashboardViewModel*: empty vs populated, lists of Course/Event (from mock repo).  
  - *ImportViewModel*: import progress state; later: invokes ParseService.  
  - *PreviewViewModel*: [EventItem] for List/Calendar, selection filters, expansion states.  
  - *CourseDetailViewModel*: filtered events by type, reorder state.  
  - *SettingsViewModel*: toggles for theme/haptics; reset action.

**Data flow (MVP)**
1. MockData seeds → Repositories → ViewModels → SwiftUI Views.
2. Actions (tap/drag/long-press) → ViewModel methods → update state → UI reacts.

**Data flow (Post‑MVP)**  
1. ImportViewModel uploads PDF to StorageService (server) → requests `/parse` → server runs extraction/OpenAI parsing → returns structured `[EventItem]`.  
2. PreviewViewModel shows diff vs existing → user approves → CalendarService writes via EventKit → local cache updates.

---

## 5) Services (Boundaries & Implementations)

### 5.1 PDF Text Extraction
- **Protocol:** `PDFTextExtractor`  
  - `func extractText(from data: Data) async throws -> String`
- **Impls:**  
  - `PDFKitExtractor`: try PDFKit text first.  
  - Fallback OCR with Vision (for scanned PDFs).

### 5.2 Syllabus Parsing
- **Protocol:** `SyllabusParser`  
  - `func parse(text: String) async throws -> [EventItem]`
- **Impls:**  
  - `SyllabusParserRemote`: OpenAI-powered parsing via server endpoint.  
  - `OpenAIParserRemote`: calls server `/parse` with raw/cleaned text → returns normalized JSON.

**Budget strategy:** OpenAI-powered parsing with cost controls and rate limiting. Log token usage per request server-side.

### 5.3 Calendar Service
- **Protocol:** `CalendarService`  
  - `create(events:)`, `update(events:)`, `delete(ids:)`  
- **Impl:** `EventKitCalendarService` w/ permission handling & calendar selection (create an “🗓️ Syllabus Sync” calendar).

### 5.4 Notification Service
- **Protocol:** `NotificationService`  
  - Schedules local notifications (UNUserNotificationCenter).  
- **Impl:** `UserNotificationService` with weekly reminders + exam countdown.

### 5.5 Auth Service
- **MVP:** `AuthServiceMock` (immediate success).  
- **Later:** Apple Sign‑In + email/password via server (JWT). Tokens in Keychain.

### 5.6 Storage Service
- **MVP:** Mock.  
- **Later:** S3-compatible (Cloudflare R2) or Firebase Storage; presigned upload URLs to avoid storing secrets in the app.

### 5.7 API Client
- **Protocol:** `APIClient` → `URLSessionAPIClient` with request builders, Codable decoders, retry/backoff, network logging (debug only).

---

## 6) Backend (Pragmatic, Low‑Cost, Secure)

**Goal:** Keep it tiny, cheap, secure, and easy to maintain.

**Option A (Recommended): Cloudflare Workers (or Vercel Functions) + Cloudflare R2/S3**
- **Endpoints**
  - `POST /parse`  
    - Body: `{ text: string, locale?: string }` **or** `{ fileUrl: string }` after upload.  
    - Server cleans text and calls **OpenAI** (gpt‑4o‑mini) for parsing.  
    - Returns: `{ events: EventItemDTO[], confidence: number, diagnostics?: {...} }`.
  - `POST /upload` (optional)  
    - Returns presigned URL. Client uploads PDF directly to storage.
  - `POST /auth/*` (optional)  
    - If using email/password flows. For Apple Sign‑In, exchange identity token → server issues JWT.
- **Why**: Server‑side keeps OpenAI API key secret and allows rate limiting, logging, and model swapping without an app update.
- **Storage**: R2/S3 for PDFs (7‑14 day retention).  
- **DB (Optional)**: DynamoDB/Supabase/Postgres if you need persistent courses/events; not required for MVP.

**OpenAI usage (server-side only)**
- Model: **gpt‑4o‑mini** for low cost; fall back to **o3‑mini** for structured JSON if needed.  
- Prompting: Provide cleaned syllabus text + schema (JSON) + examples. Use `response_format: { type: "json_schema", schema: ... }` when available for strictness.  
- Safety: Truncate input length, strip images unless OCR needed.

**Security**
- Never embed the OpenAI key in the app.  
- Use **secrets manager** (Cloudflare/Vercel env vars) for API keys.  
- Rate limit per user/IP.  
- Validate inputs; reject enormous PDFs; strip binary content.  
- Signed URLs with short TTL for uploads.  
- Return only structured data; never echo back raw PDFs.

---

### 6a) iCloud / CloudKit Persistence & Lightweight Auth (MVP+)

**Goal:** Ensure user data (courses, parsed events, prefs) survives delete/reinstall with $0 infra and no custom DB. Use the user’s **iCloud Private Database**.

**Approach (recommended): Core Data + NSPersistentCloudKitContainer**
- Use Core Data locally for speed + offline.
- Mirror to CloudKit automatically for backup/sync.

**Entities (mirror your Domain models):**
- `Course`: id (UUID string), code, title, instructor?, colorHex
- `EventItem`: id, courseId (string ref), type, title, start, end?, allDay?, notes?, reminderMinutes?, confidence?
- `UserPrefs`: id (singleton), theme, hapticsOn, lastCalendarId?, lastImportHashByCourse (JSON)

**What goes to CloudKit:** Only **metadata** above. **Do NOT** store PDFs or raw syllabus text.

**Minimal setup (pseudocode):**
```swift
// Persistence/CoreDataStack.swift
let container = NSPersistentCloudKitContainer(name: "SyllabusSync")
let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.your.bundle")
container.persistentStoreDescriptions.first?.cloudKitContainerOptions = options
container.loadPersistentStores { _, error in
    if let error = error { fatalError("Core Data load error: \(error)") }
}

Sync pattern:
	1.	On launch → fetch Core Data (which syncs with iCloud in background).
	2.	After parse/preview approve → write Course, EventItem[], UserPrefs.
	3.	On re-import → use stored lastImportHashByCourse to detect changes (client diff).

Auth stance (MVP):
	•	Rely on Apple ID implicitly via iCloud for CloudKit.
	•	Keep app “force login” UX, but client remains anonymous UUID for server rate-limiting.
	•	Optional later: Sign in with Apple → app sends identity token to server → server issues short-lived JWT for API calls.

Security & Privacy:
	•	iCloud Private DB is per-user. No cross-user access.
	•	Provide “Delete my Cloud Data” action: delete all CK-backed Core Data records.
	•	Continue to keep OpenAI/API keys server-side only. CloudKit stores no secrets.

---

## 7) Data Models (Shared DTO)

```ts
// Server/Client DTO shape (KebabCase or CamelCase; be consistent)
EventItemDTO {
  id: string
  courseId: string
  courseCode?: string
  type: "ASSIGNMENT" | "QUIZ" | "MIDTERM" | "FINAL" | "LAB" | "LECTURE" | "OTHER"
  title: string
  start: string        // ISO8601
  end?: string         // ISO8601
  allDay?: boolean
  location?: string
  notes?: string
  reminderMinutes?: number   // e.g., 1440 for 1 day
  confidence?: number        // 0..1 from parser
}
```

On device, store as `EventItem` (Swift struct) with the same fields. Use mappers for conversions.

---

## 8) Permissions & Integrations (iOS)

- **Calendar**: `EventKit` (request once; allow user to choose target calendar).  
- **Notifications**: Ask for permission after value is demonstrated (post‑import).  
- **Files**: `UIDocumentPickerViewController` or SwiftUI’s `.fileImporter`.  
- **Haptics**: `UINotificationFeedbackGenerator`, `UIImpactFeedbackGenerator` via wrapper.

---

## 9) Security, Privacy & Compliance

- **Secrets**: No API keys in client. All third‑party keys live server-side.  
- **Storage**: PDFs kept only as long as needed; allow user to delete; default short retention.  
- **Encryption**: TLS in transit; at rest via provider (R2/S3).  
- **PII**: Minimize; store only necessary identifiers.  
- **Keychain**: Store JWT/session tokens only; never store PDFs.  
- **Scopes/Permissions**: Request least privilege (Calendar write only when syncing).  
- **Logging**: Server logs exclude raw syllabus content; store counts/metrics, not content.  
- **Telemetry**: Opt‑in analytics; aggregate only (feature usage), no content.  
- **App Transport Security (ATS)**: Enforce HTTPS only.  
- **Crash Reporting**: Redact PII.  
- **Data Export/Deletion**: Simple endpoint/UI for account deletion (post‑MVP).

---

## 10) Cost & Token Strategy

- **OpenAI-powered parsing** provides high accuracy for complex syllabi.  
- **Batching**: Combine multiple short sections into one LLM call where feasible.  
- **Cheap models**: Use `gpt‑4o‑mini` with JSON mode.  
- **Caching**: Hash syllabus text; cache parse results server-side for re‑imports.  
- **Budget alerting**: Daily usage cap + alert; circuit-breaker to prevent overuse.

---

## 11) Error Handling & Resilience

- **Client**: Friendly errors + retry; show diagnostics panel in Preview when something is ambiguous.  
- **Server**: Timeouts (15–20s), exponential backoff on OpenAI, idempotent parse requests (content hash).  
- **Diff UX**: On re‑import, show “added/changed/removed” events with clear badges.

---

## 12) Build Configs & Environments

- **Configs**: `Config.debug.json`, `Config.release.json` loaded at launch.  
  - API base URL, feature flags (e.g., `useOpenAIParser: Bool`).  
- **Schemes**: Debug/Release with different signing + endpoints.  
- **Feature Flags**: Toggle server parsing, shimmer durations, etc.

---

## 13) Testing Strategy (pragmatic)

- **Unit**: OpenAI parser unit tests (server repo).  
- **Snapshot**: Light/dark snapshots for key screens.  
- **Contract**: JSON schema tests for `/parse` responses.  
- **Manual QA**: Scripted demo: Onboarding → Auth → Dashboard → Import (mock) → Preview → Calendar → Settings.

---

## 14) Roadmap (Post‑MVP)

1. Replace mock Import with real upload + `/parse` flow.  
2. Calendar selection + per‑course color coding.  
3. Diff view for re‑import updates.  
4. Team/club plans (shared calendar export links).  
5. LMS connectors (optional): read‑only ICS import first.  
6. Paywall with StoreKit 2, receipt validation (server).

---

## 15) Sequence Diagram (Parsing)

```
App(ImportView)  -> StorageService: upload PDF (presigned URL)
App              -> Server /parse: { fileUrl | text }
Server           -> OpenAI: parse()
OpenAI           -> Server: result + confidence
Server (if low)  -> OpenAI: prompt(text) -> JSON events
OpenAI           -> Server: events JSON
Server           -> App: events + diagnostics
App(Preview)     -> User: approve changes
App              -> EventKit: create/update events
```

---

## 16) Notes for Cursor/LLM

- Keep public types small and well‑commented.  
- Favor protocol‑first services; inject mocks in previews/tests.  
- Centralize animation durations and easing in `AnimationTokens`.  
- Never reference server secrets in client code.  
- Treat all networking as optional (graceful degradation).

---

**This architecture enables a delightful, low‑cost, and secure path:** ship the front‑end first, then add a tiny server that safely uses OpenAI to “unlock” robust parsing without exposing keys or overspending.
