# Implementation Plan: Milestone M3 Batch D — Persistent Emotion & Mood Engine, Companion Grounding & Stream Safeguards

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Implemented & Verified (Phase 2 & Phase 3 Complete on `feature/m3-emotion-mood-engine-d`)
- **Delivery Level:** Level B — Planned Autonomous (Core Architecture Feature Implementation under Approved Decisions D11/ADR-0012)
- **Work Breakdown Structure IDs:** `PC-CHAR-003`, `PC-CHAR-004`, `PC-CHAR-002` (grounding refinement), `PC-CLIENT-006`, `PC-CLIENT-007`
- **Scope Mode:** New Feature & Quality Polish — Persistent bounded companion mood simulation, elapsed-time decay, pre-generation turn appraisal, natural companion grounding, DRY/stream safeguards, and live desktop mood presentation.
- **Target Files:**
  - `backend/migrations/versions/012_character_mood_and_emotion.py` (new)
  - `backend/app/models/character_instance.py`
  - `backend/app/schemas/character.py`
  - `backend/app/services/emotion/__init__.py` (new)
  - `backend/app/services/emotion/mood_engine.py` (new)
  - `backend/app/services/emotion/appraisal.py` (new)
  - `backend/app/services/character_service.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `backend/tests/test_prepare_database_schema_backup.py`
  - `backend/tests/test_schema_lifecycle.py`
  - `contracts/openapi/openapi.json`
  - `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart`
  - `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart`
  - `frontend/flutter/apps/desktop/lib/screens/chat_screen.dart`
  - `frontend/flutter/apps/desktop/lib/features/studio/studio_inspector_panel.dart`
  - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
  - `docs/01_Tracking/active/task-feature-m3-emotion-mood-engine-d.md`
- **Branch:** `feature/m3-emotion-mood-engine-d`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-emotion-mood-engine-d.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m3-emotion-mood-engine-d.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### Primary Objective
Deliver Milestone 3 Batch D, completing the Character, Personality, and Emotion track by introducing:
1. **Persistent Bounded Emotion & Mood Dynamics (`PC-CHAR-003`)**: SQLite persistence of companion mood and intensity across application and Windows restarts, with deterministic elapsed-time rebalancing toward baseline during user absence.
2. **Turn Appraisal Engine & Typed Emotion Events (`PC-CHAR-004`)**: Zero-latency deterministic appraisal evaluating user conversational cues prior to response generation so the companion reacts emotionally on the immediate turn while strictly obeying D11 Mood Isolation (mood alters social presentation/style only; never facts, memories, tool safety, or permissions).
3. **Natural Companion Prompt Grounding (`PC-CHAR-002` refinement)**: Resolve the "lacking vs. overacting" persona split by adding concise conversational grounding directives inside `<character_persona>` that suppress unprompted `*stage directions*`, rhetorical self-interruption loops, and melodrama while keeping all existing security and context-budget invariants intact.
4. **DRY Sampling & Stream Degeneracy Circuit Breaker**: Add `llama.cpp` DRY n-gram sampling parameters and a sliding-window SSE stream circuit breaker that truncates runaway phrase repetition before it reaches the UI.
5. **Live Mood Presentation (`PC-CLIENT-006`, `PC-CLIENT-007`)**: Subtle mood badge with guaranteed emoji glyph fallback (`D-PHONE-UX-10` aligned) in the Desktop Chat header, Welcome card, and Character Studio Inspector, auto-refreshing upon turn completion.

### Relevant Canonical Requirements
- **[`SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md)**: Decision D11 (Persona, State & Continuity Separation).
- **[`characters-personality-and-emotion.md`](../../04_Architecture/01_Domains/characters-personality-and-emotion.md)**: §2.1.5 (Persistent Simulated Mood Dynamics & Mood Isolation), §2.3 (Emoji Fallback & Presentation Isolation), §4.4 (`PC-CHAR-003`).
- **[`ADR-0012-d11-persona-and-state-separation.md`](../../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md)**: Strict separation of Profile, Character Instance, Mood, and Memory.

