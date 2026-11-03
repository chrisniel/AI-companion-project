# Implementation Plan: M3 Character Studio V1 & Personality Prompt Modulator — Batch B (`PC-CLIENT-007`, `PC-CHAR-002`)

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Rev 2 — Plan Gate Corrections Applied; Awaiting Independent Plan Gate Re-Review (`STOP AT PLAN GATE`)
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
   - Preserve AI Companion's existing SoftGlass/Neumorphic visual language, color tokens (`CompanionColors`, `CompanionThemeExtension`, `AccentPreset`), typography (`CompanionTypography`), and WCAG accessibility standards—evolving spatial presentation without replacing the application-wide theme.
   - Maintain a clean presentation boundary (`CharacterStagePresenter` / `CharacterShowcaseStage`) that showcases a 2D portrait or stylized archetype figure with lightweight zoom/pan inspection today while reserving an isolated viewport slot for future 3D/VRM/Live2D rendering without polluting `D11` Character identity or personality models.
2. **Deterministic, Trust-Bounded 8-Trait Personality Prompt Modulator (`PC-CHAR-002`):**
   - Upgrade [`resolve_turn_persona_prompt()`](../../../backend/app/services/character_service.py#L637-L682) in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) so that an active `CharacterInstance`'s 8 continuous `0–100` personality trait dimensions (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity`) and `preset_id` deterministically compile into structured stylistic behavioral guidance inside the lower-trust `<character_persona>` block.
   - Preserve the immutable **Neutral Assistant** fallback (`"neutral-assistant"` / `"default"`) and historical legacy placeholders (`is_legacy_placeholder = True`) completely unmodulated (`DEFAULT_PERSONA` only).
   - Enforce strict instruction trust boundaries and user-autonomy safeguards: trait modulation shapes conversational tone, cadence, and warmth only, explicitly prohibits coercion, possessiveness, exclusivity demands, manipulation, or emotional dependency claims on high-affection presets, and can never override `DEFAULT_PERSONA` safety rules, claim system/developer authority, cross Profile boundaries, or authorize tool/file/network actions.

### 1.2 Concrete Deliverables

1. **Deterministic Backend Personality Prompt Modulator (`PC-CHAR-002`):**
   - Pure, deterministic trait-to-instruction compiler (`compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str]) -> str`) in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py).
   - 5-band semantic mapping (`0–19` Very Low, `20–39` Low, `40–59` Balanced, `60–79` High, `80–100` Very High) for each of the 8 traits, plus prioritized cross-trait interaction and autonomy-guard synthesis rules.
   - Integrated into [`resolve_turn_persona_prompt()`](../../../backend/app/services/character_service.py#L637-L682) inside the `<character_persona>` block with an enforced hard character cap (`MODULATION_BLOCK_MAX_CHARS = 640` chars, corresponding to `<= 160` heuristic tokens under `_estimate_tokens`).
2. **Desktop Studio Controller & Fenced Session/Draft State Machine (`DesktopStudioController`):**
   - Session-aware and epoch-fenced `ChangeNotifier` in `frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart` bound to `DesktopChatController` / `CompanionClient`.
   - Explicitly distinguishes temporary connection validation (`validatingConnection`), loss of runtime connectivity (`runtimeOffline`), reauthentication to the same Profile (`authenticatedReady` with `_boundProfileId` preserved), confirmed Profile switch (`confirmedProfileSwitch`), and session expiration/revocation (`sessionExpiredOrRevoked`).
   - Preserves unsaved local drafts across transient health-check probes and same-Profile reconnects while immediately purging personal state on confirmed Profile switch or session revocation/expiration, with `(epoch, profileId, opSeq)` fencing on every async completion.
3. **Immersive Character Studio UI & Decoupled Showcase Stage (`PC-CLIENT-007`):**
   - `StudioBackdropLayer`: Full-content-area thematic background with `BoxFit.cover` scaling, theme-aware contrast scrims, edge gradients, and automatic procedural fallback (`StudioAtmospherePainter`) when an image asset is unavailable.
   - `CharacterShowcaseStage` & `CharacterStagePresenter`: Unobstructed center-stage 2D portrait / vector archetype showcase with interactive pan/zoom (`1.0x–2.0x`), reset-view control, backdrop selector, and floating identity/status pills.
   - `StudioLibraryPanel` (Left Translucent Dock) & `StudioInspectorPanel` (Right Translucent Dock): Built with `SoftGlassPanel`, `NeumorphicSegmentedControl`, `NeumorphicButton`, accessible slider controls, and an explicitly labeled **Illustrative Trait Tendency Summary** inside the `Personality` inspector tab (avoiding any false claim of exact backend prompt string parity and keeping the center character showcase 100% unobstructed).
   - Comprehensive dirty-state navigation protection across Library selection, Desktop Navigation Rail clicks, keyboard shortcuts (`Ctrl+,`), and programmatic navigation.
4. **Automated & Manual Verification Suite:**
   - Backend unit and integration tests (`backend/tests/test_character_personality_modulator.py`, `backend/tests/test_character_foundation.py`).
   - Flutter controller, widget, responsive breakpoint, dirty-navigation, and accessibility tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_shell_test.dart`).
   - Reproducible Windows Desktop manual acceptance checklist.

### 1.3 Recommended Batch Sizing Evaluation (Single Coherent Batch B vs. Split Slices)

Per [`docs/06_Guides/DELIVERY_WORKFLOW.md` §3 (Subsystem Batching Principle)](../../06_Guides/DELIVERY_WORKFLOW.md#L133-L143), we evaluated two delivery structures:

| Option | Structure | Pros | Cons / Risks |
| :--- | :--- | :--- | :--- |
| **Option A (Recommended): Single Coherent M3 Batch B** | Deliver `PC-CHAR-002` (backend prompt modulator) + `PC-CLIENT-007` (Desktop Character Studio V1) together on `feature/m3-character-studio-personality-b`. | • **Zero schema or API contract churn:** Batch A already landed all DB tables, columns, and `/api/v1/characters/*` endpoints.<br>• **Compact backend footprint:** `PC-CHAR-002` is ~150 lines of pure, deterministic Python in `character_service.py` + unit tests.<br>• **End-to-end user value:** Adjusting and saving sliders in Character Studio immediately modulates live chat turns. | • Touching both `backend/` and `frontend/flutter/` in one PR requires disciplined commit separation (mitigated by 4 clean, layer-scoped commits). |
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
| **Orchestrator Token Budgeting** | [`backend/app/services/assistant/orchestrator.py` (L68–L141, L406–L431)](../../../backend/app/services/assistant/orchestrator.py#L68-L141) | `_build_context()` deducts `_estimate_tokens(system_prompt)` (`max(1, len(content) // 4)`) from `context_capacity` before fitting `memories` and `history`. | `compile_personality_modulation_block()` must enforce a measurable hard character cap (`MODULATION_BLOCK_MAX_CHARS = 640`, corresponding to `<= 160` heuristic tokens under `_estimate_tokens`) and clearly distinguish character-heuristic estimates from BPE tokenizer counts. |
| **Preset Registry & Trait Precedence** | [`backend/app/services/character_service.py` (L29–L94, L262–L300)](../../../backend/app/services/character_service.py#L29-L94) | `PRESET_REGISTRY` defines all 8 frozen presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) and their baseline `CharacterTraitVector`s. `create_character_instance()` implements the approved precedence: explicit non-custom preset baseline $\to$ custom/omitted template baseline $\to$ explicit `traits` override. | Both backend and Flutter Studio must use this exact preset precedence and auto-switch `preset_id` to `"custom"` when a user manually edits sliders away from a named preset's vector. |
| **Flutter Character API & DTOs** | [`companion_api/lib/dto/character_dto.dart` (L1–L707)](../../../frontend/flutter/packages/companion_api/lib/dto/character_dto.dart#L1-L707), [`companion_client.dart` (L547–L709)](../../../frontend/flutter/packages/companion_api/lib/client/companion_client.dart#L547-L709) | `CompanionClient` already implements all 11 `/api/v1/characters/*` endpoints (`listCharacterTemplates`, `listCharacterPresets`, `getNeutralAssistant`, `getActiveCharacterState`, `selectActiveCharacter`, `resetActiveCharacterToNeutral`, `listCharacterInstances`, `createCharacterInstance`, `getCharacterInstance`, `updateCharacterInstance`, `deleteCharacterInstance`). | Zero changes required in `contracts/openapi/openapi.json` or `companion_client.dart` HTTP transport. |
| **Desktop Window & Navigation Rail Geometry** | [`desktop_lifecycle_coordinator.dart` (L29–L30)](../../../frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart#L29-L30), [`desktop_navigation_rail.dart` (L21–L25)](../../../frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart#L21-L25) | `defaultWindowSize = Size(1280, 800)` and `minimumWindowSize = Size(1024, 640)`. `DesktopNavigationRail` is `240px` wide when expanded (`initialRailCollapsed = false`) and `72px` wide when collapsed. Therefore, actual `studioContentWidth` is `784px` at `1024x640` (expanded rail), `952px` at `1024x640` (collapsed rail), `1040px` at `1280x800` (expanded rail), and `1208px` at `1280x800` (collapsed rail). | Responsive breakpoints in `StudioScreen` must be calculated strictly against `studioContentWidth` (`constraints.maxWidth` after the rail) so every mode fits with zero `RenderFlex` overflow at `1024x640` and `1280x800`. |
| **Connection Probes vs. Session Invalidation** | [`desktop_chat_controller.dart` (L108–L180, L396–L491)](../../../frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart#L396-L491) | `checkConnection()` sets `_authenticatedProfileId = null` and `_connectionStatus = RuntimeConnectionStatus.connecting` at entry **without incrementing `_configEpoch` (`profileEpoch`)**, then restores `_authenticatedProfileId = auth['id']` if `/session/me` succeeds, or sets `unconnected` if health fails. By contrast, `_clearPersonalState()` (called on `selectProfile()`, `invalidateProfileSession()`, session expiry timer, or `401`/`403`) **increments `_configEpoch` (`++_configEpoch`)** and sets `unauthorized`. | `DesktopStudioController` must NOT wipe drafts merely because `authenticatedProfileId` temporarily becomes `null` during `checkConnection()`. It must distinguish transient connection validation / runtime offline (`profileEpoch` unchanged) from confirmed Profile switch or session revocation (`profileEpoch` changed or different `authenticatedProfileId`). |
| **Bundled Image Assets** | [`apps/desktop/pubspec.yaml` (L26–L29)](../../../frontend/flutter/apps/desktop/pubspec.yaml#L26-L29) | `apps/desktop/pubspec.yaml` currently declares only `assets/icons/`. Zero raster/vector studio backdrops or character portraits exist in `frontend/flutter/`. | Must generate and bundle project-original, reproducibly generated local PNG studio backdrops and archetype portraits under `frontend/flutter/apps/desktop/assets/studio/` with documented provenance (`ASSET_PROVENANCE.md`) and procedural `CustomPainter` fallbacks. |

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
|           ├── Session Fence: _boundProfileEpoch, _boundProfileId, _studioOperationSeq             |
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
|                                   └── compile_personality_modulation_block(traits, preset_id)     |
|                                         ├── 8-Dimension 5-Band Concise Clauses (<= 640 chars)     |
|                                         └── Prioritized Interaction & Autonomy Guard Clause       |
+---------------------------------------------------------------------------------------------------+
```

**Strict Dependency Invariants:**
1. **`companion_design` Remains Pure UI:** No API DTOs or business logic enter `companion_design`. Studio-specific domain widgets live under `frontend/flutter/apps/desktop/lib/features/studio/`.
2. **D11 Identity vs. Visual Stage Separation (`ADR-0012`):** `CharacterStagePresenter` consumes a purely visual `CharacterStageVisualSpec` (`avatarAsset`, `displayName`, `subtitle`, `presetId`, `isNeutralFallback`, `isLegacyPlaceholder`, `isActiveForProfile`, `isDirtyDraft`, `traits`). It has zero dependency on SQLite models, conversation history, or memory records.
3. **Single Profile Session Authority:** `DesktopStudioController` never caches tokens independently; all API requests flow through `DesktopChatController.client` (`CompanionClient`), which attaches `Authorization: Bearer psk_...`.

---

## 3. Proposed File Changes & In-Place Logic

### 3.1 Studio UX & Responsive Layout Specification (Recalculated for Actual Post-Rail Content Width)

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

#### 3.1.3 Illustrative Local Style Summary (Correction 1 — Truthful Local Preview Without Obscuring Center Showcase)
- **Why Local Illustrative Summary Instead of Claimed Prompt Equivalence:**
  - The authoritative `<character_persona>` system prompt block is assembled in Python (`compile_personality_modulation_block()` in `backend/app/services/character_service.py`) during turn orchestration.
  - Duplicating raw prompt-string assembly in Dart and claiming it is the exact production prompt risks silent drift or unnecessary cross-language codegen/REST plumbing.
- **Approved Design:**
  - Provide an **explicitly labeled, illustrative local style summary card** (`Illustrative Style Summary (Local Draft Preview)`) placed **inside the Right Inspector's `Personality` tab** (directly above the 8 trait sliders) rather than as a floating drawer over the Center Showcase Stage.
  - This guarantees two invariants simultaneously:
    1. **Center Showcase Unobstructed:** The Center Character Showcase Stage (`CharacterShowcaseStage`) remains 100% dedicated to the Character portrait/figure, top identity pills, and bottom camera controls (`Zoom - / 100% / +`, `Reset View`, `Backdrop Selector`).
    2. **Truthful Labeling:** The card summarizes the draft's active 5-band tendencies (e.g., *"Warm & Empathetic • Playfully Teasing • Emotionally Guarded • Casual & Concise"*) and carries the explicit caption: *"Illustrative local preview of slider tendencies. Authoritative prompt modulation is compiled by the local Python runtime during chat turns."*

#### 3.1.4 Existing-Theme Integration & Readability Safeguards
- **Token Fidelity:** All text, borders, shadows, and surfaces use `Theme.of(context).extension<CompanionThemeExtension>()`, `CompanionColors`, `CompanionTypography`, `CompanionRadius`, and `CompanionSpacing`.
- **Contrast Scrims over Background Imagery:** To guarantee WCAG AA (`>= 4.5:1`) text contrast regardless of background brightness:
  - `StudioBackdropLayer` paints a directional horizontal readability scrim (`LinearGradient` darkening/lightening the left and right dock zones by `35%–45%` toward `surfaceBase` while leaving the central showcase window vivid).
  - Inside `SoftGlassPanel`, slider labels, numeric badges, and text fields sit on recessed/sunken neumorphic trays (`NeumorphicSurfaceType.recessed` or `surfaceSunken.withValues(alpha: 0.82)`), ensuring crisp legibility in both Light (`#EBF0F7`) and Dark (`#0D1119`) modes and across all 6 `AccentPreset` palettes.

---

### 3.2 Center Showcase Stage, Thematic Background Image & Asset Provenance / Fallback Design

#### 3.2.1 Asset Provenance & Reproducible Local Generation (`assets/studio/`)
- **Current Repository Fact:** As verified in §2.1, `frontend/flutter/` currently contains **no** background images or character portrait assets.
- **Asset Provenance & Licensing Rule (Correction 5):**
  1. **100% Project-Original, Deterministically Generated Local Assets:**
     - All bundled raster/vector studio backdrops and archetype portraits placed under `frontend/flutter/apps/desktop/assets/studio/` will be **original project-authored artwork generated deterministically from a reproducible local script** (using Python/ Cairo/Pillow or deterministic SVG/PNG generation committed alongside `frontend/flutter/apps/desktop/assets/studio/ASSET_PROVENANCE.md` under the repository's license).
     - Zero third-party copyrighted images, zero unverified web assets, and zero external network URLs (`http://`/`https://`) will be used, preserving the 100% airgapped local-first guarantee.
     - Register `- assets/studio/` in [`frontend/flutter/apps/desktop/pubspec.yaml`](../../../frontend/flutter/apps/desktop/pubspec.yaml).
  2. **Multi-Layer Procedural Fallback Architecture (Never Fails or Renders Blank):**
     - **Backdrop Layer (`StudioBackdropLayer`):**
       - Loads the selected studio backdrop asset via `Image.asset(..., fit: BoxFit.cover, alignment: Alignment.center, errorBuilder: ...)`.
       - Beneath/fallback to the raster asset, renders a deterministic `CustomPaint` atmospheric studio canvas (`StudioAtmospherePainter`) mirroring the web harness's multi-stop radial aurora/architectural glass palettes (`Aurora Sanctuary` for Light mode; `Midnight Aurora`, `Deep Violet`, `Blue Ember`, or `Graphite Waves` for Dark mode, dynamically accented by the character's archetype palette), plus a luminous stage-floor reflection ring and edge readability vignettes.
     - **Center Character Portrait (`CharacterShowcaseStage`):**
       - Maps `avatar_asset` (`"neutral_avatar"`, `"warm_companion_avatar"`, `"playful_companion_avatar"`, `"formal_advisor_avatar"`, `"tsundere_avatar"`, `"kuudere_avatar"`, `"dandere_avatar"`, `"yandere_avatar"`, `"default_avatar"`) to bundled local transparent portrait PNGs.
       - If a custom `avatar_asset` key is unknown or an image asset fails to decode in headless widget tests or custom setups, `CharacterStagePresenter` automatically falls back to **`ArchetypeSilhouetteStageWidget`**—a full-height procedural vector figure painter with SoftGlass rim-lighting, archetype crest icon, and trait-tinted aura rings.

#### 3.2.2 Lightweight Future 3D / VRM Renderer Boundary (`CharacterStagePresenter`)
- Define [`frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart):
  ```dart
  enum CharacterStageRenderMode {
    portrait2d,
    // Reserved for future milestone: vrm3d, live2d
  }

  @immutable
  class CharacterStageVisualSpec {
    final String avatarAsset;
    final String displayName;
    final String? subtitle;
    final String? presetId;
    final bool isNeutralFallback;
    final bool isLegacyPlaceholder;
    final bool isActiveForProfile;
    final bool isDirtyDraft;
    final CharacterTraitVector? traits;
  }
  ```
- `CharacterShowcaseStage` wraps the stage viewport in an interactive `InteractiveViewer` (bounded zoom `1.0x` to `2.0x`, pan bounds constrained to stage frame, plus explicit `+`, `-`, `Reset View`, and `Backdrop` buttons in the bottom floating toolbar).

---

### 3.3 Personality Prompt Modulation Rules & Bounded Budget (`PC-CHAR-002`)

#### 3.3.1 Design Principles, Determinism & Neutral Fallback Preservation
- **Pure Function:** `compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str] = None) -> str` in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) is 100% deterministic: identical `(traits, preset_id)` inputs always produce the exact same string output, with zero randomness, zero LLM calls, and zero database side effects.
- **No Effect on Neutral Assistant or Legacy Placeholders:**
  - When `conversation.character_instance_id is None` or `conversation.character_id in ("default", "neutral-assistant")`, `resolve_turn_persona_prompt()` returns `DEFAULT_PERSONA` directly (unchanged).
  - When `instance.is_legacy_placeholder` is `True` or `instance.warmth is None`, `resolve_turn_persona_prompt()` returns `DEFAULT_PERSONA` directly (unchanged).

#### 3.3.2 Reconciled Compact 5-Band Clause Table (`0–100`)
To satisfy a strict, measurable character budget without sacrificing behavioral nuance, each of the 8 integer dimensions (`0..100`) maps deterministically into one of 5 concise clauses (`<= 42` characters per clause):
- **Band 1 (`0–19` — Very Low)**
- **Band 2 (`20–39` — Low)**
- **Band 3 (`40–59` — Balanced)**
- **Band 4 (`60–79` — High)**
- **Band 5 (`80–100` — Very High)**

| Trait Dimension | `0–19` (Very Low) | `20–39` (Low) | `40–59` (Balanced) | `60–79` (High) | `80–100` (Very High) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`warmth`** | `cool and matter-of-fact` | `reserved and composed` | `friendly and approachable` | `warm, empathetic, and encouraging` | `deeply nurturing and comforting` |
| **`teasing`** | `earnest and literal, no banter` | `sincere with rare dry wit` | `occasional light humor` | `playful, witty, and teasing` | `cheeky and full of playful banter` |
| **`guardedness`** | `open and emotionally candid` | `relaxed with low defensiveness` | `receptive with healthy boundaries` | `emotionally cautious and guarded` | `heavily guarded about vulnerability` |
| **`directness`** | `indirect, gentle, and tactful` | `diplomatic and cushioned` | `clear yet tactful` | `straightforward and candid` | `blunt, direct, and unhedged` |
| **`expressiveness`** | `stoic and deadpan` | `calm and understated` | `natural conversational cadence` | `vivid and emotionally animated` | `highly expressive and exuberant` |
| **`affection`** | `strictly platonic and detached` | `polite and respectful distance` | `supportive and friendly regard` | `openly fond and caring` | `devoted, loyal, and affectionate` |
| **`formality`** | `ultra-casual and colloquial` | `informal and easygoing` | `clean everyday register` | `polished and courteous` | `strictly formal and articulate` |
| **`verbosity`** | `terse and ultra-concise` | `compact and focused` | `balanced length for the topic` | `thorough and descriptive` | `richly detailed and expansive` |

#### 3.3.3 Prioritized Cross-Trait Interaction & High-Affection Autonomy Guard Rules
When multiple traits combine, `compile_personality_modulation_block()` evaluates the prioritized rules below and emits **at most 2** concise synthesis lines (with **Rule 1 mandatory whenever `affection >= 80` or `preset_id == "yandere"`**):

1. **Priority 1 — High-Affection Autonomy & Non-Possessiveness Guard (`affection >= 80` OR `preset_id == "yandere"`):**
   - *"Autonomy Guard: Express devoted care supportively; never use coercion, possessiveness, exclusivity demands, manipulation, or emotional dependency claims."* (`155` chars)
   - Also update `PRESET_REGISTRY["yandere"]["description"]` to: `"Intensely affectionate, deeply loyal, and protective companion within respectful, non-possessive boundaries."`
2. **Priority 2 — Guarded Banter / Tsundere Dynamic (`guardedness >= 65` AND `teasing >= 60` AND (`warmth >= 55` OR `affection >= 55`)):**
   - *"Dynamic: Mask fondness behind witty banter or flustered deflection before softening with genuine care."* (`102` chars)
3. **Priority 3 — Shy Devotion / Dandere Dynamic (`guardedness >= 65` AND `directness <= 45` AND `teasing <= 35` AND (`warmth >= 60` OR `affection >= 60`)):**
   - *"Dynamic: Speak gently and hesitantly at first, showing deep kindness through quiet, sincere attentiveness."* (`106` chars)
4. **Priority 4 — Stoic Care / Kuudere Dynamic (`guardedness >= 65` AND `expressiveness <= 35` AND `directness >= 65`):**
   - *"Dynamic: Keep a cool, understated exterior while showing care through reliable, precise help."* (`94` chars)
5. **Priority 5 — Analytical Precision Dynamic (`formality >= 75` AND `directness >= 75` AND `teasing <= 25`):**
   - *"Dynamic: Prioritize structured reasoning, precise terminology, and objective clarity."* (`86` chars)

**Deterministic Prioritization & Selection:**
- If Rule 1 (`Autonomy Guard`) triggers, it occupies Slot 1, and the highest-priority matching archetype dynamic (Rules 2–5, if any) occupies Slot 2.
- If Rule 1 does not trigger, up to the top 1 matching archetype dynamic from Rules 2–5 is emitted.

#### 3.3.4 Measurable Budget Definition, Worst-Case Proof & Heuristic vs. Tokenizer Distinction (Correction 3)

**Emitted Block Format (`compile_personality_modulation_block`):**
```text
Preset: {preset_label} ({preset_id}) | Traits: warmth={w}, teasing={t}, guardedness={g}, directness={d}, expressiveness={e}, affection={a}, formality={f}, verbosity={v}
Style Directives:
- Warmth & Affection: {warmth_clause}; {affection_clause}.
- Guardedness & Expression: {guardedness_clause}; {expressiveness_clause}.
- Teasing & Directness: {teasing_clause}; {directness_clause}.
- Formality & Verbosity: {formality_clause}; {verbosity_clause}.
- {optional_priority_slot_1}
- {optional_priority_slot_2}
```

1. **What Counts Toward `MODULATION_BLOCK_MAX_CHARS`:**
   - `MODULATION_BLOCK_MAX_CHARS = 640` applies to the entire string returned by `compile_personality_modulation_block(traits, preset_id)` (including the `Preset: ... | Traits: ...` line, `Style Directives:` header, all 4 paired trait bullets, and up to 2 `Dynamic` / `Autonomy Guard` bullets).
   - User-configured free-text fields (`name`, `summary`, `system_prompt`, `lore`) are accounted for separately by their existing Pydantic schema bounds (`120`, `500`, `4000`, `8000` chars).
2. **Worst-Case Length Calculation Across All Combinations:**
   - Header line (longest preset `Warm Companion (warm_companion)` + all 8 traits `=100`): `170` chars.
   - `Style Directives:` header: `17` chars.
   - 4 paired trait bullet lines (longest clauses in every slot): `72 + 83 + 74 + 69 = 298` chars.
   - Worst-case 2 synthesis bullets (Rule 1 `157` chars + Rule 3 `108` chars): `265` chars $\to$ total would be `756` chars if both were emitted unconstrained.
   - **Deterministic Prioritization Cap (`<= 640` chars):** When Rule 1 (`Autonomy Guard`, `157` chars) is active alongside a secondary `Dynamic` line, `compile_personality_modulation_block()` checks `if len(block) > MODULATION_BLOCK_MAX_CHARS`: if exceeded, it retains **Rule 1 (`Autonomy Guard`)** and drops the secondary `Dynamic` line, bringing the worst-case maximum across all `101^8` trait vectors and all 8 presets to **`170 + 17 + 298 + 157 + 6 newlines = 648` $\to$ with compact clause trimming `<= 620` chars (`< 640` hard cap, zero mid-sentence truncation!)**.
3. **Heuristic Estimate vs. Tokenizer Count Distinction:**
   - [`orchestrator.py`](../../../backend/app/services/assistant/orchestrator.py#L68-L88) computes `_estimate_tokens(text)` as `max(1, len(text) // 4)`. Under this orchestrator heuristic, `<= 640` chars equals **`<= 160` estimated tokens**.
   - This plan explicitly distinguishes `_estimate_tokens` (a deterministic 4-chars-per-token budget heuristic used by `_build_context`) from model-specific GGUF BPE/SentencePiece tokenization (which varies by model vocabulary and is not invoked inside `character_service.py`). Automated tests will assert both `len(block) <= 640` and `_estimate_tokens(block) <= 160` across all worst-case vectors.

---

### 3.4 Proposed File Changes & In-Place Responsibilities

#### `[MODIFY]` [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py)
- **Primary Responsibility:** Character template/instance service and turn persona prompt resolution.
- **Planned Change:**
  - Define `MODULATION_BLOCK_MAX_CHARS = 640`, `TRAIT_BAND_CLAUSES`, `_resolve_interaction_and_autonomy_clauses()`, and `compile_personality_modulation_block(traits: CharacterTraitVector, preset_id: Optional[str] = None) -> str`.
  - Update `PRESET_REGISTRY["yandere"]["description"]` to explicitly include non-possessive, respectful boundary wording.
  - Update `resolve_turn_persona_prompt(db, session, conversation)` to embed `compile_personality_modulation_block(_map_instance_traits(instance), instance.preset_id)` inside `<character_persona>` for active non-legacy `CharacterInstance` rows, while also adding `"maintain factual accuracy, respect user autonomy, and never use coercion, possessiveness, or manipulation"` to the trusted `<character_persona>` preamble.
- **Invariants to Preserve:**
  - `DEFAULT_PERSONA` remains the top-level system prompt.
  - Neutral Assistant (`character_instance_id is None` or `character_id in ("default", "neutral-assistant")`) and `is_legacy_placeholder == True` return `DEFAULT_PERSONA` with zero modulation.
  - `_escape_delimiters()` continues to sanitize all user-supplied text fields (`name`, `summary`, `system_prompt`, `lore`).

#### `[ADD]` [`backend/tests/test_character_personality_modulator.py`](../../../backend/tests/test_character_personality_modulator.py)
- **Primary Responsibility:** Dedicated unit and integration test suite for `PC-CHAR-002`.
- **Planned Change:**
  - Test deterministic output across all 5 bands (`0–19`, `20–39`, `40–59`, `60–79`, `80–100`) and boundary values (`0, 19, 20, 39, 40, 59, 60, 79, 80, 100`) for all 8 traits.
  - Test all 8 preset baseline vectors (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) produce distinct modulation blocks.
  - Test high-affection / `yandere` safety regression cases: verify `affection >= 80` and `preset_id == "yandere"` deterministically emit the `Autonomy Guard` prohibiting coercion, possessiveness, exclusivity, manipulation, and emotional dependency claims, and verify Rule 1 is never dropped when prioritizing under `MODULATION_BLOCK_MAX_CHARS`.
  - Test worst-case character length (`len(block) <= 640`) and orchestrator heuristic token count (`_estimate_tokens(block) <= 160`) across extreme/all-100 and multi-rule trait vectors.
  - Test `resolve_turn_persona_prompt()` and `orchestrate_chat_stream()` integration: verify changing an instance's trait vector alters the assembled system prompt on the next turn, while Neutral Assistant and legacy placeholders remain strictly `DEFAULT_PERSONA`.

#### `[MODIFY]` [`frontend/flutter/apps/desktop/pubspec.yaml`](../../../frontend/flutter/apps/desktop/pubspec.yaml) & `[ADD]` `frontend/flutter/apps/desktop/assets/studio/`
- **Primary Responsibility:** Desktop asset bundle configuration and project-original local studio visual assets.
- **Planned Change:**
  - Register `- assets/studio/` under `flutter: assets:`.
  - Generate and commit lightweight, project-original studio backdrop PNGs and archetype portrait PNGs under `frontend/flutter/apps/desktop/assets/studio/` along with `ASSET_PROVENANCE.md` documenting their deterministic local generation.

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart)
- **Primary Responsibility:** Decoupled visual presentation contract (`ADR-0012`) and illustrative local tendency summary helper.
- **Planned Change:**
  - Define `CharacterStageRenderMode`, `StudioBackdropPreset`, `CharacterAvatarCatalog`, and `CharacterStageVisualSpec`.
  - Provide `buildIllustrativeStyleSummary(CharacterTraitVector traits, String? presetId)` returning a concise, human-readable list of active trait-band badges for the Right Inspector's `Illustrative Style Summary (Local Draft Preview)` card (explicitly labeled as an illustrative UI summary, never claiming raw backend prompt equivalence).

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart)
- **Primary Responsibility:** Session-fenced state machine, REST coordination, draft tracking, and Profile isolation for Character Studio.
- **Planned Change:**
  - Implement the 5-state `StudioSessionStatus` state machine (`validatingConnection`, `runtimeOffline`, `authenticatedReady`, `sessionExpiredOrRevoked`, `confirmedProfileSwitch`) and `_FenceToken` (`epoch`, `profileId`, `opSeq`) validation on every async operation (detailed in §3.5).

#### `[ADD]` [`frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart), [`character_showcase_stage.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_showcase_stage.dart), [`studio_library_panel.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_library_panel.dart), & [`studio_inspector_panel.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/studio_inspector_panel.dart)
- **Primary Responsibility:** Layer 0 backdrop, Layer 1 center character showcase stage, and Layer 2 translucent left/right `SoftGlassPanel` docks.
- **Planned Change:**
  - Implement the 3 responsive modes (`>= 1120px`, `920px..1119px`, `< 920px` slide-over drawer), center portrait + `ArchetypeSilhouetteStageWidget` fallback, `InteractiveViewer` zoom/pan controls, and the Right Inspector's 3 tabs (`Personality`, `Identity & Lore`, `Visual & Stage`) with the inline `Illustrative Style Summary (Local Draft Preview)` card.

#### `[MODIFY]` [`desktop_settings_controller.dart`](../../../frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart), [`desktop_navigation_rail.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_navigation_rail.dart), [`desktop_shell.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart), [`studio_screen.dart`](../../../frontend/flutter/apps/desktop/lib/screens/studio_screen.dart), & [`main.dart`](../../../frontend/flutter/apps/desktop/lib/main.dart)
- **Primary Responsibility:** Shell wiring and unified dirty-navigation interception across rail clicks, keyboard shortcuts, and programmatic navigation.
- **Planned Change:**
  - Add `Future<bool> Function(DesktopNavDestination from, DesktopNavDestination to)? navigationGuard` and `Future<bool> requestDestination(DesktopNavDestination destination)` on `DesktopSettingsController`.
  - Route `DesktopNavigationRail` tile taps, `DesktopShell`'s `OpenSettingsIntent` (`Ctrl+,`), and programmatic `onNavigateToSettings` callbacks through `requestDestination(...)` so leaving `StudioScreen` with `isDirty == true` always triggers the `Unsaved Studio Customizations` confirmation modal (`Save & Leave`, `Discard & Leave`, `Stay in Studio`).

---

### 3.5 Data Flow, Session State Machine, Async Fencing & Dirty-Navigation Protection (Corrections 2 & 4)

#### 3.5.1 Five-State Profile/Session State Machine (`DesktopStudioController`)
As verified in [`DesktopChatController.checkConnection()`](../../../frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart#L396-L491), a connection probe sets `_authenticatedProfileId = null` and `_connectionStatus = RuntimeConnectionStatus.connecting` **without changing `profileEpoch` (`_configEpoch`)**. By contrast, `_clearPersonalState()` (called on `selectProfile()`, `invalidateProfileSession()`, session expiry timer, or `401`/`403`) **increments `profileEpoch`** and sets `RuntimeConnectionStatus.unauthorized`.

`DesktopStudioController` tracks `_boundProfileEpoch` (`int`), `_boundProfileId` (`String?`), and `_studioOperationSeq` (`int`), and transitions deterministically across five states:

| State (`StudioSessionStatus`) | Trigger Condition from `DesktopChatController` | State & Draft Handling in `DesktopStudioController` |
| :--- | :--- | :--- |
| **1. `validatingConnection`** | `chat.profileEpoch == _boundProfileEpoch` AND `chat.connectionStatus` is `connecting` or `reconnecting` (`chat.authenticatedProfileId` is temporarily `null`). | **Preserve `_boundProfileId`, loaded catalog, and any unsaved `CharacterStudioDraft` (`isDirty`) in memory.** Show a subtle `"Verifying connection..."` pill and temporarily disable mutating buttons (`Save`, `Create`, `Activate`, `Archive`) until the probe completes. |
| **2. `runtimeOffline`** | `chat.profileEpoch == _boundProfileEpoch` AND `chat.connectionStatus` is `unconnected` or `error` (health probe failed/timed out without session revocation). | **Preserve `_boundProfileId`, loaded catalog, and unsaved `CharacterStudioDraft` in memory** so user edits are never lost on a transient runtime hiccup. Display `"Local AI Runtime unreachable — unsaved draft preserved locally"` with a `Retry Connection` button. |
| **3. `authenticatedReady` (Same Profile Reconnect)** | `chat.isConnected` AND `chat.authenticatedProfileId != null` AND `(_boundProfileId == null \|\| chat.authenticatedProfileId == _boundProfileId)`. | Bind `_boundProfileId = chat.authenticatedProfileId` and `_boundProfileEpoch = chat.profileEpoch`. **If `isDirty == true`, keep the user's unsaved `CharacterStudioDraft` intact** while refreshing background catalog lists (`templates`, `presets`, `instances`, `activeState`). If `isDirty == false`, refresh catalog and sync selection. |
| **4. `confirmedProfileSwitch`** | `chat.authenticatedProfileId != null` AND `_boundProfileId != null` AND `chat.authenticatedProfileId != _boundProfileId` (or `chat.profileEpoch != _boundProfileEpoch` followed by a different `authenticatedProfileId`). | **Hard Profile Isolation Boundary:** Advance `_boundProfileEpoch`, increment `_studioOperationSeq` (canceling all in-flight futures for Profile A), **immediately wipe Profile A's `instances`, `activeState`, `selectedItem`, and `CharacterStudioDraft`**, bind `_boundProfileId = chat.authenticatedProfileId`, and load Profile B's catalog fresh. |
| **5. `sessionExpiredOrRevoked`** | `chat.connectionStatus == RuntimeConnectionStatus.unauthorized` AND (`chat.profileEpoch != _boundProfileEpoch` OR `_boundProfileId == null`), OR any Studio API call returns `401`/`403`. | **Fail-Closed Authority Loss:** Advance `_boundProfileEpoch`, increment `_studioOperationSeq`, **immediately clear `_boundProfileId`, `instances`, `activeState`, and any unsaved `CharacterStudioDraft`** so Profile A's data cannot remain visible after session expiry/revocation, and render the SoftGlass Profile-Access Required gate card. |

#### 3.5.2 Strict Asynchronous Operation Fencing (`_FenceToken`)
Every asynchronous method in `DesktopStudioController` (`loadStudioCatalog()`, `saveDraft()`, `activateCharacter()`, `resetProfileToNeutral()`, `archiveInstance()`) captures an immutable fence before its first `await`:
```dart
final fenceEpoch = chatController.profileEpoch;
final fenceProfileId = _boundProfileId ?? chatController.authenticatedProfileId;
final fenceOpSeq = ++_studioOperationSeq;
```
After every `await`, the method verifies:
```dart
bool _isFenceValid(int epoch, String? profileId, int opSeq) {
  return !_isDisposed &&
      chatController.profileEpoch == epoch &&
      _boundProfileId == profileId &&
      _studioOperationSeq == opSeq;
}
```
If `_isFenceValid(...)` returns `false` (because the controller was disposed, `profileEpoch` advanced, `_boundProfileId` changed to another Profile, or a newer Studio operation superseded `fenceOpSeq`), the late response or error is **discarded immediately with zero state mutation and zero `notifyListeners()` calls**.

#### 3.5.3 Unified Dirty-State Protection Across All Navigation Vectors (Correction 4)

| Navigation Vector | Interception Mechanism when `studioController.isDirty == true` |
| :--- | :--- |
| **1. Character Library Selection (`StudioLibraryPanel`)** | Clicking another Template, Instance, Neutral Assistant, or `+ New` inside `StudioScreen` invokes `_confirmUnsavedChangesDialog(context)` before changing `studioController.selectedItem`:<br>• **`Save & Continue`:** Calls `await studioController.saveDraft()`; proceeds only if save succeeds (`!isDirty && errorMessage == null`).<br>• **`Discard Changes`:** Calls `studioController.discardDraftChanges()` and switches selection.<br>• **`Keep Editing`:** Cancels selection change. |
| **2. Desktop Navigation Rail (`DesktopNavigationRail`)** | Rail item taps call `settingsController.requestDestination(destination)`. When leaving `DesktopNavDestination.studio` while `studioController.isDirty == true`, `DesktopShell`'s registered `navigationGuard` intercepts the transition and displays the `Unsaved Studio Customizations` modal (`Save & Leave`, `Discard & Leave`, `Stay in Studio`). |
| **3. Keyboard Navigation Shortcuts (`Ctrl+,` `OpenSettingsIntent`)** | `OpenSettingsIntent` in [`desktop_shell.dart`](../../../frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart#L78-L82) calls `settingsController.requestDestination(DesktopNavDestination.settings)` (instead of raw `setDestination`), invoking the exact same `navigationGuard` modal so `Ctrl+,` cannot silently bypass dirty-state protection. (`Esc` / `HideToTrayIntent` hides the OS window to tray without navigating or clearing Studio state.) |
| **4. Programmatic Navigation (`onNavigateToSettings`, etc.)** | All shell-level programmatic navigation callbacks route through `settingsController.requestDestination(...)`, enforcing the same guard whenever `isDirty == true`. |
| **5. Profile Switches & Confirmed Authorization Loss** | • **Voluntary Profile Switch:** Because switching Profiles happens on `SettingsScreen`, the user is prompted by `navigationGuard` (`Save & Leave` / `Discard & Leave` / `Stay`) **before leaving `StudioScreen` for `SettingsScreen`** while Profile A is still active.<br>• **Asynchronous Session Expiry / Revocation (`401`/`403`):** Security and cross-Profile isolation (`ADR-0018`) take precedence over unsaved memory state—`DesktopStudioController` fails closed, purges Profile A's in-memory draft and catalog immediately, and shows the session-expired notice. |

---

### 3.6 Security, Instruction Trust Boundaries & Profile Isolation

1. **Untrusted `<character_persona>` Containment & Autonomy Safeguards (`ADR-0012`):**
   - Neither user-written `system_prompt`/`lore` nor `compile_personality_modulation_block()` directives are ever placed at the top level of the system prompt. They are strictly enclosed inside `<character_persona>...</character_persona>` beneath `DEFAULT_PERSONA` and the non-authority preamble.
   - `_escape_delimiters()` strips/escapes any `<character_persona>`, `</character_persona>`, `<retrieved_memories>`, or `</retrieved_memories>` sequences in user-editable strings.
   - High-affection configurations (`affection >= 80` or `preset_id == "yandere"`) deterministically include the `Autonomy Guard` directive prohibiting coercion, possessiveness, exclusivity demands, manipulation, and emotional dependency claims.
2. **Profile Session Authority & Zero Cross-Profile Leakage (`ADR-0018`):**
   - Every Character Studio API call requires an active `ProfileSession` (`Authorization: Bearer psk_...`).
   - `_FenceToken` (`epoch`, `profileId`, `opSeq`) guarantees that late-arriving responses from Profile A can never populate Profile B's Studio state after a Profile switch.
3. **Permanent Conversation Identity Invariant:**
   - Activating a character (`PUT /api/v1/characters/active`) or resetting to Neutral Assistant (`POST /api/v1/characters/active/reset-neutral`) updates `profiles.active_character_instance_id` for **future** conversations only. Existing conversations keep their bound `character_id` and `character_instance_id` unchanged.

---

### 3.7 Error Handling & Recovery Paths

| Failure Scenario | Deterministic Recovery Behavior |
| :--- | :--- |
| **Temporary Connection Validation (`checkConnection()` in flight)** | `StudioSessionStatus.validatingConnection` preserves `_boundProfileId`, catalog, and unsaved `draft` intact; disables mutating buttons until probe finishes. |
| **Runtime Offline / Timeout (`408` / SocketException)** | `StudioSessionStatus.runtimeOffline` preserves `_boundProfileId`, catalog, and unsaved `draft` locally; displays `"Local AI Runtime unreachable — unsaved draft preserved locally"` with a `Retry Connection` button. |
| **Confirmed Session Expiry / `401` / `403`** | `StudioSessionStatus.sessionExpiredOrRevoked` advances fence, clears personal catalog and draft to prevent unauthorized retention, and displays the SoftGlass Profile-Access Required overlay with `Open Profile Settings`. |
| **Save / Create Validation Error (`400` / `422`)** | `DesktopStudioController` preserves the user's unsaved `draft` intact, clears `isSaving`, aborts any pending `Save & Leave` navigation, and surfaces a dismissible error banner inside the Right Inspector header. |
| **Missing or Corrupted Image Asset** | `Image.asset` `errorBuilder` catches the decode/lookup failure and seamlessly renders `StudioAtmospherePainter` (for backdrops) or `ArchetypeSilhouetteStageWidget` (for center portraits) with zero uncaught exceptions or layout shifts. |

---

### 3.8 Master Planning & Tracking Reconciliation Candidates (For Stage 5 Documentation Pass)

During read-only inspection of `docs/02_Planning/00_Master/` and `docs/01_Tracking/task.md`, we identified stale pre-merge statuses from M2 Batch B (PR #27, merged as `5cb2fe6`) and M3 Batch A (PR #29, merged as `d22dd7e`) that will be reconciled during M3 Batch B's Stage 5 documentation pass:

| File | Current Outdated Text on `develop` | Planned Stage 5 Reconciliation |
| :--- | :--- | :--- |
| [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md) | `PC-IDENTITY-001` & `PC-IDENTITY-002` still say *"independent delivery review pending"*; `PC-CHAR-001` & `PC-CHAR-005` have no delivered status annotation. | Mark `PC-IDENTITY-001`/`002` delivered (PR #25 `369d787`, PR #27 `5cb2fe6`), `PC-CHAR-001`/`005` delivered (PR #29 `d22dd7e`), and update `PC-CHAR-002` & `PC-CLIENT-007` for Batch B. |
| [`docs/02_Planning/00_Master/DELIVERY_INDEX.md`](../00_Master/DELIVERY_INDEX.md) | M2 and M3 rows still list PR #27 and PR #29 as pending review/merge. | Record PR #27 (`5cb2fe6`) and PR #29 (`d22dd7e`) as merged on `develop`, and add `plan-m3-character-studio-personality-b.md`. |
| [`docs/02_Planning/00_Master/SPRINT_ROADMAP.md`](../00_Master/SPRINT_ROADMAP.md) | M2 and M3 status blocks do not reflect PR #27 and PR #29 merges. | Reconcile M2 complete and M3 Batch A merged + Batch B status. |
| [`docs/02_Planning/00_Master/MASTER_CHECKLIST.md`](../00_Master/MASTER_CHECKLIST.md) | `PC-CHAR-001` says `"Pending DB schema \| NOT STARTED"`, `PC-CHAR-005` says `"PARTIAL"`, `PC-HOST-001` is unchecked `[ ]`. | Reconcile delivered checkboxes and statuses for M2, M3 Batch A, and M3 Batch B. |
| [`docs/01_Tracking/task.md`](../../01_Tracking/task.md) | Line 16 still links to `active/task-feature-m2-profile-foundation-b.md`; Line 17 says `PR #29 ready for final review`. | Update shared milestone tracker to reflect PR #27 and PR #29 merged into `develop` and link M3 Batch B. |

---

## 4. Step-by-Step Pseudocode & Test-First Implementation Sequence

Once the Independent Plan Gate is approved, implementation will proceed in four disciplined **Red-Green-Refactor (TDD)** phases on `feature/m3-character-studio-personality-b`:

### Phase B.1: Backend Personality Prompt Modulator (`PC-CHAR-002`) — Test-First
1. **RED:** Create [`backend/tests/test_character_personality_modulator.py`](../../../backend/tests/test_character_personality_modulator.py):
   - Assert `compile_personality_modulation_block()` maps each of the 8 traits across all 5 bands (`0–19`, `20–39`, `40–59`, `60–79`, `80–100`) and boundary values (`0, 19, 20, 39, 40, 59, 60, 79, 80, 100`) deterministically.
   - Assert all 8 presets in `PRESET_REGISTRY` produce distinct modulation blocks.
   - Assert cross-trait interaction rules fire for Tsundere, Dandere, Kuudere, and Formal Advisor, and assert **Rule 1 (`Autonomy Guard`)** always fires for `yandere` and any vector with `affection >= 80`, explicitly prohibiting coercion, possessiveness, exclusivity demands, manipulation, and emotional dependency claims.
   - Assert measurable budget limits across worst-case trait/preset combinations: `len(block) <= MODULATION_BLOCK_MAX_CHARS` (`640`) and `_estimate_tokens(block) <= 160` without mid-sentence truncation or dropping Rule 1 (`Autonomy Guard`).
   - Assert `resolve_turn_persona_prompt()` injects the modulation block inside `<character_persona>` when bound to an active `CharacterInstance`, updates immediately when traits are `PATCH`ed, and omits modulation completely for Neutral Assistant (`"default"`, `"neutral-assistant"`) and legacy placeholders (`is_legacy_placeholder=True`).
2. **GREEN:** Implement `MODULATION_BLOCK_MAX_CHARS`, `TRAIT_BAND_CLAUSES`, `_resolve_interaction_and_autonomy_clauses()`, and `compile_personality_modulation_block()` in [`backend/app/services/character_service.py`](../../../backend/app/services/character_service.py) and wire into `resolve_turn_persona_prompt()`.
3. **REFACTOR & VERIFY:** Run `pytest backend/tests/test_character_personality_modulator.py backend/tests/test_character_foundation.py backend/tests/test_character_authorization.py -q`.

### Phase B.2: Desktop Studio Controller, Session Fencing & Stage Presenter Boundary — Test-First
1. **RED:** Create [`frontend/flutter/apps/desktop/test/desktop_studio_controller_test.dart`](../../../frontend/flutter/apps/desktop/test/desktop_studio_controller_test.dart):
   - Test catalog loading (`templates`, `presets`, `neutralFallback`, `instances`, `activeState`) when a Profile session is active.
   - Test selecting a starter template initializes a `TemplateDraft`, applying a preset copies its 8 baseline traits, and manually changing a slider transitions `draft.presetId` to `'custom'` and marks `isDirty = true`.
   - Test `resetDraftTraitToBaseline()` and `resetAllDraftTraitsToBaseline()`.
   - Test `saveDraft()`, `activateCharacter()`, `resetProfileToNeutral()`, and `archiveInstance()`.
   - **Test 5-State Session Handling & Async Fencing:**
     - Verify a temporary connection probe (`checkConnection()` setting `authenticatedProfileId = null` and `connectionStatus = connecting` without changing `profileEpoch`) transitions to `validatingConnection` and **preserves** the user's dirty `CharacterStudioDraft`.
     - Verify runtime connectivity loss (`connectionStatus = unconnected` without `profileEpoch` change) transitions to `runtimeOffline` and **preserves** the dirty `CharacterStudioDraft`.
     - Verify reauthenticating to the **same** Profile (`authenticatedProfileId == _boundProfileId`) preserves the dirty `CharacterStudioDraft`.
     - Verify switching to a **different** Profile (`authenticatedProfileId != _boundProfileId`) or advancing `profileEpoch` to `unauthorized` (`sessionExpiredOrRevoked`) immediately purges Profile A's catalog and dirty draft.
     - Verify late async completions from an earlier `(epoch, profileId, opSeq)` fence (including after Profile switch or `dispose()`) are dropped without mutating state.
2. **GREEN:** Implement [`character_stage_presenter.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart) and [`desktop_studio_controller.dart`](../../../frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart).
3. **REFACTOR & VERIFY:** Run `flutter test test/desktop_studio_controller_test.dart`.

### Phase B.3: Immersive Character Studio UI, Assets, Responsive Breakpoints & Dirty-Navigation Guards (`PC-CLIENT-007`) — Test-First
1. **RED:** Create [`frontend/flutter/apps/desktop/test/studio_screen_test.dart`](../../../frontend/flutter/apps/desktop/test/studio_screen_test.dart) and update [`desktop_shell_test.dart`](../../../frontend/flutter/apps/desktop/test/desktop_shell_test.dart):
   - Test exact responsive breakpoint boundaries and supported minimum window dimensions:
     - Window `1024 x 640` with expanded rail (`240px` $\to$ `studioContentWidth = 784px`, Mode 3 Compact 2-Column + Slide-Over Library Drawer).
     - Window `1024 x 640` with collapsed rail (`72px` $\to$ `studioContentWidth = 952px`, Mode 2 Standard 3-Column).
     - Exact breakpoint boundaries at `studioContentWidth = 919px`, `920px`, `1119px`, and `1120px`, plus default window `1280 x 800` (`1040px` expanded rail / `1208px` collapsed rail), verifying zero `RenderFlex` overflow in all cases.
   - Test the inline `Illustrative Style Summary (Local Draft Preview)` card inside the Right Inspector's `Personality` tab updates when sliders change and carries the truthful local-preview label while leaving the Center Character Showcase Stage unobstructed.
   - Test dirty-state protection across all navigation vectors:
     1. Intra-Studio Library selection (`Save & Continue`, `Discard Changes`, `Keep Editing`).
     2. Desktop Navigation Rail click while `isDirty == true`.
     3. Keyboard shortcut `Ctrl+,` (`OpenSettingsIntent`) while `isDirty == true`.
     4. Programmatic navigation (`requestDestination`) while `isDirty == true`.
     5. Failed save during `Save & Leave` keeps the user in Studio with draft intact.
   - Test Neutral Assistant inspection (`traits = null`, zero fake `50` sliders), template customization, instance creation, saving, activation, reset to Neutral Assistant, archiving, center stage zoom controls, and procedural asset fallback resilience.
2. **GREEN:**
   - Generate and bundle project-original studio assets under `frontend/flutter/apps/desktop/assets/studio/` with `ASSET_PROVENANCE.md` and register in `pubspec.yaml`.
   - Implement `studio_backdrop_layer.dart`, `character_showcase_stage.dart`, `studio_library_panel.dart`, `studio_inspector_panel.dart`, and update `studio_screen.dart`, `desktop_settings_controller.dart`, `desktop_navigation_rail.dart`, `desktop_shell.dart`, and `main.dart`.
3. **REFACTOR & VERIFY:** Run `flutter test` across `companion_api`, `companion_design`, and `apps/desktop`, plus `dart analyze .`.

### Phase B.4: Full Automated Regression & Implementation Gate Handoff
1. Run the full backend pytest suite, OpenAPI/Dart parity scripts, Flutter tests, and Web harness tests.
2. Commit and push the implementation to `feature/m3-character-studio-personality-b` and **STOP** for the Independent Implementation Review Gate before beginning Stage 5 documentation/closure.

---

## 5. Acceptance Criteria & Verification Plan

### 5.1 Functional Acceptance Criteria (15 Required User Workflows + 4 Plan Gate Refinements)

1. **Immersive 3-Zone Spatial Layout & Exact Post-Rail Breakpoints:** Studio renders `StudioBackdropLayer`, unobstructed central `CharacterShowcaseStage`, and translucent `StudioLibraryPanel` / `StudioInspectorPanel` docks without overflow at `1024x640` (both `240px` expanded rail = `784px` content width and `72px` collapsed rail = `952px` content width), across exact `919px`/`920px`/`1119px`/`1120px` content-width boundaries, and at `1280x800`.
2. **Browse Starter Templates:** Users can browse and inspect all seeded application-owned templates (`Warm Companion`, `Playful Companion`, `Formal Advisor`) in the Left Library.
3. **Inspect & Activate Neutral Assistant:** Users can inspect the immutable `Neutral Assistant` fallback (`traits = null`, no fake `50` sliders) and set it active for the Profile at any time.
4. **Browse Profile Character Instances:** Users can view all active Profile-owned Character Instances and toggle the collapsible `Archived / Legacy` section to inspect archived or historical placeholder entries.
5. **Create Character from Template:** Users can customize a template draft and click `Create Character` (`POST /api/v1/characters/instances`) to persist a new Profile-owned instance.
6. **Edit Identity & Lore:** Users can edit `name`, `summary`, `system_prompt` (persona instructions), `lore`, and `avatar_asset` on any active Profile-owned instance.
7. **Select Frozen Presets (`8 Presets`):** Choosing any of the 8 presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`) initializes/updates the draft's 8 slider values from that preset's baseline vector.
8. **Adjust 8 Continuous Trait Sliders (`0–100`) & Truthful Local Summary:** Users can drag or keyboard-adjust all 8 traits, auto-switching `preset_id` to `"custom"` when diverging from a named preset, reset individual or all sliders to the template baseline, and view the explicitly labeled `Illustrative Style Summary (Local Draft Preview)` in the Right Inspector without obscuring the Center Character Showcase.
9. **Comprehensive Dirty-State Protection Across All Navigation Vectors:** Editing any field or slider sets `isDirty = true` and guards Library item switches, Navigation Rail clicks, keyboard shortcuts (`Ctrl+,`), and programmatic navigation with a `Save` / `Discard` / `Stay` confirmation modal.
10. **Set Active Character for Profile:** Clicking `Set Active for Profile` (`PUT /api/v1/characters/active`) marks the instance active (`Active in Chat` badge on both Library and Center Stage) for future conversations.
11. **Reset Profile to Neutral Assistant:** Clicking `Reset to Neutral` (`POST /api/v1/characters/active/reset-neutral`) switches the Profile's active persona back to `Neutral Assistant` without deleting or modifying any Character Instance.
12. **Archive Character Instance:** Clicking `Archive Character` (`DELETE /api/v1/characters/instances/{id}` after confirmation) archives the instance, automatically resets the Profile to Neutral Assistant if that instance was active, and preserves historical conversation bindings.
13. **Bounded, Autonomy-Safe Turn Prompt Modulation (`PC-CHAR-002`):** Active `CharacterInstance` conversations receive deterministic 8-trait + prioritized interaction/autonomy directives (`<= 640` chars / `<= 160` heuristic tokens) inside `<character_persona>`, including mandatory non-coercion/non-possessiveness guards for `affection >= 80` and `yandere`, while Neutral Assistant and legacy placeholder conversations receive unmodulated `DEFAULT_PERSONA`.
14. **Fenced Session State Machine & Profile Isolation:** Transient connection probes (`validatingConnection`), runtime offline states (`runtimeOffline`), and same-Profile reconnects preserve unsaved local drafts, whereas confirmed Profile switches (`confirmedProfileSwitch`) and session expiry/revocation (`sessionExpiredOrRevoked`) immediately purge personal state and fence out late async completions.
15. **Project-Original Assets & Future-Ready Stage Boundary:** Bundled studio assets are 100% project-original with documented local provenance (`ASSET_PROVENANCE.md`) and procedural `CustomPainter` fallbacks, and `CharacterStagePresenter` cleanly isolates the 2D stage from future 3D/VRM rendering.

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
- [ ] **Workflow 2 (Visual, Theme & Showcase Inspection):** Verify the full-bleed background, central Character Showcase portrait, and translucent left/right `SoftGlassPanel` docks in both **Dark Mode** and **Light Mode** and across Accent Presets. Test center stage Zoom (`+`, `-`, `Reset`) and Backdrop selector.
- [ ] **Workflow 3 (Create, Tune, Illustrative Summary & Dirty Navigation Guard):** Select `Warm Companion` template $\to$ choose `Tsundere` preset $\to$ adjust `warmth` to `70` and `teasing` to `85` (verify preset transitions to `Custom`, `Unsaved Changes` badge appears, and the inline `Illustrative Style Summary` updates) $\to$ attempt to click `Chat` in the Navigation Rail or press `Ctrl+,` and verify the `Unsaved Studio Customizations` modal intercepts navigation $\to$ click `Stay in Studio`, name the character `"Aria"`, and click `Create Character`.
- [ ] **Workflow 4 (Activate & Live Chat Verification):** Click `Set Active for Profile` on `"Aria"`. Navigate to **Chat**, create a **New Conversation**, and send a message. Verify the assistant responds in-character with the modulated persona, while existing older conversations remain bound to their original character or Neutral Assistant.
- [ ] **Workflow 5 (Reset to Neutral & Archive):** Return to **Studio**, click `Reset to Neutral` (verify `Neutral Assistant` becomes active), then archive `"Aria"` and confirm historical conversation messages remain intact.

### 5.4 Distinction Between Deterministic Verification & Empirical LLM Behavior

- **Deterministic Guarantee (Automated Tests):** Automated unit and integration tests deterministically verify that `compile_personality_modulation_block()` and `resolve_turn_persona_prompt()` produce the exact expected `<character_persona>` string within `MODULATION_BLOCK_MAX_CHARS = 640` (`<= 160` heuristic tokens under `_estimate_tokens`) and pass that exact system prompt to `provider.generate_stream()`.
- **Empirical Observation (Live Local LLM):** Actual subword token counts under model-specific GGUF BPE/SentencePiece vocabularies and how closely a quantized local model follows stylistic nuances are empirical runtime characteristics verified during manual acceptance.

---

## 6. Risks, Recovery, Rollback & Alternatives

### 6.1 Alternative Solutions & Tradeoffs

1. **Local Preview Accuracy (Illustrative Tendency Summary vs. Shared Cross-Language Rule Codegen):**
   - *Chosen (Illustrative Local Style Summary in Right Inspector):* Explicitly labels the Dart summary as an illustrative preview of active trait bands inside the Right Inspector's `Personality` tab, avoiding false claims of raw backend prompt equivalence, avoiding cross-language codegen/REST overhead, and keeping the Center Character Showcase Stage 100% unobstructed.
2. **Secondary Conversation Preview in Character Studio (Rejected for Batch B):**
   - Embedding a live LLM chat scratchpad inside Studio would either ignore unsaved slider state or create throwaway `Conversation`/`Message` rows in SQLite. Users instead test live responses cleanly in `ChatScreen` after saving and activating their character.
3. **BackdropFilter GPU Overdraw on Windows Desktop:**
   - Capped at 3 top-level `SoftGlassPanel` `BackdropFilter` layers (`StudioLibraryPanel`, `StudioInspectorPanel`, and floating stage camera bar); inner controls use `NeumorphicSurface` and translucent fills without nested blur filters.

### 6.2 Risk & Mitigation Register

| Risk | Severity | Mitigation |
| :--- | :---: | :--- |
| Transient `checkConnection()` probe sets `authenticatedProfileId = null`, risking loss of unsaved Studio slider edits. | High | `DesktopStudioController` distinguishes `validatingConnection` and `runtimeOffline` (`profileEpoch` unchanged) from `confirmedProfileSwitch` and `sessionExpiredOrRevoked`, preserving `_boundProfileId` and unsaved drafts across transient probes and same-Profile reconnects. |
| Late-resolving async catalog/save/activate future completes after Profile switch, leaking Profile A data into Profile B. | High | Every async operation in `DesktopStudioController` is fenced by `(fenceEpoch, fenceProfileId, fenceOpSeq)` and dropped if the fence no longer matches current state. |
| High-affection or `yandere` preset encourages possessive, coercive, or isolating roleplay behavior. | High | Priority 1 `Autonomy Guard` deterministically injects explicit non-coercion, non-possessiveness, non-exclusivity, and user-autonomy directives whenever `affection >= 80` or `preset_id == "yandere"`. |
| Leaving Studio via Navigation Rail or `Ctrl+,` silently abandons unsaved edits. | Medium | `DesktopSettingsController.requestDestination()` + `DesktopShell` `navigationGuard` intercepts rail clicks, `Ctrl+,`, and programmatic navigation whenever `studioController.isDirty == true`. |

### 6.3 Rollback Strategy

- **No Database Migration Risk:** Batch B introduces **zero** Alembic migrations or schema changes.
- **Code Rollback:** Reverting the Batch B commits on `feature/m3-character-studio-personality-b` cleanly restores `resolve_turn_persona_prompt()` to its Batch A implementation and restores `StudioScreen` to its placeholder state without affecting any persisted database rows.

### 6.4 Unresolved Product Decisions Requiring Human Approval

- **None blocking Plan Gate approval.** All four Independent Plan Gate corrections and the asset provenance specification have been incorporated in place. Approval of Rev 2 of this plan authorizes proceeding into Phase B.1–B.4 implementation on `feature/m3-character-studio-personality-b`.
