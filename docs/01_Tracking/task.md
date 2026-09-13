# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Planning (Pending User Plan Approval)
- Current Sprint: Track B5 — Assistant Orchestration, Persistent Conversations & SQLite FTS5 Memory
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Deliver persistent conversations, message history, FTS5 keyword memory retrieval, prompt context packaging, and Web client integration.
- Scope Guard: Only Track B5 bounded items; no audio/STT/TTS in this slice.

## [CURRENT EXECUTION STATE - PLANNING]

- Active Files:
  - `docs/02_Planning/plan-assistant-orchestration-and-memory.md`
  - Implementation Plan Artifact (`implementation_plan.md`)
- Current Status: Implementation plan authored and presented for user review.
- Next Action: Await user approval of implementation plan before writing code.

## Active Checklist

- [ ] Task B5.1: Create ORM models (`Conversation`, `Message`, `Memory`) & Alembic migration 003 with SQLite FTS5 virtual table.
- [ ] Task B5.2: Implement `MemoryRetriever` service with FTS5 keyword matching and soft-delete filtering.
- [ ] Task B5.3: Implement `AssistantOrchestrator` service (persona injection, FTS5 memories, context window, LLM streaming).
- [ ] Task B5.4: Implement REST API endpoints (`/api/v1/conversations`, `/api/v1/memories`) and register in router.
- [ ] Task B5.5: Connect React Web `AssistantView.tsx` with `conversationApi` for persistent chat threads.
- [ ] Task B5.6: Author automated test suite (`test_conversations.py`, `test_memory_fts.py`, `test_assistant_orchestrator.py`) and verify 100% pass rate.
- [ ] Task B5.7: Manual end-to-end verification, walkthrough documentation, and task archiving.