### Concrete Deliverables
1. **Alembic Migration 012**: Add `current_mood`, `mood_intensity`, and `mood_updated_at` to `character_instances` with full SQLite trigger and partial index preservation, constraint updates, and loss-aware fail-closed downgrade.
2. **Mood Engine & Elapsed-Time Rebalancing Service**: Deterministic integer rebalancing toward baseline (`calm`, intensity `50`) based on elapsed time since `mood_updated_at`, evaluated on read and turn resolution.
3. **Pre-Generation Turn Appraisal Engine**: Heuristic conversational cue evaluator (gratitude/warmth, playful banter/teasing, stress/sadness/comfort, curiosity/questions, return after long gap) that updates and persists mood state prior to prompt assembly.
4. **Natural Companion Prompt Directives**: Inject concise conversational grounding and active mood state inside `<character_persona>` in `resolve_turn_persona_prompt()`, preserving all delimiter-escaping and 4,096-token context-budget invariants.
5. **DRY Sampling & Stream Repetition Circuit Breaker**: Pass DRY parameters to `llama-server` and enforce a sliding-window token stream guard that halts generation if any 4+-word phrase repeats $\ge 3$ times consecutively or within the window.
6. **Desktop UI Live Mood Badge & Auto-Refresh**: Display companion's current mood with emoji glyph in `ChatScreen` and `StudioInspectorPanel`, with `DesktopChatController` refreshing the cached `CharacterInstanceOut` upon turn completion.
7. **OpenAPI & Dart SDK Parity**: Synchronize `contracts/openapi/openapi.json` and `character_dto.dart`, verified by `scripts/check_dart_openapi_parity.py`.

### Explicit Out-of-Scope
- Multi-dimensional clinical affective modeling (e.g., 3D PAD vectors) — strictly bounded to 7 discrete non-clinical moods and `0..100` intensity per Decision D11.
- Mobile AR / 3D Live2D rendering runtimes — remains scheduled for PC Later / Mobile follow-on.
- Relationship familiarity / intimacy depth progression — formally decoupled under Decision D11 and scheduled for PC Later.
- Scheduling, Reminders, Alarms, and Routines (`PC-SCHED-001`..`005`, `PC-CLIENT-008`) — scheduled as the next dedicated Milestone 3 track.

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Observation / Evidence | Verified Interpretation |
| :--- | :--- |
| `character_instances` in Migration 009 has 5 SQLite triggers referencing it (`trg_character_instances_immutable_provenance`, `trg_character_instances_deactivate_clear_profile`, `trg_profiles_active_character_owner_insert/update`, `trg_conversations_character_owner_insert`) and partial index `uq_character_instances_profile_legacy_id`. | In SQLite, `op.batch_alter_table("character_instances")` recreates the table. All 5 triggers must be dropped before `batch_alter_table` and recreated immediately after, and the partial index must be preserved, followed by `PRAGMA foreign_key_check`. |
| `test_prepare_database_schema_backup.py` and `test_schema_lifecycle.py` assert `HEAD_REVISION = "011_profile_memory_extraction_toggle"`. | Adding Migration 012 requires updating `HEAD_REVISION` in both test files to `"012_character_mood_and_emotion"`. |
| `test_character_personality_modulator.py` asserts `prompt.count("<character_persona>") == 2`, `prompt.endswith("</character_persona>")`, and $\ge 512$ available generation tokens in a 4,096-token window with 30 history messages and 8 memories. | Mood and Conversational Grounding lines must be placed *inside* `<character_persona>` and kept compact ($\le 280$ chars combined) so all existing delimiter and token-budget tests continue to pass with wide margin. |
| `characters-personality-and-emotion.md` §2.1.5 states: *"Do NOT mandate exponential decay in the durable architecture."* | The durable specification keeps the decay curve configurable, while the V1 implementation uses a clean, deterministic integer step decay toward baseline `50` without floating-point drift. |
| `DesktopChatController` caches `CharacterInstanceOut` in `_characterCache`. | If appraisal ran in a slow post-turn background task, the UI could fetch stale mood state. Running `<1ms` deterministic appraisal *before* generation and refreshing `_characterCache[instanceId]` when the turn completes guarantees immediate reaction and zero race conditions. |

