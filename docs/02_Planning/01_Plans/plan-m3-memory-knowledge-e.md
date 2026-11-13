# Implementation Plan: Milestone M3 Batch E — Memory & Knowledge Architecture V2

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval (Phase 1 Planning Complete)
- **Delivery Level:** Level B — Planned Autonomous (Core Architecture Feature Implementation under Approved Decision D7 & ADR-0018)
- **Work Breakdown Structure IDs:** `PC-MEM-002` (guardrails & TTL), `PC-MEM-006` (3-tier memory & keyword lorebook), `PC-CLIENT-009` (Memory Control Center 3-tier inner sub-menu UI)
- **Scope Mode:** New Feature & Architectural Revamp — 3-Tier memory model (Fixed Knowledge, Long-Term Memory, Short-Term Context), Alembic Migration 013 (`trigger_keywords` + `recall_count`), deterministic 72h Short-Term TTL decay, background AI overwrite protection for Fixed Knowledge, stem/prefix-aware keyword lorebook retrieval, explicit `"Remember that..."` instant verification & importance boost, structured multi-section prompt assembly, and Desktop UI revamp with Option 2A inner left sub-menu & context-aware creation CTA.
- **Target Files:**
  - `backend/migrations/versions/013_memory_knowledge_and_triggers.py` (new)
  - `backend/app/models/memory.py`
  - `backend/app/schemas/memory.py`
  - `backend/app/services/memory/retriever.py`
  - `backend/app/services/memory/extractor.py`
  - `backend/app/services/memory/reconciler.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `contracts/openapi/openapi.json`
  - `frontend/flutter/packages/companion_api/lib/dto/memory_dto.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/desktop_memory_controller.dart`
  - `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_tier_sidebar.dart` (new)
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_filter_bar.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_edit_dialog.dart`
  - `frontend/flutter/apps/desktop/lib/features/memory/memory_item_card.dart`
  - `backend/tests/test_migration_013.py` (new)
  - `backend/tests/test_memory_knowledge_tiers.py` (new)
  - `frontend/flutter/apps/desktop/test/memory_screen_test.dart`
