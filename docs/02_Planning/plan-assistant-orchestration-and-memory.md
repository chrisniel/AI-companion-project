# Implementation Plan: Assistant Orchestration, Persistent Conversations & FTS5 SQLite Memory (Track B5)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

> **Sprint Track:** Track B5 — Assistant Orchestration, Persistent Conversations & SQLite FTS5 Memory  
> **Master Spec References:** Sections 15 (Backend Foundation), 16 (Database & Soft Delete), 18 (Memory & FTS5), 33 (V1 Acceptance Criteria #5 & #8), 34 (Implementation Order)  
> **Feature Branch:** `feature/assistant-orchestration-and-memory`  
> **Status:** Pending User Approval  

---

## 1. Request Understanding & Business Goal

### 1.1 Problem Statement
Currently, our Local AI Core has an operational GGUF inference runtime (`llama-server.exe` Vulkan offload on the RX 580) and a React dashboard that can stream chat completions over SSE. However, each chat completion is currently **stateless** and ephemeral:
1. **No Conversation Persistence**: Chat messages exist only in React component state (`useState`); refreshing the web app wipes all history.
2. **No Multi-Turn Context**: Each prompt sent to `/api/v1/chat/completions` lacks automatic conversational thread tracking.
3. **No Memory Layer**: The assistant has zero recall of user facts, preferences, or past interactions.
4. **Master Roadmap Sequence**: Track B5 is the designated next milestone to build canonical conversation storage, assistant orchestration, and SQLite FTS5 memory retrieval.

### 1.2 Business Goal
Deliver a robust, local-first conversational orchestration layer that:
- Persists conversations and messages in SQLite with user scoping (`owner_id`) and soft-delete protection.
- Automatically injects conversation history and character persona into prompt context packages.
- Implements keyword-based memory retrieval using SQLite FTS5 virtual tables to allow the assistant to remember user facts without external vector databases.
- Connects the React Web `AssistantView` to persistent threads so conversations survive browser refreshes.

---

## 2. Actors & Trigger

- **Actor**: Local PC User (via Web Dashboard or future Android app).
- **Trigger**:
  - User opens the Web Assistant tab or creates a new conversation thread.
  - User types a message; backend retrieves context, queries FTS5 memories, invokes LLM with SSE streaming, and persists the turn.
  - User manages memories (view, add, delete user facts/preferences).

---

## 3. Affected Layers & Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Web Dashboard                          │
│   (AssistantView.tsx, BackendContext, conversationApi.ts)   │
└──────────────────────────────┬──────────────────────────────┘
                               │ REST / SSE
┌──────────────────────────────▼──────────────────────────────┐
│                    FastAPI Companion Core                   │
│   /api/v1/conversations  |  /api/v1/memories                │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
┌──────────────▼─────────────┐ ┌──────────────▼───────────────┐
│   Assistant Orchestrator   │ │       Memory Retriever       │
│   (Context Assembler,      │ │       (SQLite FTS5           │
│    Persona Injection,      │ │        Full-Text Search)     │
│    LLM Streaming)          │ └──────────────┬───────────────┘
└──────────────┬─────────────┘                │
               │                              │
┌──────────────▼──────────────────────────────▼───────────────┐
│              SQLite Database (companion.db)                 │
│   conversations | messages | memories | memories_fts        │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Acceptance Criteria (Pass/Fail)

### Functional Acceptance Criteria
1. **Conversation CRUD**:
   - `POST /api/v1/conversations`: Creates a new thread with title and optional character ID (`aria`, etc.).
   - `GET /api/v1/conversations`: Returns user's active conversations sorted by `updated_at DESC`.
   - `GET /api/v1/conversations/{id}`: Returns thread metadata and message count.
   - `DELETE /api/v1/conversations/{id}`: Soft-deletes the conversation (`deleted_at IS NOT NULL`).
2. **Message Persistence & Thread Retrieval**:
   - `GET /api/v1/conversations/{id}/messages`: Returns ordered chat history for the thread (`ASC` by `created_at`).
   - `POST /api/v1/conversations/{id}/messages`: Appends user message, queries relevant memories, triggers LLM response (streaming SSE or JSON), and saves assistant turn to the database.
3. **SQLite FTS5 Memory Engine**:
   - `memories` table stores facts, preferences, and context with category and importance.
   - `memories_fts` virtual table indexed on `content` and `category`.
   - `MemoryRetriever` executes `MATCH` queries to find top-k relevant memories matching keywords from the user prompt.
   - `GET /api/v1/memories`: Lists user memories.
   - `POST /api/v1/memories`: Adds a manual or extracted memory.
   - `DELETE /api/v1/memories/{id}`: Soft-deletes a memory.
4. **Assistant Orchestration**:
   - Context packager combines:
     - Character Persona System Prompt (e.g. Aria: friendly, witty, multilingual EN/FIL/JA companion).
     - Retrieved memory snippets (`<memories> ... </memories>`).
     - Recent conversation window (last N turns).
     - Active user prompt.
   - Seamless streaming SSE response with token persistence upon completion.
5. **Web Client Integration**:
   - `AssistantView.tsx` loads previous conversation messages from the backend on load.
   - Switching or creating conversations works seamlessly without losing data.
   - Messages persist across page reloads.

### Non-Functional & Security Criteria
1. **Security**: Strict `owner_id` scoping on all queries (OWASP API1 BOLA prevention); API key validation on all endpoints.
2. **Performance**: FTS5 retrieval completes in < 5ms on SQLite.
3. **Resilience**: If FTS5 search yields no matches, LLM proceeds normally with clean context. If LLM generation is aborted by user, partial response is cleanly recorded or handled without database corruption.

---

## 5. Step-by-Step Implementation Logic (Pseudocode)

### Step 1: Database Models & Alembic Migration
```python
# backend/app/models/conversation.py
class Conversation(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    __tablename__ = "conversations"
    title = mapped_column(String(255), nullable=False, default="New Conversation")
    character_id = mapped_column(String(64), nullable=False, default="aria")

# backend/app/models/message.py
class Message(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    __tablename__ = "messages"
    conversation_id = mapped_column(String(36), ForeignKey("conversations.id"), nullable=False, index=True)
    sender = mapped_column(String(32), nullable=False) # "user" | "assistant" | "system"
    content = mapped_column(Text, nullable=False)
    model_name = mapped_column(String(64), nullable=True)
    tokens = mapped_column(Integer, nullable=True)

# backend/app/models/memory.py
class Memory(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    __tablename__ = "memories"
    category = mapped_column(String(32), default="fact", nullable=False) # "fact" | "preference" | "context"
    content = mapped_column(Text, nullable=False)
    importance = mapped_column(Float, default=1.0, nullable=False)
```
Alembic migration `003_conversations_and_fts5_memory.py`:
- Creates `conversations`, `messages`, `memories` tables.
- Creates `CREATE VIRTUAL TABLE memories_fts USING fts5(id UNINDEXED, content, category);`
- Sets up SQLite insert/update/delete triggers for automatic FTS5 synchronization.

### Step 2: FTS5 Memory Retriever Service
```python
# backend/app/services/memory/retriever.py
class MemoryRetriever:
    async def search_relevant_memories(db: AsyncSession, query: str, owner_id: str, limit: int = 5) -> List[Memory]:
        # 1. Clean query into tokenized terms for FTS5 syntax
        # 2. SELECT m.* FROM memories m JOIN memories_fts f ON m.id = f.id
        #    WHERE memories_fts MATCH :clean_query 
        #      AND m.owner_id = :owner_id 
        #      AND m.deleted_at IS NULL
        #    ORDER BY rank LIMIT :limit
        # 3. Return memory objects
```

### Step 3: Assistant Orchestrator Service
```python
# backend/app/services/assistant/orchestrator.py
class AssistantOrchestrator:
    async def generate_response(
        db: AsyncSession,
        conversation_id: str,
        user_text: str,
        owner_id: str,
        stream: bool = True
    ) -> AsyncGenerator[str, None]:
        # 1. Save user message to database
        # 2. Retrieve last 10 messages from database for conversation_id
        # 3. MemoryRetriever.search_relevant_memories(user_text)
        # 4. Assemble system prompt:
        #    - Persona instructions
        #    - If memories found: "Relevant context about user:\n{memories}"
        # 5. Build ChatMessage list: [SystemMessage, ...history, UserMessage]
        # 6. Call active LLM provider stream_chat_completions
        # 7. Yield SSE chunks to HTTP client
        # 8. Upon completion, save assistant Message(content=accumulated_text) to database
```

### Step 4: REST API Endpoints
- `backend/app/api/v1/endpoints/conversations.py`
- `backend/app/api/v1/endpoints/memories.py`
- Wire into `backend/app/api/v1/router.py`.

### Step 5: Web Client Integration
- `frontend/web/src/services/api/conversationApi.ts`
- `frontend/web/src/services/api/memoryApi.ts`
- Connect `AssistantView.tsx` to load persistent messages and sync conversation threads.

---

## 6. Verification Plan

### Automated Checks
- `backend/.venv/Scripts/pytest backend/tests/test_conversations.py`: Tests CRUD, ordering, soft-delete.
- `backend/.venv/Scripts/pytest backend/tests/test_memory_fts.py`: Tests FTS5 indexing, keyword search, triggers.
- `backend/.venv/Scripts/pytest backend/tests/test_assistant_orchestrator.py`: Tests context packaging and streaming.
- `tsc --noEmit` & `npm run build` in `frontend/web/`.

### Manual End-to-End Verification
1. Start backend server.
2. Open Web Dashboard (`http://localhost:3000`), navigate to Assistant.
3. Post message: "My favorite anime is Steins;Gate and I live in Tokyo."
4. Add memory via API or verify memory insertion.
5. Refresh the browser: verify conversation thread reloads completely from SQLite.
6. Post follow-up: "Where do I live and what show do I like?"
7. Verify assistant accurately recalls Tokyo and Steins;Gate via FTS5 memory injection.
