# PRD — Organization Chatbot Remediation & Hardening

**Repo:** `organization-chatbot`
**Branch:** `feature/rag-chatbot` (1 commit ahead of origin, large unstaged WIP)
**Stack:** Rails 7.1.6, Ruby 3.3.5, PostgreSQL + pgvector, Sidekiq, Devise, Hotwire, ruby_llm (Gemini), neighbor.
**Audit date:** 2026-05-17
**Test baseline:** 101 tests, 222 assertions, 0 failures, 0 errors, 0 skips.
**Static analysis:** Brakeman = 2 warnings. Rubocop = 25 offenses (24 autocorrectable).

---

## 1. Executive Summary

The app implements a dual-auth RAG chatbot (Devise employee auth + a custom admin auth) over a Rails 7 stack. The core flows work and the test suite is green. However the repo is in an inconsistent, partially-shipped state:

- A pile of un-pushed local commits and a large block of uncommitted edits (37 files, +409 / -1647) mix security fixes, refactors, and dev artifact cleanup. None of it is on origin.
- Several real defects remain (mass-assignable `role`, first-user auto-promote, pgvector schema drift, EOL Rails, no CI, ~0% service test coverage).
- "Documentation" is sprawling and conflicting: `SPEC.md`, `ADMIN-LOGIN-SPEC.md`, `AUDIT-REPORT.md`, `SECURITY-FIXES.md`, `README.md`, `CLAUDE.md`, and now this PRD.

This PRD is the single source of truth for what is broken, what is missing, and what to do next.

---

## 2. Repo State (Right Now)

### 2.1 Git
- Branch `feature/rag-chatbot` is **1 commit ahead** of `origin/feature/rag-chatbot` (un-pushed).
- **Staged deletions:** `.claude/command-history.log`, `.mcp.json` (correct, dev-only artifacts).
- **Unstaged modifications:** 35 files including `User`, `Document`, `DocumentChunk`, `VectorSearchService`, jobs, all admin views/auth, CSP, Devise initializer, Rack::Attack, schema, seeds.
- **Untracked but important:** `db/migrate/20260211122906_create_active_storage_tables.active_storage.rb`, `lib/tasks/admin.rake`, `.env.example`, `CLAUDE.md`, `AUDIT-REPORT.md`.
- **Working tree contains real fixes that have never been committed** (CSP nonce regeneration, Devise pepper + paranoid + timeout + secure remember cookies, additional rack_attack throttles, file size validation, locking in jobs, XSS hardening in `bulk_upload_controller.js`, sensitive-field filtering in `Auditable`).

### 2.2 Test / Lint / Security baseline
| Tool | Result |
| --- | --- |
| `rails test` | 101 / 0 failures / 0 errors |
| `brakeman` | 2 warnings (1 EOL, 1 Mass Assignment) |
| `rubocop` | 25 offenses (24 autocorrectable) |
| Coverage tool | **None installed** — coverage figure in AUDIT-REPORT (~30-35%) is a hand-estimate |

### 2.3 Files that exist but shouldn't be authoritative
Three documents claim to describe the system and disagree on details (e.g. employee login URL, registration policy, password length, embedding model):
- `SPEC.md` (27KB, original feature spec)
- `ADMIN-LOGIN-SPEC.md` (19KB, admin login feature spec)
- `AUDIT-REPORT.md` (10KB, Feb-11 audit)
- `SECURITY-FIXES.md` (3KB)
- `CLAUDE.md` (4KB, agent guidance, currently the most accurate)
- `README.md` (6KB)

---

## 3. Issues Found

Severity: **P0** = blocks shipping, **P1** = ship-stopper for production, **P2** = hardening, **P3** = polish.

### P0 — Must fix before merge

