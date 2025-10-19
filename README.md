# Syllabus Sync

[![CI](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml)

> **Note**: Replace `USERNAME` with your actual GitHub username once you create the repository.

**Syllabus Sync** lets students import course syllabi (PDFs), extract key dates, preview a clean timeline/calendar, and one‑tap sync to Apple Calendar with reminders. The app favors **delightful motion, microinteractions, and clarity** over heavy configuration.

## 🏗️ Architecture

This is a **hybrid iOS + serverless backend** project with:

- **iOS App**: SwiftUI (iOS 17+) with MVVM pattern
- **Server**: Cloudflare Workers with TypeScript  
- **Parsing**: OpenAI-powered parsing (server-side only)
- **Persistence**: Core Data + CloudKit for iCloud sync
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

- ✅ **Milestone 0**: Project setup & configuration
- ✅ **Milestone 1-3**: iOS Design System & Screens (mock-first)
- ✅ **Milestone 4-5**: Server scaffold & OpenAI parser
- ✅ **Milestone 8**: Real Import Flow (Client ↔ Server)
- ✅ **Milestone 9**: Full Event Editing UX
- ✅ **Milestone 9.5**: Core Data + CloudKit Backup/Sync
- ⏳ **Milestone 10**: Calendar & Notifications

See [tasks.md](./tasks.md) for detailed milestone tracking.

## 📊 Current Endpoints

### Server API
- `GET /health` - Health check
- `POST /parse` - Parse syllabus text → structured events (OpenAI-powered)

## ☁️ Cloud Backup & Sync

### Core Data + CloudKit Integration

**Syllabus Sync** uses **Core Data** backed by **CloudKit** to automatically backup and sync your data across devices.

#### What's Stored in iCloud?

Your app data is stored in **iCloud Private Database** (only you can access it):

- **Courses**: Course codes, titles, instructors, colors
- **Events**: All imported/edited events with dates, titles, types, locations, notes
- **Preferences**: App settings and import history

#### Important Notes

- **PDFs are NOT stored** - Only extracted metadata
- **iCloud account required** - Sign in on your device to enable sync
- **Paid Apple Developer Account** - CloudKit requires a paid membership ($99/year)
- **Simulator mode** - Uses local-only Core Data (no CloudKit sync)

#### How to Delete Your Cloud Data

If you need to wipe all your data:

1. Open **Settings** in the app
2. Scroll to **Data Management**
3. Tap **Delete Cloud Backup**
4. Confirm deletion

This will:
- ✅ Delete all Core Data records (Courses, Events, Preferences)
- ✅ Remove data from iCloud (if CloudKit is enabled)
- ✅ Cannot be undone - make sure you want to proceed!

#### Developer Setup

For CloudKit to work, you need:

1. **Paid Apple Developer Account** ($99/year)
2. **iCloud Capability enabled** in Xcode:
   - Signing & Capabilities → iCloud → CloudKit
   - Container: `iCloud.SylSyn.Syllabus-Sync`
3. **Signed into iCloud** on your test device

**Without paid account:**
- ✅ App works perfectly with local Core Data only
- ❌ CloudKit sync disabled (data doesn't sync between devices)
- ✅ Data persists locally and survives app relaunches

## 🛡️ Security & Privacy

- **No API keys in client** - All sensitive operations server-side only
- **OpenAI usage**: Server-side only for parsing
- **Budget controls**: Rate limiting and cost guardrails
- **Data minimization**: PDFs auto-deleted, minimal PII storage
- **Private database**: CloudKit uses your iCloud Private DB (not shared)

### Secrets Management

**For developers:**
```bash
# 1. Copy example file 
cp server/.dev.vars.example server/.dev.vars

# 2. Add your OpenAI API key to .dev.vars
# Never commit .dev.vars - it's in .gitignore

# 3. For production deployment:
cd server && wrangler secret put OPENAI_API_KEY
```

**Security principles:**
- ✅ All secrets server-side only via Wrangler secrets
- ✅ `.dev.vars` is git-ignored (local development only) 
- ✅ Rate limiting prevents abuse
- ✅ Budget caps prevent runaway costs
- ✅ CloudKit Private DB - only you can access your data

## 📄 License

MIT License - see LICENSE file for details.

---

**Status**: MVP development in progress - functional but not production-ready.