- **Branch:** `feature/m3-memory-knowledge-e`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-memory-knowledge-e.md`

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective
Revamp companion memory and knowledge systems from a single flat list of facts into a robust, structured **3-tier architecture** ([ai-companion-memory-guide.md](file:///d:/Download/ai-companion-memory-guide.md)) separating:
1. **Fixed Knowledge & User Profile**: Core identity, user-defined rules, and keyword-triggered lorebook entries, permanently protected from background AI modification.
2. **Long-Term & Episodic Memory**: Semantic preferences and character-scoped shared milestones retrieved on-demand via FTS5.
3. **Short-Term Context**: Active situational states with a deterministic 72-hour default TTL decay, visible countdown in the UI, and 1-click promotion to long-term memory.

### 1.2 Relevant Canonical Requirements
- **Decision D7 & ADR-0018:** All memories remain strictly owned by the active Profile (`profile_id`), supporting `PROFILE` and `CHARACTER` scopes.
- **Decision D-SHARED-AI-03:** Unified context retrieval across distinct sources without flattening separate lifecycles into a single generic store.
- **Context Budget Manager (`D-SHARED-AI-01`):** Maintain strict token budgeting for prompt context across 2B-parameter models (`qwen3-vl-2b-instruct`).

### 1.3 Concrete Deliverables
1. **Alembic Migration 013 (`trigger_keywords` & `recall_count` Columns)**: Adds `trigger_keywords` JSON text column and `recall_count` (`Integer, default=0, nullable=False`) column to `memories`, with trigger and FTS5 preservation, and fail-closed downgrade protection.
2. **Deterministic Short-Term TTL Decay, Explicit Intent Boost & Fixed Knowledge Protection**:
   - Situational context (`category == "context"` or temporal indicators like *today, tonight, currently*) receives a deterministic 72-hour `expires_at` default from Python upon creation.
   - Explicit `"Remember that..."` intent (`is_explicit_intent(user_text)`) immediately marks extracted candidates `user_verified = True` and boosts their importance floor to `>= 1.5`.
   - `reconciler.py` enforces that auto-extracted candidates cannot merge into or overwrite manual or pinned core knowledge (`is_core = True` or `source_type == "manual"`).
   - Re-mentioning an active short-term context item across sessions either refreshes its TTL or promotes it to long-term memory (`expires_at = None`).
3. **Stem/Prefix-Aware Keyword-Triggered Lorebook & Recall Tracking (`PC-MEM-006`)**:
   - Dormant knowledge entries with defined trigger words (e.g. `["project-x", "tokyo", "sarah"]`) activate when matching terms or stem prefixes (e.g. `"cook"` matching `"cooking"`, `"sarah"` matching `"Sarah's"`) appear in recent conversation turns, saving active context window budget.
   - FTS5 retrieval uses prefix matching (`token*`) and increments `recall_count` whenever a memory is retrieved into active prompt context, factoring recall frequency into retrieval priority.
4. **Structured Multi-Section XML Prompt Context**:
   - Replaces monolithic `<retrieved_memories>` with distinct, semantically partitioned XML tags: `<user_core_profile>`, `<triggered_knowledge_lore>`, `<episodic_and_long_term_memories>`, and `<short_term_context>`.
5. **Desktop Memory Control Center UI Revamp — Option 2A Inner Sub-Menu (`PC-CLIENT-009`)**:
   - Inner left sub-menu (`memory_tier_sidebar.dart`, `~210px`) inside `MemoryScreen` separating the 3 tiers right next to the main navigation rail for minimal cursor travel:
     - 📌 **Knowledge & Profile** (live count + subtitle *Locked rules & #lorebook*)
     - 🧠 **Long-Term Memories** (live count + subtitle *Durable facts & preferences*)
     - ⏳ **Short-Term Context** (live count + subtitle *72h working state*)
   - Responsive fallback to a compact horizontal selector if the window width narrows below split-pane threshold.
   - Context-aware `+ Add` CTA and `MemoryEditDialog` defaults per active tier (`+ Add Knowledge`, `+ Add Memory`, `+ Add Context`), plus keyword tag chip editor, `Recalled N×` badge, TTL remaining badge, and 1-click *Promote* button.

### 1.4 Explicit Out-of-Scope
- Standalone vector embedding database / dense semantic search (reserved for PC Later per Decision D7).
- Modifying character personality presets, emotion engine, or mood step decay (frozen in Batch D).

### 1.5 Documented Follow-On ("Big Benefits" Scheduled for Next Batch M3-F)
Per canonical architecture decisions **`D-SHARED-AI-01`**, **`D-SHARED-AI-02`**, and **`D-SHARED-AI-03`** in [`assistant-and-conversations.md`](../../04_Architecture/01_Domains/assistant-and-conversations.md) and [`BACKLOG.md`](../00_Master/BACKLOG.md), the following high-impact memory & context capabilities are documented for the immediately following implementation batch:
1. **Pre-Limit Context Compaction & Rolling Conversation Summaries (`D-SHARED-AI-01` & `D-SHARED-AI-02`):**
   - Automatic compaction before reaching the configured/effective safe context limit, plus explicit user-triggered `Compact context` action.
   - Persists rolling episode digests (`conversation_summaries`) as **derived conversation records** (preserving raw SQLite transcript authority and provenance without polluting canonical `D7` `memories`) and injects `<recent_episode_digest>` under `D-SHARED-AI-03`.
2. **Emotion-Weighted Memory Importance (`D11` + `D7` Synergy):**
   - Boosts initial `importance` (`+0.3`) when facts are extracted during high-intensity emotional turns (`user_distress` / `empathetic` or `user_gratitude` / `cheerful`).
3. **Temporal Fact Evolution ("Used to..." Historical Supersession Trail):**
   - Preserves prior values and transition timestamps when `reconciler.py` performs an `UPDATE` on a mutable fact (e.g., *"Lives in Cebu (previously Manila until Nov 2026)"*).
4. **Chat Bubble "Quick Capture to Memory / Knowledge" Action:**
   - 1-click bookmark action on chat bubbles in `ChatScreen` to save any turn directly into Knowledge Base or Episodic Memory.

---

## 2. Architecture & Technical Approach

### 2.1 Current Technical Baseline
| Subsystem | Current State | Architecture Problem / Gap |
| :--- | :--- | :--- |
| **Data Model (`Memory`)** | Flat table storing facts, preferences, and context together. | No mechanism for keyword-triggered dormancy or explicit 3-tier presentation. |
| **Extraction (`extractor.py`)** | Prompts LLM for ISO `expires_at` string. | 2B local models almost always emit `"expires_at": null`, turning temporary banter into permanent clutter. |
| **Reconciler (`reconciler.py`)** | `MERGE` and `UPDATE` slots can mutate manual facts. | Auto-extraction can contaminate carefully curated user knowledge. |
| **Prompt Injection (`orchestrator.py`)** | Injects `<retrieved_memories>` and `<core_facts>`. | Model cannot distinguish reference lore from user identity or fleeting situational states. |
| **Desktop UI (`MemoryScreen`)** | Single scrolling list with category/scope filter chips. | Cluttered view where high-value knowledge is buried among automated chat snippets. |

### 2.2 The 3-Tier Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Tier 1: Fixed Knowledge Base & User Profile (Locked / Curated)               │
│ - is_core = True OR source_type = 'manual' OR trigger_keywords IS NOT NULL │
│ - Injected into <user_core_profile> and <triggered_knowledge_lore>          │
│ - Immutable to background LLM extraction (conflicts only via banner)        │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       ▲ User Pin (★) / Manual Creation
┌──────────────────────────────────────┴──────────────────────────────────────┐
│ Tier 2: Long-Term & Episodic Memory (Semantic / Shared History)             │
│ - category IN ('fact', 'preference') AND expires_at IS NULL                 │
│ - Scoped by Profile or Character instance                                    │
│ - Injected into <episodic_and_long_term_memories> via FTS5 relevance         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       ▲ Recurring across sessions / 1-Click Promote
┌──────────────────────────────────────┴──────────────────────────────────────┐
│ Tier 3: Short-Term Context (Dynamic Working State)                           │
│ - category == 'context' OR expires_at IS NOT NULL                           │
│ - Default 72-hour TTL decay; auto-excluded upon expiration                  │
│ - Injected into <short_term_context>                                        │
│ - Shows visible countdown pill (⏳ 48h left) with 1-click "Promote"         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/013_memory_knowledge_and_triggers.py`
- Add `trigger_keywords` nullable `Text` column to `memories` table (JSON array of strings, e.g. `["project-x", "tokyo"]`).
- Add `recall_count` non-nullable `Integer` column (`server_default="0"`) to `memories` table.
- Recreate FTS5 triggers safely ensuring `trigger_keywords` and `recall_count` do not break index synchronization.
- Implement fail-closed `downgrade()` refusing rollback if any non-null `trigger_keywords` or non-zero `recall_count` exist.