| # | Issue | Location | Evidence |
| - | --- | --- | --- |
| P0-1 | **WIP not committed.** 35 modified files contain security-critical changes (CSP nonce, Devise pepper, timeout, paranoid, secure cookies, file-size validation, job row-locking, XSS hardening). One git crash or `reset --hard` loses all of it. | working tree | `git diff --stat HEAD` shows +409/-1647 |
| P0-2 | **Active Storage migration untracked.** Schema includes the tables but the migration file isn't in git — a fresh clone + `db:migrate` will produce a divergent schema. | `db/migrate/20260211122906_create_active_storage_tables.active_storage.rb` | `git status` Untracked |
| P0-3 | **Mass assignment of `:role`.** `Admin::UsersController#user_params` permits `:role`. An admin can demote/promote any user including themselves through the standard create/update form — `User#cannot_remove_last_admin` covers demotion of the last admin, but **nothing prevents an admin from promoting an arbitrary user** via the `new` endpoint with `role=admin`. Brakeman flagged this. Acceptable only if intentional. | `app/controllers/admin/users_controller.rb:87` | Brakeman: Mass Assignment Medium |
| P0-4 | **First-user auto-promote bypass.** `Users::RegistrationsController#after_sign_up_path_for` promotes the registrant to admin when `User.count == 1`. Combined with `check_registration_allowed` which **explicitly allows registration when `User.none?`**, anyone who reaches the deployed app before a seed admin exists becomes the admin. There is no setup token, no first-boot lock. | `app/controllers/users/registrations_controller.rb:14-29` | Code path |
| P0-5 | **pgvector schema drift.** `db/schema.rb` records `t.text "embedding"` while the migration tries to create a `vector(768)` column when the extension is present (`db/migrate/20260201083544_create_document_chunks.rb`). The IVFFLAT index from the migration is also missing from the schema dump. Whichever side is wrong, production and dev are guaranteed to diverge. | `db/schema.rb:87`, migration L13-19 | Direct read |
| P0-6 | **Rails 7.1.6 is end-of-life** (support ended 2025-10-01). No more security patches. | `Gemfile`, `Gemfile.lock` | Brakeman EOLRails High |

### P1 — Production blockers

| # | Issue | Location | Notes |
| - | --- | --- | --- |
| P1-1 | **No CI.** No `.github/workflows`, no GitLab CI, nothing. Tests / brakeman / rubocop run only locally. | repo root | `ls .github` → not present |
| P1-2 | **Sidekiq has no Redis configured for prod.** `REDIS_URL` is commented out in `.env.example`. `config/sidekiq.yml` and a `cable.yml` Redis configuration are unverified. | `.env.example:58` | Missing infra |
| P1-3 | **Service-layer coverage ≈ 0%.** No tests for `RagService`, `VectorSearchService`, `EmbeddingService`, `TextChunkerService`, `DocumentParserService`. These are the hot path. | `test/services/` | Directory does not exist |
| P1-4 | **Audit log silently swallows errors in production.** `AdminAuditLog.log_action` rescues `ActiveRecord::RecordInvalid` and only re-raises in dev/test. A misconfigured audit row in prod is logged-and-forgotten. | `app/models/admin_audit_log.rb:39-46` | Direct read |
| P1-5 | **Embedding model is experimental.** `gemini-embedding-exp-03-07` is the experimental Gemini embedding model. `.env.example` references `gemini-embedding-001`. These are different — and the experimental model may be deprecated without notice. | `app/services/embedding_service.rb:2`, `.env.example:67` | Conflict |
| P1-6 | **DocumentParserService loads entire file into memory.** PDFs and DOCX are downloaded and parsed in-process with no upper bound. 10MB upload limit applies to upload but not to expansion (a 10MB PDF can yield many MB of extracted text). | `app/services/document_parser_service.rb` | Code review |
| P1-7 | **Ruby fallback vector search is unbounded.** `search_with_ruby` does `DocumentChunk.with_embeddings.includes(:document).to_a` — every chunk into memory on every query. | `app/services/vector_search_service.rb:47` | Code review |
| P1-8 | **`acceptable_file_type` trusts client-supplied `content_type`.** A renamed `.exe` with `application/pdf` Content-Type passes. Need magic-byte sniff (e.g., `marcel`). | `app/models/document.rb:26-32` | Code review |
| P1-9 | **CSP `connect_src :self, :https`** allows any HTTPS endpoint for `fetch`/`XHR`. Should be a small explicit allow-list. | `config/initializers/content_security_policy.rb:16` | Code review |
| P1-10 | **`after_initialize :ensure_neighbors_configured`** runs on every new `DocumentChunk` record (only `if: :new_record?`, but still adds boot-time cost). The same `configure_neighbors!` is called from `VectorSearchService` already; the after_initialize hook is redundant. | `app/models/document_chunk.rb:32` | Code review |

