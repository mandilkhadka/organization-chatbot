# Organization Chatbot with RAG - Technical Specification

## Objective

Build a production-ready AI-powered knowledge assistant that enables employees to ask questions about company policies and receive accurate, context-aware answers using Retrieval-Augmented Generation (RAG).

## Background

Organizations need a centralized way for employees to quickly find answers about HR policies, procedures, and company information. Instead of searching through documents or asking HR, employees can chat with an AI assistant that retrieves relevant information from uploaded company documents.

**Problem Solved:**

- Reduces HR workload for repetitive policy questions
- Provides instant 24/7 access to company knowledge
- Ensures consistent, accurate answers based on official documents

---

## Requirements

### Functional Requirements

1. **User Authentication**
   - Employee login via Devise (email/password)
   - Role-based access: Admin and Employee
   - Admins can upload/manage documents
   - Employees can only chat

2. **Document Management (Admin)**
   - Upload documents (PDF, DOCX, TXT)
   - View uploaded documents list
   - Delete documents
   - Automatic text extraction and chunking
   - Automatic embedding generation

3. **Chat Interface (All Users)**
   - Real-time streaming AI responses
   - Show source document citations
   - Conversation history persistence
   - Thumbs up/down feedback on responses

4. **RAG Pipeline**
   - Document chunking with overlap
   - Vector embeddings via Gemini API
   - Semantic similarity search via pgvector
   - Context-aware response generation

### Non-functional Requirements

| Requirement         | Target                                                 |
| ------------------- | ------------------------------------------------------ |
| **Performance**     | Response start < 2 seconds, full response < 10 seconds |
| **Security**        | API keys server-side only, document access controlled  |
| **Scalability**     | Support 1-50 concurrent users                          |
| **Reliability**     | Graceful error handling, retry on API failures         |
| **Maintainability** | Comprehensive tests, documented code                   |

---

## Design

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        RAILS APPLICATION                          │
├──────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Devise    │  │   Admin     │  │      Chat Interface     │  │
│  │    Auth     │  │  Dashboard  │  │    (Turbo Streams)      │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│         │                │                      │                │
│  ┌──────┴────────────────┴──────────────────────┴──────┐        │
│  │                    SERVICES LAYER                     │        │
│  ├───────────────┬───────────────┬──────────────────────┤        │
│  │ DocumentParser│ EmbeddingService│   RAGService        │        │
│  │ (PDF/DOCX/TXT)│ (Gemini API)    │ (Query + Generate)  │        │
│  └───────────────┴───────────────┴──────────────────────┘        │
│         │                │                      │                │
│  ┌──────┴────────────────┴──────────────────────┴──────┐        │
│  │                    BACKGROUND JOBS                    │        │
│  │           DocumentProcessorJob, EmbeddingJob          │        │
│  └───────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
   │    SUPABASE   │  │  GEMINI API   │  │ FILE STORAGE  │
   │  PostgreSQL   │  │  (ruby_llm)   │  │ (Active       │
   │  + pgvector   │  │               │  │  Storage)     │
   └───────────────┘  └───────────────┘  └───────────────┘
```

### Data Flow

```
DOCUMENT UPLOAD FLOW:
┌────────┐    ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Admin  │───▶│ Upload  │───▶│  Parse   │───▶│  Chunk   │───▶│  Embed   │
│ Upload │    │ Document│    │  Text    │    │  Text    │    │  Vectors │
└────────┘    └─────────┘    └──────────┘    └──────────┘    └──────────┘
                                                                   │
                                                                   ▼
                                                            ┌──────────┐
                                                            │  Store   │
                                                            │ Supabase │
                                                            └──────────┘

CHAT QUERY FLOW:
┌────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ User   │───▶│  Embed   │───▶│  Vector  │───▶│ Retrieve │───▶│ Generate │
│ Query  │    │  Query   │    │  Search  │    │ Context  │    │ Response │
└────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                                   │
                                                                   ▼
                                                            ┌──────────┐
                                                            │ Stream   │
                                                            │ to User  │
                                                            └──────────┘
```

### Component Design

#### Models

```ruby
# User (existing - extend with role)
class User < ApplicationRecord
  enum role: { employee: 0, admin: 1 }
  has_many :documents
  has_many :conversations
