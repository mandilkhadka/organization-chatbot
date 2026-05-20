# Admin Login System with Document Management

## Objective

Create a dedicated administrator login system with a separate login page, enhanced security features (session timeout, audit logging), and improved document management capabilities (categories, bulk upload).

## Background

The application currently uses a single Devise login page for all users, with admin access controlled by a role check after authentication. This approach lacks:

- A dedicated admin entry point
- Admin-specific session security
- Audit trail for admin actions
- Advanced document organization

This feature creates a professional admin experience with proper security controls.

## Requirements

### Functional Requirements

1. **Separate Admin Login Page**
   - Dedicated login page at `/admin/login`
   - Distinct admin branding (different color scheme)
   - Admin-specific welcome message
   - Redirect non-admins attempting `/admin/*` to admin login

2. **Session Security**
   - 30-minute session timeout for admin sessions
   - Automatic logout on timeout with message
   - Session tracking for audit purposes

3. **Audit Logging**
   - Log all admin actions (create, update, delete)
   - Track: admin user, action, resource, IP address, timestamp
   - Immutable audit log table

4. **Document Categories**
   - Create/manage document categories
   - Assign documents to categories
   - Filter documents by category
   - Categories have name and optional description

5. **Bulk Document Upload**
   - Upload multiple documents at once
   - Progress indication during upload
   - Handle partial failures gracefully
   - Apply same category to batch

6. **Comprehensive Testing**
   - Admin controller tests (authorization, CRUD)
   - Model tests (validations, associations)
   - System tests (end-to-end flows)
   - Target: 90%+ coverage on admin functionality

### Non-functional Requirements

- **Performance**: Bulk upload should handle 10+ files without timeout
- **Security**: CSRF protection, rate limiting consideration, input validation
- **Scalability**: Categories and audit logs should not degrade query performance
- **Reliability**: Audit logs must persist even if request fails
- **Maintainability**: Follow existing code patterns and conventions

## Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        ADMIN MODULE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌───────────────┐    ┌─────────────────┐  │
│  │ Admin Login  │───▶│ Admin Session │───▶│ Admin Dashboard │  │
│  │ /admin/login │    │ (30min timeout)│    │ /admin          │  │
│  └──────────────┘    └───────────────┘    └─────────────────┘  │
│         │                    │                     │            │
│         │                    ▼                     │            │
│         │            ┌───────────────┐             │            │
│         │            │  Audit Logger │◀────────────┤            │
│         │            │  (all actions) │            │            │
│         │            └───────────────┘             │            │
│         ▼                                          ▼            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Admin Features                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │ User Mgmt    │  │ Documents    │  │ Categories     │  │  │
│  │  │ - CRUD       │  │ - Upload     │  │ - CRUD         │  │  │
│  │  │ - Roles      │  │ - Bulk       │  │ - Assignment   │  │  │
│  │  └──────────────┘  │ - Categories │  └────────────────┘  │  │
│  │                    └──────────────┘                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Design

#### 1. Admin Sessions Controller

- Custom sessions controller at `Admin::SessionsController`
- Inherits from `Devise::SessionsController`
- Sets admin-specific session timeout flag
- Tracks login for audit

#### 2. Admin Base Controller Updates

- Add `before_action :check_admin_timeout`
- Inject `AuditLogger` concern
- Redirect unauthorized to `/admin/login`

#### 3. Audit Logger Concern

- `after_action` callback for all admin actions
- Creates `AdminAuditLog` records
- Captures context (IP, user agent, params)

#### 4. Document Categories

- New `Category` model
- `has_many :documents` / `belongs_to :category (optional)`
- Admin-only category management

#### 5. Bulk Upload

- JavaScript controller for multi-file selection
- Server-side batch processing
- Transactional document creation

### Data Structure

#### New Tables