### P2 — Hardening / scale / DX

| # | Issue | Location |
| - | --- | --- |
| P2-1 | No pagination on `Admin::UsersController#index`, `Admin::DocumentsController#index`, `Admin::AuditLogsController`, `ConversationsController#index`. `LEFT JOIN conversations + GROUP BY users.id` on the users index will get heavy. | several |
| P2-2 | `Category.name` uniqueness is case-sensitive in DB (`index_categories_on_name unique`). "Hr" and "HR" are different. | `db/schema.rb:69` |
| P2-3 | `TextChunkerService` doesn't enforce `chunk_size`. A sentence longer than 512 chars produces an oversized chunk; this can blow embedding tokens. | `app/services/text_chunker_service.rb:18-25` |
| P2-4 | `MAX_UPLOAD_SIZE_MB` env var is advertised in `.env.example` but hard-coded to 10MB in `Document#acceptable_file_size` and `Admin::DocumentsController::MAX_FILE_SIZE`. | `app/models/document.rb:37`, `app/controllers/admin/documents_controller.rb:6` |
| P2-5 | `Document.find_by!(id: params[:id])` in `Admin::DocumentsController#destroy` finds globally — admin can delete any document, which may be desired, but there's no scoping by ownership/category permission. (No multi-tenant boundary today, so call it "future risk".) | `app/controllers/admin/documents_controller.rb:38` |
| P2-6 | `bulk_create` doesn't run rack_attack-style per-file rate limiting nor per-batch byte limits beyond MAX_BULK_FILES * 10MB = 200MB potential ingestion in one request. | `app/controllers/admin/documents_controller.rb:48-89` |
| P2-7 | `Auditable` runs on `after_action`, but actions that `render :new, status: :unprocessable_entity` will still trigger audit if `@audited_resource` was set. Currently `audit_resource(@user)` is only called on success — but the convention is fragile. | `app/models/concerns/auditable.rb` |
| P2-8 | `RagService.query` rescues all `StandardError` and returns a generic message — error class and backtrace fragment should be logged with `error_class` and the user message should differ for "no chunks" vs "LLM failure". | `app/services/rag_service.rb:50` |
| P2-9 | `EmbeddingService#generate_batch` issues N synchronous calls — should use Gemini's batch embedding endpoint. | `app/services/embedding_service.rb:12-14` |
| P2-10 | `Rack::Attack` is disabled in test (correct) but no `request_id` correlation is logged on 429/403 responses. | `config/initializers/rack_attack.rb:55-71` |
| P2-11 | `Document` has no `failed!` transition wired to audit / notification. Failed documents are invisible to admin. | `app/models/document.rb`, dashboard |

### P3 — Polish

| # | Issue |
| - | --- |
| P3-1 | 25 Rubocop offenses (`Style/GuardClause`, `Layout/MultilineMethodCallIndentation`, etc.). 24 auto-correctable. |
| P3-2 | `:unprocessable_entity` deprecation warnings from Rack — Rails 7.2+ wants `:unprocessable_content`. Compounded by P0-6. |
| P3-3 | `config/database.yml` last line missing newline. |
| P3-4 | Documentation sprawl: `SPEC.md`, `ADMIN-LOGIN-SPEC.md`, `AUDIT-REPORT.md`, `SECURITY-FIXES.md`, `README.md`, `CLAUDE.md`, and now `PRD.md`. Three of them contradict each other on minor details. |
| P3-5 | `app/controllers/admin/users_controller.rb#toggle_status` is a stub: `# We'll add an active field later`. Route exists, button likely exists in views, no-op behavior. |
| P3-6 | No `simplecov`, `webmock`, or `vcr` — service tests cannot stub Gemini cleanly today. |
| P3-7 | No system / E2E tests despite Capybara + Selenium being installed. |
| P3-8 | `Procfile.dev` runs `bin/rails server` instead of `bin/dev` infra — fine in practice, just unconventional. Sidekiq worker also runs in dev only via Procfile. |

