# Walkthrough: Milestone M3 Batch F — Pre-Limit Context Compaction, Rolling Conversation Summaries & Memory V2 Follow-On

> **Branch:** `feature/m3-context-compaction-memory-f`
> **Plan:** [`plan-m3-context-compaction-memory-f.md`](../02_Planning/01_Plans/plan-m3-context-compaction-memory-f.md)
> **Canonical Specs:** [`assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md), [`memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md)

---

## 1. What Was Delivered

Batch F addresses long-conversation context overflow, rolling episode continuity, emotional/temporal memory quality, 1-click in-chat memory bookmarking, and Batch E independent-review hardening:

1. **Pre-Limit Conversation Compaction & Rolling Summaries (Migration `014`, `ConversationSummary`):** Added persisted `conversation_summaries` rows with sequence bounds (`from_sequence_no`, `to_sequence_no`), single-active-row partial unique index (`uq_conversation_summaries_one_active`), source tracking (`auto`, `manual`, `extractive_fallback`), conversation soft-delete and `ProfilePurgeService` cascade cleanup, plus Migration `013` unused `import json` cleanup.
2. **Automatic & Manual Episode Compaction (`compactor.py`, `orchestrator.py`, `config.py`):** Configured `CONTEXT_COMPACTION_*` thresholds (`0.72` ratio, keep recent `8`, min `4`, summary `<= 180` tokens). `ConversationCompactor` compacts older turns ahead of the recent tail using low-temperature LLM summarization with deterministic `extractive_fallback` and injects active digests inside `<recent_episode_digest>` with XML delimiter escaping (`escape_prompt_xml_delimiters`), preserving raw `messages` immutability and separation from canonical `memories`.
3. **Conversation Summary & Compaction API (`endpoints/conversations.py`, `schemas/conversation.py`):** Added `GET /api/v1/conversations/{conversation_id}/summary` and `POST /api/v1/conversations/{conversation_id}/compact` with OpenAPI and `companion_api` Dart DTO/client parity.
4. **Memory V2 Follow-On & Batch E Hardening (`extractor.py`, `reconciler.py`, `retriever.py`, `schemas/memory.py`, `endpoints/memories.py`):** Added `+0.3` emotion-weighted importance boost (`<= 2.0`), single-step `(previously: ... until YYYY-MM)` temporal evolution suffix, `MemoryUpdate.clear_expires_at` Short-Term promotion flag, pre-slice `exclude_ids`, `profile_id`-scoped `recall_count` increment, keyword-lorebook exclusion from legacy short-term fallback, defensive non-core flag stripping, FTS5 `NEAR` operator reservation, and null-safe JSON parsing.
5. **Flutter Desktop Chat & Memory Controls (`desktop_chat_controller.dart`, `desktop_memory_controller.dart`, `chat_screen.dart`):** Added `Episode Digest` header badge/dialog (`Key('episode_digest_badge')`), responsive `Compact Context` control (`Key('compact_context_button')`), 1-click per-bubble memory/knowledge bookmark menu (`Key('bookmark_message_${msg.id}')`), atomic summary + message loading on conversation switch, and `clearExpiresAt: true` Short-Term promotion.

---

## 2. Files Changed

| Area | File | Purpose |
| :--- | :--- | :--- |
| Migrations & Models | `backend/migrations/versions/014_conversation_summaries_and_compaction.py`, `013_memory_knowledge_and_triggers.py`, `backend/app/models/conversation_summary.py`, `backend/app/models/__init__.py`, `backend/app/db/base.py` | `conversation_summaries` table/indexes, `ConversationSummary` ORM, Migration `013` cleanup |
| Compaction & Config | `backend/app/core/config.py`, `backend/app/services/assistant/compactor.py`, `backend/app/services/assistant/orchestrator.py` | Pre-limit thresholds, rolling digest generator + `extractive_fallback`, `<recent_episode_digest>` XML injection & delimiter escaping |
| API, Schemas & Purge | `backend/app/api/v1/endpoints/conversations.py`, `backend/app/schemas/conversation.py`, `backend/app/api/v1/endpoints/memories.py`, `backend/app/schemas/memory.py`, `backend/app/services/profile_purge_service.py` | `GET /summary`, `POST /compact`, `clear_expires_at`, purge & soft-delete cascade |
| Memory V2 & Hardening | `backend/app/services/memory/{extractor.py,reconciler.py,retriever.py}` | Emotion boost, temporal evolution trail, Batch E retrieval & extraction hardening |
| Contracts & Parity | `contracts/openapi/openapi.json`, `scripts/check_dart_openapi_parity.py`, `scripts/tests/test_check_dart_openapi_parity.py`, `frontend/flutter/packages/companion_api/{lib/client/companion_client.dart,lib/dto/conversation_dto.dart,lib/dto/memory_dto.dart,test/companion_client_test.dart}` | `46`-route OpenAPI contract & `companion_api` DTO/client parity |
| Desktop UI & State | `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart`, `lib/features/memory/desktop_memory_controller.dart`, `lib/screens/chat_screen.dart` | Summary loading/compaction, bookmarking, `clearExpiresAt` promote, responsive UI controls |
| Tests & Docs | `backend/tests/{test_context_compaction.py,test_memory_knowledge_tiers.py,test_prepare_database_schema_backup.py,test_schema_lifecycle.py}`, `frontend/flutter/apps/desktop/test/{desktop_chat_test.dart,desktop_memory_controller_test.dart}`, canonical docs, WBS/checklist/index/tracking/changelog | Automated tests across all layers + Phase 3 canonical documentation closure |