end

# Document
class Document < ApplicationRecord
  belongs_to :user  # uploaded by
  has_many :document_chunks, dependent: :destroy
  has_one_attached :file

  enum status: { pending: 0, processing: 1, ready: 2, failed: 3 }
end

# DocumentChunk
class DocumentChunk < ApplicationRecord
  belongs_to :document
  # embedding stored as vector(768) in Supabase
end

# Conversation
class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy
end

# Message
class Message < ApplicationRecord
  belongs_to :conversation
  has_many :message_sources, dependent: :destroy

  enum role: { user: 0, assistant: 1 }
  enum feedback: { none: 0, positive: 1, negative: 2 }
end

# MessageSource (citations)
class MessageSource < ApplicationRecord
  belongs_to :message
  belongs_to :document_chunk
end
```

#### Database Schema

```sql
-- Enable pgvector extension (run in Supabase)
CREATE EXTENSION IF NOT EXISTS vector;

-- Add role to users
ALTER TABLE users ADD COLUMN role INTEGER DEFAULT 0;

-- Documents table
CREATE TABLE documents (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id),
  title VARCHAR(255) NOT NULL,
  filename VARCHAR(255) NOT NULL,
  content_type VARCHAR(100),
  file_size INTEGER,
  status INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Document chunks with vector embeddings