---

## 4. Requirements (Remediation Plan)

### 4.1 Functional requirements
The product itself (RAG chatbot, admin console, document mgmt, audit logging, categories, bulk upload) is **feature-complete** per `SPEC.md` and `ADMIN-LOGIN-SPEC.md`. This PRD does not add product features. It defines the work needed to ship the existing product reliably and securely.

### 4.2 Non-functional requirements
| Area | Target |
| --- | --- |
| Security | Brakeman 0 high-confidence warnings. Rails on a supported release. No mass-assignable `role`. Setup-token-gated bootstrap. Magic-byte file validation. |
| Reliability | Sidekiq + Redis configured in prod. Audit log failures surface to error tracking. pgvector schema canonical across envs. |
| Performance | Vector search bounded (no `to_a` over full table). Bulk upload chunked. List views paginated. |
| Quality | `simplecov` ≥ 70% line coverage on `app/services`, `app/jobs`, `app/models`. CI runs tests + rubocop + brakeman on every PR. |
| Operability | One canonical `README` + this PRD; the other docs archived. `.env.example` is the source of truth for env vars. |

---

## 5. Work Breakdown — In Priority Order

### Phase A — Save the work (today)

**A1. Commit and push the WIP.**
Group the 35 modified files into two or three logical commits:
- *security:* CSP nonce, Devise pepper/timeout/paranoid/secure cookies, file-size validation, job row-locking, XSS hardening in `bulk_upload_controller.js`, Auditable sensitive-field filter, Rack::Attack login throttles, ruby_llm timeout + missing-key warning.
- *infra:* untracked Active Storage migration, schema.rb update, seeds, `.env.example`, `lib/tasks/admin.rake`, `CLAUDE.md`, `AUDIT-REPORT.md`.
- *cleanup:* deletion of `.claude/command-history.log` and `.mcp.json`.

Push the branch.

**A2. Cut a PR** to `master`. CI work in Phase C will run on the PR.

### Phase B — Fix P0 defects

**B1. Lock down mass-assignment of `:role`.**
- Strip `:role` from `user_params`. Add a separate `update_role` action with explicit `before_action :require_admin_promoting_user` and a CSRF-protected form. Audit-log the role change as a distinct audit action.

**B2. Replace the first-user auto-promote with a setup token.**
- Remove `after_sign_up_path_for` promotion and the `User.none?` registration bypass.
- Add a `bin/rails admin:create` task (one already exists in untracked `lib/tasks/admin.rake` — verify it). Document it in README as the only supported way to create the first admin.
- If the unauthenticated first-boot UX is desired, gate it on `ENV["INITIAL_SETUP_TOKEN"]` matching a value in the request.

**B3. Reconcile the pgvector schema.**
- Decide whether prod uses `vector(768)` or `text` and make `db/schema.rb` reflect reality. Recommended: standardize on `vector(768)` everywhere (the gem already supports it; Supabase has the extension per AUDIT-REPORT).
- Drop the `if extension_enabled?` branch from `20260201083544_create_document_chunks.rb` in favor of a hard requirement, OR keep the fallback but emit the index + dim column from `schema.rb` correctly by running `db:schema:dump` against the production schema.
- Add a migration test that asserts `enable_extension "vector"` before creating the column.

**B4. Upgrade Rails to a supported series (7.2.x or 8.0.x).**
- `bundle update rails` to the latest 7.2 patch first; resolve `:unprocessable_entity` → `:unprocessable_content` deprecations along the way.
- Run full test suite; expect minor Devise / Turbo changes.
- Re-run brakeman to confirm EOLRails warning clears.

### Phase C — CI + coverage

**C1. Add `.github/workflows/ci.yml`:**
```yaml
- bundle exec rails db:test:prepare
- bundle exec rails test
- bundle exec rubocop --parallel
- bundle exec brakeman -q --no-pager --no-summary
```
Postgres + pgvector service container with `enable_extension "vector"` pre-installed.

**C2. Add `simplecov` (development+test group).** Fail CI under 65% on `app/`.

**C3. Add `webmock` (test group) and stub all Gemini calls in service tests.**

