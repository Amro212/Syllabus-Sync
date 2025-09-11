<<<<<<< HEAD
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

## 📄 License

MIT License - see LICENSE file for details.

---

**Status**: Early MVP development - not ready for production use.
=======
# Syllabus Sync Server

[![CI](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml)

> **Note**: Replace `USERNAME` with your actual GitHub username.

Cloudflare Workers API for Syllabus Sync - handles PDF parsing, event extraction, and provides secure access to OpenAI services.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run start

# Run tests
npm test

# Deploy to Cloudflare
npm run deploy
```

## 📊 API Endpoints

### Health Check
```bash
curl http://localhost:8787/health
# Returns: {"ok": true, "timestamp": "2025-09-06T..."}
```

### Coming Soon
- `POST /parse` - Parse syllabus text → structured events
- `POST /upload` - Upload PDFs (optional)

## 🏗️ Architecture

- **Runtime**: Cloudflare Workers (V8 isolates)
- **Language**: TypeScript with strict typing
- **Validation**: Custom runtime validation (Workers-compatible)
- **Testing**: Vitest with Workers pool
- **Parsing Strategy**: Heuristics-first → OpenAI fallback

## 📁 Structure

```
server/
├── src/
│   ├── index.ts              # Main Worker entry point
│   └── types/
│       ├── eventItem.ts      # TypeScript DTOs
│       └── validation.ts     # Runtime validation
├── schemas/
│   └── eventItem.schema.json # JSON Schema definition
├── test/
│   ├── index.spec.ts         # Worker integration tests
│   └── validation.spec.ts    # Validation unit tests
├── wrangler.jsonc            # Cloudflare Workers config
└── package.json
```

## 🧪 Testing

The server includes comprehensive test coverage:

```bash
npm test              # Run all tests
npm test -- --watch   # Watch mode for development
```

**Test Coverage**:
- ✅ Health endpoint integration
- ✅ EventItem validation (19 test cases)
- ✅ JSON schema compliance
- ✅ Error handling and edge cases

## 🔧 Configuration

### Environment Variables Setup

1. **Copy example environment file:**
   ```bash
   cp .dev.vars.example .dev.vars
   ```

2. **Fill in your secrets in `.dev.vars`:**
   ```bash
   # Required for OpenAI parsing
   OPENAI_API_KEY=sk-your-actual-openai-api-key
   
   # Optional: customize rate limits
   RATE_LIMIT_REQUESTS=100
   RATE_LIMIT_OPENAI=10
   OPENAI_DAILY_BUDGET=10.00
   ```

3. **For production deployment, use Wrangler secrets:**
   ```bash
   # Set production secrets (never commit these!)
   wrangler secret put OPENAI_API_KEY
   wrangler secret put RATE_LIMIT_REQUESTS
   wrangler secret put RATE_LIMIT_OPENAI
   ```

### Security Notes
- ⚠️ **Never commit `.dev.vars`** - it contains your API keys
- ✅ The `.dev.vars.example` file is safe to commit (no real secrets)  
- ✅ Use `wrangler secret put` for production secrets
- ✅ All secrets are server-side only (never exposed to client)

### Wrangler Configuration
See `wrangler.jsonc` for Workers-specific settings:
- Compatibility date
- Environment variables
- Custom domains (when deployed)

## 🛡️ Security Features

- **CORS**: Configured for iOS app origin
- **Rate Limiting**: IP-based request throttling  
- **Input Validation**: Strict runtime type checking
- **Error Handling**: Structured error responses
- **Budget Controls**: OpenAI usage limits

## 📋 Development Workflow

1. **Local Development**:
   ```bash
   npm run start
   curl http://localhost:8787/health
   ```

2. **Testing**:
   ```bash
   npm test
   ```

3. **Type Checking**:
   ```bash
   npx tsc --noEmit
   ```

4. **Deploy**:
   ```bash
   npm run deploy
   ```

## 🚦 CI/CD

GitHub Actions automatically:
- ✅ Type checking with TypeScript
- ✅ Run full test suite  
- ✅ Validate Wrangler configuration
- ✅ Dry-run deployment

## 📈 Performance

- **Cold Start**: ~10ms (V8 isolates)
- **Memory**: <128MB typical usage
- **Latency**: <50ms response time (health check)
- **Throughput**: 1000+ req/sec supported

## 🔗 Related

- [Main Project README](../README.md)
- [Architecture Overview](../architecture.md)  
- [Development Tasks](../tasks.md)
>>>>>>> 9702465 (Milestone 4 and 5 Complete with tests passing)