### [MODIFY] `backend/app/models/memory.py`
- Add `trigger_keywords: Mapped[Optional[str]] = mapped_column(Text, nullable=True)`.
- Add `recall_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)`.
- Helper properties: `is_fixed_knowledge`, `is_short_term`, `is_long_term`.

### [MODIFY] `backend/app/schemas/memory.py`
- Add `trigger_keywords: Optional[List[str]] = None` to `MemoryCreate`, `MemoryUpdate`, `MemoryOut`.
- Add `recall_count: int = 0` to `MemoryOut`.
- Add `tier: Optional[Literal["knowledge", "long_term", "short_term"]] = None` query filter parameter to `MemoryList`.

### [MODIFY] `backend/app/services/memory/extractor.py` & `reconciler.py`
- In `extractor.py`:
  - When a candidate has `category == "context"` or contains temporal phrases (*today, tonight, this week, right now*), deterministically set `expires_at = now + 72 hours` in Python if null.
  - When `is_explicit_intent(user_text)` is true (e.g., *"Remember that..."*, *"Don't forget..."*), immediately set `user_verified = True` and enforce an importance floor `importance = max(candidate.importance, 1.5)`.
- In `reconciler.py`:
  - Protect Fixed Knowledge: If existing memory has `is_core = True` or `source_type == "manual"`, candidate CANNOT execute `UPDATE` or `MERGE`. It must either be `DUPLICATE` (touch `last_verified_at`), `NEW`, or `CONFLICT`.
  - Consolidation: When a candidate matches an existing Short-Term memory in a later session ($> 12$ hours later), extend TTL by 72 hours or promote to Long-Term (`expires_at = None`) if verified twice.