### 1. Approved Bounded Mood State Model (`PC-CHAR-003`)
Companion mood is represented by 7 canonical non-clinical states (`CharacterMoodId`):
- `calm` — Relaxed, composed baseline state (Emoji glyph: `😌`)
- `cheerful` — Warm, upbeat, happy (Emoji glyph: `😊`)
- `playful` — Witty, mischievous, energetic banter (Emoji glyph: `😄`)
- `thoughtful` — Reflective, analytical, contemplative (Emoji glyph: `🤔`)
- `empathetic` — Caring, comforting, gentle support (Emoji glyph: `🥺`)
- `curious` — Intrigued, inquisitive, engaged (Emoji glyph: `✨`)
- `attentive` — Focused, reliable, alert (Emoji glyph: `🎯`)

**Intensity Scalar (`0..100`, default `50`):**
- `0..19` / `20..39`: Subtle / Mild
- `40..59`: Balanced / Baseline (`50` is neutral equilibrium)
- `60..79`: Warm / Engaged
- `80..100`: Expressive / High (strictly capped at `100`)

**Database Invariants:**
- Non-legacy `CharacterInstance` rows always have non-null `current_mood IN ('calm', 'cheerful', 'playful', 'thoughtful', 'empathetic', 'curious', 'attentive')`, `mood_intensity BETWEEN 0 AND 100`, and `mood_updated_at IS NOT NULL`.
- Legacy placeholder rows (`is_legacy_placeholder = 1`) have `current_mood IS NULL`, `mood_intensity IS NULL`, and `mood_updated_at IS NULL`, enforced by `ck_character_instances_legacy_or_standard`.
- Neutral Assistant (`is_neutral_fallback = True`) is stateless and does not use simulated mood.

### 2. Deterministic Elapsed-Time Rebalancing (`mood_engine.py`)
When evaluating a Character Instance at time $t_{\text{now}}$:
1. Compute elapsed seconds $\Delta t = \max(0, (t_{\text{now}} - \text{mood\_updated\_at}).\text{total\_seconds}())$.
2. Every 30 minutes ($1,800\text{s}$) of elapsed absence steps `mood_intensity` by $5$ points toward baseline equilibrium (`50`):
   $$\text{steps} = \lfloor \Delta t / 1800 \rfloor$$
   $$\text{rebalanced\_intensity} = \begin{cases} \max(50, \text{intensity} - 5 \times \text{steps}) & \text{if intensity} > 50 \\ \min(50, \text{intensity} + 5 \times \text{steps}) & \text{if intensity} < 50 \\ 50 & \text{otherwise} \end{cases}$$
3. Once $\Delta t \ge 4\text{ hours}$ ($14,400\text{s}$) and `rebalanced_intensity == 50`, `current_mood` settles back to the character's trait-derived baseline mood (default `'calm'`; `'cheerful'` if `warmth >= 75` and `guardedness < 60`; `'playful'` if `teasing >= 75` and `guardedness < 60`; `'attentive'` if `formality >= 75`).
4. This integer arithmetic is 100% deterministic, requires no floating-point exponentials, and ensures that after a few hours or a restart, the companion naturally settles back to their baseline temperament.

