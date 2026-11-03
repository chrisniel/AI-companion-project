# M3 Batch B — Immersive Character Studio V1 & Personality Prompt Modulator (`PC-CLIENT-007`, `PC-CHAR-002`)

> **Status:** PLANNING (Rev 3) — Final Plan Gate corrections applied in place; awaiting Independent Plan Gate re-review (`STOP AT PLAN GATE`).
> **Branch:** `feature/m3-character-studio-personality-b`
> **Base:** `develop` @ `d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`
> **Owner / Authorization:** Chris; planning branch creation, plan file authoring, and Plan Gate Rev 2 / Rev 3 corrections authorized 2026-11-03. No production implementation, PR creation, or protected-branch mutation authorized yet.
> **Plan:** [`docs/02_Planning/01_Plans/plan-m3-character-studio-personality-b.md`](../../02_Planning/01_Plans/plan-m3-character-studio-personality-b.md)
> **Work Items:** `PC-CLIENT-007` (Immersive Character Studio V1 — Windows Desktop) & `PC-CHAR-002` (8-Trait Personality Prompt Modulator)

---

## 1. Delivery Lifecycle Checkpoints

- [x] **Stage 1 — PLAN (Rev 1):** Initial plan authored and committed at `88774d79df1a8807d1f207faa34aa7774b5b745c`.
- [x] **Stage 1b — PLAN GATE CORRECTIONS (Rev 2):** Applied initial 4 Plan Gate design corrections + asset provenance at `50cf5ddca65d718d285f3b7f07e42d06bed6bda4`.
- [x] **Stage 1c — FINAL PLAN GATE CORRECTIONS (Rev 3):** Resolved the remaining 2 technical blockers and 2 accuracy improvements in place on `feature/m3-character-studio-personality-b`:
  1. **Reproducible Prompt-Budget Proof (`<= 695` chars exact worst-case $\le$ `MODULATION_BLOCK_MAX_CHARS = 700`):** Verified exact character counts for every header (`<= 171`), `Style Directives:` (`17`), all 4 paired trait lines (`67 + 74 + 69 + 68 = 278` max), optional `Dynamic` (`<= 89`), mandatory `Autonomy Guard` (`133`), and newline separators (`7`), proving `695` chars absolute maximum (`605` chars with `Autonomy Guard` only) with zero mid-sentence truncation and defense-in-depth priority preservation of `Autonomy Guard`.
  2. **Unchanged-Epoch `unauthorized` & Separated Read/Write Concurrency:** Made `chat.connectionStatus == RuntimeConnectionStatus.unauthorized` the highest-priority trigger for `sessionExpiredOrRevoked` (immediately purging personal catalog and drafts even when `profileEpoch` is unchanged), separated `_sessionFenceId` and `_readGeneration` from serialized `_isMutating` mutations so overlapping reads never discard committed write responses, and specified delayed-commit dropping after Profile switches and uncertain-write timeout reconciliation.
  3. **Accurate Schema Field Limits & Turn-Assembly Bounding:** Corrected schema documentation to reflect that `lore` and `system_prompt` are unbounded `Optional[str]` / `Text` columns in `backend/app/schemas/character.py`, and specified deterministic pre-escaping turn-assembly bounds (`TURN_PERSONA_INSTRUCTIONS_MAX_CHARS = 1200`, `TURN_PERSONA_LORE_MAX_CHARS = 1600`) plus non-breaking Studio UI recommended-length counters.
  4. **Programmatic WCAG Contrast, Keyboard/Text-Scaling A11y & Truthful Milestone Tracking:** Specified high-contrast token surfaces, `Color.computeLuminance()` automated contrast tests (`>= 4.5:1` text, `>= 3.0:1` controls/focus rings) across Light/Dark themes, backdrops, and accent presets, `1.0x`/`1.25x` text scaling at `1024x640`, and preserved wider M2 and wider M3 as `IN PROGRESS` during Stage 5 planning reconciliation.
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
  - [ ] Deterministic 8-trait (`0–100`) 5-band concise clause compiler, mandatory `Autonomy Guard` (`affection >= 80` / `yandere`), cross-trait interaction synthesis (`compile_personality_modulation_block`, `<= 695` chars worst-case $\le$ `MODULATION_BLOCK_MAX_CHARS = 700`), and pre-escaping turn-assembly bounding for `system_prompt` (`1,200`) and `lore` (`1,600`) in `backend/app/services/character_service.py`.
  - [ ] Integration into `resolve_turn_persona_prompt()` inside `<character_persona>` while preserving `DEFAULT_PERSONA` safety precedence and keeping `Neutral Assistant` and legacy placeholders unmodulated.
  - [ ] Unit, worst-case budget-limit, field-bounding, and autonomy-safety regression tests in `backend/tests/test_character_personality_modulator.py`.
- **`PC-CLIENT-007` (Immersive Windows Desktop Character Studio V1):**
  - [ ] `DesktopStudioController` (`desktop_studio_controller.dart`) with 5-state `StudioSessionStatus` machine (including immediate purge on unchanged-epoch `unauthorized`), separated `_sessionFenceId` / `_readGeneration` / serialized `_isMutating` concurrency, uncertain-write timeout reconciliation, and dirty-state protection.
  - [ ] `CharacterStagePresenter` (`character_stage_presenter.dart`) & `CharacterShowcaseStage` (`character_showcase_stage.dart`) providing an unobstructed center portrait/archetype stage with zoom/pan controls and a clean boundary for future 3D/VRM rendering.
  - [ ] `StudioBackdropLayer` (`studio_backdrop_layer.dart`) providing full-content-area project-original thematic background imagery (`ASSET_PROVENANCE.md`) with `StudioAtmospherePainter` procedural fallback and readability scrims.
  - [ ] Translucent `SoftGlassPanel` docks (`StudioLibraryPanel` on left, `StudioInspectorPanel` on right with inline `Illustrative Style Summary` and scrollable large-text `lore`/`system_prompt` editors), post-rail responsive breakpoints (`>= 1120px`, `920px..1119px`, `< 920px`), and `DesktopShell` / `DesktopSettingsController` dirty-navigation guard wiring.
  - [ ] Controller, concurrency/fencing, widget, breakpoint-boundary, `computeLuminance()` WCAG contrast, keyboard focus/text-scaling, and dirty-navigation tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_shell_test.dart`).
