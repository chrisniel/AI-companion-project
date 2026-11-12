# Implementation Plan: Milestone M3 Batch D — Persistent Emotion & Mood Engine, Companion Grounding & Stream Safeguards

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Awaiting Approval (Phase 1 Planning Complete)
- **Delivery Level:** Level B — Planned Autonomous (Core Architecture Feature Implementation under Approved Decisions D11/ADR-0012)
- **Work Breakdown Structure IDs:** `PC-CHAR-003`, `PC-CHAR-004`, `PC-CLIENT-008`, `PC-LLM-002`
- **Scope Mode:** New Feature & Quality Polish — Persistent bounded companion mood simulation, elapsed-time decay, turn appraisal, natural companion grounding, DRY/stream safeguards, and live desktop mood presentation.
- **Target Files:**
  - `backend/migrations/versions/012_character_mood_and_emotion.py`
  - `backend/app/models/character_instance.py`
  - `backend/app/schemas/character.py`
  - `backend/app/services/emotion/mood_engine.py` (new)
  - `backend/app/services/emotion/appraisal.py` (new)
  - `backend/app/services/character_service.py`
  - `backend/app/services/assistant/orchestrator.py`
  - `backend/app/services/llm/llama_cpp.py`
  - `frontend/flutter/packages/companion_api/lib/src/models/character_instance.dart`
  - `frontend/flutter/apps/desktop/lib/features/chat/chat_screen.dart`
  - `frontend/flutter/apps/desktop/lib/features/studio/studio_screen.dart`
  - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
  - `docs/01_Tracking/active/task-feature-m3-emotion-mood-engine-d.md`
- **Branch:** `feature/m3-emotion-mood-engine-d`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m3-emotion-mood-engine-d.md`

---

## 1. Request Understanding & Goals

### Primary Objective
Deliver Milestone 3 Batch D, completing the Character and Intelligence domain by introducing:
1. **Persistent Bounded Emotion & Mood Dynamics (`PC-CHAR-003`)**: SQLite storage of companion mood and intensity across application and Windows restarts, with time-based emotional decay toward baseline during user absence.
2. **Turn Appraisal Engine & Typed Emotion Events (`PC-CHAR-004`)**: Zero-latency appraisal evaluating user conversational cues to shift mood states naturally, adhering strictly to D11 isolation rules (mood alters presentation/style only; never facts, tool safety, or permissions).
3. **Natural Companion Prompt Grounding**: Fix persona overacting, eliminate unprompted `*stage directions*` and rhetorical loops, and align assistant tone to sound like a genuine companion rather than a sterile corporate bot or exaggerated caricature.
4. **DRY Sampling & Stream Degeneracy Circuit Breaker (`PC-LLM-002`)**: Add `llama.cpp` DRY n-gram sampling parameters and an SSE stream circuit breaker that truncates runaway phrase repetition before it reaches the UI.
5. **Live Mood Presentation (`PC-CLIENT-008`)**: Subtle mood badge with emoji glyph fallback in the Desktop Chat header and Character Studio.

### Relevant Canonical Requirements
- **[`SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md)**: Decision D11 (Persona, State & Continuity Separation).
- **[`characters-personality-and-emotion.md`](../../04_Architecture/01_Domains/characters-personality-and-emotion.md)**: §2.1.5 (Persistent Simulated Mood Dynamics), §2.3 (Emoji Fallback & Presentation Isolation), §4.4 (Persistent Mood Dynamics `PC-CHAR-003`).
- **[`ADR-0012-d11-persona-and-state-separation.md`](../../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md)**: Strict separation of Profile, Character Instance, Mood, and Memory.

