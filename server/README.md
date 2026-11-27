# Syllabus Sync Server

[![CI](https://github.com/Amro212/syllabus-sync/actions/workflows/ci.yml/badge.svg)](https://github.com/Amro212/syllabus-sync/actions/workflows/ci.yml)

Cloudflare Workers API for Syllabus Sync - handles PDF parsing, event extraction, and provides secure access to OpenRouter services.

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
- **Parsing Strategy**: OpenRouter-powered with validation

## 📁 Structure

```
server/
├── src/
│   ├── index.ts              # Main Worker entry point
│   ├── clients/              # OpenRouter client
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
│   └── openrouterClient.spec.ts  # OpenRouter client tests
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
- ✅ OpenRouter client
- ✅ Error handling and edge cases

## 🔧 Configuration

### Environment Variables Setup

1. **Copy example environment file:**
   ```bash
   cp .dev.vars.example .dev.vars
   ```

2. **Fill in your secrets in `.dev.vars`:**
   ```bash
   # Required for OpenRouter parsing
   OPENROUTER_API_KEY=sk-or-v1-your-openrouter-api-key
   
   # Optional: customize rate limits
   RATE_LIMIT_REQUESTS=100
   RATE_LIMIT_OPENROUTER=10
   OPENROUTER_DAILY_BUDGET=10.00
   
   # CORS allowed origins for local development
   ALLOWED_ORIGINS=capacitor://*,http://localhost:*
   ```

3. **For production deployment, use Wrangler secrets:**
   ```bash
   # Set production secrets (never commit these!)
   wrangler secret put OPENROUTER_API_KEY
   wrangler secret put SUPABASE_URL
   wrangler secret put SUPABASE_SERVICE_ROLE_KEY
   wrangler secret put ALLOWED_ORIGINS
   wrangler secret put RATE_LIMIT_REQUESTS
   wrangler secret put RATE_LIMIT_OPENROUTER
   wrangler secret put RATE_LIMIT_SOCIAL
   ```

   Production `ALLOWED_ORIGINS` must contain exact HTTPS origins only, such as
   `https://syllabussync.example`. Wildcards, localhost, and plaintext HTTP make
   the Worker fail closed with `PRODUCTION_CONFIG_INVALID`.

#### Set the OpenRouter key

Create an API key for this Worker in the [OpenRouter workspace](https://openrouter.ai/settings/keys).
In Cloudflare, select the **Bilal (Syllabus Sync)** account and open **Workers & Pages → server → Settings → Variables and Secrets**.
Add `OPENROUTER_API_KEY` with type **Secret**, then deploy. The Worker reads the encrypted secret from its environment.

For local development, set `OPENROUTER_API_KEY` in the ignored `server/.dev.vars` file.
The default model is `deepseek/deepseek-v4.1-flash-1017`. Set `OPENROUTER_MODEL` to override it with a model that supports structured outputs and zero-data-retention routing.
Production scans require an app build that presents the OpenRouter disclosure.

## Security Notes
- ⚠️ **Never commit `.dev.vars`** - it contains your API keys
- ✅ The `.dev.vars.example` file is safe to commit (no real secrets)  
- ✅ Use `wrangler secret put` for production secrets
- ✅ All secrets are server-side only (never exposed to client)
- ✅ Durable Object `ABUSE_LIMITER` backs production parse/OpenRouter/social limits

### Wrangler Configuration
See `wrangler.jsonc` for Workers-specific settings:
- Compatibility date
- Environment variables
- Custom domains (when deployed)
- Durable Object abuse limiter binding and migration

## 🛡️ Security Features

- **CORS**: Env-based allowlist; production allows exact HTTPS origins only
- **Rate Limiting**: Durable Object-backed user/IP request throttling  
- **Input Validation**: Strict runtime type checking
- **Error Handling**: Structured error responses
- **Budget Controls**: Durable OpenRouter per-user caps and daily budget
- **Social Abuse Controls**: Server recommendation throttles plus Supabase social action triggers

## 📋 Development Workflow

1. **Local Development**:
   ```bash
   npm run dev
   curl http://localhost:8787/health
   ```

2. **Testing**:
   ```bash
   npm test -- --run
   ```

3. **Type Checking**:
   ```bash
   npx tsc --noEmit
   ```

4. **Security Release Gate**:
   ```bash
   npm run security:scan
   ```

5. **Deploy**:
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