**C4. Write tests for the untested services / jobs:**
- `RagService` — happy path, empty chunks path, LLM failure path, prompt-injection sanitization.
- `VectorSearchService` — pgvector path, Ruby fallback path, threshold filtering, error path.
- `EmbeddingService` — happy path, retry on RubyLLM error.
- `TextChunkerService` — empty input, oversized sentence, overlap behavior.
- `DocumentParserService` — each of PDF/DOCX/TXT, unsupported type, parse error.
- `EmbeddingJob`, `DocumentProcessorJob` — already partially covered by `GenerateResponseJob`; mirror that pattern.

**C5. Add at least one Capybara system test** for: admin login → upload → list → delete, and employee login → ask question → see streamed answer (with Sidekiq inline + stubbed Gemini).

### Phase D — P1 hardening

**D1.** Verify and configure `REDIS_URL` for Sidekiq in production. Add `config/cable.yml` Redis section. Add a `bin/dev` healthcheck for the worker.

**D2.** Make `AdminAuditLog.log_action` post to an error tracker on failure (Sentry/Honeybadger hook), keep it non-blocking but visible.

**D3.** Pin `EMBEDDING_MODEL` to the GA value (`gemini-embedding-001` or its current GA equivalent), update `.env.example` and `CLAUDE.md` to match.

**D4.** Stream PDF/DOCX parsing or cap extracted-text size (e.g. 2 MB of text per document). Reject documents whose extracted text exceeds the cap with a `failed!` transition and an audit entry.

**D5.** Add per-tenant or per-user upper bound for the Ruby vector-search fallback (e.g. `LIMIT 5000`) and emit a `Rails.logger.warn` when triggered. Long-term plan: require pgvector and remove the fallback.

**D6.** Switch `Document` file-type validation to `marcel` magic-byte sniffing, not the HTTP-supplied `content_type`. Also reject zero-byte uploads.

**D7.** Tighten CSP `connect_src` to `:self` plus the explicit WebSocket origin only. Drop the `:https` wildcard.

**D8.** Remove the redundant `after_initialize :ensure_neighbors_configured` on `DocumentChunk`. Call `configure_neighbors!` once at boot from an initializer guarded by `if ActiveRecord::Base.connection.table_exists?("document_chunks")`.

### Phase E — P2 / P3 polish (when convenient)

- Add Pagy or Kaminari pagination to `Admin::Users`, `Admin::Documents`, `Admin::AuditLogs`, `Conversations#index`.
- Lowercase-unique index on `Category.name`.
- Enforce `chunk_size` hard limit in `TextChunkerService`.
- Surface `MAX_UPLOAD_SIZE_MB` env var by reading it in both `Document` and `Admin::DocumentsController`.
- Auto-correct rubocop (`bundle exec rubocop -A`).
- Add newline at EOF of `config/database.yml`.
- Archive `SPEC.md`, `ADMIN-LOGIN-SPEC.md`, `SECURITY-FIXES.md`, `AUDIT-REPORT.md` under `docs/archive/` and replace `README.md` with a slim doc that points at this PRD for status.
- Either implement `Admin::UsersController#toggle_status` (add `active:boolean` column) or remove the route and view button.

---

## 6. Verification Method

The remediation is "done" when **all of these hold simultaneously**:

- [x] `git status` is clean on `feature/rag-chatbot`; branch pushed to origin. *(local clean — push deferred to user)*
- [ ] PR merged; CI is green on `master`.
- [x] `bundle exec rails test` → 0 failures, **service tests present**. *(123 tests / 283 assertions / 0 failures)*
- [ ] `bundle exec brakeman -q` → 0 High-confidence warnings. *(Mass Assignment cleared; EOLRails remains pending Rails 7.2 upgrade)*
- [x] `bundle exec rubocop` → 0 offenses *(with `rubocop-performance` and `rubocop-minitest` plugins, Metrics cops re-enabled at sensible thresholds)*.
- [ ] `simplecov` ≥ 65% on `app/` (≥ 80% on `app/services`). *(at 47% — biggest gap is controllers and the streaming chat path; factory_bot now available to make request specs writable)*
- [x] `db/schema.rb` shows `vector(768)` for `document_chunks.embedding` and the IVFFLAT index, matching what's actually in production.
- [x] Untracked `db/migrate/...active_storage_tables.rb` is committed.
- [x] First-admin bootstrap is the rake task, not the registration form.
- [x] `:role` is not assignable through the create/update user form; a dedicated role-change action exists and is audit-logged.
- [x] `REDIS_URL` is wired through `config.cache_store`, Sidekiq, and Rack::Attack. **Sidekiq Web** mounted at `/admin/sidekiq` behind a Warden admin constraint. `config/sidekiq.yml` defines weighted queues and a 6-month dead-set window.
- [x] Audit-log creation failures are reported to error tracking (via `Rails.error.report`).
- [x] CSP `connect_src` is an explicit allow-list.
- [x] **Observability**: Sentry (PII-scrubbed via `before_send`) + lograge (JSON, request_id-tagged).
- [x] **Health endpoints**: `/up` & `/health` (liveness), `/health/deep` (Postgres + Redis readiness, optional Gemini probe).
- [x] **DNS rebinding protection**: `config.hosts` driven by `APP_HOST` + `ADDITIONAL_HOSTS`; health paths exempted.
- [x] **SMTP**: Production mailer wired with `SMTP_*` env vars; password reset will no longer silently fail.
- [x] **Mailer branding**: All Devise templates carry a custom layout, branded header, and plaintext siblings.
- [x] **Frontend unification**: Admin login no longer a light-theme outlier; now uses the same dark slate/teal `auth-card` pattern as Devise sessions.
- [x] **Empty states**: `shared/_empty_state.html.erb` partial replaces the one-line `<p>No X yet</p>` placeholders across dashboard, documents, users, categories.
- [x] **Flash component**: Multi-flash support (notice/alert/info/warning/success/error), auto-dismiss with hover-pause via `flash_controller.js`, reduced-motion respected.
- [x] **N+1 fix**: `document_chunks_count` counter cache replaces inline `document_chunks.count` in the documents table.
- [x] **N+1 detection**: Bullet integrated in dev/test (currently warn-only — flip to `raise` once existing N+1s in dashboard are audited).

---

## 7. Open Questions (resolve before / during Phase B)

1. **Mass-assignable `:role` — is admin-promotion via the user form intentional?** If yes, restrict to admins promoting *others* (not themselves) and emit an explicit audit event. If no, remove `:role` from `user_params` entirely.
2. **First-user bootstrap UX:** is it acceptable to require shell access (`rails admin:create`) before first login, or do we need a one-shot web setup wizard with an environment-provided setup token?
3. **pgvector requirement:** keep the Ruby fallback (so local dev without pgvector works) or hard-require pgvector and standardize dev on the Supabase-style schema?
4. **Rails upgrade target:** 7.2.x (lower-risk) or jump directly to 8.0.x (more durable, more work)?
5. **Documentation:** archive the legacy specs into `docs/archive/` and treat this PRD + `CLAUDE.md` + `README.md` as canonical, or keep them?
6. **`Admin::UsersController#toggle_status`:** ship the `active:boolean` column or remove the half-feature?

---

## 8. Findings Output (Quick Reference Table)

| Severity | Count | Examples |
| --- | --- | --- |
| P0 | 6 | uncommitted WIP, untracked AS migration, mass-assign `role`, first-user auto-promote, pgvector schema drift, Rails EOL |
| P1 | 10 | no CI, no Redis prod config, 0% service tests, audit-log silent fails, experimental embedding model, unbounded parser/search, content-type spoofing, broad CSP, redundant after_initialize |
| P2 | 11 | no pagination, case-sensitive category names, oversized chunks, hard-coded 10MB, no marcel sniff, batch upload limits, audit fragility, RAG error class hidden, no batch embeddings, no rate-limit logging, no failed-doc surfacing |
| P3 | 8 | rubocop offenses, deprecation warnings, EOF newline, docs sprawl, toggle_status stub, no simplecov/webmock/vcr, no system tests, Procfile.dev convention |

Tests: **101 passing**. Brakeman: **2** (1 EOLRails High, 1 Mass Assignment Medium). Rubocop: **25** (24 autocorrectable).

