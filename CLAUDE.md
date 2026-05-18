# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
bin/dev                            # Start Rails server + Sidekiq + livereload (Procfile.dev)
bin/rails test                     # Full Minitest suite (parallel)
bin/rails test test/models/user_test.rb        # Single test file
bin/rails test test/models/user_test.rb:42     # Single test by line number
bin/rails test:system              # Capybara/Selenium system tests
bundle exec rubocop                # Lint (config in .rubocop.yml)
bundle exec rubocop -A             # Auto-correct
bundle exec brakeman -q            # Security scan
bin/rails db:migrate               # Run pending migrations
bin/rails admin:create             # Interactive admin user seeder (lib/tasks/admin.rake)
bin/rails console                  # Interactive console
```

## Architecture

### Dual authentication

**Employee auth** uses standard Devise (routes at `/users/sign_in`, `/users/sign_up`). Public registration is gated by `ALLOW_PUBLIC_REGISTRATION=true` (see `Users::RegistrationsController`). When disabled, only admins can create employee accounts via the admin panel.

**Admin auth** is Devise-backed but uses a separate session-timeout column (`admin_session_expires_at`) and a custom controller (`Admin::SessionsController`) at `/admin/login`. It performs constant-time password comparison, has a 30-minute sliding timeout, generic "invalid credentials" errors (no enumeration), and audit-logged login/logout. Admin controllers inherit from `Admin::BaseController` which enforces `require_admin` and the timeout check.

### RAG pipeline

```
Upload → DocumentProcessorJob (parse + chunk) → EmbeddingJob (per chunk) → status: ready
```

Services in `app/services/`:

- `DocumentParserService` — PDF/DOCX/TXT text extraction; capped at `MAX_EXTRACTED_TEXT_MB`.
- `TextChunkerService` — 512-char chunks with 50-char overlap, sentence-aware splitting.
- `EmbeddingService` — Gemini API via ruby_llm (`gemini-embedding-001` recommended; `gemini-embedding-exp-03-07` default).
- `VectorSearchService` — pgvector cosine similarity with a bounded Ruby fallback (`RUBY_FALLBACK_MAX_CHUNKS`).
- `RagService` — orchestrates vector search + Gemini Flash generation with streaming; sanitizes user input (2000 char cap, control-char strip, prompt-injection-resistant instructions).

### pgvector graceful degradation

`DocumentChunk.configure_neighbors!` lazily configures `has_neighbors :embedding` only when the `vector` extension is present. `VectorSearchService` switches between SQL-level cosine similarity and a Ruby fallback. Migrations conditionally create `:vector` or `:text` columns.

### Streaming responses

`GenerateResponseJob` streams LLM output via Turbo Streams at a 100 ms throttle:
`Turbo::StreamsChannel.broadcast_replace_to("conversation_#{id}", ...)`.

### Security patterns

- `Auditable` concern auto-logs `create/update/destroy/bulk_create` to `admin_audit_logs` with IP, UA, request_id. **Role changes go through `AdminAuditLog.log_action` directly** because `update_role` is not in the auto-logged list.
- `AdminAuditLog::ALLOWED_RESOURCE_TYPES` whitelist prevents unsafe `constantize`.
- `User#last_admin?` prevents deletion or demotion of the final admin.
- `Document#acceptable_file_type` validates against `file.blob.content_type` (Marcel-sniffed by ActiveStorage at unfurl time) — **never** `file.open` during validation (the blob isn't uploaded yet).
- `Rack::Attack` cache store is explicitly configured to `MemoryStore` in dev/test and `Rails.cache` (Redis) in prod. **NullStore would silently disable every throttle** — never let it fall back to the default in any environment.

### Observability & operations

- **Sentry** (`config/initializers/sentry.rb`) — initializes only when `SENTRY_DSN` is set, scrubs PII via `before_send`, samples 5% of traces by default.
- **lograge** (`config/initializers/lograge.rb`) — JSON request logs everywhere except development; includes `request_id`, `user_id`, sanitized params.
- **Sidekiq Web** mounted at `/admin/sidekiq` behind a Warden route-constraint that requires `admin?` and a non-expired admin session.
- **Health endpoints** — `/up` and `/health` are liveness (Rails-booted); `/health/deep` is readiness (pings Postgres + Redis, optionally Gemini via `HEALTH_CHECK_GEMINI=true`).
- **Bullet** (dev/test only) — warns on N+1; `Bullet.raise = false` until existing N+1s are cleaned up.

### Frontend

- Importmap-rails (no Node, no esbuild). Bootstrap 5.3. Stimulus controllers in `app/javascript/controllers/`.
- CSP uses nonces — scripts/styles must use `nonce: true` in views. Whitelisted CDNs: cdnjs.cloudflare.com, fonts.googleapis.com, cdn.jsdelivr.net.
- Custom design system: `app/assets/stylesheets/config/_colors.scss` defines the slate/teal palette; `_fonts.scss` loads Geist + Sora.
- **Shared partials** to use in views:
  - `shared/empty_state` — render whenever a collection is empty. Locals: `icon`, `title`, `body`, `cta: { label:, path:, icon: }`, `size: :sm|:md|:lg`.
  - `shared/flashes` — already rendered by layouts. Multi-flash; auto-dismisses via `flash_controller.js`.
- **Mailer templates** — branded layout at `app/views/layouts/mailer.html.erb` (table-based, inline-styled for email-client compat). All Devise templates have plaintext siblings.

### Test setup

- Minitest with fixtures (parallel via `:number_of_processors`).
- `FactoryBot` available via `factory_bot_rails`; factories in `test/factories/`. Prefer factories for new test scenarios; fixtures remain for the baseline auth + audit-log records.
- All fixture passwords are `password123`. Fixture users: `employee@example.com`, `admin@example.com`, `lastadmin@example.com`.
- WebMock blocks outbound HTTP — stub Gemini API calls explicitly.
- SimpleCov runs with parallel worker namespacing; current coverage hovers near 47%. Aim to climb toward the 65% bar called out in PRD §5.

### Environment variables

See `.env.example` — organized into **Required**, **Production-required**, **Observability**, and **Tuning knobs**. Most have safe defaults; uncomment only to override.

Key required-for-prod variables: `REDIS_URL`, `APP_HOST`, `SMTP_*`, `MAILER_SENDER`, `RAILS_MASTER_KEY`, `DEVISE_PEPPER`, `GEMINI_API_KEY`, `DATABASE_URL`.
