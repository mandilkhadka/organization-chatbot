# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
bin/dev                          # Start Rails server + Sidekiq worker (uses Procfile.dev)
rails test                       # Run full test suite (Minitest, parallel)
rails test test/models/user_test.rb          # Run a single test file
rails test test/models/user_test.rb:42       # Run a single test by line number
rails test:system                # System tests (requires Chrome/Selenium)
rubocop                          # Lint
brakeman                         # Security scan
rails db:migrate                 # Run pending migrations
rails console                    # Interactive console
```

## Architecture

### Dual Authentication System

**Employee auth** uses standard Devise (routes at `/users/sign_in`, `/users/sign_up`). Public registration is gated by `ALLOW_PUBLIC_REGISTRATION=true` env var (see `Users::RegistrationsController`). When disabled, only admins can create employee accounts via the admin panel.

**Admin auth** is a completely separate custom session system (NOT Devise). Routes: `/admin/login`, `/admin/logout`. Controller: `Admin::SessionsController`. Features constant-time password comparison, separate 30-minute session timeout tracked via `admin_session_expires_at` column on User, and sliding session refresh. All admin controllers inherit from `Admin::BaseController` which enforces `require_admin` and session timeout checks.

### RAG Pipeline

Documents flow through: Upload → `DocumentProcessorJob` (parse + chunk) → `EmbeddingJob` (per chunk) → ready.

Five services in `app/services/`:

- `DocumentParserService` - extracts text from PDF/DOCX/TXT
- `TextChunkerService` - 512-char chunks with 50-char overlap, sentence-aware splitting
- `EmbeddingService` - calls Gemini API via ruby_llm (`gemini-embedding-exp-03-07`)
- `VectorSearchService` - pgvector cosine similarity with Ruby fallback when extension unavailable
- `RagService` - orchestrates vector search + Gemini LLM generation (`gemini-2.0-flash`) with streaming

### pgvector Graceful Degradation

`DocumentChunk` conditionally configures `has_neighbors :embedding` based on whether the pgvector extension exists. `VectorSearchService` switches between SQL-level cosine similarity and a pure-Ruby fallback. Migrations conditionally create `:vector` or `:text` columns.

### Streaming Responses

`GenerateResponseJob` streams LLM output via Turbo Streams with 100ms throttled broadcasts. Messages use `Turbo::StreamsChannel.broadcast_replace_to("conversation_#{id}", ...)`.

### Key Security Patterns

- `Auditable` concern auto-logs CRUD operations with IP/user-agent to `admin_audit_logs`
- `AdminAuditLog` uses `ALLOWED_RESOURCE_TYPES` whitelist to prevent unsafe `constantize`
- Last-admin protection: `User#last_admin?` prevents deletion/role change of final admin
- RagService sanitizes user input (2000 char limit, control char removal, prompt injection instructions)
- Rack::Attack rate limiting on login, uploads, and bulk uploads with Fail2ban

### Environment Variables

Key env vars with defaults: `GEMINI_API_KEY`, `CHAT_MODEL` (gemini-2.0-flash), `EMBEDDING_MODEL` (gemini-embedding-exp-03-07), `ADMIN_SESSION_TIMEOUT_MINUTES` (30), `ALLOW_PUBLIC_REGISTRATION` (false), `DATABASE_URL` (production).

### Frontend

Importmap-rails (no webpack/esbuild). Bootstrap 5.3. Stimulus controllers in `app/javascript/controllers/`. CSP uses nonces — scripts/styles must use `nonce: true` in views. Whitelisted CDNs: cdnjs.cloudflare.com, fonts.googleapis.com, cdn.jsdelivr.net.

### Test Setup

Minitest with fixtures. Parallel execution. Devise test helpers included. All fixture passwords are "password123". Fixture users: `employee@example.com` (employee), `admin@example.com` (admin), `lastadmin@example.com` (admin).
