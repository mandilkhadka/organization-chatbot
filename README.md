# 🤖 AI Knowledge Chatbot for Organizations

An internal **AI-powered knowledge assistant** built with **Ruby on Rails**, **React**, **OpenAI SDK**, **pgvector**, and **Ollama** (for local inference).
It enables organizations to upload internal policies, guidelines, and documents — so employees can easily ask questions like:

> “What’s our leave policy?”
> “How do I submit an expense report?”
> “What’s our remote work policy?”

---

## 🎯 Objective

Build an **internal knowledge chatbot** that:
- Learns from uploaded company documents or policies.
- Uses **Retrieval-Augmented Generation (RAG)** for precise, context-aware answers.
- Runs via **OpenAI API** or locally with **Ollama**.
- Integrates seamlessly into existing Rails-based internal tools.

---

## 🔧 Tech Stack

| Layer | Technology | Purpose |
|-------|-------------|----------|
| **Backend** | Ruby on Rails | API and RAG pipeline |
| **Frontend** | React | Interactive chat interface |
| **AI SDK** | OpenAI SDK | Embeddings + LLM inference |
| **Vector DB** | PostgreSQL + pgvector | Semantic document storage |
| **Local AI** | Ollama | On-device LLM inference option |

---

## ⚙️ Setup

### 1. Clone the repository
```bash
git clone https://github.com/your-org/organization-chatbot.git
cd organization-chatbot
```

### 2. Install dependencies
```bash
bundle install
yarn install
```
### 3. Configure environment variables
```
.env

OPENAI_API_KEY=your_openai_api_key
DATABASE_URL=postgres://user:password@localhost:5432/organization_chatbot_development
OLLAMA_HOST=http://localhost:11434
```

### 4. Setup the database
```
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector;"
rails db:create db:migrate
```

### 5. Start the server
```
rails s
```

# 🧠 How It Works
#### Upload Documents

Admins upload PDFs, DOCX files, or text documents.
The app extracts and chunks text for embeddings.

#### Embedding & Storage

Each text chunk is embedded using the OpenAI embeddings API (or Ollama local model).
The embeddings are stored in pgvector for semantic search.

#### Querying & Retrieval

When a user asks a question, relevant chunks are retrieved based on vector similarity.

#### Answer Generation

The chatbot sends the question + retrieved context to an LLM (OpenAI or Ollama) for a grounded answer.

### 🚀 Future Enhancements
🔜 Multi-user access control

🔜 Slack / Teams integration

🔜 Fine-tuned company-specific model support
