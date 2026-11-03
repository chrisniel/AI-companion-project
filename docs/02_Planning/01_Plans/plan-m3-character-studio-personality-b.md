# Implementation Plan: M3 Character Studio V1 & Personality Prompt Modulator — Batch B (`PC-CLIENT-007`, `PC-CHAR-002`)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** APPROVED — Plan Gate approved by Chris and independent review; executing implementation (`STOP AT IMPLEMENTATION GATE`)
- **Date:** 2026-11-03
- **Author:** AI Agent
- **Branch:** `feature/m3-character-studio-personality-b` (branched from `develop` @ `d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`)
- **Active Branch Tracker:** [`docs/01_Tracking/active/task-feature-m3-character-studio-personality-b.md`](../../01_Tracking/active/task-feature-m3-character-studio-personality-b.md)
- **WBS Mapping:**
  - `PC-CLIENT-007`: Character Studio V1 — Immersive Windows Desktop customization workspace (Character Library, Center Character Showcase Stage, Translucent Customization Inspector, Presets, 8 Sliders, Lore/Prompt Editor, Neutral Assistant Fallback & Profile Activation).
  - `PC-CHAR-002`: 8 Continuous Personality Traits Scoring (`0–100`) & Deterministic Personality Prompt Modulator.
- **Scope Mode:** New Feature — Deterministic Backend Personality Prompt Modulator & Immersive Game-Style Windows Flutter Desktop Character Studio V1
- **Target Files:**
  - **Backend (`PC-CHAR-002`):**
    - `backend/app/services/character_service.py` (`[MODIFY]`)
    - `backend/tests/test_character_personality_modulator.py` (`[ADD]`)
    - `backend/tests/test_character_foundation.py` (`[MODIFY]`)
  - **Flutter Desktop Client & Assets (`PC-CLIENT-007`):**
    - `frontend/flutter/apps/desktop/pubspec.yaml` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/assets/studio/` (`[ADD]` — project-original, deterministically generated local studio backdrop & archetype portrait PNGs + `ASSET_PROVENANCE.md`)
    - `frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/features/studio/character_showcase_stage.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/features/studio/studio_library_panel.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/features/studio/studio_inspector_panel.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/lib/screens/studio_screen.dart` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/lib/main.dart` (`[MODIFY]`)
    - `frontend/flutter/apps/desktop/test/desktop_studio_controller_test.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/test/studio_screen_test.dart` (`[ADD]`)
    - `frontend/flutter/apps/desktop/test/desktop_shell_test.dart` (`[MODIFY]`)
  - **Documentation & Planning Reconciliation (Stage 5 — After Implementation Gate Approval):**
    - `docs/05_Design/03_Character_Studio_and_Personality.md` (`[MODIFY]`)
    - `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md` (`[MODIFY]`)
    - `docs/02_Planning/00_Master/WBS.md` (`[MODIFY]`)
    - `docs/02_Planning/00_Master/DELIVERY_INDEX.md` (`[MODIFY]`)
    - `docs/02_Planning/00_Master/SPRINT_ROADMAP.md` (`[MODIFY]`)
    - `docs/02_Planning/00_Master/MASTER_CHECKLIST.md` (`[MODIFY]`)
    - `docs/01_Tracking/task.md` (`[MODIFY]`)
    - `docs/03_Walkthroughs/walkthrough-m3-character-studio-personality-b.md` (`[ADD]`)
    - `CHANGELOG.md` (`[MODIFY]`)

Notice: Update this plan in place during planning. After approval, track live branch execution in [`docs/01_Tracking/active/task-feature-m3-character-studio-personality-b.md`](../../01_Tracking/active/task-feature-m3-character-studio-personality-b.md) and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

### 1.1 Primary Objective

Deliver **M3 Batch B (`PC-CLIENT-007` + `PC-CHAR-002`)** on top of the M3 Batch A Character Foundation (`d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`):

1. **Immersive, Game-Inspired Windows Desktop Character Studio (`PC-CLIENT-007`):**
   - Replace the static placeholder in [`frontend/flutter/apps/desktop/lib/screens/studio_screen.dart`](../../../frontend/flutter/apps/desktop/lib/screens/studio_screen.dart) with a functional, showcase-first Character customization workspace.
   - Follow the approved visual direction: **a polished game's character customization experience, with a full-content-area thematic background, the Character showcased prominently in the center, and translucent SoftGlass customization controls arranged on the left and right sides (`LEFT: Character Library | CENTER: Character Showcase | RIGHT: Customization Inspector`).**
   - Preserve AI Companion's existing SoftGlass/Neumorphic visual language, color tokens (`CompanionColors`, `CompanionThemeExtension`, `AccentPreset`), typography (`CompanionTypography`), and verified accessibility standards—evolving spatial presentation without replacing the application-wide theme.
   - Maintain a clean presentation boundary (`CharacterStagePresenter` / `CharacterShowcaseStage`) that showcases a 2D portrait or stylized archetype figure with lightweight zoom/pan inspection today while reserving an isolated viewport slot for future 3D/VRM/Live2D rendering without polluting `D11` Character identity or personality models.
2. **Deterministic, Trust-Bounded 8-Trait Personality Prompt Modulator (`PC-CHAR-002`):**
   - Upgrade [`resolve_turn_persona_prompt()`](../../../backend/app/services/character_service.py#L637-L682) in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) so that an active `CharacterInstance`'s 8 continuous `0–100` personality trait dimensions (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`) and `preset_id` deterministically compile into structured stylistic behavioral guidance inside the lower-trust `<character_persona>` block.
   - Preserve the immutable **Neutral Assistant** fallback (`"neutral-assistant"` / `"default"`) and historical legacy placeholders (`is_legacy_placeholder = True`) completely unmodulated (`DEFAULT_PERSONA` only).
   - Enforce strict instruction trust boundaries and user-autonomy safeguards: trait modulation shapes conversational tone, cadence, and warmth only, explicitly prohibits coercion, possessiveness, exclusivity demands, manipulation, or emotional dependency claims on high-affection presets, and can never override `DEFAULT_PERSONA` safety rules, claim system/developer authority, cross Profile boundaries, or authorize tool/file/network actions.

### 1.2 Concrete Deliverables

1. **Deterministic Backend Personality Prompt Modulator (`PC-CHAR-002`):**
   - Pure, deterministic trait-to-instruction compiler (`compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str]) -> str`) in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py).
   - 5-band semantic mapping (`0–19` Very Low, `20–39` Low, `40–59` Balanced, `60–79` High, `80–100` Very High) for each of the 8 traits, plus prioritized cross-trait interaction and autonomy-guard synthesis rules.
   - Reproducible worst-case character proof: **at most `695` characters** when all 8 longest trait clauses, longest preset header (`31` chars), longest secondary `Dynamic` (`89` chars), mandatory `Autonomy Guard` (`133` chars), and all `7` newline separators fire simultaneously (`<= 605` chars when a single synthesis line fires), strictly bounded under `MODULATION_BLOCK_MAX_CHARS = 700` (`<= 175` heuristic tokens under `_estimate_tokens(text) = len // 4`) with zero mid-sentence truncation.
   - Deterministic per-turn bounding of unbounded SQLite `Text` fields (`system_prompt` capped at `TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200` and `lore` capped at `TURN_PERSONA_LORE_MAX_CHARS = 1600` before `_escape_delimiters()`) so oversized user-authored text never starves conversation history in `_build_context()`.
2. **Desktop Studio Controller & Concurrency-Safe Session/Draft State Machine (`DesktopStudioController`):**
   - Session-aware `ChangeNotifier` in `frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart` bound to `DesktopChatController` / `CompanionClient`.
   - Immediately transitions to `sessionExpiredOrRevoked` and purges all personal catalog and draft data whenever `chat.connectionStatus == RuntimeConnectionStatus.unauthorized`—**even when `chat.profileEpoch` is unchanged** (e.g., when `checkConnection()` detects a missing saved token).
   - Separates **session authority fencing** (`_sessionFenceId`, `_boundProfileId`), **stale-read protection** (`_readGeneration`), and **serialized mutation coordination** (`_isMutating` / single-flight mutation queue) so background catalog reads never discard a committed `saveDraft()` response, delayed responses after a Profile switch are dropped, and uncertain network timeouts trigger authoritative state reconciliation.
3. **Immersive Character Studio UI & Decoupled Showcase Stage (`PC-CLIENT-007`):**
   - `StudioBackdropLayer`: Full-content-area thematic background with `BoxFit.cover` scaling, theme-aware contrast scrims, edge gradients, and automatic procedural fallback (`StudioAtmospherePainter`) when an image asset is unavailable.
   - `CharacterShowcaseStage` & `CharacterStagePresenter`: Unobstructed center-stage 2D portrait / vector archetype showcase with interactive pan/zoom (`1.0x–2.0x`), reset-view control, backdrop selector, and floating identity/status pills.
   - `StudioLibraryPanel` (Left Translucent Dock) & `StudioInspectorPanel` (Right Translucent Dock): Built with `SoftGlassPanel`, `NeumorphicSegmentedControl`, `NeumorphicButton`, accessible slider controls, and an explicitly labeled **Illustrative Trait Tendency Summary** inside the `Personality` inspector tab (avoiding any false claim of exact backend prompt string parity and keeping the center character showcase 100% unobstructed).
   - Comprehensive dirty-state navigation protection across Library selection, Desktop Navigation Rail clicks, keyboard shortcuts (`Ctrl+,`), and programmatic navigation.
