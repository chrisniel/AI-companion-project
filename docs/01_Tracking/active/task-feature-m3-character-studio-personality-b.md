# M3 Batch B — Immersive Character Studio V1 & Personality Prompt Modulator (`PC-CLIENT-007`, `PC-CHAR-002`)

> **Status:** PLANNING (Rev 2) — Plan Gate corrections applied in place; awaiting Independent Plan Gate re-review (`STOP AT PLAN GATE`).
> **Branch:** `feature/m3-character-studio-personality-b`
> **Base:** `develop` @ `d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`
> **Owner / Authorization:** Chris; planning branch creation, plan file authoring, and Plan Gate Rev 2 corrections authorized 2026-11-03. No production implementation, PR creation, or protected-branch mutation authorized yet.
> **Plan:** [`docs/02_Planning/01_Plans/plan-m3-character-studio-personality-b.md`](../../02_Planning/01_Plans/plan-m3-character-studio-personality-b.md)
> **Work Items:** `PC-CLIENT-007` (Immersive Character Studio V1 — Windows Desktop) & `PC-CHAR-002` (8-Trait Personality Prompt Modulator)

---

## 1. Delivery Lifecycle Checkpoints

- [x] **Stage 1 — PLAN (Rev 1):** Initial plan authored and committed at `88774d79df1a8807d1f207faa34aa7774b5b745c`.
- [x] **Stage 1b — PLAN GATE CORRECTIONS (Rev 2):** Applied the 4 bounded Plan Gate design corrections + asset provenance specification in place on `feature/m3-character-studio-personality-b`:
  1. **Local Preview Accuracy:** Replaced claimed prompt-equivalent center-stage drawer with an explicitly labeled inline `Illustrative Style Summary (Local Draft Preview)` card inside the Right Inspector's `Personality` tab, keeping the Center Character Showcase Stage 100% unobstructed.
  2. **Profile/Session State Machine & Async Fencing:** Designed the 5-state `StudioSessionStatus` machine (`validatingConnection`, `runtimeOffline`, `authenticatedReady`, `confirmedProfileSwitch`, `sessionExpiredOrRevoked`) with `(fenceEpoch, fenceProfileId, fenceOpSeq)` fencing so transient `checkConnection()` probes preserve local drafts while Profile switches and session revocations purge state fail-closed.
  3. **Personality Prompt Budget & Autonomy Guard:** Redesigned `compile_personality_modulation_block()` with a compact clause table, measurable `MODULATION_BLOCK_MAX_CHARS = 640` hard cap (`<= 160` heuristic tokens under `_estimate_tokens`), explicit distinction between character-heuristic estimates and BPE tokenizers, and mandatory Priority 1 `Autonomy Guard` for `affection >= 80` and `yandere` prohibiting coercion, possessiveness, exclusivity, manipulation, and emotional dependency claims.
  4. **Post-Rail Responsive Sizing & Comprehensive Dirty-Navigation Guards:** Recalculated breakpoints against actual `studioContentWidth` after `DesktopNavigationRail` (`240px` expanded / `72px` collapsed) down to `1024x640` (`>= 1120px` Wide 3-Column, `920px..1119px` Standard 3-Column, `< 920px` Compact 2-Column + Slide-Over Library Drawer), and added `DesktopSettingsController.requestDestination()` + `DesktopShell` `navigationGuard` covering Library selection, Navigation Rail clicks, `Ctrl+,` shortcut, and programmatic navigation.
  5. **Asset Provenance:** Specified 100% project-original, deterministically generated local studio assets under `frontend/flutter/apps/desktop/assets/studio/` with `ASSET_PROVENANCE.md` and procedural `CustomPainter` fallbacks.
- [ ] **Stage 2 — PLAN APPROVAL (`CURRENT GATE`):** Halted at the Independent Plan Gate awaiting re-review and approval by Chris and the independent reviewer.
- [ ] **Stage 3 — IMPLEMENTATION:** Pending Plan Gate approval.
- [ ] **Stage 4 — INDEPENDENT IMPLEMENTATION REVIEW:** Pending implementation completion.
- [ ] **Stage 5 — DOCUMENTATION + PROVISIONAL CLOSURE:** Pending Implementation Gate approval.
- [ ] **Stage 6 — DRAFT PR:** Pending authorization.
- [ ] **Stage 7 — COMBINED INDEPENDENT DOCUMENTATION/CLOSURE/PR REVIEW:** Pending draft PR.
- [ ] **Stage 8 — FINAL PRE-MERGE CLOSURE RECONCILIATION:** Pending combined review approval.
- [ ] **Stage 9 — HUMAN SQUASH MERGE:** Exclusively executed by Chris.

---

## 2. Planned Batch B Scope Summary

- **`PC-CHAR-002` (Backend Personality Prompt Modulator):**
  - [ ] Deterministic 8-trait (`0–100`) 5-band concise clause compiler, Priority 1 `Autonomy Guard` (`affection >= 80` / `yandere`), and cross-trait interaction synthesis (`compile_personality_modulation_block`, `MODULATION_BLOCK_MAX_CHARS = 640`) in `backend/app/services/character_service.py`.
  - [ ] Integration into `resolve_turn_persona_prompt()` inside `<character_persona>` while preserving `DEFAULT_PERSONA` safety precedence and keeping `Neutral Assistant` and legacy placeholders unmodulated.
  - [ ] Unit, budget-limit, and autonomy-safety regression tests in `backend/tests/test_character_personality_modulator.py`.
- **`PC-CLIENT-007` (Immersive Windows Desktop Character Studio V1):**
  - [ ] `DesktopStudioController` (`desktop_studio_controller.dart`) with 5-state `StudioSessionStatus` machine, `(epoch, profileId, opSeq)` async fencing, draft-vs.-persisted state tracking, preset initialization, and dirty-state protection.
  - [ ] `CharacterStagePresenter` (`character_stage_presenter.dart`) & `CharacterShowcaseStage` (`character_showcase_stage.dart`) providing an unobstructed center portrait/archetype stage with zoom/pan controls and a clean boundary for future 3D/VRM rendering.
  - [ ] `StudioBackdropLayer` (`studio_backdrop_layer.dart`) providing full-content-area project-original thematic background imagery (`ASSET_PROVENANCE.md`) with `StudioAtmospherePainter` procedural fallback and readability scrims.
  - [ ] Translucent `SoftGlassPanel` docks (`StudioLibraryPanel` on left, `StudioInspectorPanel` on right with inline `Illustrative Style Summary`), post-rail responsive breakpoints (`>= 1120px`, `920px..1119px`, `< 920px`), and `DesktopShell` / `DesktopSettingsController` dirty-navigation guard wiring.
  - [ ] Controller, widget, breakpoint-boundary, dirty-navigation, and accessibility tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_shell_test.dart`).