```ruby
# AdminAuditLog
create_table :admin_audit_logs do |t|
  t.references :user, null: false, foreign_key: true
  t.string :action, null: false           # create, update, delete
  t.string :resource_type, null: false    # User, Document, Category
  t.bigint :resource_id
  t.jsonb :changes, default: {}           # What changed
  t.string :ip_address
  t.string :user_agent
  t.string :request_id
  t.timestamps
end

add_index :admin_audit_logs, [:resource_type, :resource_id]
add_index :admin_audit_logs, :created_at

# Category
create_table :categories do |t|
  t.string :name, null: false
  t.text :description
  t.integer :documents_count, default: 0
  t.timestamps
end

add_index :categories, :name, unique: true

# Add category_id to documents
add_reference :documents, :category, foreign_key: true
```

#### Modified Tables

```ruby
# Add admin_session_expires_at to users (for timeout tracking)
add_column :users, :admin_session_expires_at, :datetime
```

### API Design

#### Routes

```ruby
# config/routes.rb additions
namespace :admin do
  # Admin authentication
  get 'login', to: 'sessions#new', as: :login
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout

  # Categories
  resources :categories

  # Documents with bulk upload
  resources :documents do
    collection do
      post :bulk_create
    end
  end

  # Audit logs (read-only)
  resources :audit_logs, only: [:index, :show]
end
```

#### Endpoints

| Method | Path                         | Action                | Description         |
| ------ | ---------------------------- | --------------------- | ------------------- |
| GET    | /admin/login                 | sessions#new          | Admin login form    |
| POST   | /admin/login                 | sessions#create       | Process admin login |
| DELETE | /admin/logout                | sessions#destroy      | Admin logout        |
| GET    | /admin/categories            | categories#index      | List categories     |
| POST   | /admin/categories            | categories#create     | Create category     |
| PATCH  | /admin/categories/:id        | categories#update     | Update category     |
| DELETE | /admin/categories/:id        | categories#destroy    | Delete category     |
| POST   | /admin/documents/bulk_create | documents#bulk_create | Bulk upload         |
| GET    | /admin/audit_logs            | audit_logs#index      | View audit log      |

### Processing Flow

#### Admin Login Flow

```
1. User visits /admin/login
2. Enters credentials
3. Admin::SessionsController#create validates
4. If valid + admin role:
   a. Set session[:admin_session_started_at]
   b. Log audit event (admin_login)
   c. Redirect to /admin
5. If valid but not admin:
   a. Flash error "Admin access required"
   b. Re-render login form
6. If invalid:
   a. Flash error "Invalid credentials"
   b. Re-render login form
```

#### Session Timeout Flow

```
1. Admin makes request
2. Admin::BaseController checks:
   a. Is user authenticated? (Devise)
   b. Is user admin? (role check)
   c. Has session expired? (30 min check)
3. If session expired:
   a. Clear session
   b. Log audit event (session_timeout)
   c. Redirect to /admin/login with message
```

#### Bulk Upload Flow

```
1. Admin selects multiple files
2. JavaScript shows file list with progress bars
3. POST /admin/documents/bulk_create with:
   - files[] array
   - category_id (optional)
   - title_prefix (optional)
4. Server processes each file:
   a. Validate file type/size
   b. Create Document record
   c. Attach file
   d. Queue DocumentProcessorJob
5. Return JSON with results:
   - successful: [{id, title}, ...]
   - failed: [{filename, error}, ...]
6. JavaScript updates UI with results
```

### Integration Points

- **Devise**: Custom sessions controller extends Devise
- **Active Storage**: Reuse existing attachment logic
- **Turbo/Stimulus**: Add bulk upload controller
- **Background Jobs**: Existing DocumentProcessorJob for each file

## Trade-offs & Decisions

### Decision 1: Single User Model vs Separate AdminUser

**Options Considered:**

1. **Single User Model (Chosen)**: Keep existing User with role enum
   - Pros: No migration of existing admins, simpler queries, reuses Devise
   - Cons: Shared session concerns, less strict separation
2. **Separate AdminUser Model**: New table with separate Devise scope
   - Pros: Complete isolation, different security policies
   - Cons: Complex migration, code duplication, harder to query

**Rationale**: The existing admin functionality works well. A separate login page with session timeout provides sufficient separation without the complexity of a new model.

### Decision 2: Session Timeout Implementation

**Options Considered:**