### 3. Pre-Generation Turn Appraisal Engine (`PC-CHAR-004`, `appraisal.py`)
Before assembling the system prompt for a user turn:
1. Apply elapsed-time rebalancing to the bound `CharacterInstance`.
2. Evaluate `appraise_turn(user_text, current_mood, mood_intensity, traits, elapsed_seconds)`:
   - **Distress / Venting / Comfort Cues** (e.g., *"rough day"*, *"stressed"*, *"sad"*, *"exhausted"*, *"anxious"*, *"tired"*, *"hurt"*): shifts mood to `'empathetic'`, intensity bounded in `65..85` (modulated by `warmth`).
   - **Gratitude / Warmth / Praise Cues** (e.g., *"thank you"*, *"thanks"*, *"you're amazing"*, *"love talking"*, *"glad"*, *"appreciate"*): shifts mood to `'cheerful'`, intensity `65..85`.
   - **Playful Banter / Humor Cues** (e.g., *"lmao"*, *"haha"*, *"lol"*, *"teasing"*, *"bet you"*, playful emojis): shifts mood to `'playful'` (or `'cheerful'` if `teasing < 30`), intensity `60..80`.
   - **Deep / Analytical / Philosophical Queries** (e.g., *"why do you think"*, *"explain how"*, *"compare"*, *"philosophy"*, *"meaning"*): shifts mood to `'thoughtful'` or `'curious'`, intensity `55..75`.
   - **Curiosity / Recommendation / Exploration Queries** (e.g., *"what about"*, *"recommend"*, *"suggest"*, *"have you heard"*): shifts mood to `'curious'`, intensity `55..70`.
   - **Normal / Neutral Turn**: nudges intensity gently toward `55` while retaining current mood (or baseline if at `50`).
3. Persist the updated `(current_mood, mood_intensity, mood_updated_at)` on the `CharacterInstance` row so both the current turn's prompt and subsequent API reads reflect the new state immediately.

### 4. Natural Companion Grounding & Prompt Assembly
Inside `resolve_turn_persona_prompt()`, within `<character_persona>`:
```text
Current Mood: Cheerful (Intensity: 70/100) — Warm, upbeat, and pleased; let this gently color your tone without overriding factual accuracy.

Conversational Grounding:
- Speak naturally like a close, attentive companion in real-time chat, matching the user's casual energy.
- Answer questions and topic requests substantively first before adding banter.
- Never use asterisk stage directions (*leans in*, *smiles*), scripted self-interruptions ("Wait... nope!"), or repetitive catchphrases.
```
This block is $\approx 260$ characters ($\approx 65$ tokens), keeping the total `<character_persona>` block well inside the 4,096-token budget test requirements while directly curing the "corporate bot vs. overacting roleplayer" issue.

### 5. DRY Sampling & Stream Degeneracy Circuit Breaker
- **`llama_cpp.py`**: Include `dry_multiplier: 0.8`, `dry_base: 1.75`, `dry_allowed_length: 2`, and `dry_penalty_last_n: 128` in standalone `llama-server` payloads alongside `repeat_penalty: 1.15` and `min_p: 0.05`.
- **`orchestrator.py` (`_guard_repetitive_stream`)**: Wrap the token generator in a lightweight sliding-window detector that tracks normalized 4-word n-grams in the assistant's current response. If any 4-word phrase repeats $\ge 3$ times, the generator stops yielding runaway tokens, sets `finish_reason = "repetition_cutoff"`, and cleanly terminates the turn.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/012_character_mood_and_emotion.py`
- **Primary Responsibility:** Upgrade `character_instances` schema with persistent mood columns while preserving all SQLite triggers, foreign keys, and partial indexes.
- **Planned Change:**
  1. Drop the 5 triggers referencing `character_instances`.
  2. Drop partial index `uq_character_instances_profile_legacy_id`.
  3. Run `op.batch_alter_table("character_instances")` to add `current_mood` (`String(32)`, nullable=True, server_default `'calm'`), `mood_intensity` (`Integer`, nullable=True, server_default `'50'`), and `mood_updated_at` (`DateTime(timezone=True)`, nullable=True), backfill standard rows (`is_legacy_placeholder = 0`) with `'calm'`, `50`, `CURRENT_TIMESTAMP` and legacy rows (`is_legacy_placeholder = 1`) with `NULL`, and replace `ck_character_instances_legacy_or_standard` to enforce valid mood values on standard instances and `NULL` on legacy placeholders.
  4. Recreate `uq_character_instances_profile_legacy_id` and all 5 SQLite triggers.
  5. Verify `PRAGMA foreign_key_check`.
  6. Implement loss-aware fail-closed `downgrade()` (refuses downgrade if any instance has non-default mood shift unless clean, or safely restores schema).

