# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Architecture Reconciled / Awaiting Claude B5 Plan Revision
- Current Sprint: Pre-B5 Architecture Reconciliation & Track B5 Preparation
- Branch: `feature/assistant-orchestration-and-memory`
- Target: Canonical architecture reconciliation complete; handoff to Claude for Track B5 plan revision before implementation.
- Scope Guard: Documentation & architectural contracts only in this phase; no application code changes.

## [CURRENT EXECUTION STATE - RECONCILIATION COMPLETE]

- Active Files:
  - `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
  - `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`
  - `docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md`
  - `docs/02_Planning/plan-assistant-orchestration-and-memory.md` (to be revised by Claude)
- Current Status: Pre-B5 Master Architecture Reconciliation completed.
- Next Action: Claude revises Track B5 plan (`docs/02_Planning/plan-assistant-orchestration-and-memory.md`) to align with reconciled architecture; Gemini then executes B5 coding.

## Active Checklist

- [x] Task Pre-B5.1: Reconcile `AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` with active repository facts (B1, B2, B4, C2).
- [x] Task Pre-B5.2: Create canonical `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md` (router mode, sleep vs unload, PID-scoped kill).
- [x] Task Pre-B5.3: Create canonical `docs/04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md` (V0–V6 roadmap, CPU-first speech, barge-in).
- [x] Task Pre-B5.4: Document Qwen3-VL portfolio (2B/4B/8B, Instruct/Thinking), ModelRegistry, and decoupled runtime profiles.
- [ ] Task B5.0: Claude revises `docs/02_Planning/plan-assistant-orchestration-and-memory.md` for Track B5 execution.
- [ ] Task B5.1: Create ORM models (`Conversation`, `Message`, `Memory`) & Alembic migration 003 with SQLite FTS5 virtual table.
- [ ] Task B5.2: Implement `MemoryRetriever` service with FTS5 keyword matching and soft-delete filtering.
- [ ] Task B5.3: Implement `AssistantOrchestrator` service (persona injection, FTS5 memories, context window, LLM streaming).
- [ ] Task B5.4: Implement REST API endpoints (`/api/v1/conversations`, `/api/v1/memories`) and register in router.
- [ ] Task B5.5: Connect React Web `AssistantView.tsx` with `conversationApi` for persistent chat threads.
- [ ] Task B5.6: Author automated test suite (`test_conversations.py`, `test_memory_fts.py`, `test_assistant_orchestrator.py`) and verify 100% pass rate.
- [ ] Task B5.7: Manual end-to-end verification, walkthrough documentation, and task archiving.