---

*This PRD supersedes ad-hoc notes in `AUDIT-REPORT.md` and `SECURITY-FIXES.md`. Update this file as items are closed; do not start a new audit document.*

---

## 9. Changelog

### 2026-05-18 — Production hardening + frontend polish

**Infrastructure**

- Added `sentry-ruby` / `sentry-rails` / `sentry-sidekiq` with a PII-scrubbing `before_send` hook (`config/initializers/sentry.rb`). DSN-gated — silent unless `SENTRY_DSN` set.
- Added `lograge` (`config/initializers/lograge.rb`) emitting one JSON log line per request with `request_id`, `user_id`, sanitized params, exception class/message.
- Added `redis` gem and configured `config.cache_store = :redis_cache_store` in production with timeouts, retry, and a Sentry-hooked error handler. **Closes the prior silent-throttle bug where Rack::Attack inherited NullStore.**
- Added `config/sidekiq.yml` (weighted queues — `embeddings:4, documents:3, responses:3, default:2, mailers:1`; 6-month dead-set retention) and `config/initializers/sidekiq.rb` (REDIS_URL-driven pool sizing, dead-job logging).
- Mounted `Sidekiq::Web` at `/admin/sidekiq` behind a Warden route-level constraint that requires `admin? && !admin_session_expired?`.
- Set `config.active_job.queue_adapter = :sidekiq` in production.
- Configured SMTP (`SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_DOMAIN`, `MAILER_SENDER`) and ActionMailer delivery method.
- Set `config.hosts` from `APP_HOST` + `ADDITIONAL_HOSTS` for DNS rebinding protection; health endpoints exempted.
- New `HealthController` with `/up` & `/health` (liveness) and `/health/deep` (Postgres + Redis readiness; optional Gemini auth probe via `HEALTH_CHECK_GEMINI=true`). Inherits from `ActionController::Base` to skip Devise/CSRF.

**Code quality**

- Re-enabled Metrics rubocop cops (AbcSize, MethodLength, ClassLength, CyclomaticComplexity, PerceivedComplexity, BlockLength, LineLength) at realistic thresholds. Added `rubocop-performance` and `rubocop-minitest` plugins.
- Added `bullet` (`config/initializers/bullet.rb`) for N+1 detection in dev/test — currently warn-only.
- Added `factory_bot_rails` and seed factories (`test/factories/{users,categories,documents}.rb`).
- Cleaned up `.env.example`: removed misleading Supabase-only block, added grouped sections with concise per-var comments, added Sentry/SMTP/health knobs.

**Frontend**

- Unified admin login into the dark slate/teal theme (was a white card on indigo gradient — visual outlier). Reuses the `auth-card` / `hero-section auth-section` pattern from Devise sessions. Stripped legacy `.admin-login-*` styles from `_admin.scss`.
- New `shared/_empty_state.html.erb` partial + `components/_empty_state.scss` design (sm/md/lg variants). Replaced bare `<p>No X yet</p>` empty states in admin dashboard, documents, users, and categories with iconography + body copy + contextual CTA.
- Rewrote `shared/_flashes.html.erb` to iterate over the whole flash hash (notice/alert/success/error/info/warning) and added a `flash_controller.js` Stimulus controller that auto-dismisses after 4.5–8 s, pauses on hover, and respects `prefers-reduced-motion`.
- Branded Devise mailer templates (`confirmation_instructions`, `reset_password_instructions`, `unlock_instructions`, `email_changed`, `password_change`) with a new table-based, inline-styled `layouts/mailer.html.erb` + plaintext siblings.
- Added counter cache `document_chunks_count` (migration + `belongs_to :document, counter_cache: true`) and replaced `document.document_chunks.count` in the documents table view — kills an O(N+1) query per page render.

**Outstanding (not in this changeset)**

- Rails 7.2 / 8.0 upgrade (Brakeman EOLRails).
- System tests for the streaming chat path; coverage push to ≥ 65%.
- Pick a deploy target (Kamal / Fly.io / Render) and check in the config.
- i18n externalization (`Rails/I18nLocaleTexts` currently disabled).
- 2FA for admin (`devise-two-factor`).
