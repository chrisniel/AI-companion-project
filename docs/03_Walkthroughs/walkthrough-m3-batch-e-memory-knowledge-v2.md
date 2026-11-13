# Walkthrough: Milestone M3 Batch E — Memory & Knowledge Architecture V2

> **Branch:** `feature/m3-memory-knowledge-e`
> **Plan:** [`plan-m3-memory-knowledge-e.md`](../02_Planning/01_Plans/plan-m3-memory-knowledge-e.md)
> **Canonical Spec:** [`memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md)

---

## 1. What Was Delivered

Batch E upgraded the flat memory store into a 3-tier **Memory & Knowledge Architecture V2** built for small local LLMs (e.g., 2B/4B parameter models running inside tight 2,048–4,096 token context budgets):

1. **Three Logical Tiers (`knowledge`, `long_term`, `short_term`):** Separated permanent profile facts & keyword lorebooks from learned durable preferences/episodes and 72-hour decaying situational context.
2. **Database & API Schema Extension (Migration 013):** Added `trigger_keywords` (JSON string array) and `recall_count` (bounded `>= 0`) with full SQLite FTS5 trigger preservation, `GET /api/v1/memories?tier=...` filtering, and profile-wide tier counts.
3. **Extraction & Reconciliation Guardrails:** Deterministic 72h TTL for situational context, immediate verification + `importance >= 1.5` floor for explicit *"Remember that..."* commands, immutable protection of Fixed Knowledge against background AI overwrites, and cross-session consolidation/promotion of recurring short-term episodes.
4. **On-Demand Lorebooks & Multi-Section Prompt Assembly:** Stem/prefix-aware keyword lorebooks (`get_triggered_knowledge`), FTS5 prefix queries (`token*`), recall tracking/ranking boosts, and structured XML prompt sections (`<user_core_profile>`, `<triggered_knowledge_lore>`, `<episodic_and_long_term_memories>`, `<short_term_context>`).
5. **Option 2A Desktop Memory Control Center:** Added the inner left Soft Glass tier sub-menu (`MemoryTierSidebar` with responsive narrow fallback), context-aware creation CTAs (`+ Add Knowledge`, `+ Add Memory`, `+ Add Context`), lorebook `#keyword` inputs/pills, `RECALLED N×` and `TTL` badges, and 1-click **Promote** buttons.

---

## 2. Files Changed

| Area | File | Purpose |
| :--- | :--- | :--- |
| Migration | `backend/migrations/versions/013_memory_knowledge_and_triggers.py` | Add `trigger_keywords` + `recall_count`, rebuild FTS5 safely |
| ORM & Schemas | `backend/app/models/memory.py`, `backend/app/schemas/memory.py` | Tier classification properties, keyword normalization, tier counts |
| REST API | `backend/app/api/v1/endpoints/memories.py` | `?tier=` SQL predicates, `q` keyword matching, profile tier counts |
| Memory Engine | `backend/app/services/memory/extractor.py`, `reconciler.py`, `retriever.py` | 72h TTL, explicit intent boost, fixed knowledge lock, cross-session promotion, stem/prefix lorebook & recall boost |
| Orchestrator | `backend/app/services/assistant/orchestrator.py` | 4-section XML `<retrieved_memories>` assembly with per-section token caps |
| Contracts & SDK | `contracts/openapi/openapi.json`, `frontend/flutter/packages/companion_api/lib/{dto/memory_dto.dart,client/companion_client.dart}` | OpenAPI regeneration & Dart DTO/client parity |
| Desktop UI | `frontend/flutter/apps/desktop/lib/features/memory/{memory_tier_sidebar.dart,desktop_memory_controller.dart,memory_filter_bar.dart,memory_edit_dialog.dart,memory_item_card.dart}`, `lib/screens/memory_screen.dart` | Option 2A inner sub-menu, lorebook editor/chips, recall & TTL badges, 1-click Promote |
| Tests | `backend/tests/test_migration_013.py`, `backend/tests/test_memory_knowledge_tiers.py`, `backend/tests/test_schema_lifecycle.py`, `backend/tests/test_prepare_database_schema_backup.py`, `frontend/flutter/packages/companion_api/test/companion_client_test.dart`, `frontend/flutter/apps/desktop/test/memory_screen_test.dart` | Migration lifecycle, tier/lorebook/XML prompt tests, SDK & widget tests |

---

## 3. How the Logic Works

1. **Event Trigger / Input:**
   - User opens **Memory & Knowledge** -> Desktop fetches unresolved conflicts and `GET /api/v1/memories?tier=knowledge`, populating all three tier counts in `MemoryTierSidebar`.
   - User sends a chat message -> `AssistantOrchestrator.orchestrate_chat_stream` runs retrieval before building the prompt, and triggers `_run_post_turn_memory_extraction` asynchronously after SSE `done`.
2. **Validation & Authorization:**
   - Every memory read/write validates the active `ProfileSession` via `validate_profile_session` and enforces `WHERE profile_id = :profile_id`.
   - Keyword lorebooks normalize trimmed lowercase non-empty terms; `recall_count` enforces non-negative DB CHECK constraints (`ck_memories_recall_count`).
3. **Core Domain Processing:**
   - `get_core_memories` excludes keyword-gated lorebooks so dormant knowledge consumes `0` baseline tokens.
   - `get_triggered_knowledge` activates dormant lorebooks via normalized phrase or ASCII prefix overlap ($\ge 3$ chars) and increments `recall_count` in the DB.
   - `search_relevant_memories` executes sanitized prefix FTS5 queries (`token*`), combines BM25 rank order with importance and bounded recall frequency boost, and increments `recall_count`.
   - `AssistantOrchestrator._build_context` packs deduplicated records into `<user_core_profile>` ($\le 120$), `<triggered_knowledge_lore>` ($\le 150$), `<episodic_and_long_term_memories>` ($\le 200$), and `<short_term_context>` ($\le 100$).
   - Post-turn `extractor` assigns a 72h TTL to situational context unless explicitly commanded to remember (`user_verified=True`, `importance >= 1.5`), while `reconciler` blocks auto-overwrites of Fixed Knowledge and promotes recurring ($\ge 12$h apart) short-term episodes.
4. **Completion & Output State:**
   - Prompt receives neatly compartmentalized `<retrieved_memories>` XML blocks tailored for 2B models.
   - UI cards reflect `RECALLED N×` badges, remaining `TTL` countdown badges, `#keyword` pills, and 1-click **Promote** transitions (`expires_at: null`, `category: 'fact'`, `source_type: 'user_explicit'`, `user_verified: true`).
5. **Error Handling & Recovery / Cancellation:**
   - FTS5 sanitization filters reserved operators (`AND`, `OR`, `NOT`) and strips punctuation before constructing `token*`.
   - Alembic `013` downgrade refuses destructive column removal if any non-null `trigger_keywords` or positive `recall_count` exists (unless explicitly overridden for disposable test teardowns).
   - Background extraction executes inside an isolated session with explicit rollback on exceptions.

---

## 4. Key Concepts

- **Keyword Lorebook (`trigger_keywords`):** Fixed knowledge that stays dormant at `0` context-token cost until conversation text mentions one of its configured keywords or stems (e.g., `cook` activating on `"cooking"`).
- **Fixed Knowledge Write-Protection:** Guardrail preventing background LLM extraction from mutating or overwriting user-pinned (`is_core=True`), `manual`, or lorebook knowledge records.
- **Deterministic Situational Decay & Consolidation:** Assigning a default 72-hour expiration (`expires_at`) to transient `context` statements so chat episodes do not pollute long-term memory, while automatically extending or promoting facts confirmed across sessions ($\ge 12$h apart).

---

## 5. Verification Steps

### Automated Commands & Observed Results
- `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_migration_013.py backend/tests/test_schema_lifecycle.py backend/tests/test_prepare_database_schema_backup.py -v` -> **14 passed**
- `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_memory_knowledge_tiers.py backend/tests/test_memory_foundation.py backend/tests/test_memory_fts.py backend/tests/test_memory_reconciliation.py backend/tests/test_memory_extraction_pipeline.py backend/tests/test_assistant_orchestrator.py -v` -> **50 passed**
- `backend/.venv/Scripts/python.exe -m pytest backend/tests -q` -> **788 passed**
- `backend/.venv/Scripts/python.exe scripts/check_openapi_contract.py --check` -> **0 errors** (`44` routes)
- `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py --check` -> **Passed** (`32/32` DTO schemas, `42/26` M1+M2 covered routes)
- `dart test` (`frontend/flutter/packages/companion_api`) -> **97 passed**
- `flutter analyze` (`frontend/flutter/apps/desktop`) -> **No issues found**
- `flutter test` (`frontend/flutter/apps/desktop`) -> **353 passed** (including 11/11 in `test/memory_screen_test.dart`)
- `npm --prefix frontend/web test -- --run` -> **248 passed** (`16` test files)
- `npm --prefix frontend/web run build` -> **Succeeded** (`vite build` exit `0`)

### Manual Windows Acceptance Checklist
1. Switch between **Knowledge & Profile**, **Long-Term Memories**, and **Short-Term Context** in Desktop **Memory & Knowledge** (`Option 2A` sidebar) and verify live item counts and context-aware `+ Add` CTA labels.
2. Create an unpinned Knowledge entry with trigger keywords `sarah, cook` and verify `#sarah` / `#cook` pills render and `RECALLED 1×` increments after mentioning *"cooking dinner for Sarah"* in Chat.
3. Say *"I have a huge presentation tonight"* in Chat and verify a **Short-Term Context** card appears with an active ~`TTL 2D/3D LEFT` badge.
4. Click **Promote** on that Short-Term Context card and confirm it moves permanently into **Long-Term Memories** (`expires_at` cleared, `VERIFIED`).
5. Say *"Please remember that I am allergic to peanuts"* in Chat and confirm immediate `VERIFIED` save without waiting for manual review, while attempting a contradictory casual message does not overwrite an existing `manual` Fixed Knowledge rule.

---

## 6. Safe Customization & Invariants

- **Token Budget Constants:** `<user_core_profile>` (`120`), `<triggered_knowledge_lore>` (`150`), `<episodic_and_long_term_memories>` (`200`), and `<short_term_context>` (`100`) are bounded inside `AssistantOrchestrator._build_context`.
- **Short-Term TTL:** `DEFAULT_SHORT_TERM_TTL_HOURS = 72` in `backend/app/services/memory/extractor.py`; cross-session recurrence gap (`timedelta(hours=12)`) in `backend/app/services/memory/reconciler.py`.
- **Invariant:** `expires_at != None` always takes precedence for `is_short_term` so expiring test/context entries can never leak into permanent core knowledge even if `is_core=True`.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| Dormant lorebook triggers during unrelated turns | Trigger keyword is too broad (e.g., short 3-letter common root matching unrelated words) | Use specific keywords or multi-word phrases (exact normalized phrase match for 2+ words). |
| Edit dialog or list overflows on narrow desktop window | Window resized `< 720px` | `MemoryScreen` automatically switches `MemoryTierSidebar` to compact horizontal strip under `720px`. |
| Migration 013 downgrade aborts | `trigger_keywords` or `recall_count > 0` already contains user data | Clear/archive populated columns explicitly before downgrading past `013`. |