1. **Custom Middleware (Chosen)**: Track timeout in session, check in BaseController
   - Pros: Full control, admin-only timeout
   - Cons: Manual implementation
2. **Devise Timeoutable**: Use built-in Devise module
   - Pros: Battle-tested
   - Cons: Applies to all users, not just admin sessions

**Rationale**: We want admin-specific timeout while employees keep longer sessions.

### Decision 3: Audit Log Storage

**Options Considered:**

1. **Database Table (Chosen)**: AdminAuditLog model with JSONB changes
   - Pros: Queryable, part of app, easy to display
   - Cons: Database growth over time
2. **External Service**: Send to logging service (ELK, etc.)
   - Pros: Scalable, searchable
   - Cons: External dependency, complexity

**Rationale**: For an organization chatbot, database storage is sufficient and keeps everything self-contained.

## Edge Cases

- **Concurrent sessions**: Admin logged in on multiple devices - each has independent timeout
- **Role change during session**: If admin demoted while logged in, next request will fail admin check and redirect
- **Bulk upload partial failure**: Return detailed results; successful uploads remain, failed ones reported
- **Category deletion with documents**: Nullify document category_id (soft removal) or require moving documents first
- **Last admin protection**: Existing logic prevents deletion/demotion of last admin

## Fail-safe & Error Handling