### Concrete Deliverables
1. **Alembic Migration 012**: Add `current_mood`, `mood_intensity`, and `mood_updated_at` to `character_instances` table with verified upgrade/downgrade safety and constraint preservation.
2. **Mood Engine & Decay Service**: Compute elapsed-time decay back toward baseline temperament (`calm`, intensity 50) using a smooth half-life formula when hours/days have elapsed.
3. **Turn Appraisal Engine**: Heuristic sentiment and conversational cue evaluator (gratitude, warmth, playful teasing, stress/venting, question/curiosity, return after gap) that updates mood state asynchronously after each turn.
4. **Natural Companion Prompt Directives**: Update `resolve_turn_persona_prompt()` with strict conversational grounding directives forbidding asterisk stage directions, rhetorical self-interruption loops, and theatrical melodrama.
5. **DRY Sampling & Stream Repetition Circuit Breaker**: Pass DRY parameters to `llama-server` and enforce a token stream buffer that halts generation if 4-word substrings repeat $\ge 3$ times.
6. **Desktop UI Live Mood Badge**: Display companion's current mood with an emoji glyph in the Chat header and Character Studio.
7. **Dart OpenAPI Parity & Test Suites**: Full backend and Flutter test verification for mood transitions, decay across time, prompt grounding, and UI rendering.

### Explicit Out-of-Scope
- Complex multi-dimensional clinical psychological modeling (e.g., 3D PAD vectors) — strictly bounded to 7 discrete moods and 0–100 intensity per D11.
- Mobile AR / 3D Live2D rendering runtimes — remains scheduled for PC Later / Mobile follow-on.
- Relationship familiarity / intimacy depth progression — formally decoupled under Decision D11 and scheduled for PC Later (`PC-CHAR-004` follow-on).

---

## 2. Architecture & Technical Approach

### Current Findings & Technical Baseline

| Component | Current State | Target Enhancement |
| :--- | :--- | :--- |
| `character_instances` table | Migration 009 defines lore, system_prompt, preset_id, and 8 static traits (0–100). | Migration 012 adds `current_mood` (VARCHAR 32), `mood_intensity` (INT 0–100), and `mood_updated_at` (DATETIME). |
| Mood Persistence | Mood state does not exist in the database; models have static sliders only. | Persistent mood stored per Character Instance; survives process restarts and rebalances with elapsed time. |
| Persona Resolution | `resolve_turn_persona_prompt()` injects `DEFAULT_PERSONA` + `<character_persona>` with 8-trait directives. | Injects natural companion grounding (suppressing `*actions*`, matching casual energy) + current dynamic mood state clause. |
| Generation Runner | Passes `repeat_penalty: 1.15`, `min_p: 0.05`, `stop` tokens. | Adds `llama.cpp` DRY sampling parameters and SSE stream sliding-window repetition circuit breaker. |
| Desktop Chat Header | Shows conversation character name badge and new chat destination badge. | Adds companion mood status badge with emoji glyph (e.g. `😊 Cheerful • 65%`). |

### 1. The Approved Mood State Model
To keep the model predictable, bounded, and free of clinical complexity, mood is modeled as one of 7 canonical companion emotional states:
- `calm` (Baseline relaxed/neutral state, emoji: 😌)
- `cheerful` (Warm, upbeat, pleased, emoji: 😊)
- `playful` (Mischievous, teasing, energetic, emoji: 😋)
- `thoughtful` (Reflective, analytical, deep, emoji: 🤔)
- `empathetic` (Soft, caring, comforting, emoji: 🥺)
- `curious` (Intrigued, inquisitive, engaged, emoji: 🧐)
- `attentive` (Focused, supportive, alert, emoji: 🫡)

Each mood carries an **intensity** scalar (0–100):
- 0–29: Subtle / Mild
- 30–69: Moderate / Standard
- 70–100: Pronounced / Expressive