---

## 3. How the Logic Works

1. **Pre-Limit Evaluation & Manual Compaction:** Before building chat history in `AssistantOrchestrator`, or when `POST /api/v1/conversations/{conversation_id}/compact` is called, `ConversationCompactor` checks whether uncompacted turns exceed `CONTEXT_COMPACTION_TRIGGER_RATIO` (`0.72` of the active context budget) and leave at least `CONTEXT_COMPACTION_MIN_MESSAGES` (`4`) older turns before the `CONTEXT_COMPACTION_KEEP_RECENT_MESSAGES` (`8`) recent tail.
2. **Rolling Digest Generation & Immutability:** `ConversationCompactor` merges any existing active `ConversationSummary` with the newly compacted span into an updated single active summary (`is_active = True`, `from_sequence_no`..`to_sequence_no`), falling back cleanly to deterministic `_extractive_episode_digest` when LLM summarization is unavailable or produces unusable placeholder text. Raw `messages` rows are never modified or deleted.
3. **Prompt Assembly & Security Boundaries:** `AssistantOrchestrator` injects active episode digests inside `<recent_episode_digest>` (escaped with `escape_prompt_xml_delimiters`) alongside multi-section `<retrieved_memories>` and recent turns strictly after `to_sequence_no`, keeping episode digests strictly separated from canonical `memories`.
4. **Memory V2 Follow-On & Promotion:** `extractor.py` applies a `+0.3` importance adjustment (clamped `<= 2.0`) for emotionally weighted statements; `reconciler.py` records single-step `(previously: ... until YYYY-MM)` history on mutable slot updates while respecting Fixed Knowledge locks; and Desktop **Promote** passes `MemoryUpdate(clearExpiresAt: true, ...)` instead of implicit `null` JSON fields.
5. **Atomic Conversation Switching in Desktop:** `DesktopChatController.selectConversation` awaits `loadMessages` and `loadConversationSummary` together via `Future.wait` so profile/session switches settle cleanly without dangling async HTTP calls.

---

## 4. Verification Steps

### Automated Commands & Observed Results (Run After Final Code Edits)
- `backend\.venv\Scripts\python.exe -m pytest backend/tests -q` -> **`796 passed, 77 warnings in 377.63s`** (exit `0`)
- `backend\.venv\Scripts\python.exe scripts/check_openapi_contract.py --check` -> **`OpenAPI contract is up-to-date (46 routes, all required model routes present)`** (exit `0`)
- `backend\.venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check` -> **`ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED (35/35 schemas, 44/26 routes)`** (exit `0`)
- `backend\.venv\Scripts\python.exe -B -m unittest scripts/tests/test_check_dart_openapi_parity.py` -> **`Ran 8 tests in 0.147s — OK`** (exit `0`)
- `npm --prefix frontend/web run lint` -> **`tsc --noEmit passed`** (exit `0`)
- `npm --prefix frontend/web test -- --run` -> **`Test Files 16 passed (16), Tests 248 passed (248)`** (exit `0`)
- `npm --prefix frontend/web run build` -> **`vite build succeeded (1737 modules transformed)`** (exit `0`)
- `dart test` (`frontend/flutter/packages/companion_api`) -> **`99` tests passed** (exit `0`)
- `flutter analyze` (`frontend/flutter`) -> **`No issues found!`** (exit `0`)
- `flutter test` (`frontend/flutter/apps/desktop`) -> **`+356: All tests passed!`** (exit `0`)

### Manual Windows Acceptance Checklist
1. Open an active conversation with `< 3` messages in Flutter Desktop **Chat** and confirm the `Compact Context` button (`OutlinedButton` with label on wide window, icon-only on `< 900px` narrow window) is disabled; send messages until `>= 3` messages exist and confirm the button becomes enabled.
2. Continue chatting until at least `12` messages exist (default `KEEP_RECENT_MESSAGES = 8` + `MIN_MESSAGES = 4`), click `Compact Context` (or let pre-limit auto-compaction trigger when uncompacted context exceeds `72%`), confirm the `Episode Digest` badge appears in the chat header, click it to inspect the compacted range (`from_sequence_no..to_sequence_no`), and confirm all historical chat bubbles remain intact in the timeline.
3. Click the top-right bookmark menu on both a User bubble and an Assistant bubble, test **Save to Long-Term Memory** and **Pin to Fixed Knowledge**, and verify the newly created verified records appear under the corresponding tier in **Memory & Knowledge**.
4. In **Memory & Knowledge -> Short-Term Context**, click **Promote** on an expiring entry and confirm it moves cleanly to **Long-Term Memories** without any remaining TTL badge.
5. Delete a compacted conversation (or purge a test profile) and verify no orphaned `conversation_summaries` remain in SQLite.
