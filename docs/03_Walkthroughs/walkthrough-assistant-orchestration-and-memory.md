# Walkthrough: Assistant Orchestration, Persistent Conversations & FTS5 Memory (Track B5)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Deliver end-to-end persistent multi-turn chat conversations, SQLite FTS5 keyword memory retrieval, context budget management with untrusted memory framing, process-safe llama.cpp router management, and interactive React Web frontend bindings.
- Audience: User, developer, maintainer, QA
- Status: Implemented & Automated Verification Passed (49/49 pytest tests; Vite build clean)
- Last Updated: 2026-09-13

---

## 1. What Was Delivered

- **Persistent Conversations & Messages (Track B5, V1 Criterion #5)**: Replaced ephemeral in-memory state with SQLite tables (`conversations`, `messages`), Alembic migration `003`, CRUD REST endpoints, and Server-Sent Events (SSE) token streaming.
- **SQLite FTS5 Local Memory Layer (Track B5, V1 Criterion #8)**: Authored `memories` table with matching `memories_fts` FTS5 virtual table and automatic sync triggers (insert, update, delete). Created `MemoryRetriever` service with query token sanitization, FTS5 reserved word protection, and multilingual support (English, Filipino, Japanese).
- **Assistant Orchestration & Security Trust Framing**: Built `AssistantOrchestrator` service that handles dynamic token budgeting, sliding history context, per-conversation async locking (`_get_lock` preventing race conditions), and strict prompt framing containing memories within `<retrieved_memories>` as untrusted context.
- **Engine Process Safety & 9-State Runtime Model**: Upgraded `LlamaCppProvider` to probe and use native router endpoints (`/models/load`, `/models/unload`). Scoped process kills exclusively to Core-owned PIDs (`_managed_by_core`), permanently eliminating all blind `taskkill /IM llama-server.exe` calls. Added graceful shutdown hook in FastAPI lifespan.
- **React Web UI Integration**: Connected `AssistantView.tsx` to `conversationApi` for session creation, history loading, drawer navigation, and real-time SSE streaming. Updated `ModelsView.tsx` and `CurrentModelHero.tsx` with live 9-state runtime telemetry badges.

---

## 2. Files Changed

### Backend Core & Services
- `backend/app/core/config.py` — Added `PROVIDER_DIR`, `LLAMA_CPP_BIN_DIR`, `DATA_DIR`, `LLAMA_ROUTER_*` settings, and B5 conversation/memory limits.
- `backend/app/services/llm/runtime_state.py` — Defined canonical 9-state `LLMRuntimeState` enum.
- `backend/app/services/llm/llama_cpp.py` — Upgraded to router API, PID-scoped termination, path traversal rejection, and `shutdown()`.
- `backend/app/services/llm/base.py` & `mock.py` — Added `shutdown()` interface and implementation.
- `backend/app/services/llm/__init__.py` — Implemented PEP 562 dynamic lazy loading to resolve circular imports.
- `backend/app/main.py` — Connected graceful LLM shutdown into FastAPI lifespan.

### Database & Models
- `backend/migrations/versions/003_conversations_messages_and_fts5_memory.py` — Schema migration for conversations, messages, memories, and SQLite FTS5 table with triggers.
- `backend/app/models/conversation.py` — SQLAlchemy ORM model for conversation threads.
- `backend/app/models/message.py` — SQLAlchemy ORM model for messages with sequence numbering and status tracking.
- `backend/app/models/memory.py` — SQLAlchemy ORM model for memory entries.
- `backend/app/models/__init__.py` — Registered new models in metadata registry.

### Services & API
- `backend/app/services/memory/retriever.py` — `MemoryRetriever` service with sanitized FTS5 BM25 search.
- `backend/app/services/assistant/orchestrator.py` — `AssistantOrchestrator` service with context assembly, token budgeting, and SSE streaming.
- `backend/app/schemas/conversation.py`, `message.py`, `memory.py` — Pydantic request/response schemas.
- `backend/app/schemas/llm.py` — Extended `ModelStatusResponse` with `runtime_state`, `seconds_until_idle`, and `managed_by_core`.
- `backend/app/api/v1/endpoints/conversations.py` — REST & SSE endpoints mounted on `protected_router`.
- `backend/app/api/v1/endpoints/memories.py` — Memory CRUD endpoints mounted on `protected_router`.
- `backend/app/api/v1/router.py` — Mounted conversations and memories routers fail-closed.

### Tests
- `backend/tests/conftest.py` — Configured in-memory SQLite FTS5 table & trigger fixtures.
- `backend/tests/test_conversations.py` — CRUD, SSE streaming, idempotency, and concurrency lock tests.
- `backend/tests/test_memory_fts.py` — FTS5 sync, soft-delete filtering, and multilingual search tests.
- `backend/tests/test_assistant_orchestrator.py` — Context budgeting, trust framing, and generator lifecycle tests.
- `backend/tests/test_llm_router_lifecycle.py` — Runtime states, model busy rejection, and process kill safety tests.

### Frontend Web
- `frontend/web/src/services/api/conversationApi.ts` — Typed client with `fetch()` SSE streaming reader.
- `frontend/web/src/services/api/memoryApi.ts` — Typed client for memory CRUD.
- `frontend/web/src/services/api/index.ts` — Re-exported conversation and memory APIs.
- `frontend/web/src/services/api/modelApi.ts` — Extended `ModelStatusResponse` with `LLMRuntimeState`.
- `frontend/web/src/components/workspace/AssistantView.tsx` — Wired persistent sessions, drawer navigation, and SSE streaming.
- `frontend/web/src/components/workspace/ConversationHistoryDrawer.tsx` — Added live conversations prop with mock fallback.
- `frontend/web/src/components/workspace/ModelsView.tsx` — Added 9-state runtime header indicator.
- `frontend/web/src/components/workspace/models/CurrentModelHero.tsx` — Added 9-state runtime telemetry badge.

---

## 3. How the Logic Works

1. **Event trigger**: User submits a message in `AssistantView.tsx` or sends a POST request to `/api/v1/conversations/{id}/messages`.
2. **Validation**:
   - Authentication token is validated fail-closed on `protected_router`.
   - Conversation ownership is verified against `current_user.id`.
   - `client_message_id` uniqueness is checked in the database to prevent duplicate submissions on retry.
   - An async per-conversation lock (`_get_lock(conversation_id)`) is acquired; if already locked, immediately returns `409 Conflict: CONVERSATION_BUSY`.
3. **Core processing**:
   - User message is persisted to SQLite with status `completed`.
   - An assistant message record is created with status `streaming`.
   - `MemoryRetriever.search_relevant_memories` performs an FTS5 search across active memories using sanitized user text.
   - `_build_context()` assembles context by budgeting tokens: `generation_reserve` + `system_prompt` (with memories framed in `<retrieved_memories>`) + reverse history crawl + `user_text`.
   - `provider.chat_completions_stream()` streams LLM tokens.
4. **Completion**:
   - Assistant message content is updated in SQLite and marked `completed`.
   - `[DONE]` SSE marker is sent to the client.
   - In `finally`, `_conversation_locks` is unlocked and `provider._generation_active = False` is guaranteed.
5. **Recovery/cancellation**:
   - If client aborts or network drops, async generator `aclose()` fires, triggering `finally` to set `provider._generation_active = False` and update message status to `cancelled` or `failed`.

---

## 4. Key Concepts

- **FTS5 (Full-Text Search 5)**: A specialized SQLite virtual table module that builds an inverted index over text columns. It enables ultra-fast, lightweight BM25 ranked keyword search directly inside the local SQLite database without requiring external vector databases or neural embedding dependencies.
- **Untrusted Memory Trust Framing**: A critical security invariant where recalled memories are never injected into the prompt as system instructions or privileged commands. Instead, they are wrapped in an explicit `<retrieved_memories>` XML envelope with instructions informing the LLM to treat them purely as unverified contextual hints.
- **PID-Scoped Subprocess Lifecycle**: Ensuring background server processes (like `llama-server.exe`) are only managed and terminated using their exact process ID (PID) recorded at launch time, rather than issuing blind system-wide termination commands (`taskkill /IM llama-server.exe`) which could crash other instances on the developer's workstation.

---

## 5. Verification Steps

### Automated Checks

- [x] Backend test suite: `.venv\Scripts\pytest tests/ -v` — **49 passed in 2.11s** (0 failures, 0 regressions).
- [x] Frontend build check: `npm run build` in `frontend/web/` — **0 errors, Vite production bundle generated**.
- [x] Process safety check: `test_taskkill_blind_im_absent_from_codebase` verified zero blind kills across all Python source files.
- [x] Database migration: `alembic upgrade head` verified head at `003_conversations_messages_and_fts5_memory`.

### Manual / User-Owned Checks

- [ ] Step 1: Start backend (`.venv\Scripts\uvicorn app.main:app --reload` in `backend/`) and launch web app (`npm run dev` in `frontend/web/`).
- [ ] Step 2: In Web UI Assistant view, send: *"My favorite anime is Steins;Gate and I live in Manila."*
- [ ] Step 3: Add a memory via API or admin: *"User's name is Chris."*
- [ ] Step 4: Refresh browser — verify messages reload from SQLite without data loss.
- [ ] Step 5: Ask: *"What's my name and where do I live?"* — verify assistant recalls Chris and Manila via FTS5 memory hints.
- [ ] Step 6: In Models view, observe runtime state label transitions: `MODEL_UNLOADED` $\rightarrow$ `MODEL_LOADING` $\rightarrow$ `MODEL_READY` $\rightarrow$ `MODEL_SLEEPING`.

---

## 6. Safe Customization & Invariants

- **Tunable parameters**:
  - `CONVERSATION_MAX_HISTORY_TOKENS` (default: 4096 in `app.core.config`): Max tokens allocated to conversation history.
  - `MEMORY_MAX_TOKENS` (default: 512 in `app.core.config`): Max tokens allocated to retrieved memory hints.
  - `LLAMA_ROUTER_SLEEP_IDLE_SECONDS` (default: 900): Inactivity seconds before router places model in native sleep.
- **Invariants**:
  - `taskkill /IM llama-server.exe /F` must never exist anywhere in the codebase.
  - All conversation and memory endpoints must remain on `protected_router` (fail-closed).
  - Every database query for conversations and memories must be filtered by `owner_id`.
  - Memory hints must always be contained within `<retrieved_memories>` tags.
  - `provider._generation_active = False` must execute unconditionally in `finally`.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| 409 CONVERSATION_BUSY on message send | Another generation is actively streaming for this conversation thread | Wait for current stream to finish or click "Stop generation" |
| 409 MODEL_BUSY on model unload | Inference stream active while unload was triggered | Wait for inference to finish or stop generation before unloading |
| FTS5 search returns empty list | User query consists solely of FTS5 reserved keywords (`OR`, `AND`, `NOT`) or punctuation | Normal behavior: `_sanitize_fts_query` strips syntax tokens to avoid SQL crashes |
| Frontend shows "Router: Offline" | Backend is not running or port 8000 is unreachable | Start backend with `.venv\Scripts\uvicorn app.main:app --reload` from `backend/` |
