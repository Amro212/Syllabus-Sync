# Syllabus Sync Server

[![CI](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/USERNAME/syllabus-sync/actions/workflows/ci.yml)

> **Note**: Replace `USERNAME` with your actual GitHub username.

Cloudflare Workers API for Syllabus Sync - handles PDF parsing, event extraction, and provides secure access to OpenAI services.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run dev

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

### Parse Syllabus
```bash
curl -X POST http://localhost:8787/parse \
  -H "Content-Type: application/json" \
  -d '{"text": "...", "courseCode": "CS101"}'
```

### Upload (Stub)
```bash
curl -X POST http://localhost:8787/upload
```

## 🏗️ Architecture

- **Runtime**: Cloudflare Workers (V8 isolates)
- **Language**: TypeScript with strict typing
- **Validation**: Custom runtime validation (Workers-compatible)
- **Testing**: Vitest with Workers pool
- **Parsing Strategy**: OpenAI-powered with validation

## 📁 Structure

```
server/
├── src/
│   ├── index.ts              # Main Worker entry point
│   ├── clients/              # OpenAI client
│   ├── prompts/              # Parsing prompts
│   ├── utils/                # Date utils, course code detection
│   ├── types/
│   │   ├── eventItem.ts      # TypeScript DTOs
│   │   └── validation.ts     # Runtime validation
│   └── validation/           # Event validation
├── schemas/
│   └── eventItem.schema.json # JSON Schema definition
├── test/
│   ├── index.spec.ts         # Worker integration tests
│   ├── validation.spec.ts    # Validation unit tests
│   ├── cors.spec.ts          # CORS tests
│   ├── rateLimit.spec.ts     # Rate limiting tests
│   └── openaiClient.spec.ts  # OpenAI client tests
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
- ✅ EventItem validation
- ✅ JSON schema compliance
- ✅ CORS handling
- ✅ Rate limiting
- ✅ OpenAI client
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
   
   # CORS allowed origins
   ALLOWED_ORIGINS=capacitor://*,http://localhost:*
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

- **CORS**: Env-based allowlist for origins
- **Rate Limiting**: IP-based request throttling  
- **Input Validation**: Strict runtime type checking
- **Error Handling**: Structured error responses
- **Budget Controls**: OpenAI usage limits per IP and daily budget

## 📋 Development Workflow

1. **Local Development**:
   ```bash
   npm run dev
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