CREATE TABLE document_chunks (
  id BIGSERIAL PRIMARY KEY,
  document_id BIGINT REFERENCES documents(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  embedding vector(768),  -- Gemini embedding dimension
  position INTEGER,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Index for vector similarity search
CREATE INDEX ON document_chunks
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Conversations
CREATE TABLE conversations (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id),
  title VARCHAR(255),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Messages
CREATE TABLE messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT REFERENCES conversations(id) ON DELETE CASCADE,
  role INTEGER NOT NULL,  -- 0=user, 1=assistant
  content TEXT NOT NULL,
  feedback INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Message sources (citations)
CREATE TABLE message_sources (
  id BIGSERIAL PRIMARY KEY,
  message_id BIGINT REFERENCES messages(id) ON DELETE CASCADE,
  document_chunk_id BIGINT REFERENCES document_chunks(id),
  relevance_score FLOAT,
  created_at TIMESTAMP NOT NULL
);
```

### Services

#### DocumentParserService

```ruby
# app/services/document_parser_service.rb
class DocumentParserService
  def parse(document)
    case document.content_type
    when 'application/pdf'
      parse_pdf(document.file)
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      parse_docx(document.file)
    when 'text/plain'
      parse_txt(document.file)
    else
      raise UnsupportedFormatError, "Unsupported format: #{document.content_type}"
    end
  end
end
```

#### TextChunkerService

```ruby
# app/services/text_chunker_service.rb
class TextChunkerService
  CHUNK_SIZE = 512
  CHUNK_OVERLAP = 50

  def chunk(text)
    # Split into chunks with overlap for context preservation
    chunks = []
    sentences = text.split(/(?<=[.!?])\s+/)
    current_chunk = ""

    sentences.each do |sentence|
      if (current_chunk + sentence).length > CHUNK_SIZE
        chunks << current_chunk.strip
        # Keep overlap from previous chunk
        current_chunk = current_chunk.last(CHUNK_OVERLAP) + sentence
      else
        current_chunk += " " + sentence
      end
    end

    chunks << current_chunk.strip unless current_chunk.empty?
    chunks
  end
end
```

#### EmbeddingService

```ruby
# app/services/embedding_service.rb
class EmbeddingService
  def generate(text)
    RubyLLM.embed(text, model: "gemini-embedding-001").vectors
  end

  def generate_batch(texts)
    texts.map { |text| generate(text) }
  end
end
```

#### VectorSearchService

```ruby
# app/services/vector_search_service.rb
class VectorSearchService
  def search(query, limit: 5, threshold: 0.7)
    query_embedding = EmbeddingService.new.generate(query)

    DocumentChunk
      .select("*, 1 - (embedding <=> '#{query_embedding}') AS similarity")
      .where("1 - (embedding <=> '#{query_embedding}') > ?", threshold)
      .order("similarity DESC")
      .limit(limit)
  end
end
```

#### RAGService

```ruby
# app/services/rag_service.rb
class RAGService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful company knowledge assistant. Answer questions based ONLY on
    the provided context from company documents. If the answer is not in the context,
    say "I don't have information about that in the company documents."

    Always be professional, accurate, and cite which document the information comes from.
  PROMPT

  def query(question, user, &block)
    # 1. Retrieve relevant chunks
    chunks = VectorSearchService.new.search(question)

    # 2. Build context
    context = chunks.map { |c| "From #{c.document.title}:\n#{c.content}" }.join("\n\n")

    # 3. Generate response with streaming
    chat = RubyLLM.chat(model: "gemini-2.0-flash")

    response = chat.ask(
      "Context:\n#{context}\n\nQuestion: #{question}",
      system: SYSTEM_PROMPT,
      &block  # Stream callback
    )

    { response: response, sources: chunks }
  end
end
```

### API Design

#### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  root "pages#home"

  # Admin routes
  namespace :admin do
    resources :documents, only: [:index, :new, :create, :destroy]
  end

  # Chat routes
  resources :conversations, only: [:index, :show, :create] do
    resources :messages, only: [:create] do
      member do
        post :feedback
      end
    end
  end

  # Health check
  get "up" => "rails/health#show"
end
```

### UI/UX Design

#### Chat Interface

```
┌─────────────────────────────────────────────────────────┐
│  Company Knowledge Assistant           [User ▼] [Logout]│
├─────────────────────────────────────────────────────────┤
│ ┌─────────┐                                             │
│ │ History │  ┌─────────────────────────────────────────┐│
│ │ ─────── │  │                                         ││
│ │ Today   │  │  👤 What is our leave policy?           ││
│ │ • Leave │  │                                         ││
│ │ • Expen │  │  🤖 Based on the Employee Handbook,     ││
│ │         │  │     employees receive:                  ││
│ │ Yesterd │  │     • 15 days annual leave              ││
│ │ • Remot │  │     • 10 days sick leave                ││
│ │         │  │     • 5 days personal leave             ││
│ │         │  │                                         ││
│ │         │  │     📄 Source: employee-handbook.pdf    ││
│ │         │  │                                         ││
│ │         │  │     [👍] [👎]                           ││
│ │         │  │                                         ││
│ └─────────┘  └─────────────────────────────────────────┘│
│              ┌─────────────────────────────────┐ [Send] │
│              │ Ask a question...               │        │
│              └─────────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

---

## Trade-offs & Decisions

### Decision 1: Gemini API via ruby_llm

**Options Considered:**

1. OpenAI API - Most mature, expensive
2. Gemini API via ruby_llm - Good balance, already installed
3. Local Ollama - Free, but requires server resources

**Chosen:** Gemini API via ruby_llm

**Rationale:**

- `ruby_llm` gem already in Gemfile
- Supports both chat and embeddings
- Gemini offers competitive pricing
- Single gem for all AI operations

### Decision 2: Supabase for Vector Storage

**Options Considered:**

1. Supabase PostgreSQL + pgvector - Managed, scalable
2. Local PostgreSQL + pgvector - Full control, self-managed
3. Pinecone - Purpose-built, expensive

**Chosen:** Supabase with pgvector

**Rationale:**

- User's explicit preference
- Managed PostgreSQL with pgvector support
- Easy connection from Rails via standard pg gem
- Scales automatically

### Decision 3: Turbo Streams for Real-time Chat

**Options Considered:**

1. Turbo Streams - Native Rails, no extra JS
2. Server-Sent Events (SSE) - Simple, wide support
3. WebSockets (Action Cable) - Full duplex, more complex

**Chosen:** Turbo Streams

**Rationale:**

- Already configured in the codebase
- Native Rails integration
- Perfect for streaming AI responses
- Simpler than raw WebSockets

### Decision 4: Background Jobs for Document Processing

**Options Considered:**

1. Synchronous processing - Simple, blocks request
2. Background jobs (ActiveJob) - Async, scalable
3. Separate microservice - Complex, overkill for scale

**Chosen:** Background Jobs with ActiveJob

**Rationale:**

- Document parsing can take seconds/minutes
- Don't block web requests
- Can use Solid Queue (Rails 8) or Sidekiq
- Proper error handling and retries

---

## Edge Cases

| Edge Case                    | Handling                                     |
| ---------------------------- | -------------------------------------------- |
| Empty document               | Reject with validation error                 |
| Corrupted PDF                | Catch parse error, mark document as failed   |
| No relevant chunks found     | Return "I don't have information about that" |
| Gemini API rate limit        | Retry with exponential backoff               |
| Very long document           | Process in batches, show progress            |
| Concurrent uploads           | Queue jobs, process sequentially             |
| User asks off-topic question | System prompt instructs to stay on topic     |
| Malicious file upload        | Validate content type, scan for issues       |

---

## Fail-safe & Error Handling

| Failure Scenario           | Recovery Mechanism                           |
| -------------------------- | -------------------------------------------- |
| Gemini API down            | Show error, retry button, log for monitoring |
| Supabase connection lost   | Retry with backoff, queue failed operations  |
| Document parsing fails     | Mark as failed, notify admin, allow retry    |
| Embedding generation fails | Retry job, mark chunk as unembedded          |
| Streaming interrupted      | Save partial response, allow continuation    |

---

## Security Considerations

| Concern                 | Mitigation                                           |
| ----------------------- | ---------------------------------------------------- |
| API key exposure        | Store in environment variables, never in code/client |
| Document access control | Filter queries by user role, admin-only upload       |
| Prompt injection        | System prompt guardrails, input sanitization         |
| PII in documents        | Encrypt at rest, audit logging, access controls      |
| XSS in chat             | Sanitize all user input and AI output                |
| CSRF                    | Rails built-in CSRF protection                       |
| Rate limiting           | Implement per-user rate limits on chat endpoint      |

---

## Testing Strategy

### Unit Tests (70%)

- Model validations
- Service methods (chunking, embedding, search)
- Background job logic

### Integration Tests (20%)

- Full RAG pipeline
- Document upload flow
- Chat message flow

### System Tests (10%)

- E2E user chat workflow
- Admin document management

### Mocking Strategy

- Use WebMock + VCR for Gemini API calls
- Use FactoryBot for test data
- Stub vector search in unit tests

---

## Implementation Plan

### Priority

| Priority | Feature                                |
| -------- | -------------------------------------- |
| **P0**   | User authentication with roles         |
| **P0**   | Document upload and parsing            |
| **P0**   | RAG pipeline (embed, search, generate) |
| **P0**   | Chat interface with streaming          |
| **P1**   | Source citations                       |
| **P1**   | Conversation history                   |
| **P1**   | Feedback system                        |
| **P2**   | Admin dashboard                        |
| **P2**   | Analytics/reporting                    |

### Phases

#### Phase 1: Foundation (Core)

- Add role to User model
- Create Document and DocumentChunk models
- Set up Supabase connection with pgvector
- Implement DocumentParserService (PDF, DOCX, TXT)
- Implement EmbeddingService with Gemini
- Create admin document upload UI

#### Phase 2: RAG Pipeline

- Implement TextChunkerService
- Implement VectorSearchService
- Implement RAGService
- Create background jobs for processing
- Test full pipeline

#### Phase 3: Chat Interface

- Create Conversation and Message models
- Build chat UI with Turbo Streams
- Implement streaming responses
- Add source citations display
- Add conversation history sidebar

#### Phase 4: Polish

- Feedback system (thumbs up/down)
- Error handling and edge cases
- Security hardening
- Comprehensive testing
- Update README documentation

### Files to be Modified/Created

```
app/
├── controllers/
│   ├── admin/
│   │   └── documents_controller.rb (new)
│   ├── conversations_controller.rb (new)
│   └── messages_controller.rb (new)
├── models/
│   ├── user.rb (modify - add role)
│   ├── document.rb (new)
│   ├── document_chunk.rb (new)
│   ├── conversation.rb (new)
│   ├── message.rb (new)
│   └── message_source.rb (new)
├── services/
│   ├── document_parser_service.rb (new)
│   ├── text_chunker_service.rb (new)
│   ├── embedding_service.rb (new)
│   ├── vector_search_service.rb (new)
│   └── rag_service.rb (new)
├── jobs/
│   ├── document_processor_job.rb (new)
│   └── embedding_job.rb (new)
├── views/
│   ├── admin/
│   │   └── documents/ (new)
│   ├── conversations/ (new)
│   └── messages/ (new)
└── javascript/
    └── controllers/
        └── chat_controller.js (new)

config/
├── routes.rb (modify)
├── initializers/
│   └── ruby_llm.rb (new)
└── database.yml (modify for Supabase)

db/
└── migrate/
    ├── XXXX_add_role_to_users.rb (new)
    ├── XXXX_create_documents.rb (new)
    ├── XXXX_create_document_chunks.rb (new)
    ├── XXXX_create_conversations.rb (new)
    ├── XXXX_create_messages.rb (new)
    └── XXXX_create_message_sources.rb (new)

.env (modify - add placeholders)
README.md (modify - update documentation)
```

### Dependencies to Add

```ruby
# Gemfile additions
gem "pdf-reader"           # PDF parsing
gem "docx"                 # DOCX parsing
gem "neighbor"             # pgvector ActiveRecord integration
gem "sidekiq"              # Background jobs (or solid_queue)
```

---

## Verification Method

- [ ] User can sign up and log in
- [ ] Admin can upload PDF, DOCX, TXT documents
- [ ] Documents are parsed and chunked automatically
- [ ] Embeddings are generated and stored in Supabase
- [ ] User can ask questions in chat
- [ ] Responses stream in real-time
- [ ] Source citations are displayed
- [ ] Conversation history is persisted
- [ ] Feedback buttons work
- [ ] Unauthorized users cannot access admin features
- [ ] All tests pass
- [ ] Security audit completed

---

## Risks & Mitigations

| Risk                      | Impact | Mitigation                                       |
| ------------------------- | ------ | ------------------------------------------------ |
| Gemini API changes        | High   | Pin API version, monitor deprecations            |
| Supabase downtime         | High   | Implement circuit breaker, show cached responses |
| Poor response quality     | Medium | Tune chunking, prompts; add feedback loop        |
| Cost overrun from API     | Medium | Implement usage tracking, rate limits            |
| Document parsing failures | Medium | Support multiple parsers, fallback to plain text |
| Scaling issues            | Low    | Small scale (1-50), can optimize later           |

---

## Future Enhancements

- [ ] Slack/Teams integration
- [ ] Multi-language support
- [ ] Document versioning
- [ ] Analytics dashboard
- [ ] Fine-tuned embeddings
- [ ] Voice input/output
- [ ] Mobile app

---

## Environment Variables

```bash
# .env - Required placeholders
GEMINI_API_KEY=your_gemini_api_key_here
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_DB_URL=postgresql://postgres:[password]@db.[project].supabase.co:5432/postgres
RAILS_MASTER_KEY=your_rails_master_key
```

---

## Investigation Summary

### Codebase Findings

- Rails 7.1.6 with Devise already configured
- `ruby_llm` gem installed (supports Gemini for chat and embeddings)
- Hotwire/Turbo/Stimulus configured and ready
- PostgreSQL as database (compatible with Supabase)
- Bootstrap 5.3 for styling
- No existing RAG or chat functionality

### Key Technical Decisions from Investigation

1. Use `ruby_llm` for Gemini integration (already installed)
2. Use `neighbor` gem for pgvector ActiveRecord integration
3. Use Turbo Streams for real-time chat (already configured)
4. Use ActiveJob with Sidekiq for background processing

---

## Interview Summary

| Topic            | Decision                  |
| ---------------- | ------------------------- |
| Data Input       | Admin uploads documents   |
| User Roles       | Admin + Employee          |
| Chat UX          | Real-time streaming       |
| Vector Storage   | Supabase with pgvector    |
| Document Formats | PDF, DOCX, TXT            |
| Citations        | Show source documents     |
| Use Cases        | HR Policies               |
| Chat History     | Persist all conversations |
| Scale            | Small (1-50 employees)    |
| Feedback         | Thumbs up/down            |
| Scope            | Full production           |

---

_Generated by Spec Interview process on 2026-02-01_