### [MODIFY] `backend/app/models/character_instance.py`
- **Primary Responsibility:** ORM mapping for `CharacterInstance`.
- **Planned Change:** Add `current_mood`, `mood_intensity`, and `mood_updated_at` columns and update `ck_character_instances_legacy_or_standard`.

### [MODIFY] `backend/app/schemas/character.py`
- **Primary Responsibility:** Pydantic DTOs for Character endpoints.
- **Planned Change:** Define `CharacterMoodId = Literal["calm", "cheerful", "playful", "thoughtful", "empathetic", "curious", "attentive"]` and add `current_mood: Optional[CharacterMoodId] = None`, `mood_intensity: Optional[int] = None`, and `mood_updated_at: Optional[datetime] = None` to `CharacterInstanceOut`.

### [ADD] `backend/app/services/emotion/mood_engine.py` & `appraisal.py`
- **Primary Responsibility:** Deterministic mood baseline resolution, elapsed-time step decay, and pre-generation turn appraisal.
- **Planned Change:** Implement `resolve_baseline_mood(traits)`, `rebalance_mood_for_elapsed_time(...)`, `appraise_user_turn(...)`, and `compile_mood_directive(...)`.

### [MODIFY] `backend/app/services/character_service.py`
- **Primary Responsibility:** Character instance CRUD and `resolve_turn_persona_prompt()`.
- **Planned Change:**
  - Initialize `current_mood`, `mood_intensity=50`, `mood_updated_at=now_utc()` on instance creation.
  - Apply elapsed-time rebalancing when mapping `CharacterInstanceOut`.
  - Add `appraise_and_update_conversation_mood()` and inject the compact Mood + Conversational Grounding lines inside `<character_persona>` in `resolve_turn_persona_prompt()`.

### [MODIFY] `backend/app/services/assistant/orchestrator.py`
- **Primary Responsibility:** Chat turn orchestration and SSE token streaming.
- **Planned Change:**
  - Call `appraise_and_update_conversation_mood()` before `resolve_turn_persona_prompt()`.
  - Wrap the LLM token stream in `_guard_repetitive_stream()` to halt runaway n-gram repetition loops.

### [MODIFY] `backend/app/services/llm/llama_cpp.py`
- **Primary Responsibility:** Local `llama-server` and `llama_cpp` inference requests.
- **Planned Change:** Add DRY sampling parameters (`dry_multiplier: 0.8`, `dry_base: 1.75`, `dry_allowed_length: 2`, `dry_penalty_last_n: 128`) to `llama-server` HTTP payloads.

### [MODIFY] `contracts/openapi/openapi.json` & `frontend/flutter/packages/companion_api/lib/dto/character_dto.dart`
- **Primary Responsibility:** OpenAPI contract and Dart DTO parity.
- **Planned Change:** Export updated OpenAPI schema and add `currentMood`, `moodIntensity`, `moodUpdatedAt`, and helper `moodEmoji` / `moodLabel` to `CharacterInstanceOut` in `character_dto.dart`.

### [MODIFY] `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart`, `lib/screens/chat_screen.dart` & `lib/features/studio/studio_inspector_panel.dart`
- **Primary Responsibility:** Desktop Chat and Character Studio UI.
- **Planned Change:**
  - Add `getConversationCharacterMoodBadge(Conversation?)` to `DesktopChatController` and refresh the active conversation's cached `CharacterInstanceOut` when a message stream completes.
  - Render a compact Mood Pill (e.g. `😊 Cheerful`) next to the Character badge in `ChatScreen` header and `StudioInspectorPanel`.

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Step 1 — Migration 012 & ORM Model (Backend TDD):**
   - Write `backend/tests/test_migration_012.py` testing upgrade, trigger preservation, legacy placeholder `NULL` enforcement, and downgrade safety.
   - Implement `012_character_mood_and_emotion.py`, update `character_instance.py`, and update `HEAD_REVISION` in `test_prepare_database_schema_backup.py` and `test_schema_lifecycle.py`.