### [MODIFY] `backend/app/services/memory/retriever.py` & `orchestrator.py`
- In `retriever.py`:
  - Implement `get_triggered_knowledge(profile_id, user_message_tokens)`: Queries memories with `trigger_keywords IS NOT NULL`, scanning token overlap with stem/prefix matching (so `"cook"` matches `"cooking"` and `"sarah"` matches `"Sarah's"`).
  - Use FTS5 prefix queries (`token*`) for long-term retrieval and increment `recall_count` on retrieved memories, adding a bounded recall-frequency boost (`0.05 * min(recall_count, 10)`) to ranking.
  - Separate queries for Core Profile, Triggered Knowledge, Relevant Long-Term, and Active Short-Term.
- In `orchestrator.py`:
  - Format distinct XML prompt sections:
    - `<user_core_profile>` ($\le 120$ tokens)
    - `<triggered_knowledge_lore>` ($\le 150$ tokens, only when keywords match)
    - `<episodic_and_long_term_memories>` ($\le 200$ tokens)
    - `<short_term_context>` ($\le 100$ tokens)

### [MODIFY] `contracts/openapi/openapi.json` & `companion_api`
- Regenerate OpenAPI specification.
- Update `memory_dto.dart` with `triggerKeywords`, `recallCount`, and parity assertions.

### [ADD / MODIFY] `frontend/flutter/apps/desktop/lib/screens/memory_screen.dart` & `features/memory/`
- **Inner Left Sub-Menu (`memory_tier_sidebar.dart`, Option 2A):**
  - Renders a `~210px` vertical sub-menu inside `MemoryScreen` (positioned immediately adjacent to the main app navigation rail) with icon, title, live item count badge, and 1-line subtitle for each tier:
    1. 📌 **Knowledge & Profile** (Core pinned facts, manual rules, Lorebook entries with `#tag` chips).
    2. 🧠 **Long-Term Memories** (Durable preferences and character-scoped memories).
    3. ⏳ **Short-Term Context** (Situational context with `⏳ 48h remaining` badge and 1-click **Promote** button).
  - Automatically falls back to a compact horizontal tier switcher when viewport width is narrow.
- In `memory_filter_bar.dart`: Make the primary CTA label and creation defaults context-aware to the selected tier (`+ Add Knowledge`, `+ Add Memory`, `+ Add Context`).
- In `memory_edit_dialog.dart`: Accept `initialTier` preset defaults (`knowledge` defaults `sourceType='manual'` / shows `Trigger Keywords`; `short_term` defaults `category='context'` + 72h TTL) and include the `Trigger Keywords` comma-separated tag input.
- In `memory_item_card.dart`: Display trigger keyword pills, `Recalled N×` badge when `recallCount > 0`, and 1-click "Promote to Long-Term" action for short-term cards.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Step 1 — Migration 013 & Data Model (Backend TDD):**
   - Write `backend/tests/test_migration_013.py` (upgrade, triggers, downgrade protection).
   - Implement `013_memory_knowledge_and_triggers.py` and update `Memory` model.
