# Syllabus Sync

[![CI](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml)

> **Note**: Replace `USERNAME` with your actual GitHub username once you create the repository.

**Syllabus Sync** lets students import course syllabi (PDFs), extract key dates, preview a clean timeline/calendar, and one‑tap sync to Apple Calendar with reminders. The app favors **delightful motion, microinteractions, and clarity** over heavy configuration.

## 🏗️ Architecture

This is a **hybrid iOS + serverless backend** project with:

- **iOS App**: SwiftUI (iOS 17+) with MVVM pattern
- **Server**: Cloudflare Workers with TypeScript  
- **Parsing**: Heuristics-first + OpenAI fallback (server-side only)
- **Calendar**: EventKit integration for Apple Calendar sync

## 📁 Project Structure

```
Syllabus Sync/
├── Syllabus Sync/          # iOS app (Xcode project)
├── server/                 # Cloudflare Workers API
├── .github/workflows/      # CI/CD pipelines
├── architecture.md         # Detailed technical architecture
└── tasks.md               # Development roadmap
```

## 🚀 Quick Start

### iOS App
```bash
# Open in Xcode
open "Syllabus Sync.xcodeproj"

# Or build from command line
cd "Syllabus Sync"
xcodebuild -project "Syllabus Sync.xcodeproj" -scheme "Syllabus Sync" build
```

### Server
```bash
cd server
npm install
npm run start    # Local development
npm test        # Run validation tests
```

## 🧪 Development Status

- ✅ **Task 0.2**: iOS project init  
- ✅ **Task 0.3**: Server project init (Cloudflare Workers + TypeScript)
- ✅ **Task 0.4**: Shared DTO + JSON Schema with validation tests
- 🚧 **Task 0.5**: CI basics (GitHub Actions)
- ⏳ **Task 0.6**: Secrets & env files

See [tasks.md](./tasks.md) for detailed milestone tracking.

## 📊 Current Endpoints

### Server API
- `GET /health` - Health check (returns `{"ok": true}`)

## 🛡️ Security & Privacy

- **No API keys in client** - All sensitive operations server-side only
- **OpenAI usage**: Server-side only as fallback after heuristics
- **Budget controls**: Rate limiting and cost guardrails
- **Data minimization**: PDFs auto-deleted, minimal PII storage

## 📄 License

MIT License - see LICENSE file for details.

---

**Status**: Early MVP development - not ready for production use.