2. **Step 2 — Mood Engine, Elapsed-Time Decay & Turn Appraisal (Backend TDD):**
   - Write `backend/tests/test_mood_engine_and_appraisal.py` covering baseline derivation, 30-minute step decay across simulated restarts, and turn appraisal across distress, gratitude, playful, curious, and neutral inputs.
   - Implement `backend/app/services/emotion/mood_engine.py` and `appraisal.py`.
3. **Step 3 — Natural Companion Grounding & Stream Circuit Breaker (Backend TDD):**
   - Add tests in `test_character_personality_modulator.py` and `test_mood_engine_and_appraisal.py` verifying `<character_persona>` grounding directives, mood line inclusion, 4,096-token budget compliance, DRY payload keys, and stream repetition cutoff.
   - Update `character_service.py`, `orchestrator.py`, and `llama_cpp.py`.
4. **Step 4 — OpenAPI Contract & Dart SDK Parity (Contract TDD):**
   - Regenerate `contracts/openapi/openapi.json`, update `character_dto.dart` and `character_dto_test.dart`, and verify `scripts/check_dart_openapi_parity.py` + `dart test`.
5. **Step 5 — Desktop Chat & Studio Live Mood UI (Flutter TDD):**
   - Update `desktop_chat_controller.dart`, `chat_screen.dart`, and `studio_inspector_panel.dart`.
   - Add widget tests in `desktop_chat_test.dart` / `studio_screen_test.dart` verifying mood badge rendering and post-turn refresh.
6. **Step 6 — Phase 3 Documentation, Closure & Draft PR:**
   - Sync `characters-personality-and-emotion.md`, `CHANGELOG.md`, walkthrough, `task.md`, `DELIVERY_INDEX.md`, `WBS.md`, and `MASTER_CHECKLIST.md`, archive branch tracker, push, and open Draft PR.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [x] Backend Migration 012 & Schema Lifecycle: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_migration_012.py backend/tests/test_schema_lifecycle.py backend/tests/test_prepare_database_schema_backup.py -v` (14 passed)
- [x] Backend Mood, Appraisal & Modulator Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_mood_engine_and_appraisal.py backend/tests/test_character_personality_modulator.py backend/tests/test_character_foundation.py -v` (34 passed)
- [x] Backend Full Regression Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests` (779 passed)
- [x] OpenAPI Contract Verification: `backend/.venv/Scripts/python.exe scripts/check_openapi_contract.py --check` (PASSED — 44 routes)
- [x] Dart OpenAPI Parity: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py` (PASSED — 32/32 schemas, 42 routes)
- [x] Dart API Package Tests: `dart test` (in `frontend/flutter/packages/companion_api` — 96 passed)
- [x] Flutter Desktop Tests & Analyze: `flutter analyze` (No issues found) and `flutter test` (in `frontend/flutter/apps/desktop` — 350 passed)

### Manual & Host-Level Checks (Where Applicable)
- [ ] Launch Desktop App and confirm active character conversation displays the live mood pill in the Chat header (e.g., `😌 Calm` or `😊 Cheerful`).
- [ ] Send an appreciative or playful message and verify the mood pill updates automatically when the reply finishes.
- [ ] Confirm companion responses sound natural and conversational without unprompted `*stage directions*` or repetition loops.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Risk:* SQLite `batch_alter_table` dropping triggers on `character_instances`.
  - *Safeguard:* Explicitly drop and recreate all 5 triggers and partial index in Migration 012, verified by automated trigger regression tests in `test_migration_012.py`.
  - *Risk:* Additional prompt lines overflowing small context windows.
  - *Safeguard:* Mood + Grounding directives are strictly bounded to $< 280$ characters ($\approx 70$ tokens) and verified against the 4,096-token context budget test.
- **Dependencies & Assumptions:** Existing Alembic chain `001..011` intact; local Python `.venv` and Flutter SDK available.
- **Required Permissions:** Task-bounded branch commits, push, and draft PR on `feature/m3-emotion-mood-engine-d`.
- **Genuine Stop Conditions:** Unresolvable migration/trigger conflict, contract parity failure, or test regression.
