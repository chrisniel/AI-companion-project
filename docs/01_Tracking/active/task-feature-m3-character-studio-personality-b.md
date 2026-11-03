# M3 Batch B — Immersive Character Studio V1 & Personality Prompt Modulator (`PC-CLIENT-007`, `PC-CHAR-002`)

> **Status:** PLANNING — Plan authored and committed; awaiting Independent Plan Gate approval (`STOP AT PLAN GATE`).
> **Branch:** `feature/m3-character-studio-personality-b`
> **Base:** `develop` @ `d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`
> **Owner / Authorization:** Chris; planning branch creation, plan file authoring, commit, and HTTPS push authorized 2026-11-03. No production implementation, PR creation, or protected-branch mutation authorized yet.
> **Plan:** [`docs/02_Planning/01_Plans/plan-m3-character-studio-personality-b.md`](../../02_Planning/01_Plans/plan-m3-character-studio-personality-b.md)
> **Work Items:** `PC-CLIENT-007` (Immersive Character Studio V1 — Windows Desktop) & `PC-CHAR-002` (8-Trait Personality Prompt Modulator)

---

## 1. Delivery Lifecycle Checkpoints

- [x] **Stage 1 — PLAN:** Read-only repository investigation completed; authored [`docs/02_Planning/01_Plans/plan-m3-character-studio-personality-b.md`](../../02_Planning/01_Plans/plan-m3-character-studio-personality-b.md) on `feature/m3-character-studio-personality-b`.
- [ ] **Stage 2 — PLAN APPROVAL (`CURRENT GATE`):** Halted at the Independent Plan Gate awaiting review and approval by Chris and the independent reviewer.
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
  - [ ] Deterministic 8-trait (`0–100`) 5-band directive compiler and cross-trait interaction synthesis (`compile_personality_modulation_block`) in `backend/app/services/character_service.py`.
  - [ ] Integration into `resolve_turn_persona_prompt()` inside `<character_persona>` while preserving `DEFAULT_PERSONA` safety precedence and keeping `Neutral Assistant` and legacy placeholders unmodulated.
  - [ ] Unit and integration tests in `backend/tests/test_character_personality_modulator.py`.
- **`PC-CLIENT-007` (Immersive Windows Desktop Character Studio V1):**
  - [ ] `DesktopStudioController` (`desktop_studio_controller.dart`) with Profile-epoch synchronization, draft-vs.-persisted state tracking, preset initialization, and dirty-state protection.
  - [ ] `CharacterStagePresenter` (`character_stage_presenter.dart`) & `CharacterShowcaseStage` (`character_showcase_stage.dart`) providing a prominent center portrait/archetype stage with zoom/pan controls, zero-persistence Style & Prompt Preview drawer, and a clean boundary for future 3D/VRM rendering.
  - [ ] `StudioBackdropLayer` (`studio_backdrop_layer.dart`) providing full-content-area thematic background imagery with procedural atmospheric canvas fallback and readability scrims.
  - [ ] Translucent `SoftGlassPanel` docks (`StudioLibraryPanel` on left, `StudioInspectorPanel` on right) and `DesktopShell` wiring.
  - [ ] Controller, widget, responsive layout, and accessibility tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_shell_test.dart`).
