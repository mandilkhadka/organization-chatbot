# Organization Knowledge Chatbot

An internal **AI-powered knowledge assistant** built with **Ruby on Rails 7**, **Hotwire/Turbo**, **Google Gemini API**, and **Supabase with pgvector**.

Employees can easily ask questions about company policies and get instant, accurate answers:

> "What's our leave policy?"
> "How do I submit an expense report?"
> "What's our remote work policy?"

---

## Features

- **AI-Powered Answers** - Uses Google Gemini for intelligent, context-aware responses
- **RAG Architecture** - Retrieval-Augmented Generation ensures answers are grounded in your documents
- **Real-time Streaming** - ChatGPT-like streaming responses via Turbo Streams
- **Document Upload** - Admin upload for PDF, DOCX, and TXT files
- **Source Citations** - Shows which documents the answer came from
- **Conversation History** - All chats are saved per user
- **Role-based Access** - Admin (manage docs) and Employee (chat only) roles
- **Feedback System** - Thumbs up/down to track response quality
- **Devise Authentication** - Secure employee login

---

## Tech Stack

| Layer          | Technology                    | Purpose                          |
| -------------- | ----------------------------- | -------------------------------- |
| **Backend**    | Ruby on Rails 7.1             | API, RAG pipeline, auth          |
| **Frontend**   | Hotwire (Turbo + Stimulus)    | Real-time streaming chat UI      |
| **AI**         | Google Gemini API (ruby_llm)  | Embeddings + LLM responses       |
| **Vector DB**  | Supabase PostgreSQL + pgvector| Semantic document storage        |
| **Styling**    | Bootstrap 5.3                 | Responsive UI components         |
| **Auth**       | Devise                        | User authentication              |
| **Background** | Sidekiq                       | Document processing jobs         |

---

## Quick Start

### Prerequisites

- Ruby 3.3.5
- PostgreSQL 15+ (or Supabase)
- Node.js 18+
- Google Gemini API key
- Supabase project (free tier works)

### 1. Clone the repository

```bash
git clone https://github.com/mandilkhadka/organization-chatbot.git
cd organization-chatbot
```

### 2. Install dependencies

```bash
bundle install
```

### 3. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and add your credentials (see `.env.example` for all options).

### 4. Setup the database

```bash
# Enable pgvector extension in Supabase SQL Editor:
# CREATE EXTENSION IF NOT EXISTS vector;

rails db:migrate
```

### 5. Create an admin user

```bash
rails console
> User.create!(email: "admin@yourcompany.com", password: "yourpassword", role: :admin)
```

### 6. Start the server

```bash
bin/dev
```

Visit `http://localhost:3000` and log in!

---

## How It Works

### 1. Document Upload (Admin)

Admins upload company documents (PDF, DOCX, TXT) through the admin dashboard.

### 2. Processing Pipeline

```
Upload -> Parse Text -> Chunk (512 tokens) -> Generate Embeddings -> Store in Supabase
```

### 3. Chat Query

```
User Question -> Embed Query -> Vector Search -> Retrieve Context -> Gemini Generates Answer
```

### 4. Response with Citations

The AI responds with an answer AND shows which documents it used as sources.

---

## Architecture

```
+-------------------------------------------------------------+
|                     RAILS APPLICATION                        |
+--------------+-----------------+----------------------------+
|    Devise    |  Admin Panel    |      Chat Interface        |
|     Auth     |  (Documents)    |    (Turbo Streams)         |
+------+-------+--------+--------+------------+---------------+
       |                |                     |
+------+----------------+---------------------+---------------+
|                      SERVICES LAYER                          |
+----------------+------------------+-------------------------+
| DocumentParser | EmbeddingService |      RAGService          |
| (PDF/DOCX/TXT) |   (Gemini API)   | (Search + Generate)      |
+----------------+------------------+-------------------------+
       |                |                     |
       v                v                     v
+--------------+ +-------------+ +----------------------------+
|   Supabase   | | Gemini API  | |    Background Jobs         |
|  PostgreSQL  | |  (ruby_llm) | |      (Sidekiq)             |
|  + pgvector  | |             | |                            |
+--------------+ +-------------+ +----------------------------+
```

---

## API Keys Setup

### Google Gemini API

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create a new API key
3. Add to `.env` as `GEMINI_API_KEY`

### Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **Settings > API** to find your keys
3. Go to **Settings > Database** for the connection string
4. In the SQL Editor, enable pgvector:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

---

## User Roles

| Role         | Capabilities                          |
| ------------ | ------------------------------------- |
| **Admin**    | Upload documents, manage users, chat  |
| **Employee** | Chat only, view conversation history  |

---

## Document Formats

| Format | Extension | Parser           |
| ------ | --------- | ---------------- |
| PDF    | .pdf      | pdf-reader gem   |
| Word   | .docx     | docx gem         |
| Text   | .txt      | Native Ruby      |

---

## Development

### Run tests

```bash
rails test
rails test:system
```

### Background jobs (development)

```bash
bundle exec sidekiq
```

### Console

```bash
rails console
```

---

## Troubleshooting

### "No relevant information found"

- Ensure documents are uploaded and processed (status: "ready")
- Check that pgvector extension is enabled in Supabase
- Verify embeddings were generated (check `document_chunks` table)

### Streaming not working

- Ensure Turbo is properly loaded
- Check browser console for JavaScript errors
- Verify Action Cable is configured

---

## Roadmap

- [ ] Slack / Microsoft Teams integration
- [ ] Multi-language support
- [ ] Document versioning
- [ ] Analytics dashboard
- [ ] Voice input/output
- [ ] Mobile app

---

## Technical Specification

For detailed architecture, data models, and implementation plan, see [SPEC.md](SPEC.md).