| Scenario                    | Recovery                                                         |
| --------------------------- | ---------------------------------------------------------------- |
| Audit log write fails       | Log to Rails logger, continue request (don't block admin action) |
| Bulk upload file invalid    | Skip file, report in response, continue with valid files         |
| Session timeout during form | Save form state to localStorage, restore after re-login          |
| Category creation fails     | Show validation errors, keep form populated                      |
| Large file upload timeout   | Increase timeout for bulk endpoint, show progress                |

## Security Considerations

| Concern             | Mitigation                                               |
| ------------------- | -------------------------------------------------------- |
| Brute force login   | Consider implementing account lockout (Devise :lockable) |
| Session fixation    | Regenerate session on login (Devise default)             |
| CSRF attacks        | Rails CSRF protection enabled by default                 |
| Admin enumeration   | Generic error messages ("Invalid credentials")           |
| Audit log tampering | Read-only in app, no delete action, database permissions |
| Bulk upload DoS     | File size limits (10MB), file count limits (20 files)    |
| XSS in audit logs   | Escape all rendered user input                           |

## Testing Strategy

### Unit Tests

- `AdminAuditLog` model validations and associations
- `Category` model validations and associations
- `User#admin_session_expired?` method
- Document-Category relationship

### Integration Tests (Controllers)

- `Admin::SessionsController`: login, logout, timeout
- `Admin::CategoriesController`: CRUD operations
- `Admin::DocumentsController`: bulk upload
- `Admin::AuditLogsController`: listing, filtering
- Authorization tests for all admin routes

### System Tests (E2E)

- Admin login with timeout
- Category management workflow
- Bulk document upload flow
- Audit log viewing

### Coverage Targets

- Admin controllers: 90%+
- Models: 85%+
- Overall admin functionality: 90%+

## Implementation Plan

### Priority

**High Priority (Core)**

1. Admin login page and sessions controller
2. Session timeout implementation
3. Redirect non-admins to admin login
4. Admin login branding/styling

**Medium Priority (Features)** 5. Audit logging concern and model 6. Category model and controller 7. Document-category association 8. Category filter in documents list

**Lower Priority (Enhancement)** 9. Bulk upload JavaScript controller 10. Bulk upload server endpoint 11. Audit log viewer 12. Comprehensive test suite

### Phases

**Phase 1 (MVP)**: Admin Login & Security

- Admin login page at /admin/login
- Session timeout (30 min)
- Basic audit logging
- Admin branding

**Phase 2**: Document Categories

- Category model and CRUD
- Document-category relationship
- Category filter in documents

**Phase 3**: Bulk Upload

- Multi-file selection UI
- Batch processing endpoint
- Progress and error handling

**Phase 4**: Polish & Testing

- Audit log viewer
- Comprehensive tests
- Documentation

### Files to be Modified/Created

**New Files:**

- `app/controllers/admin/sessions_controller.rb`
- `app/controllers/admin/categories_controller.rb`
- `app/controllers/admin/audit_logs_controller.rb`
- `app/models/admin_audit_log.rb`
- `app/models/category.rb`
- `app/models/concerns/auditable.rb`
- `app/views/admin/sessions/new.html.erb`
- `app/views/admin/categories/` (index, new, edit, \_form)
- `app/views/admin/audit_logs/index.html.erb`
- `app/javascript/controllers/bulk_upload_controller.js`
- `app/assets/stylesheets/pages/_admin_login.scss`
- `db/migrate/YYYYMMDD_create_admin_audit_logs.rb`
- `db/migrate/YYYYMMDD_create_categories.rb`
- `db/migrate/YYYYMMDD_add_category_to_documents.rb`
- `test/controllers/admin/sessions_controller_test.rb`
- `test/controllers/admin/categories_controller_test.rb`
- `test/models/admin_audit_log_test.rb`
- `test/models/category_test.rb`

**Modified Files:**

- `config/routes.rb` - Add admin session and category routes
- `app/controllers/admin/base_controller.rb` - Add timeout check, audit concern
- `app/controllers/admin/documents_controller.rb` - Add bulk upload, category
- `app/models/document.rb` - Add category association
- `app/views/admin/documents/index.html.erb` - Add category filter
- `app/views/admin/documents/new.html.erb` - Add category select
- `app/views/shared/_navbar.html.erb` - Update admin menu
- `config/initializers/devise.rb` - Ensure timeoutable not globally applied

### Dependencies

**Existing (no changes):**

- Devise (authentication)
- Active Storage (file uploads)
- Turbo/Stimulus (JavaScript)

**No new gems required** - all features can be built with existing stack.

## Verification Method

- [ ] Admin can access /admin/login
- [ ] Admin can login and reach dashboard
- [ ] Non-admin redirected to /admin/login with message
- [ ] Session expires after 30 minutes of inactivity
- [ ] Admin actions create audit log entries
- [ ] Categories can be created/edited/deleted
- [ ] Documents can be assigned to categories
- [ ] Documents can be filtered by category
- [ ] Multiple files can be uploaded at once
- [ ] Bulk upload shows success/failure for each file
- [ ] Audit log displays admin activity
- [ ] All tests pass with 90%+ coverage

## Risks & Mitigations

| Risk                                 | Impact | Mitigation                                            |
| ------------------------------------ | ------ | ----------------------------------------------------- |
| Session timeout too aggressive       | Medium | Allow 30 min default, make configurable via ENV       |
| Audit log database growth            | Low    | Add retention policy, archive old logs monthly        |
| Bulk upload file size issues         | Medium | Set reasonable limits (10MB/file, 20 files)           |
| Breaking existing admin flow         | High   | Extensive testing, gradual rollout, feature flag      |
| Category migration for existing docs | Low    | Categories optional, existing docs have null category |

## Future Enhancements

- Two-factor authentication (2FA) for admin accounts
- IP-based access restrictions for admin
- Admin activity dashboard with charts
- Export audit logs to CSV
- Document versioning
- Nested category hierarchy
- Drag-and-drop file upload

## Investigation Summary

Five parallel agents investigated the codebase:

1. **Code Explorer**: Documented existing Devise setup, admin namespace, document upload flow
2. **Security Auditor**: Identified missing lockout, no timeout, no audit logging
3. **Architecture Reviewer**: Recommended separate login page with same User model
4. **Test Architect**: Found 0% admin controller coverage, proposed 64 new tests
5. **Routes Analyzer**: Mapped existing routes, recommended explicit admin auth routes

## Interview Summary

Key decisions from user:

- **Auth Model**: Separate login page (recommended)
- **Security**: Session timeout + audit logging
- **Access Denied**: Redirect to admin login page
- **Documents**: Keep current + add categories + add bulk upload
- **UI Design**: Distinct admin branding
- **Scope**: Full feature set

---

_Generated by Spec Interview process on 2026-02-03_