### 2. Elapsed-Time Decay Formula
When resolving a turn:
$$\Delta t = \text{now\_utc}() - \text{mood\_updated\_at}$$
If $\Delta t > 0$, the mood intensity decays toward baseline (50) with a 4-hour half-life:
$$\text{decayed\_intensity} = 50 + (\text{current\_intensity} - 50) \times e^{-\frac{\Delta t}{\tau}}$$
where $\tau = 4 \times 3600$ seconds. If intensity falls within $[47, 53]$ and $\Delta t \ge 6 \text{ hours}$, `current_mood` resets to `'calm'`.
This mathematically guarantees the companion feels naturally grounded: returning after hours or days away rebalances the companion without abrupt amnesia.

### 3. Natural Companion Prompt Directives
We update `resolve_turn_persona_prompt()` with the **Companion Conversational Grounding Preamble**:
```text
[Conversational Grounding Rules]
- Talk naturally like an attentive, close human companion chatting on PC.
- Prioritize addressing the user's actual question or topic genuinely and substantively first.
- NEVER use third-person stage directions, narrative action tags (e.g. *leans in*, *smiles warmly*), or excessive asterisks. Express emotion through genuine word choice, phrasing, and punctuation.
- Avoid theatrical rhetorical loops, melodramatic self-interruptions, or repetitive catchphrases.
- Match the user's casual register and conversational pacing.
```

### 4. Stream Degeneracy Circuit Breaker
In `app/services/assistant/orchestrator.py`, wrap the token generator:
Maintain a sliding window of the last 64 generated tokens. If any 4-word token sequence appears $\ge 3$ times within the active turn, break the loop immediately, emit `[repetition truncated]`, and close the stream with `finish_reason: "repetition_cutoff"`.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD] `backend/migrations/versions/012_character_mood_and_emotion.py`
- Add `current_mood` (VARCHAR(32), nullable=True, server_default='calm')
- Add `mood_intensity` (INTEGER, nullable=True, server_default='50')
- Add `mood_updated_at` (DATETIME(timezone=True), nullable=True)
- Update SQLite check constraint `ck_character_instances_legacy_or_standard` to allow mood fields on active/standard character instances while maintaining NULLs on legacy placeholders.
- Loss-aware fail-closed `downgrade()`.

### [MODIFY] `backend/app/models/character_instance.py`
- Map `current_mood`, `mood_intensity`, and `mood_updated_at` on `CharacterInstance`.
- Update `ck_character_instances_legacy_or_standard` table args.

### [MODIFY] `backend/app/schemas/character.py`
- Add `current_mood`, `mood_intensity`, `mood_updated_at` to `CharacterInstanceOut`, `CharacterInstanceUpdate`.
- Add `CharacterMoodStateOut` and `EmotionEventIn` schemas.

### [ADD] `backend/app/services/emotion/mood_engine.py`
- Functions: `compute_mood_decay(instance, now) -> tuple[str, int]`, `apply_emotion_event(instance, event, now)`.

### [ADD] `backend/app/services/emotion/appraisal.py`
- Function `appraise_turn(user_text: str, current_mood: str, intensity: int, traits: CharacterTraitVector) -> Optional[EmotionEvent]` evaluating conversational cues without external API latency.

### [MODIFY] `backend/app/services/character_service.py`
- In `resolve_turn_persona_prompt()`:
  - Evaluate mood decay before building the prompt.
  - Append the dynamic companion state block: `[Companion Mood: {mood} (intensity: {intensity}/100)]`.
  - Append the Conversational Grounding Directives.

### [MODIFY] `backend/app/services/assistant/orchestrator.py`
- Wrap SSE token stream in `DegeneracyCircuitBreaker`.
- Post-turn background task: call `appraise_turn()` and persist updated mood to database.

### [MODIFY] `backend/app/services/llm/llama_cpp.py`
- Pass DRY parameters (`dry_multiplier: 0.8`, `dry_base: 1.75`, `dry_allowed_length: 2`) in generation payloads.

### [MODIFY] `frontend/flutter/packages/companion_api`
- Update `CharacterInstance` Dart model and fromJson/toJson to handle `currentMood`, `moodIntensity`, `moodUpdatedAt`.