4. **Automated & Manual Verification Suite:**
   - Backend unit and integration tests (`backend/tests/test_character_personality_modulator.py`, `backend/tests/test_character_foundation.py`).
   - Flutter controller, concurrency/fencing, widget, responsive breakpoint, programmatic WCAG luminance contrast, keyboard focus/text-scaling, and dirty-navigation tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_shell_test.dart`).
   - Reproducible Windows Desktop manual acceptance checklist.

### 1.3 Recommended Batch Sizing Evaluation (Single Coherent Batch B vs. Split Slices)

Per [`docs/06_Guides/DELIVERY_WORKFLOW.md` §3 (Subsystem Batching Principle)](../../06_Guides/DELIVERY_WORKFLOW.md#L133-L143), we evaluated two delivery structures:

| Option | Structure | Pros | Cons / Risks |
| :--- | :--- | :--- | :--- |
| **Option A (Recommended): Single Coherent M3 Batch B** | Deliver `PC-CHAR-002` (backend prompt modulator) + `PC-CLIENT-007` (Desktop Character Studio V1) together on `feature/m3-character-studio-personality-b`. | • **Zero schema or API contract churn:** Batch A already landed all DB tables, columns, and `/api/v1/characters/*` endpoints.<br>• **Compact backend footprint:** `PC-CHAR-002` is ~160 lines of pure, deterministic Python in `character_service.py` + unit tests.<br>• **End-to-end user value:** Adjusting and saving sliders in Character Studio immediately modulates live chat turns. | • Touching both `backend/` and `frontend/flutter/` in one PR requires disciplined commit separation (mitigated by 4 clean, layer-scoped commits). |
| **Option B: Split into Batch B1 (`PC-CHAR-002`) and Batch B2 (`PC-CLIENT-007`)** | Ship the backend prompt modulator in one PR, then open a second branch/PR for the Flutter Studio UI. | • Slightly smaller individual PR diffs. | • Doubles full gate/review/walkthrough/closure ceremony for a single user-facing feature.<br>• Leaves B1 invisible to desktop users until B2 merges. |

**Recommendation:** **Option A — Single Coherent M3 Batch B** on `feature/m3-character-studio-personality-b`, executed in four ordered, independently verifiable commits (Phase 1: Backend Modulator; Phase 2: Studio Controller & Stage Presenter; Phase 3: Immersive Studio UI & Shell Wiring; Phase 4: Documentation & Closure after Implementation Gate approval).

### 1.4 Explicit Out-of-Scope Boundaries

- **No 3D Engine, VRM, glTF, or Live2D Runtime:** Do not add 3D rendering packages, shader compilers, skeletal animation runtimes, or speculative 3D database columns (`vrm_url`, `bone_map`, etc.). Only a lightweight Flutter widget boundary (`CharacterStagePresenter`) is introduced.
- **No Persistent Mood / Emotion Engine (`PC-CHAR-003` / `PC-CHAR-004`):** Do not implement turn-by-turn mood classification, emotional decay timers, or relationship familiarity tiers in this batch.
- **No Database Schema or Alembic Migrations:** Migration `009` already persists all 8 traits, `preset_id`, `avatar_asset`, `lore`, and `system_prompt`. No Migration `010` is needed or authorized.
- **No Voice Synthesis / TTS Binding (`PC-VOICE-*`):** Voice model binding remains deferred to M4.
- **No App-Wide Theme Redesign:** Do not alter Chat, Memory, Tasks, Models, or Settings screen layouts or replace the SoftGlass/Neumorphic token system in `companion_design`.
- **No Hidden Conversation Creation from Studio:** Inspecting or customizing a character in Character Studio must never create hidden `Conversation` or `Message` rows in SQLite or mutate existing conversation bindings.

---

## 2. Current Findings & Technical Root Cause

### 2.1 Source-Verified Current Implementation Evidence

| Area | Inspected File & Lines | Verified Current State on `develop` (`d22dd7e`) | Impact on M3 Batch B |
| :--- | :--- | :--- | :--- |
| **Turn Persona Prompt Assembly** | [`backend/app/services/character_service.py` (L637–L682)](../../../backend/app/services/character_service.py#L637-L682) | `resolve_turn_persona_prompt()` returns `DEFAULT_PERSONA` for Neutral Assistant (`character_instance_id is None` or `character_id in ("default", "neutral-assistant")`) and for `instance.is_legacy_placeholder`. For active instances, it injects `Name`, `Summary`, `Persona Instructions`, and `Lore` inside `<character_persona>`, escaping XML tags via `_escape_delimiters()`, **but never reads `instance.preset_id` or the 8 trait columns (`warmth..verbosity`)**. | Must add deterministic trait-to-instruction compilation (`compile_personality_modulation_block`) and include its output inside `<character_persona>` while preserving `DEFAULT_PERSONA` and delimiter escaping. |
| **Character Schema Field Limits** | [`backend/app/schemas/character.py` (L78–L137)](../../../backend/app/schemas/character.py#L78-L137), [`009_character_foundation.py`](../../../backend/migrations/versions/009_character_foundation.py) | `CharacterInstanceCreate` and `CharacterInstanceUpdate` enforce `max_length` only on `template_id` (`64`), `name` (`120`), `summary` (`500`), and `avatar_asset` (`255`). **`lore` and `system_prompt` are `Optional[str] = None` backed by SQLite `Text` columns with no schema-level length cap.** | Do not falsely claim Pydantic already caps `lore` or `system_prompt`. Keep API/OpenAPI contracts compatible with existing rows while bounding per-turn prompt injection (`TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200`, `TURN_PERSONA_LORE_MAX_CHARS = 1600` before `_escape_delimiters()`) and displaying soft prompt-budget guidance in the Studio editor. |
| **Orchestrator Token Budgeting** | [`backend/app/services/assistant/orchestrator.py` (L68–L141, L406–L431)](../../../backend/app/services/assistant/orchestrator.py#L68-L141) | `_build_context()` deducts `_estimate_tokens(system_prompt)` (`max(1, len(content) // 4)`) from `context_capacity` before fitting `memories` and `history`. | `compile_personality_modulation_block()` must have a mathematically verified worst-case maximum (`695` chars worst-case $\le$ `MODULATION_BLOCK_MAX_CHARS = 700`, corresponding to `<= 175` heuristic tokens under `_estimate_tokens`) and clearly distinguish character-ratio heuristics from model-specific BPE tokenizers. |
| **Desktop Window & Navigation Rail Geometry** | [`desktop_lifecycle_coordinator.dart` (L29–L30)](../../../frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart#L29-L30), [`desktop_navigation_rail.dart` (L21–L25)](../../../frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart#L21-L25) | `defaultWindowSize = Size(1280, 800)` and `minimumWindowSize = Size(1024, 640)`. `DesktopNavigationRail` is `240px` wide when expanded (`initialRailCollapsed = false`) and `72px` wide when collapsed. Therefore, actual `studioContentWidth` is `784px` at `1024x640` (expanded rail), `952px` at `1024x640` (collapsed rail), `1040px` at `1280x800` (expanded rail), and `1208px` at `1280x800` (collapsed rail). | Responsive breakpoints in `StudioScreen` are calculated strictly against `studioContentWidth` (`constraints.maxWidth` after the rail) so every mode fits with zero `RenderFlex` overflow at `1024x640` and `1280x800`. |
| **Connection Probes & Unchanged-Epoch `unauthorized`** | [`desktop_chat_controller.dart` (L108–L180, L396–L491)](../../../frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart#L396-L491) | `checkConnection()` sets `_authenticatedProfileId = null` and `_connectionStatus = RuntimeConnectionStatus.connecting` at entry without changing `_configEpoch` (`profileEpoch`). Critically, at lines 414–419 and 472–477, if `sessionStore.readToken()` is null/empty or verification fails, **`checkConnection()` sets `_connectionStatus = RuntimeConnectionStatus.unauthorized` WITHOUT incrementing `_configEpoch` (`profileEpoch`)**! | `DesktopStudioController` must treat `chat.connectionStatus == RuntimeConnectionStatus.unauthorized` as an immediate, unconditional authority-loss boundary **even when `profileEpoch` is unchanged**, purging all personal catalog and draft data so Profile A's state can never remain visible when unauthorized. |
| **Bundled Image Assets** | [`apps/desktop/pubspec.yaml` (L26–L29)](../../../frontend/flutter/apps/desktop/pubspec.yaml#L26-L29) | `apps/desktop/pubspec.yaml` currently declares only `assets/icons/`. Zero raster/vector studio backdrops or character portraits exist in `frontend/flutter/`. | Generate and bundle project-original, reproducibly generated local PNG studio backdrops and archetype portraits under `frontend/flutter/apps/desktop/assets/studio/` with documented provenance (`ASSET_PROVENANCE.md`) and procedural `CustomPainter` fallbacks. |

### 2.2 Proposed Architecture & Dependency Boundaries

```text
+---------------------------------------------------------------------------------------------------+
|                                   WINDOWS FLUTTER DESKTOP CLIENT                                  |
|                                                                                                   |
|  DesktopShell (Navigation Rail [240px / 72px] + Studio Content Viewport + Navigation Guard Hook)  |
|    │                                                                                              |
|    ├──► ChatScreen <─────────────────────── DesktopChatController (owns CompanionClient,          |
|    │                                          connectionStatus, authenticatedProfileId,           |
|    │                                          profileEpoch)                                       |
|    └──► StudioScreen                                 ▲                                            |
|           │                                          │ listens to connectionStatus,               |
|           ▼                                          │ authenticatedProfileId & profileEpoch      |
|         DesktopStudioController ─────────────────────┘                                            |
|           ├── Authority Fence: _sessionFenceId, _boundProfileId, _boundProfileEpoch               |
|           ├── Concurrency: _readGeneration (reads) + Serialized Mutation Queue (_isMutating)      |
|           ├── Catalog State: templates, presets, neutralFallback, instances, activeState          |
|           ├── Selection & Draft State: selectedTarget, CharacterStudioDraft, isDirty              |
|           └── Stage View State: zoomLevel (1.0..2.0), backdropPresetId                            |
|                                                                                                   |
|  StudioScreen 3-Layer Spatial Stack:                                                              |
|    ├── Layer 0: StudioBackdropLayer (Local Original PNG + Procedural Canvas + Contrast Scrims)    |
|    ├── Layer 1: CharacterShowcaseStage ──► CharacterStagePresenter (2D Portrait / Future 3D Slot) |
|    └── Layer 2: SoftGlassPanel Docks (Left: StudioLibraryPanel | Right: StudioInspectorPanel)     |
+---------------------------------------------------------------------------------------------------+
                                                   │
                                                   │ REST over Loopback (Bearer psk_<token>)
                                                   ▼
+---------------------------------------------------------------------------------------------------+
|                                   PYTHON FASTAPI LOCAL RUNTIME                                    |
|                                                                                                   |
|  /api/v1/characters/* ──► character_service.py                                                    |
|                             ├── CRUD, Active Character Selection, Reset to Neutral                |
|                             └── resolve_turn_persona_prompt(db, session, conversation)            |
|                                   ├── Per-turn bounds on system_prompt (1200) & lore (1600)       |
|                                   └── compile_personality_modulation_block(traits, preset_id)     |
|                                         ├── 8-Dimension 5-Band Concise Clauses (<= 695 chars max) |
|                                         └── Mandatory Autonomy Guard + Archetype Dynamic          |
+---------------------------------------------------------------------------------------------------+
```

---

## 3. Proposed File Changes & In-Place Logic

### 3.1 Studio UX, Responsive Layout & Accessibility Specification

#### 3.1.1 Actual Window vs. Post-Rail Studio Content Width (`studioContentWidth`)
Per [`DesktopLifecycleCoordinator`](../../../frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart#L29-L30) and [`DesktopNavigationRail`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart#L24):
- Minimum supported desktop window size is **`1024 x 640`**; default window size is **`1280 x 800`**.
- `DesktopNavigationRail` consumes **`240px`** when expanded (default) and **`72px`** when collapsed.
- Therefore, `StudioScreen`'s `LayoutBuilder` receives `studioContentWidth = windowWidth - railWidth`:
  - At `1024 x 640` with **expanded rail (`240px`)**: `studioContentWidth = 784px`.
  - At `1024 x 640` with **collapsed rail (`72px`)**: `studioContentWidth = 952px`.
  - At `1280 x 800` with **expanded rail (`240px`)**: `studioContentWidth = 1040px`.
  - At `1280 x 800` with **collapsed rail (`72px`)**: `studioContentWidth = 1208px`.

#### 3.1.2 Three Mathematically Verified Responsive Breakpoints (`studioContentWidth`)

| Breakpoint Mode | `studioContentWidth` Range | Outer Padding | Inter-Column Gaps | Left Library Dock | Center Showcase Stage (`Expanded`) | Right Inspector Dock | Exact Minimum Width Verification |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Mode 1: Wide 3-Column Studio** | **`>= 1120px`** *(e.g., `1280x800` collapsed rail `1208px`, or `>= 1360px` expanded rail)* | `16px` L/R (`32px` total) | `2 x 16px` (`32px` total) | `272px` fixed | **`>= 400px`** (`488px` at `1208px`) | `384px` fixed | `32 + 32 + 272 + 384 = 720px` fixed; at `1120px`, Center Stage = **`400px`** (`0px` overflow). |
| **Mode 2: Standard 3-Column Studio** | **`920px .. 1119px`** *(e.g., `1280x800` expanded rail `1040px`, or `1024x640` collapsed rail `952px`)* | `12px` L/R (`24px` total) | `2 x 12px` (`24px` total) | `228px` fixed | **`308px .. 507px`** (`340px` at `952px`; `428px` at `1040px`) | `336px` fixed | `24 + 24 + 228 + 336 = 612px` fixed; at `920px`, Center Stage = **`308px`** (`0px` overflow). |
| **Mode 3: Compact 2-Column + Overlay Library Drawer** | **`< 920px`** *(e.g., `1024x640` expanded rail `784px`, down to `680px` test viewports)* | `12px` L/R (`24px` total) | `1 x 12px` (`12px` total) | Slide-over `SoftGlassPanel` drawer (`268px` wide, toggled via top-left Stage `Library` button) | **`>= 316px`** (`420px` at `784px` content width!) | `328px` fixed | `24 + 12 + 328 = 364px` fixed; at `784px` (`1024x640` expanded rail), Center Stage = **`420px`** (`0px` overflow). |

#### 3.1.3 Illustrative Local Style Summary (Truthful Local Preview Without Obscuring Center Showcase)
- Provide an **explicitly labeled, illustrative local style summary card** (`Illustrative Style Summary (Local Draft Preview)`) placed **inside the Right Inspector's `Personality` tab** (above the 8 trait sliders) rather than over the Center Showcase Stage.
- The Center Character Showcase Stage (`CharacterShowcaseStage`) remains 100% dedicated to the Character portrait/figure, top identity pills, and bottom camera controls (`Zoom - / 100% / +`, `Reset View`, `Backdrop Selector`).
- The Inspector summary card carries the explicit caption: *"Illustrative local preview of slider tendencies. Authoritative prompt modulation is compiled by the local Python runtime during chat turns."*

#### 3.1.4 Measurable Contrast, Keyboard Focus, Text Scaling & Accessibility Verification (Correction 4)
Rather than assuming fixed translucent panel alpha guarantees legibility over arbitrary backdrop pixels, `StudioScreen` enforces and tests four concrete accessibility mechanisms:
1. **Deterministic High-Contrast Control Surfaces Over Scrimmed Backdrops:**
   - `StudioBackdropLayer` paints a directional horizontal readability scrim (`LinearGradient` blending the left and right dock zones toward `ext.surfaceBase` at `0.65` alpha) beneath the `SoftGlassPanel` docks (`surfaceElevated` at `0.82` alpha).
   - Every text-bearing card, text input, preset pill, and slider row inside `StudioLibraryPanel` and `StudioInspectorPanel` sits on an explicit `NeumorphicSurface` (`surfaceSunken` `#E2E8F0` / `surfaceElevated` `#F8FAFC` in Light mode with `textPrimary` `#0F172A` and `textSecondary` `#334155`; `surfaceSunken` `#090D14` / `surfaceElevated` `#161F30` in Dark mode with `textPrimary` `#F8FAFC` and `textSecondary` `#CBD5E1`).
   - Center-stage floating status pills and camera toolbar buttons use `surfaceElevated.withValues(alpha: 0.90)` with `1px` `borderHighlight` / `borderSubtle` borders so foreground labels never sit directly on raw backdrop imagery.
2. **Programmatic WCAG Luminance Contrast Verification in Automated Tests:**
   - `studio_screen_test.dart` computes composite background colors (`Color.alphaBlend`) across **both Light and Dark modes, all 4 studio backdrop presets, and all 6 `AccentPreset` palettes** (`oceanSky`, `indigoPulse`, `emeraldGlow`, `amberWarmth`, `roseQuartz`, `amethystViolet`) and verifies via `Color.computeLuminance()` that:
     - Primary and secondary text contrast against library cards, inspector surfaces, and stage status pills is **`>= 4.5:1`** (WCAG AA normal text).
     - Active control borders, selected preset pills, slider active tracks, and focus rings achieve **`>= 3.0:1`** non-text contrast against adjacent surfaces.
3. **Keyboard Navigation, Focus Visibility & Screen-Reader Semantics:**
   - **Focus Ring Visibility:** All interactive Studio widgets (Library cards, Preset pills, Segmented tabs, Trait sliders, Reset buttons, Stage camera buttons, and Action footer buttons) display an explicit `2px` focus border (`ext.accent`) when focused via keyboard (`Focus` / `FocusableActionDetector`).
   - **Keyboard Traversal & Control:** Deterministic `Tab` / `Shift+Tab` focus order (`Left Library` $\to$ `Center Stage Toolbar` $\to$ `Right Inspector Tabs & Controls` $\to$ `Pinned Action Footer`), keyboard arrow increments on all 8 `Slider` controls (`±1` arrow, `±5` `Shift+Arrow`), and `Semantics(label: ..., value: '$value of 100 ($bandLabel)')` annotations on every trait slider.
4. **Text Scaling & Minimum Window (`1024x640`) Resilience:**
   - All inspector tabs and library lists use scrollable vertical viewports and multi-line wrapping (`TextOverflow.ellipsis` / `Flexible`) verified in widget tests at `1024x640` with both `TextScaler.linear(1.0)` and `TextScaler.linear(1.25)`.

---

### 3.2 Center Showcase Stage, Thematic Background Image & Asset Provenance / Fallback Design

#### 3.2.1 Asset Provenance & Reproducible Local Generation (`assets/studio/`)
- **Current Repository Fact:** `frontend/flutter/` currently contains **no** background images or character portrait assets.
- **Asset Provenance & Licensing Rule:**
  1. **100% Project-Original, Deterministically Generated Local Assets:**
     - All bundled studio backdrops and archetype portraits placed under `frontend/flutter/apps/desktop/assets/studio/` will be **original project-authored artwork generated deterministically from a reproducible local script** committed with `frontend/flutter/apps/desktop/assets/studio/ASSET_PROVENANCE.md` under the repository's license.
     - Zero third-party copyrighted images and zero external network URLs (`http://`/`https://`) will be used.
     - Register `- assets/studio/` in [`frontend/flutter/apps/desktop/pubspec.yaml`](../../../frontend/flutter/apps/desktop/pubspec.yaml).
  2. **Multi-Layer Procedural Fallback Architecture (`StudioAtmospherePainter` & `ArchetypeSilhouetteStageWidget`):**
     - Every `Image.asset` call in `StudioBackdropLayer` and `CharacterShowcaseStage` provides an `errorBuilder` that falls back to `StudioAtmospherePainter` (for backdrops) or `ArchetypeSilhouetteStageWidget` (for center portraits) with zero uncaught exceptions or layout shifts.

#### 3.2.2 Lightweight Future 3D / VRM Renderer Boundary (`CharacterStagePresenter`)
- Define [`frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart) with `CharacterStageRenderMode.portrait2d` and `CharacterStageVisualSpec`, cleanly isolating 2D portrait + `InteractiveViewer` zoom/pan (`1.0x–2.0x`) from future 3D/VRM rendering without adding speculative 3D schema fields.

---

### 3.3 Personality Prompt Modulation Rules & Reproducible Worst-Case Budget Proof (`PC-CHAR-002`)

#### 3.3.1 Design Principles, Determinism & Neutral Fallback Preservation
- **Pure Function:** `compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str] = None) -> str` in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) is 100% deterministic: identical `(traits, preset_id)` inputs always produce the exact same string output.
- **No Effect on Neutral Assistant or Legacy Placeholders:**
  - When `conversation.character_instance_id is None` or `conversation.character_id in ("default", "neutral-assistant")`, `resolve_turn_persona_prompt()` returns `DEFAULT_PERSONA` directly (unchanged).
  - When `instance.is_legacy_placeholder` is `True` or `instance.warmth is None`, `resolve_turn_persona_prompt()` returns `DEFAULT_PERSONA` directly (unchanged).

#### 3.3.2 Exact 5-Band Clause Table With Verified Character Lengths (`0–100`)
Each of the 8 integer dimensions (`0..100`) maps deterministically into one of 5 concise clauses (`<= 29` characters per clause):

| Trait Dimension | `0–19` (Very Low) | `20–39` (Low) | `40–59` (Balanced) | `60–79` (High) | `80–100` (Very High) | Max Clause Chars |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **`warmth`** | `cool and matter-of-fact` (23) | `reserved and composed` (21) | `friendly and approachable` (25) | `warm, empathetic, supportive` (28) | `deeply nurturing and caring` (27) | **28** |
| **`affection`** | `strictly platonic distance` (26) | `polite, respectful distance` (27) | `friendly, supportive regard` (27) | `openly fond and attentive` (25) | `devoted, loyal, affectionate` (28) | **28** |
| **`guardedness`** | `open and emotionally candid` (27) | `relaxed, low defensiveness` (26) | `receptive, healthy boundaries` (29) | `emotionally cautious, guarded` (29) | `heavily guarded on feelings` (27) | **29** |
| **`expressiveness`** | `stoic and deadpan delivery` (26) | `calm and understated tone` (25) | `natural expressive cadence` (26) | `vivid and animated delivery` (27) | `highly expressive, exuberant` (28) | **28** |
| **`teasing`** | `earnest, literal, no banter` (27) | `sincere with rare dry wit` (25) | `occasional light humor` (22) | `playful, witty, and teasing` (27) | `cheeky with playful banter` (26) | **27** |
| **`directness`** | `indirect, gentle, tactful` (25) | `diplomatic and cushioned` (24) | `clear yet diplomatic` (20) | `straightforward and candid` (26) | `blunt, direct, and unhedged` (27) | **27** |
| **`formality`** | `ultra-casual and colloquial` (27) | `informal and conversational` (27) | `clean everyday register` (23) | `polished and courteous` (22) | `strictly formal, articulate` (27) | **27** |
| **`verbosity`** | `terse and ultra-concise` (23) | `compact and focused length` (26) | `balanced response length` (24) | `thorough and descriptive` (24) | `richly detailed, expansive` (26) | **26** |

#### 3.3.3 Mandatory Autonomy Guard & Cross-Trait Interaction Synthesis Rules
1. **Mandatory Safety Rule — High-Affection Autonomy & Non-Possessiveness Guard (`affection >= 80` OR `preset_id == "yandere"`):**
   - Exact emitted line (**`133` chars**):
     `- Autonomy Guard: Express devotion supportively; never use coercion, possessiveness, exclusivity, manipulation, or dependency claims.`
   - Also update `PRESET_REGISTRY["yandere"]["description"]` to: `"Intensely affectionate, deeply loyal, and protective companion within respectful, non-possessive boundaries."`
2. **Optional Secondary Archetype Dynamic Rules (At Most 1 Emitted — Highest Priority Match From Rules 2a–2d):**
   - **Rule 2a — Guarded Banter / Tsundere (`guardedness >= 65` AND `teasing >= 60` AND (`warmth >= 55` OR `affection >= 55`))** (**`85` chars**):
     `- Dynamic: Mask fondness behind witty banter at first, softening with genuine warmth.`
   - **Rule 2b — Shy Devotion / Dandere (`guardedness >= 65` AND `directness <= 45` AND `teasing <= 35` AND (`warmth >= 60` OR `affection >= 60`))** (**`89` chars**):
     `- Dynamic: Speak gently and shyly at first, showing kindness through quiet attentiveness.`
   - **Rule 2c — Stoic Care / Kuudere (`guardedness >= 65` AND `expressiveness <= 35` AND `directness >= 65`)** (**`89` chars**):
     `- Dynamic: Keep a cool, stoic exterior while showing care through reliable, precise help.`
   - **Rule 2d — Analytical Precision (`formality >= 75` AND `directness >= 75` AND `teasing <= 25`)** (**`87` chars**):
     `- Dynamic: Prioritize structured reasoning, precise terminology, and objective clarity.`

#### 3.3.4 Reproducible Worst-Case Calculation & Concrete Example (Correction 1)

**Exact Emitted Format (`compile_personality_modulation_block`):**
```text
Preset: {preset_label} ({preset_id}) | Traits: warmth={w}, teasing={t}, guardedness={g}, directness={d}, expressiveness={e}, affection={a}, formality={f}, verbosity={v}
Style Directives:
- Tone: {warmth_clause}; {affection_clause}.
- Expression: {guardedness_clause}; {expressiveness_clause}.
- Delivery: {teasing_clause}; {directness_clause}.
- Register: {formality_clause}; {verbosity_clause}.
{optional_dynamic_line}
{optional_autonomy_guard_line}
```

**Component-by-Component Reproducible Worst-Case Arithmetic:**
1. **Line 1 (Header):**
   - Longest `"{preset_label} ({preset_id})"` in `PRESET_REGISTRY` is `"Warm Companion (warm_companion)"` or `"Formal Advisor (formal_advisor)"` = **`31` chars** (`"Custom (custom)"` is `15` chars).
   - Longest trait integer values: all 8 traits = `100` (`3` digits each).
   - `len("Preset: Warm Companion (warm_companion) | Traits: warmth=100, teasing=100, guardedness=100, directness=100, expressiveness=100, affection=100, formality=100, verbosity=100")` = **`171` chars** (or **`155` chars** for `Custom (custom)`).
2. **Line 2 (`Style Directives:`):** **`17` chars**.
3. **Line 3 (`- Tone: {warmth}; {affection}.`):**
   - Prefix `"- Tone: "` (`8`) + max `warmth` (`28`) + `"; "` (`2`) + max `affection` (`28`) + `"."` (`1`) = **`67` chars**.
4. **Line 4 (`- Expression: {guardedness}; {expressiveness}.`):**
   - Prefix `"- Expression: "` (`14`) + max `guardedness` (`29`) + `"; "` (`2`) + max `expressiveness` (`28`) + `"."` (`1`) = **`74` chars**.
5. **Line 5 (`- Delivery: {teasing}; {directness}.`):**
   - Prefix `"- Delivery: "` (`12`) + max `teasing` (`27`) + `"; "` (`2`) + max `directness` (`27`) + `"."` (`1`) = **`69` chars**.
6. **Line 6 (`- Register: {formality}; {verbosity}.`):**
   - Prefix `"- Register: "` (`12`) + max `formality` (`27`) + `"; "` (`2`) + max `verbosity` (`26`) + `"."` (`1`) = **`68` chars**.
7. **Line 7 (Longest Optional `Dynamic` Line — Rule 2b or 2c):** **`89` chars**.
8. **Line 8 (Mandatory `Autonomy Guard` Line — Rule 1):** **`133` chars**.
9. **Newline Separators (`\n`):** **`6` chars** when 7 lines are emitted; **`7` chars** when all 8 lines are emitted.

**Exact Totals:**
- **Worst-Case with `Autonomy Guard` only (7 lines, 6 newlines):**
  `171 + 17 + 67 + 74 + 69 + 68 + 133 + 6 =` **`605` chars** (or **`589` chars** when `preset_id == "custom"`).
- **Absolute Global Worst-Case with BOTH `Autonomy Guard` AND Longest `Dynamic` (8 lines, 7 newlines):**
  `171 + 17 + 67 + 74 + 69 + 68 + 89 + 133 + 7 =` **`695` chars** (or **`679` chars** when `preset_id == "custom"`).
- **Measurable Hard Cap:** Define **`MODULATION_BLOCK_MAX_CHARS = 700`** characters. Because the mathematical maximum across all `8` presets and all `101^8` trait vectors is **`695` chars**, the complete block—including `Autonomy Guard` and any secondary `Dynamic`—**always fits within `700` characters (`<= 175` heuristic tokens under `_estimate_tokens(text) = len // 4`) without ever truncating mid-instruction or omitting safety rules.**
- **Defense-in-Depth Priority Omission Policy:** If a future code change ever caused the 8-line output to exceed `MODULATION_BLOCK_MAX_CHARS = 700`, `compile_personality_modulation_block()` retains the 4 trait lines and **Rule 1 (`Autonomy Guard`)** unconditionally and omits only the optional `Dynamic` line (`<= 605` chars), never truncating strings or dropping safety guards.

**Concrete Worst-Case Output Example (`695` chars exact):**
```text
Preset: Warm Companion (warm_companion) | Traits: warmth=100, teasing=100, guardedness=100, directness=100, expressiveness=100, affection=100, formality=100, verbosity=100
Style Directives:
- Tone: warm, empathetic, supportive; devoted, loyal, affectionate.
- Expression: receptive, healthy boundaries; highly expressive, exuberant.
- Delivery: earnest, literal, no banter; blunt, direct, and unhedged.
- Register: ultra-casual and colloquial; compact and focused length.
- Dynamic: Speak gently and shyly at first, showing kindness through quiet attentiveness.
- Autonomy Guard: Express devotion supportively; never use coercion, possessiveness, exclusivity, manipulation, or dependency claims.
```

#### 3.3.5 Handling Unbounded `lore` & `system_prompt` Schema Fields Safely (Correction 3)
- **Verified Schema Truth:** In [`backend/app/schemas/character.py`](../../../backend/app/schemas/character.py#L78-L137), `name` (`1..120`), `summary` (`<= 500`), and `avatar_asset` (`1..255`) have explicit Pydantic `max_length` constraints, whereas **`lore` and `system_prompt` are currently unbounded `Optional[str]` fields backed by SQLite `Text` columns**.
- **Two-Layer Handling (Zero Breaking Contract Changes):**
  1. **Backend Turn-Assembly Bounding (`resolve_turn_persona_prompt` in `character_service.py`):**
     - Define `TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200` and `TURN_PERSONA_LORE_MAX_CHARS = 1600`.
     - Before calling `_escape_delimiters()`, a deterministic helper `_bound_persona_field(text: str, max_chars: int) -> str` checks `if len(text) > max_chars`: if exceeded, it slices cleanly at the last whitespace boundary at or before `max_chars - 6` and appends `" [...]"`, and **then** applies `_escape_delimiters()` so XML delimiter entity sequences (`&lt;/character_persona&gt;`) are never split mid-entity.
     - This guarantees that total `<character_persona>` overhead (header + `<= 700`-char modulation block + `<= 1200`-char instructions + `<= 1600`-char lore + `<= 620`-char name/summary) never exceeds `~1,050` heuristic tokens in `_build_context()`, leaving `> 2,200` tokens for conversation history on a `4096`-token context window.
  2. **Flutter Studio Inspector UI Handling (`StudioInspectorPanel`):**
     - Enforce hard character limits on `Name` (`120` chars) and `Summary` (`500` chars) matching the backend schema.
     - For `Persona Instructions` (`system_prompt`) and `Backstory & Lore` (`lore`), render scrollable multi-line `TextField` editors (`minLines: 3, maxLines: 6`) that can load, display, and save arbitrarily long existing database strings without error, accompanied by a live character counter (`${text.length} / 1,200 recommended` and `${text.length} / 1,600 recommended`) and an informational helper badge when exceeded (*"Text beyond 1,200 / 1,600 chars is saved to your Character Instance, and trimmed at a word boundary during live chat turns to preserve conversation memory budget."*).

---

### 3.4 Proposed File Changes & In-Place Responsibilities

#### `[MODIFY]` [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py)
- **Primary Responsibility:** Character template/instance service and turn persona prompt resolution.
- **Planned Change:**
  - Define `MODULATION_BLOCK_MAX_CHARS = 700`, `TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200`, `TURN_PERSONA_LORE_MAX_CHARS = 1600`, `TRAIT_BAND_CLAUSES`, `_bound_persona_field()`, and `compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str] = None) -> str`.
  - Update `PRESET_REGISTRY["yandere"]["description"]` to explicitly include non-possessive, respectful boundary wording.
  - Update `resolve_turn_persona_prompt(db, session, conversation)` to bound `instance.system_prompt` and `instance.lore` prior to `_escape_delimiters()` and embed `compile_personality_modulation_block(_map_instance_traits(instance), instance.preset_id)` inside `<character_persona>`.
- **Invariants to Preserve:**
  - `DEFAULT_PERSONA` remains the top-level system prompt.
  - Neutral Assistant (`character_instance_id is None` or `character_id in ("default", "neutral-assistant")`) and `is_legacy_placeholder == True` return `DEFAULT_PERSONA` with zero modulation.

#### `[ADD]` [`backend/tests/test_character_personality_modulator.py`](../../../backend/tests/test_character_personality_modulator.py)
- **Primary Responsibility:** Dedicated unit and integration test suite for `PC-CHAR-002`.
- **Planned Change:**
  - Test deterministic output across all 5 bands (`0–19`, `20–39`, `40–59`, `60–79`, `80–100`) and boundary values (`0, 19, 20, 39, 40, 59, 60, 79, 80, 100`) for all 8 traits.
  - Test all 8 preset baseline vectors (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) produce distinct modulation blocks.
  - Test high-affection / `yandere` safety regression cases: verify `affection >= 80` and `preset_id == "yandere"` deterministically emit the `Autonomy Guard` prohibiting coercion, possessiveness, exclusivity, manipulation, and emotional dependency claims.
  - Test exhaustive worst-case character length across all 8 presets and worst-case trait/dynamic combinations: verify `len(block) <= 695 <= MODULATION_BLOCK_MAX_CHARS (700)` and `_estimate_tokens(block) <= 175` with zero mid-sentence truncation.
  - Test overlong `system_prompt` (`5,000` chars) and `lore` (`10,000` chars) bounding in `resolve_turn_persona_prompt()`, including adversarial delimiter tags near the truncation boundary (`1,195` chars + `</character_persona>`).

#### `[MODIFY]` [`frontend/flutter/apps/desktop/pubspec.yaml`](../../../frontend/flutter/apps/desktop/pubspec.yaml) & `[ADD]` `frontend/flutter/apps/desktop/assets/studio/`
- **Primary Responsibility:** Desktop asset bundle configuration and project-original local studio visual assets.
- **Planned Change:**
  - Register `- assets/studio/` under `flutter: assets:`.
  - Generate and commit lightweight, project-original studio backdrop PNGs and archetype portrait PNGs under `frontend/flutter/apps/desktop/assets/studio/` along with `ASSET_PROVENANCE.md` documenting their deterministic local generation.

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart)
- **Primary Responsibility:** Decoupled visual presentation contract (`ADR-0012`) and illustrative local tendency summary helper.
- **Planned Change:**
  - Define `CharacterStageRenderMode`, `StudioBackdropPreset`, `CharacterAvatarCatalog`, and `CharacterStageVisualSpec`.
  - Provide `buildIllustrativeStyleSummary(CharacterTraitVector traits, String? presetId)` returning active trait-band badges for the Right Inspector's `Illustrative Style Summary (Local Draft Preview)` card.

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart)
- **Primary Responsibility:** Session-fenced state machine, separated read/mutation concurrency, draft tracking, and Profile isolation for Character Studio.
- **Planned Change:**
  - Implement the 5-state `StudioSessionStatus` machine, immediate purge on `RuntimeConnectionStatus.unauthorized` (even with unchanged `profileEpoch`), separated `_sessionFenceId` / `_readGeneration` / serialized `_isMutating` coordination, and uncertain-write reconciliation (detailed in §3.5).

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart), [`character_showcase_stage.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_showcase_stage.dart), [`studio_library_panel.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_library_panel.dart), & [`studio_inspector_panel.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_inspector_panel.dart)
- **Primary Responsibility:** Layer 0 backdrop, Layer 1 center character showcase stage, and Layer 2 translucent left/right `SoftGlassPanel` docks.
- **Planned Change:**
  - Implement the 3 responsive modes (`>= 1120px`, `920px..1119px`, `< 920px` slide-over drawer), center portrait + `ArchetypeSilhouetteStageWidget` fallback, `InteractiveViewer` zoom/pan controls, high-contrast token surfaces, keyboard focus rings, and the Right Inspector's 3 tabs (`Personality`, `Identity & Lore`, `Visual & Stage`).

#### `[MODIFY]` [`desktop_settings_controller.dart`](../../../frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart), [`desktop_navigation_rail.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart), [`desktop_shell.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart), [`studio_screen.dart`](../../../frontend/flutter/apps/desktop/lib/screens/studio_screen.dart), & [`main.dart`](../../../frontend/flutter/apps/desktop/lib/main.dart)
- **Primary Responsibility:** Shell wiring and unified dirty-navigation interception across rail clicks, keyboard shortcuts, and programmatic navigation.
- **Planned Change:**
  - Add `Future<bool> Function(DesktopNavDestination from, DesktopNavDestination to)? navigationGuard` and `Future<bool> requestDestination(DesktopNavDestination destination)` on `DesktopSettingsController`.
  - Route `DesktopNavigationRail` tile taps, `DesktopShell`'s `OpenSettingsIntent` (`Ctrl+,`), and programmatic `onNavigateToSettings` callbacks through `requestDestination(...)`.

---

### 3.5 Session Authorization Classification, Read/Write Concurrency Model & Dirty-Navigation Protection (Correction 2)

#### 3.5.1 Five-State Session Classification (Including Unchanged-Epoch `unauthorized`)
As verified in [`DesktopChatController.checkConnection()`](../../../frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart#L396-L491):
- At start of `checkConnection()`, `chat.connectionStatus` becomes `connecting` and `chat.authenticatedProfileId` becomes `null` while `chat.profileEpoch` is unchanged.
- If `sessionStore.readToken()` returns `null`/empty (lines 414–419) or `getOwnSession()` fails (lines 460–477), `chat.connectionStatus` becomes **`RuntimeConnectionStatus.unauthorized`**—and in the missing-token case, **`chat.profileEpoch` is NOT incremented**!

Therefore, `DesktopStudioController` classifies session state on every `chatController` notification using the following strict precedence:

| Priority & State (`StudioSessionStatus`) | Exact Trigger Condition | State, Fence & Draft Action in `DesktopStudioController` |
| :--- | :--- | :--- |
| **1. `sessionExpiredOrRevoked` (Confirmed Unauthorized — Highest Priority)** | **`chat.connectionStatus == RuntimeConnectionStatus.unauthorized`** *(regardless of whether `chat.profileEpoch` changed or stayed the same!)* OR any Studio API response returns `HTTP 401` / `403`. | **Immediate Fail-Closed Purge:** Increment `_sessionFenceId` and `_readGeneration`, clear `_isMutating`, and **immediately wipe `_boundProfileId`, `instances`, `activeState`, `selectedItem`, and any in-memory `CharacterStudioDraft` (`isDirty`)**. Another Profile's catalog or drafts can never remain visible when `unauthorized`. |
| **2. `confirmedProfileSwitch`** | `chat.authenticatedProfileId != null` AND `_boundProfileId != null` AND `chat.authenticatedProfileId != _boundProfileId` (or `chat.profileEpoch != _boundProfileEpoch` with a new `authenticatedProfileId`). | **Hard Profile Isolation Boundary:** Increment `_sessionFenceId` and `_readGeneration`, clear `_isMutating`, **immediately wipe Profile A's `instances`, `activeState`, `selectedItem`, and `CharacterStudioDraft`**, bind `_boundProfileId = chat.authenticatedProfileId` and `_boundProfileEpoch = chat.profileEpoch`, and trigger `loadStudioCatalog()` for Profile B. |
| **3. `validatingConnection` (Transient Probe)** | `chat.connectionStatus` is `connecting` or `reconnecting` AND `chat.profileEpoch == _boundProfileEpoch` AND `_boundProfileId != null`. | **Preserve `_boundProfileId`, loaded catalog, and any unsaved `CharacterStudioDraft` (`isDirty`) in memory.** Show `"Verifying connection..."` pill and disable mutating buttons until the probe finishes. |
| **4. `runtimeOffline` (Connectivity Loss Without Auth Revocation)** | `chat.connectionStatus` is `unconnected` or `error` AND `chat.profileEpoch == _boundProfileEpoch` AND `_boundProfileId != null`. | **Preserve `_boundProfileId`, loaded catalog, and unsaved `CharacterStudioDraft` locally** so transient health-check failures never discard user work. Display `"Local AI Runtime unreachable — draft preserved locally"` with a `Retry Connection` button. |
| **5. `authenticatedReady` (Initial Bind or Same-Profile Reconnect)** | `chat.isConnected` AND `chat.authenticatedProfileId != null` AND (`_boundProfileId == null` OR `chat.authenticatedProfileId == _boundProfileId`). | Set `_boundProfileId = chat.authenticatedProfileId` and `_boundProfileEpoch = chat.profileEpoch`. **If `isDirty == true` (same-Profile reconnect), preserve the user's unsaved `CharacterStudioDraft`** while refreshing background catalog lists (`templates`, `presets`, `instances`, `activeState`). |

#### 3.5.2 Separated Read Generations vs. Serialized Mutations (Solving Overlapping Read/Write Races)
Instead of a single global `_studioOperationSeq` where a background read could invalidate an in-flight write, `DesktopStudioController` separates **session authority fencing**, **read generation tracking**, and **mutation serialization**:

1. **Session Authority Fence (`_sessionFenceId` & `_boundProfileId`):**
   - Incremented **only** on `sessionExpiredOrRevoked`, `confirmedProfileSwitch`, or `dispose()`.
   - Every async operation captures `final fenceSession = _sessionFenceId; final fenceProfile = _boundProfileId ?? chat.authenticatedProfileId;`.
   - Helper `bool _isSessionValid(int fenceSession, String? fenceProfile)` checks `!_isDisposed && _sessionFenceId == fenceSession && _boundProfileId == fenceProfile && chat.connectionStatus != RuntimeConnectionStatus.unauthorized`.
2. **Read Generation Counter (`_readGeneration` — Stale-Read Protection Only):**
   - Incremented at the start of `loadStudioCatalog()` **and** at the start and completion of any mutating operation (`saveDraft`, `activateCharacter`, `resetProfileToNeutral`, `archiveInstance`).
   - A `loadStudioCatalog()` call captures `final readGen = ++_readGeneration;`. When its HTTP responses resolve, it applies the catalog update **only if** `_isSessionValid(fenceSession, fenceProfile) && _readGeneration == readGen`.
   - Thus:
     - An older catalog read never overwrites a newer catalog read.
     - A catalog read that started *before* a mutation cannot overwrite the state after the mutation starts or finishes.
     - **Crucially, starting a catalog read (`loadStudioCatalog`) NEVER invalidates an in-flight mutation!**
3. **Mutation Serialization (`_isMutating` Single-Flight Lock):**
   - Mutating operations (`saveDraft`, `activateCharacter`, `resetProfileToNeutral`, `archiveInstance`) check `if (_isMutating) return false;` and set `_isMutating = true` before their first `await`.
   - When a mutation HTTP call (`POST`, `PATCH`, `PUT`, `DELETE`) succeeds:
     - First, it checks `_isSessionValid(fenceSession, fenceProfile)`.
     - **If the session fence is still valid:** even if a read was requested while the write was in flight, the mutation **always applies its committed server result** (e.g., updating `instances`, selecting the newly created/updated `CharacterInstanceOut`, clearing `isDirty = false`), increments `_readGeneration` (canceling any stale overlapping read), and triggers a fresh post-mutation `loadStudioCatalog()`.
     - **If the session fence changed while the write was in flight (Delayed Server Commit After Profile Switch or Logout):** the controller drops the response completely so Profile A's committed write never leaks into Profile B's UI state. (Profile A's committed row remains safely stored in SQLite under Profile A and will appear if Profile A logs back in.)
4. **Authoritative Reconciliation After Uncertain Network Results (`408` / `SocketException` on Write):**
   - If a mutating request throws a timeout (`statusCode == 408`) or transport error where the server commit outcome is uncertain:
     - `DesktopStudioController` retains the user's `CharacterStudioDraft` (`isDirty = true`) so no edits are lost, surfaces an explicit banner (*"Request timed out — verifying state with local runtime..."*), and schedules `loadStudioCatalog(reconcileUncertainWrite: true)`:
     - When `loadStudioCatalog(reconcileUncertainWrite: true)` receives the authoritative `instances` and `activeState` from the backend, if the target instance on the server already matches the draft's fields (proving the write committed before the timeout), it clears `isDirty = false` and clears the warning banner; otherwise, it preserves the dirty draft so the user can safely click `Save Changes` again.
5. **Disposal & Mounted-Context Safety:**
   - `DesktopStudioController.dispose()` sets `_isDisposed = true`, increments `_sessionFenceId`, and removes its listener from `DesktopChatController`.
   - Every `async` UI handler in `StudioScreen` checks `if (!mounted) return;` after every `await`.

#### 3.5.3 Unified Dirty-State Protection Across All 5 Navigation Vectors

| Navigation Vector | Interception Mechanism when `studioController.isDirty == true` |
| :--- | :--- |
| **1. Character Library Selection (`StudioLibraryPanel`)** | Clicking another Template, Instance, Neutral Assistant, or `+ New` inside `StudioScreen` invokes `_confirmUnsavedChangesDialog(context)` (`Save & Continue`, `Discard Changes`, `Keep Editing`). |
| **2. Desktop Navigation Rail (`DesktopNavigationRail`)** | Rail item taps call `settingsController.requestDestination(destination)`, intercepted by `DesktopShell`'s registered `navigationGuard` (`Save & Leave`, `Discard & Leave`, `Stay in Studio`). |
| **3. Keyboard Navigation Shortcuts (`Ctrl+,` `OpenSettingsIntent`)** | `OpenSettingsIntent` in [`desktop_shell.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart#L78-L82) calls `settingsController.requestDestination(DesktopNavDestination.settings)`, invoking the same `navigationGuard` modal. |
| **4. Programmatic Navigation (`onNavigateToSettings`, etc.)** | All shell-level programmatic navigation callbacks route through `settingsController.requestDestination(...)`. |
| **5. Profile Switches & Confirmed Authorization Loss** | Voluntary navigation to `SettingsScreen` prompts the user **before leaving `StudioScreen`** while Profile A is still authenticated. Asynchronous `unauthorized` / session expiry fails closed and purges Profile A's draft immediately to enforce cross-Profile privacy (`ADR-0018`). |

---

### 3.6 Security, Instruction Trust Boundaries & Profile Isolation

1. **Untrusted `<character_persona>` Containment & Autonomy Safeguards (`ADR-0012`):**
   - Neither user-written `system_prompt`/`lore` nor `compile_personality_modulation_block()` directives are ever placed at the top level of the system prompt. They are strictly enclosed inside `<character_persona>...</character_persona>` beneath `DEFAULT_PERSONA` and the non-authority preamble.
   - `system_prompt` (`<= 1200` chars) and `lore` (`<= 1600` chars) are bounded on a word boundary **before** `_escape_delimiters()` so XML delimiter escaping can never be split or bypassed.
   - High-affection configurations (`affection >= 80` or `preset_id == "yandere"`) deterministically include the `Autonomy Guard` directive prohibiting coercion, possessiveness, exclusivity demands, manipulation, and emotional dependency claims.
2. **Profile Session Authority & Zero Cross-Profile Leakage (`ADR-0018`):**
   - Every Character Studio API call requires an active `ProfileSession` (`Authorization: Bearer psk_...`).
   - Any `RuntimeConnectionStatus.unauthorized` state—even with an unchanged `profileEpoch`—immediately purges `_boundProfileId`, `instances`, `activeState`, and `draft`.

---

### 3.7 Error Handling & Recovery Paths

| Failure Scenario | Deterministic Recovery Behavior |
| :--- | :--- |
| **Temporary Connection Validation (`connecting` / `reconnecting` with unchanged `profileEpoch`)** | `StudioSessionStatus.validatingConnection` preserves `_boundProfileId`, catalog, and unsaved `draft` intact; disables mutating buttons until probe finishes. |
| **Runtime Offline (`unconnected` / `error` with unchanged `profileEpoch`)** | `StudioSessionStatus.runtimeOffline` preserves `_boundProfileId`, catalog, and unsaved `draft` locally; displays `"Local AI Runtime unreachable — draft preserved locally"` with `Retry Connection`. |
| **Confirmed `unauthorized` (Even with Unchanged `profileEpoch`) or `401`/`403`** | `StudioSessionStatus.sessionExpiredOrRevoked` increments `_sessionFenceId`, immediately purges `_boundProfileId`, `instances`, `activeState`, and `draft`, and displays the SoftGlass Profile-Access Required gate card. |
| **Uncertain Write Result (`408 Timeout` / `SocketException` during Save/Activate/Archive)** | Preserves `draft` in memory, displays `"Request timed out — verifying state with local runtime..."`, and runs `loadStudioCatalog(reconcileUncertainWrite: true)` to reconcile against authoritative server state. |
| **Save / Create Validation Error (`400` / `422`)** | Preserves `draft` intact, clears `_isMutating`, aborts any pending `Save & Leave` navigation, and surfaces a dismissible error banner inside the Right Inspector header. |
| **Missing or Corrupted Image Asset** | `Image.asset` `errorBuilder` catches the decode/lookup failure and renders `StudioAtmospherePainter` or `ArchetypeSilhouetteStageWidget` with zero uncaught exceptions. |

---

### 3.8 Master Planning & Tracking Reconciliation Candidates (For Stage 5 Documentation Pass — Correction 4)

During Stage 5 documentation reconciliation, we will update master planning and tracking documents while **strictly preserving wider M2 and wider M3 as `IN PROGRESS`** and marking only independently verified completed work items as delivered:

| File | Current Outdated Text on `develop` | Planned Stage 5 Reconciliation (Preserving Wider M2 & M3 `IN PROGRESS`) |
| :--- | :--- | :--- |
| [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md) | `PC-IDENTITY-001` & `PC-IDENTITY-002` still say *"independent delivery review pending"*; `PC-CHAR-001` & `PC-CHAR-005` have no delivered status annotation. | Mark only verified items `PC-IDENTITY-001`/`002` (PR #25 `369d787`, PR #27 `5cb2fe6`), `PC-CHAR-001`/`005` (PR #29 `d22dd7e`), and Batch B's `PC-CHAR-002` & `PC-CLIENT-007` as delivered; keep wider M2 and wider M3 milestone headers `IN PROGRESS`. |
| [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../00_Master/DELIVERY_INDEX.md) | M2 and M3 rows still list PR #27 and PR #29 as pending review/merge. | Record PR #27 (`5cb2fe6`) and PR #29 (`d22dd7e`) as merged on `develop`, add `plan-m3-character-studio-personality-b.md`, and keep the overall M2 and M3 milestone statuses `IN PROGRESS`. |
| [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../00_Master/SPRINT_ROADMAP.md) | M2 and M3 status blocks do not reflect PR #27 and PR #29 merges. | Record PR #27 and PR #29 squash merges while keeping wider M2 (`IN PROGRESS`) and wider M3 (`IN PROGRESS`) truthful. |
| [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../00_Master/MASTER_CHECKLIST.md) | `PC-CHAR-001` says `"Pending DB schema \| NOT STARTED"`, `PC-CHAR-005` says `"PARTIAL"`, `PC-HOST-001` is unchecked `[ ]`. | Check off only the independently verified delivered items (`PC-HOST-001`, `PC-CHAR-001`, `PC-CHAR-005`, `PC-CHAR-002`, `PC-CLIENT-007`); leave unimplemented M2/M3 items unchecked. |
| [`docs/01_Tracking/task.md`](../../01_Tracking/task.md) | Line 16 still links to `active/task-feature-m2-profile-foundation-b.md`; Line 17 says `PR #29 ready for final review`. | Update shared milestone tracker to reflect PR #27 (`5cb2fe6`) and PR #29 (`d22dd7e`) merged into `develop`, keep wider M2 and M3 `IN PROGRESS`, and reference M3 Batch B. |

---

## 4. Step-by-Step Pseudocode & Test-First Implementation Sequence

Once the Independent Plan Gate is approved, implementation will proceed in four disciplined **Red-Green-Refactor (TDD)** phases on `feature/m3-character-studio-personality-b`:

### Phase B.1: Backend Personality Prompt Modulator & Field Bounding (`PC-CHAR-002`) — Test-First
1. **RED:** Create [`backend/tests/test_character_personality_modulator.py`](../../../backend/tests/test_character_personality_modulator.py):
   - Assert `compile_personality_modulation_block()` maps each of the 8 traits across all 5 bands (`0–19`, `20–39`, `40–59`, `60–79`, `80–100`) and boundary values (`0, 19, 20, 39, 40, 59, 60, 79, 80, 100`) deterministically.
   - Assert all 8 presets in `PRESET_REGISTRY` produce distinct modulation blocks.
   - Assert cross-trait interaction rules fire for Tsundere, Dandere, Kuudere, and Formal Advisor, and assert **Rule 1 (`Autonomy Guard`)** always fires for `yandere` and any vector with `affection >= 80`, explicitly prohibiting coercion, possessiveness, exclusivity, manipulation, and dependency claims.
   - Assert exhaustive worst-case length across all 8 presets and worst-case trait/dynamic combinations: verify `len(block) <= 695 <= MODULATION_BLOCK_MAX_CHARS (700)` and `_estimate_tokens(block) <= 175` with zero mid-sentence truncation.
   - Assert overlong `system_prompt` (`5,000` chars) and `lore` (`10,000` chars) are bounded at `1,200` and `1,600` chars before `_escape_delimiters()`, and verify Neutral Assistant (`"default"`, `"neutral-assistant"`) and legacy placeholders (`is_legacy_placeholder=True`) remain strictly `DEFAULT_PERSONA`.
2. **GREEN:** Implement `MODULATION_BLOCK_MAX_CHARS = 700`, `TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200`, `TURN_PERSONA_LORE_MAX_CHARS = 1600`, `TRAIT_BAND_CLAUSES`, `_bound_persona_field()`, and `compile_personality_modulation_block()` in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) and wire into `resolve_turn_persona_prompt()`.
3. **REFACTOR & VERIFY:** Run `pytest backend/tests/test_character_personality_modulator.py backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py -q`.

### Phase B.2: Desktop Studio Controller, Session/Async Concurrency & Stage Presenter — Test-First
1. **RED:** Create [`frontend/flutter/apps/desktop/test/desktop_studio_controller_test.dart`](../../../frontend/flutter/apps/desktop/test/desktop_studio_controller_test.dart):
   - Test catalog loading, template draft initialization, preset baseline copying, slider edits transitioning `presetId` to `'custom'`, and individual/all slider reset to template default.
   - **Test Session Classification & Unchanged-Epoch `unauthorized`:**
     - Verify `checkConnection()` setting `connectionStatus = connecting` and `authenticatedProfileId = null` (unchanged `profileEpoch`) transitions to `validatingConnection` and preserves dirty drafts.
     - Verify `checkConnection()` setting `connectionStatus = unauthorized` **with unchanged `profileEpoch`** (missing saved token) immediately transitions to `sessionExpiredOrRevoked` and purges `_boundProfileId`, `instances`, `activeState`, and any dirty `CharacterStudioDraft`.
     - Verify `runtimeOffline` (`unconnected` / `error` with unchanged `profileEpoch`) and same-Profile reconnect (`authenticatedProfileId == _boundProfileId`) preserve dirty drafts.
     - Verify `confirmedProfileSwitch` (`authenticatedProfileId != _boundProfileId`) immediately purges Profile A's state and loads Profile B's catalog.
   - **Test Separated Read Generations, Mutation Serialization & Late Commits:**
     - Verify an overlapping `loadStudioCatalog()` started while `saveDraft()` is in flight does **not** cause `saveDraft()`'s successful response to be ignored, and verify a stale read started *before* `saveDraft()` cannot overwrite the post-save state.
     - Verify concurrent calls to mutating methods while `_isMutating == true` are rejected/serialized cleanly.
     - Verify a delayed `saveDraft()` response that resolves *after* a Profile switch to Profile B (or after `unauthorized` / `dispose()`) is dropped without mutating Profile B's state.
     - Verify an uncertain write timeout (`408`) preserves the dirty draft and reconciles cleanly when `loadStudioCatalog(reconcileUncertainWrite: true)` completes.
2. **GREEN:** Implement [`character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart) and [`desktop_studio_controller.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart).
3. **REFACTOR & VERIFY:** Run `flutter test test/desktop_studio_controller_test.dart`.

### Phase B.3: Immersive Character Studio UI, Contrast/A11y & Dirty-Navigation Guards (`PC-CLIENT-007`) — Test-First
1. **RED:** Create [`frontend/flutter/apps/desktop/test/studio_screen_test.dart`](../../../frontend/flutter/apps/desktop/test/studio_screen_test.dart) and update [`desktop_shell_test.dart`](../../../frontend/flutter/apps/desktop/test/desktop_shell_test.dart):
   - Test exact responsive breakpoint boundaries and supported minimum window dimensions (`1024x640` with `240px` expanded rail = `784px` content width; `1024x640` with `72px` collapsed rail = `952px` content width; `919px`, `920px`, `1119px`, `1120px`, and `1280x800`), verifying zero overflow at both `TextScaler.linear(1.0)` and `TextScaler.linear(1.25)`.
   - Test programmatic WCAG luminance contrast (`Color.computeLuminance()`) across Light/Dark themes, all 4 backdrop presets, and all 6 `AccentPreset` palettes (`>= 4.5:1` for text on library/inspector/stage surfaces; `>= 3.0:1` for active controls and focus rings).
   - Test keyboard traversal (`Tab`), visible focus rings, and keyboard arrow-key slider adjustments.
   - Test handling of large multi-kilobyte `lore` and `system_prompt` values in the Inspector editor (verifying clean scrolling, recommended budget indicator display, and round-trip edit/save).
   - Test dirty-state protection across all 5 vectors (Library item selection, Navigation Rail click, `Ctrl+,` shortcut, programmatic navigation, and failed save during `Save & Leave`).
2. **GREEN:**
   - Generate and bundle project-original studio assets under `frontend/flutter/apps/desktop/assets/studio/` with `ASSET_PROVENANCE.md` and register in `pubspec.yaml`.
   - Implement `studio_backdrop_layer.dart`, `character_showcase_stage.dart`, `studio_library_panel.dart`, `studio_inspector_panel.dart`, and update `studio_screen.dart`, `desktop_settings_controller.dart`, `desktop_navigation_rail.dart`, `desktop_shell.dart`, and `main.dart`.
3. **REFACTOR & VERIFY:** Run `flutter test` across `companion_api`, `companion_design`, and `apps/desktop`, plus `dart analyze .`.

### Phase B.4: Full Automated Regression & Implementation Gate Handoff
1. Run the full backend pytest suite, OpenAPI/Dart parity scripts, Flutter tests, and Web harness tests.
2. Commit and push the implementation to `feature/m3-character-studio-personality-b` and **STOP** for the Independent Implementation Review Gate before beginning Stage 5 documentation/closure.

---

## 5. Acceptance Criteria & Verification Plan

### 5.1 Functional Acceptance Criteria

1. **Immersive 3-Zone Spatial Layout & Exact Post-Rail Breakpoints:** Studio renders `StudioBackdropLayer`, unobstructed central `CharacterShowcaseStage`, and translucent `StudioLibraryPanel` / `StudioInspectorPanel` docks without overflow at `1024x640` (`784px` expanded rail and `952px` collapsed rail), across `919px`/`920px`/`1119px`/`1120px` content-width boundaries, and at `1280x800` (`1.0x` and `1.25x` text scale).
2. **Browse Starter Templates:** Users can browse and inspect all seeded application-owned templates (`Warm Companion`, `Playful Companion`, `Formal Advisor`) in the Left Library.
3. **Inspect & Activate Neutral Assistant:** Users can inspect the immutable `Neutral Assistant` fallback (`traits = null`, no fake `50` sliders) and set it active for the Profile at any time.
4. **Browse Profile Character Instances:** Users can view all active Profile-owned Character Instances and toggle the collapsible `Archived / Legacy` section to inspect archived or historical placeholder entries.
5. **Create Character from Template:** Users can customize a template draft and click `Create Character` (`POST /api/v1/characters/instances`) to persist a new Profile-owned instance.
6. **Edit Identity & Lore (Including Large Text Resilience):** Users can edit `name` (`<= 120`), `summary` (`<= 500`), `system_prompt` (`<= 1,200` recommended), `lore` (`<= 1,600` recommended), and `avatar_asset` on any active Profile-owned instance, with clean scrolling and per-turn backend bounding for oversized text.
7. **Select Frozen Presets (`8 Presets`):** Choosing any of the 8 presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) initializes/updates the draft's 8 slider values from that preset's baseline vector.
8. **Adjust 8 Continuous Trait Sliders (`0–100`) & Truthful Local Summary:** Users can drag or keyboard-adjust all 8 traits, auto-switching `preset_id` to `"custom"` when diverging from a named preset, reset individual or all sliders to the template baseline, and view the explicitly labeled `Illustrative Style Summary (Local Draft Preview)` in the Right Inspector without obscuring the Center Character Showcase.
9. **Comprehensive Dirty-State Protection Across All Navigation Vectors:** Editing any field or slider sets `isDirty = true` and guards Library item switches, Navigation Rail clicks, keyboard shortcuts (`Ctrl+,`), and programmatic navigation with a `Save` / `Discard` / `Stay` confirmation modal.
10. **Set Active Character for Profile:** Clicking `Set Active for Profile` (`PUT /api/v1/characters/active`) marks the instance active (`Active in Chat` badge on both Library and Center Stage) for future conversations.
11. **Reset Profile to Neutral Assistant:** Clicking `Reset to Neutral` (`POST /api/v1/characters/active/reset-neutral`) switches the Profile's active persona back to `Neutral Assistant` without deleting or modifying any Character Instance.
12. **Archive Character Instance:** Clicking `Archive Character` (`DELETE /api/v1/characters/instances/{id}` after confirmation) archives the instance, automatically resets the Profile to Neutral Assistant if that instance was active, and preserves historical conversation bindings.
13. **Bounded, Autonomy-Safe Turn Prompt Modulation (`PC-CHAR-002`):** Active `CharacterInstance` conversations receive deterministic 8-trait + prioritized interaction/autonomy directives (`<= 695` chars worst-case $\le$ `MODULATION_BLOCK_MAX_CHARS = 700` / `<= 175` heuristic tokens) inside `<character_persona>`, including mandatory non-coercion/non-possessiveness guards for `affection >= 80` and `yandere`, while Neutral Assistant and legacy placeholder conversations receive unmodulated `DEFAULT_PERSONA`.
14. **Concurrency-Safe Session State Machine & Profile Isolation:** Any `RuntimeConnectionStatus.unauthorized` state (even with unchanged `profileEpoch`) or `confirmedProfileSwitch` immediately purges personal state; separated `_readGeneration` and serialized `_isMutating` prevent background reads from dropping committed write responses; and delayed responses after Profile switch are dropped.
15. **Verified WCAG Contrast, Keyboard Focus & Asset Provenance:** Contrast ratios (`>= 4.5:1` text, `>= 3.0:1` controls/focus rings) are verified across Light/Dark themes, backdrops, and accent presets; all studio assets are 100% project-original (`ASSET_PROVENANCE.md`) with procedural `CustomPainter` fallbacks; and `CharacterStagePresenter` cleanly isolates the 2D stage from future 3D/VRM rendering.

### 5.2 Automated Repository Checks

- [ ] `.\venv\Scripts\python.exe -m pytest backend/tests/test_character_personality_modulator.py backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py backend/tests/test_conversations.py -v` (All pass, exit 0)
- [ ] `.\venv\Scripts\python.exe -m pytest backend/tests -q` (Full backend suite passes, exit 0)
- [ ] `.\venv\Scripts\python.exe scripts/check_openapi_contract.py` (39 routes up to date, exit 0)
- [ ] `.\venv\Scripts\python.exe scripts/check_dart_openapi_parity.py --check` (100% parity verified, exit 0)
- [ ] `cd frontend/flutter/packages/companion_api; flutter test` (All pass, exit 0)
- [ ] `cd frontend/flutter/packages/companion_design; flutter test` (All pass, exit 0)
- [ ] `cd frontend/flutter/apps/desktop; flutter test` (All desktop tests including `desktop_studio_controller_test.dart`, `studio_screen_test.dart`, and `desktop_shell_test.dart` pass, exit 0)
- [ ] `cd frontend/flutter; dart analyze .` (`No issues found!`, exit 0)
- [ ] `cd frontend/web; npm test` (All web harness tests pass, exit 0)
- [ ] `git diff --check` (0 whitespace errors, exit 0)

### 5.3 Manual / Windows Desktop Acceptance Checks

- [ ] **Workflow 1 (Launch, Minimum Window & Responsive Modes):** Launch the local backend and Windows Desktop client (`.\scripts\run-desktop.ps1`). Navigate to **Studio** at `1280x800` and resize down to `1024x640` with the Navigation Rail both expanded (`240px`) and collapsed (`72px`). Verify smooth transition between 3-column dock mode and compact 2-column + slide-over Library drawer mode with zero overflow.
- [ ] **Workflow 2 (Visual, Theme, Contrast & Keyboard Focus Inspection):** Verify the full-bleed background, central Character Showcase portrait, and translucent left/right `SoftGlassPanel` docks in both **Dark Mode** and **Light Mode** and across Accent Presets. Traverse controls with `Tab` and arrow keys to verify visible focus rings and slider adjustments.
- [ ] **Workflow 3 (Create, Tune, Illustrative Summary & Dirty Navigation Guard):** Select `Warm Companion` template $\to$ choose `Tsundere` preset $\to$ adjust `warmth` to `70` and `teasing` to `85` (verify preset transitions to `Custom`, `Unsaved Changes` badge appears, and the inline `Illustrative Style Summary` updates) $\to$ attempt to click `Chat` in the Navigation Rail or press `Ctrl+,` and verify the `Unsaved Studio Customizations` modal intercepts navigation $\to$ click `Stay in Studio`, name the character `"Aria"`, and click `Create Character`.
- [ ] **Workflow 4 (Activate & Live Chat Verification):** Click `Set Active for Profile` on `"Aria"`. Navigate to **Chat**, create a **New Conversation**, and send a message. Verify the assistant responds in-character with the modulated persona, while existing older conversations remain bound to their original character or Neutral Assistant.
- [ ] **Workflow 5 (Reset to Neutral & Archive):** Return to **Studio**, click `Reset to Neutral` (verify `Neutral Assistant` becomes active), then archive `"Aria"` and confirm historical conversation messages remain intact.

### 5.4 Distinction Between Deterministic Verification & Empirical LLM Behavior

- **Deterministic Guarantee (Automated Tests):** Automated unit and integration tests deterministically verify that `compile_personality_modulation_block()` and `resolve_turn_persona_prompt()` produce the exact expected `<character_persona>` string within `MODULATION_BLOCK_MAX_CHARS = 700` (`<= 695` chars exact worst-case / `<= 175` heuristic tokens under `_estimate_tokens`) and pass that exact system prompt to `provider.generate_stream()`.
- **Empirical Observation (Live Local LLM):** Actual subword token counts under model-specific GGUF BPE/SentencePiece vocabularies and how closely a quantized local model follows stylistic nuances are empirical runtime characteristics verified during manual acceptance.

---

## 6. Risks, Recovery, Rollback & Alternatives

### 6.1 Alternative Solutions & Tradeoffs

1. **Local Preview Accuracy (Illustrative Tendency Summary vs. Shared Cross-Language Rule Codegen):**
   - *Chosen (Illustrative Local Style Summary in Right Inspector):* Explicitly labels the Dart summary as an illustrative preview of active trait bands inside the Right Inspector's `Personality` tab, avoiding false claims of raw backend prompt equivalence, avoiding cross-language codegen/REST overhead, and keeping the Center Character Showcase Stage 100% unobstructed.
2. **Separated Read Generation + Serialized Mutations vs. Single Global Operation Counter:**
   - *Chosen (Separated `_sessionFenceId`, `_readGeneration`, and `_isMutating`):* Prevents background catalog refreshes from silently dropping the response to an already-committed backend write while still guaranteeing that stale reads and cross-Profile responses are discarded.
3. **Turn-Assembly Bounding of `lore`/`system_prompt` vs. Retroactive Strict Schema Rejection:**
   - *Chosen (Turn-Assembly Bounding at `1,200`/`1,600` chars + Studio UI Recommended Counter):* Protects the 4k LLM context window from oversized text without breaking existing stored `CharacterInstance` rows or altering OpenAPI/Dart schemas.

### 6.2 Risk & Mitigation Register

| Risk | Severity | Mitigation |
| :--- | :---: | :--- |
| `checkConnection()` sets `connectionStatus = unauthorized` without incrementing `profileEpoch` when a saved token is missing. | High | `DesktopStudioController` checks `chat.connectionStatus == RuntimeConnectionStatus.unauthorized` as its highest-priority rule and immediately purges `_boundProfileId`, `instances`, `activeState`, and `draft` even when `profileEpoch` is unchanged. |
| Overlapping catalog read invalidates an in-flight `saveDraft()` response whose backend write already committed. | High | Separated `_readGeneration` (reads only) from serialized `_isMutating` (writes) and `_sessionFenceId` (Profile/auth boundary), plus uncertain-write reconciliation on timeout. |
| High-affection or `yandere` preset encourages possessive, coercive, or isolating roleplay behavior. | High | Mandatory `Autonomy Guard` (`133` chars) deterministically injects explicit non-coercion, non-possessiveness, non-exclusivity, and user-autonomy directives whenever `affection >= 80` or `preset_id == "yandere"`. |
| Unbounded user `lore` or `system_prompt` starves conversation history in `_build_context()`. | Medium | `resolve_turn_persona_prompt()` bounds `system_prompt` (`<= 1200` chars) and `lore` (`<= 1600` chars) on a word boundary prior to `_escape_delimiters()`. |

### 6.3 Rollback Strategy

- **No Database Migration Risk:** Batch B introduces **zero** Alembic migrations or schema changes.
- **Code Rollback:** Reverting the Batch B commits on `feature/m3-character-studio-personality-b` cleanly restores `resolve_turn_persona_prompt()` to its Batch A implementation and restores `StudioScreen` to its placeholder state without affecting any persisted database rows.

### 6.4 Unresolved Product Decisions Requiring Human Approval

- **None blocking Plan Gate approval.** All technical blockers and accuracy improvements from the Independent Plan Gate review have been resolved in place (Rev 3). Approval of this plan authorizes proceeding into Phase B.1–B.4 implementation on `feature/m3-character-studio-personality-b`.