2. **Step 2 — Extractor TTL, Reconciler Protection & Consolidation (Backend TDD):**
   - Write `backend/tests/test_memory_knowledge_tiers.py` verifying:
     - 72h default TTL for context category.
     - Fixed knowledge immunity against auto-extraction `UPDATE`/`MERGE`.
     - Consolidation of recurring short-term memories.
     - Keyword trigger matching against user turn text.
   - Update `extractor.py`, `reconciler.py`, and `retriever.py`.
3. **Step 3 — Multi-Section Prompt Assembly (Backend TDD):**
   - Verify prompt injection outputs `<user_core_profile>`, `<triggered_knowledge_lore>`, `<episodic_and_long_term_memories>`, `<short_term_context>`.
   - Update `orchestrator.py` and verify context budget tests.
4. **Step 4 — OpenAPI Contract & Dart SDK Parity (Contract TDD):**
   - Regenerate `openapi.json`, update `memory_dto.dart`, and verify parity scripts (`scripts/check_dart_openapi_parity.py`).
5. **Step 5 — Desktop Option 2A Inner Sub-Menu & Lorebook UI (Flutter TDD):**
   - Update `desktop_memory_controller.dart`, `memory_screen.dart`, add `memory_tier_sidebar.dart`, and update `memory_filter_bar.dart`, `memory_edit_dialog.dart`, `memory_item_card.dart`.
   - Add widget tests in `memory_screen_test.dart` verifying Option 2A inner sub-menu tier switching, live tier counts, context-aware `+ Add` defaults, trigger keyword chips, `Recalled N×` badge, and 1-click promotion.
6. **Step 6 — Phase 3 Documentation, Closure & Draft PR:**
   - Update `memory-and-personalization.md`, `CHANGELOG.md`, create walkthrough, reconcile tracking, commit, push, and open Draft PR.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend Migration 013 & Schema: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_migration_013.py backend/tests/test_schema_lifecycle.py backend/tests/test_prepare_database_schema_backup.py -v`
- [ ] Backend Memory Tiers & Knowledge Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_memory_knowledge_tiers.py backend/tests/test_memory_foundation.py -v`
- [ ] Full Backend Regression Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests -q`
- [ ] OpenAPI Contract Verification: `backend/.venv/Scripts/python.exe scripts/check_openapi_contract.py --check`
- [ ] Dart OpenAPI Parity: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py --check`
- [ ] Companion API Tests: `dart test` (in `frontend/flutter/packages/companion_api`)
- [ ] Flutter Desktop Tests & Analyze: `flutter analyze` & `flutter test` (in `frontend/flutter/apps/desktop`)
- [ ] React Web Tests & Build: `npm --prefix frontend/web test -- --run` & `npm --prefix frontend/web run build`

### Manual & Host-Level Checks
- [ ] Open **Memory & Knowledge** in Desktop app and verify the inner left sub-menu (`Option 2A`) switches cleanly between **Knowledge & Profile**, **Long-Term Memories**, and **Short-Term Context** with accurate item counts.
- [ ] Add a Knowledge entry with trigger keywords `["anime", "movie"]`. Verify it appears under Knowledge Base with trigger pills.
- [ ] Say *"I had a really tiring day today"* in Chat. Verify it is extracted into **Short-Term Context** with a `⏳ 3d` badge.
- [ ] Click **Promote** on a Short-Term Context card and confirm it moves to **Long-Term Memories** with `expires_at = null`.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Context Window Budget:** 2B models have tight 2048/4096 context windows. Splitting into sections must enforce hard token bounds ($\le 120$ tokens core, $\le 150$ tokens lore, $\le 200$ tokens long-term, $\le 100$ tokens short-term).
- **SQLite FTS5 Triggers:** Adding `trigger_keywords` must preserve FTS5 triggers without breaking full-text search.
- **Genuine Stop Conditions:** Database migration failure, FTS5 sync corruption, or contract parity failure.