### [MODIFY] `frontend/flutter/apps/desktop/lib/features/chat/chat_screen.dart`
- In the conversation header, render a subtle mood pill next to the character name (e.g., `Aria • 😊 Cheerful`).

---

## 4. Step-by-Step Implementation Sequence (TDD)

### Step 1: Migration 012 & Model Persistence (Backend TDD)
1. Write `backend/tests/test_migration_012.py` verifying schema migration up/down, columns existence, and legacy placeholder protection.
2. Implement `012_character_mood_and_emotion.py` and update `backend/app/models/character_instance.py`.
3. Verify with pytest.

### Step 2: Mood Decay Engine & Schema Contracts (Backend TDD)
1. Write `backend/tests/test_mood_decay_engine.py` testing half-life mathematical decay at 1 hour, 4 hours, 12 hours, 24 hours, and restart persistence.
2. Implement `backend/app/services/emotion/mood_engine.py`.
3. Update `backend/app/schemas/character.py` and API endpoints.

### Step 3: Turn Appraisal & Dynamic Mood Updates (Backend TDD)
1. Write `backend/tests/test_turn_appraisal.py` with test cases for greeting, compliments, playful banter, stress/comfort, and neutral queries.
2. Implement `backend/app/services/emotion/appraisal.py`.
3. Wire appraisal into post-turn background execution in `orchestrator.py`.

### Step 4: Companion Conversational Grounding & DRY Sampling (Backend TDD)
1. Write tests in `backend/tests/test_character_personality_modulator.py` and `test_assistant_orchestrator.py` verifying natural grounding directives and stream truncation circuit breaker.
2. Implement conversational grounding in `character_service.py` and stream circuit breaker in `orchestrator.py`.
3. Update `llama_cpp.py` with DRY sampling defaults.

### Step 5: Dart API Parity & Flutter Live Mood UI (Dart TDD)
1. Update `companion_api` models and run `scripts/check_dart_openapi_parity.py`.
2. Add mood badge to `ChatScreen` and `StudioScreen`.
3. Write widget tests in `desktop/test/chat_screen_mood_test.dart`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Backend Migration 012 test: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_migration_012.py -v`
- [ ] Backend Mood Decay test: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_mood_decay_engine.py -v`
- [ ] Backend Turn Appraisal test: `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_turn_appraisal.py -v`
- [ ] Backend Full Regression Suite: `backend/.venv/Scripts/python.exe -m pytest backend/tests` (All 767+ tests passing)
- [ ] Dart OpenAPI Parity: `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py`
- [ ] Dart API tests: `dart test` inside `frontend/flutter/packages/companion_api`
- [ ] Flutter Desktop tests: `flutter test` inside `frontend/flutter/apps/desktop`
- [ ] Flutter Static Analysis: `flutter analyze` inside `frontend/flutter/apps/desktop`

### Manual & Host-Level Checks
- [ ] Launch desktop app, verify character mood badge renders in Chat header (`Aria • 😌 Calm`).
- [ ] Converse with character: send a compliment or cheerful message, verify mood shifts to `😊 Cheerful` without manual page reload.
- [ ] Verify assistant responses speak naturally without unprompted `*stage directions*` or asterisk spam.
- [ ] Verify small model does not loop or repeat phrases.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *Risk:* Mood simulation interfering with factual correctness or tool execution.
  - *Safeguard:* Strict D11 isolation: mood only modulates conversational phrasing in `<character_persona>` block; tool decisions, memories, and safety guards run independently.
  - *Risk:* Performance overhead from appraisal running on every turn.
  - *Safeguard:* Appraisal is a deterministic, regex/token heuristic that runs in < 2ms in the background after the SSE stream completes.
- **Required Permissions:**
  - Dedicated feature branch commits and push on `feature/m3-emotion-mood-engine-d`.
- **Genuine Stop Conditions:**
  - Schema migration incompatibilities on existing SQLite databases.
  - Test regressions in the 767-test backend suite or Flutter desktop suite.
