# Character Studio & Personality Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1 — M3 Batch B Implemented & Verified).
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`ADR-0012`](../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md).
> **Primary Implementation Components:** [`StudioScreen`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/screens/studio_screen.dart), [`DesktopStudioController`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart), [`CharacterStagePresenter`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart), [`CharacterShowcaseStage`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/character_showcase_stage.dart), [`StudioBackdropLayer`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart), [`StudioLibraryPanel`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/studio_library_panel.dart), [`StudioInspectorPanel`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/studio_inspector_panel.dart), [`ChatScreen`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/screens/chat_screen.dart), and [`DesktopChatController`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart).

---

## 1. Overview & Studio Philosophy

Character Studio is the dedicated, immersive creative workspace where users craft, tune, and personalize their companion's persona, conversational style, and expressive behavior on Windows Desktop.

The user experience follows a polished character customization presentation inspired by modern character-centric games:
- An unobstructed, centered **Character Showcase Stage** presents the companion's visual identity.
- Floating translucent **Soft-Glass Docks** on the flanks house library selection and deep trait tuning without obscuring the companion portrait.
- Atmospheric **Thematic Backdrops** establish environmental presence while maintaining readability through subtle contrast scrims.

### Core Architectural Separation
The design strictly reflects the D11 architectural model:
1. **Character Templates:** Read-only system distributions packaged with the application or seeded via migrations (`character_templates` table).
2. **Character Instances:** Mutable, profile-owned companion personas customized by the user (`character_instances` table).
3. **Immutable Neutral Assistant Fallback:** Built-in unalterable baseline (`is_neutral_fallback = True`, all traits strictly `NULL`).

### Current Scope & Non-Claims
- **Current Visual Scope:** 2D static portrait presentation using high-resolution 32-bit transparent RGBA PNG assets (`assets/studio/`) with procedural fallback rendering.
- **Future Renderer Boundary:** The stage architecture isolates visual asset loading through [`CharacterStagePresenter`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart), establishing a clean boundary for future 3D/VRM or Live2D companion rendering runtimes. No live 3D rendering, mesh deformation, physics, or skeletal rigging is implemented in PC V1.
- **Stylistic Guidance Non-Claim:** Personality trait sliders modulate prompt framing and stylistic tone instructions; they guide phrasing preferences and conversational delivery, but **do not guarantee a particular LLM response** or override model safety alignments.
- **Deferred Subsystems:** Persistent emotional decay, acoustic voice synthesis, and relationship progression mechanics remain separate future milestones.

---

## 2. Immersive Studio Layout & Primary Panels

The Character Studio (`StudioScreen`) organizes workspace real estate into layered, coordinated components:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ StudioBackdropLayer (Full Viewport Thematic Backdrop & Atmosphere)    │
│                                                                        │
│  ┌──────────────┐     ┌────────────────────────────┐     ┌───────────┐  │
│  │ SoftGlass    │     │ CharacterShowcaseStage     │     │ SoftGlass │  │
│  │ Library Dock │     │ (Center 2D Portrait Stage) │     │ Inspector │  │
│  │              │     │                            │     │ Dock      │  │
│  │ • Templates  │     │ • Transparent PNG Portrait │     │ • Archetype│ │
│  │ • Instances  │     │ • Pan & Zoom Controls      │     │ • 8 Traits│  │
│  │ • Neutral    │     │ • Status & Archetype Badges│     │ • Presets │  │
│  │ • New Char   │     │ • Future 3D Renderer Scaff.│     │ • Summary │  │
│  │              │     │                            │     │ • Editors │  │
│  │ (300px min)  │     │ (Unobstructed Focus)       │     │ (380px max│  │
│  └──────────────┘     └────────────────────────────┘     └───────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Studio Backdrop Layer (`StudioBackdropLayer`)
- Renders full-content-area thematic imagery behind the workspace using project-original assets:
  - `Cozy Studio` (`assets/studio/backdrop_cozy_studio.png`) — Warm ambient interior lighting.
  - `Cyber Lounge` (`assets/studio/backdrop_cyber_lounge.png`) — Cool neon and modern tech accents.
  - `Twilight Balcony` (`assets/studio/backdrop_twilight_balcony.png`) — Deep twilight sky and terrace lighting.
  - `Minimalist Vault` (`assets/studio/backdrop_minimalist_vault.png`) — Monochromatic architectural geometry.
- **Procedural Atmosphere Fallback:** If backdrop assets are absent or loading fails, [`StudioAtmospherePainter`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/studio_backdrop_layer.dart) renders smooth radial and linear gradients matching theme tokens.
- **Contrast Scrim:** Semi-transparent dark overlays ensure text and UI controls maintain verified WCAG AA contrast (text $\ge 4.5:1$, controls $\ge 3.0:1$).

### 2.2 Character Showcase Stage (`CharacterShowcaseStage`)
- Centered, unobstructed focal area showcasing the companion's current portrait.
- **Asset Resolution:** [`CharacterStagePresenter.resolveAvatarPath`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart) maps seeded avatar identifiers (`neutral_avatar`, `warm_companion_avatar`, `playful_companion_avatar`, `formal_advisor_avatar`) to bundled 32-bit transparent PNG portraits, with fallback to a neutral companion silhouette for unknown keys.
- **Interactive Inspection:**
  - Mouse-wheel and on-screen zoom controls ($0.8\times$ to $2.5\times$).
  - Smooth pan/drag inspection when zoomed, automatically clamping bounds and resetting on zoom reset.
  - Status badges for active Profile assignment, baseline template provenance, and legacy placeholder warnings.

### 2.3 Left Dock: Library Panel (`StudioLibraryPanel`)
- Floating translucent dock with backdrop blur (`SoftGlassPanel`).
- Displays three distinct categories:
  1. **Character Templates:** System archetypes available to instantiate.
  2. **Profile Character Instances:** User-created and customized personas belonging to the active Profile.
  3. **Neutral Assistant Fallback:** Direct access to inspect the immutable baseline.
- **New Character Action:** Primary action button to create a fresh draft from selected templates.
- **Responsive Collapse:** On screens $< 920\text{px}$, automatically collapses into an overlay drawer accessible via header button.

### 2.4 Right Dock: Inspector Panel (`StudioInspectorPanel`)
- Floating translucent dock housing all customization controls:
  - **Identity Card:** Name, summary, template provenance version, and active status badge.
  - **8 Continuous Trait Sliders:** Continuous 0–100 sliders with qualitative band labels and individual trait reset buttons.
  - **Personality Preset Selector:** Single "Custom" chip + 8 named presets with descriptive baselines.
  - **Illustrative Style Summary:** Real-time presenter preview of expected conversational delivery, register, and interaction dynamics.
  - **Persona Lore & System Prompt Editors:** Scrollable large-text editors for background lore and system prompt overrides.
  - **Action Footer:** Dynamic sequential save, activate, and delete controls with unsaved draft notices.

---

## 3. Eight Continuous Personality Traits

The character foundation defines exactly eight continuous (0–100 integer) dimensions:

| Trait Dimension | Spectrum Interpretation | Low Band (0–39) | Balanced Band (40–59) | High Band (60–100) |
| :--- | :--- | :--- | :--- | :--- |
| `warmth` | Empathy, friendliness, emotional warmth | Cool, detached, objective | Approachable, gentle | Empathetic, welcoming, tender |
| `teasing` | Playfulness, banter, lighthearted sarcasm | Straightforward, earnest | Occasional light banter | Playful, sarcastic, teasing |
| `guardedness` | Emotional reserve, boundary maintenance | Open, vulnerable, candid | Measured, composed | Guarded, distant, boundary-focused |
| `directness` | Candor, bluntness, communication clarity | Gentle, suggestive, indirect | Balanced, clear | Direct, concise, blunt |
| `expressiveness` | Emotional and linguistic expressiveness | Restrained, minimal, subtle | Natural, moderate | Vivid, passionate, expressive |
| `affection` | Emotional closeness, fond phrasing | Professional, platonic | Kind, friendly | Affectionate, deeply fond |
| `formality` | Grammatical rigor, stylistic formality | Casual, relaxed, informal | Standard, conversational | Structured, polite, articulate |
| `verbosity` | Sentence length, elaboration depth | Concise, brief, minimal | Balanced, natural pacing | Elaborate, detailed, expansive |

### 3.1 Five-Band Qualitative Labeling
Sliders map numeric values into five discrete qualitative bands for clear visual interpretation:
- `Very Low` (0–19)
- `Low` (20–39)
- `Balanced` (40–59)
- `High` (60–79)
- `Very High` (80–100)

### 3.2 Individual Trait Reset
Each slider includes a dedicated reset button that reverts that specific trait to its parent template baseline value without altering any other modified traits.

### 3.3 Illustrative Local Style Summary
[`CharacterStagePresenter.buildIllustrativeStyleSummary`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/character_stage_presenter.dart) provides instant visual feedback on how trait combinations shape companion demeanor:
- **Tone Directive:** Formatted label reflecting warmth and affection bands (e.g., *"Warm and Empathetic"*).
- **Expression Directive:** Formatted label reflecting expressiveness and guardedness bands.
- **Delivery Directive:** Formatted label reflecting directness, verbosity, and teasing bands.
- **Register Directive:** Formatted label reflecting formality band.
- **Interaction Dynamic:** Detected cross-trait synthesis (e.g., *"Tsundere Dynamic"*, *"Kuudere Dynamic"*).
- **Autonomy Guard Badge:** Displays active status whenever affection is high or yandere baseline is selected.

> [!NOTE]
> The Style Summary is explicitly labeled in the UI as an **Illustrative Local Style Preview**. It communicates the behavioral intent of the sliders in Dart without claiming to be an exact copy of the backend-generated prompt modulation block.

---

## 4. Presets & The Autonomy Guard

### 4.1 Preset Catalog as Baseline Initializers
Users can load initial baseline trait configurations from the approved preset catalog:
- `custom`: Dynamic indicator active whenever traits diverge from named preset definitions.
- `warm_companion`: Affectionate, empathetic, encouraging companion baseline.
- `playful`: Witty, humorous, sarcastic companion baseline.
- `formal_advisor`: Structured, precise, articulate advisor baseline.
- `tsundere`: High guardedness, sharp teasing, hidden warmth baseline.
- `kuudere`: High guardedness, extreme formality/directness, reserved expression baseline.
- `dandere`: High warmth, low directness, gentle reserved verbosity baseline.
- `yandere`: Intense affection, extreme warmth, low guardedness baseline.

*Behavioral Rule:* Selecting a preset **copies** its baseline trait values into the active draft. Presets are provisional numeric starting points; moving any slider immediately toggles the preset indicator to `custom`.

### 4.2 Mandatory Autonomy Guard
To ensure companion interactions remain healthy, safe, and free from coercive or simulated obsessive dynamics:
- **Trigger Conditions:** Activates whenever `affection >= 80` OR when the `yandere` preset is selected regardless of affection level.
- **Backend Enforcement:** The prompt modulator automatically appends the mandatory Autonomy Guard instruction:
  > *"Maintain emotional independence and healthy personal boundaries. Never express possessiveness, jealousy, obsession, or distress over the user's absence."*
- **UI Visibility:** The Inspector panel surfaces a prominent security badge informing the user that the Autonomy Guard is active.
- **Respectful Preset Phrasing:** The `yandere` preset description and prompt framing use respectful, non-possessive language focusing on unwavering dedication rather than toxic fixation.

---

## 5. Profile Ownership, Concurrency & Sequential Save & Activate

### 5.1 Sequential Save & Activate Workflow
To eliminate data loss and prevent activating stale database records while local slider edits remain unsaved:
1. When a Character draft is clean (`isDirty == false`):
   - The primary activation button reads **"Set Active for Profile"**. Clicking it directly activates the instance via `PUT /api/v1/characters/active`.
2. When a Character draft has unsaved edits (`isDirty == true`):
   - The primary activation button dynamically changes to **"Save & Activate"**.
   - An explanatory notice informs the user: *"Note: Unsaved trait changes will be saved before activating for Chat."*
   - Clicking `Save & Activate` executes [`saveAndActivateDraft()`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart#L770):
     - Sequentially submits `PATCH /api/v1/characters/instances/{id}`.
     - Strictly verifies that persistence succeeded and the draft is confirmed clean (`isDirty == false`).
     - Only upon confirmed save does it invoke `activateCharacter()`.
     - If the save fails (e.g., 500 error, network disconnect), activation is immediately aborted, the draft remains dirty, and the error banner is displayed.
3. If an already-active Character has unsaved slider edits:
   - The button reads **"Save Changes"**.
   - An explanatory notice clarifies: *"Note: You have unsaved changes. Chat uses saved traits until you click 'Save Changes'."*

### 5.2 Concurrency, Fencing & Single-Flight Mutation Tokens
- **Single-Flight Lock (`_activeMutationToken`):** Every mutation increments a monotonic integer token. Lock acquisition and release verify token parity, preventing delayed asynchronous responses from unlocking concurrent operations.
- **Profile Session Fencing (`_sessionFenceId`):** Profile switches or invalidations increment the session fence, instantly dropping delayed network responses from prior profile sessions.
- **Snapshot-Based PATCH Reconciliation (`PendingUpdateSnapshot`):** On uncertain write recovery (HTTP 408 timeout), Studio fetches the server record by exact ID and compares fields against the submitted snapshot. If the server confirmed the update and no newer edits were made, the draft is marked clean; if server data is unconfirmed or remote conflict is detected, local edits are preserved.
- **Navigation Guard:** `DesktopShell` and `StudioScreen` intercept navigation attempts when unsaved edits are present, providing explicit `Save & Continue`, `Discard`, or `Cancel` choices.

---

## 6. Desktop Chat Visibility & Character Binding

### 6.1 Dual-Indicator Architecture in Chat
Chat displays character identity truthfully across two distinct scopes without confusing users:

1. **This Conversation (`This Conversation: [Name]`):**
   - Renders as a prominent accent pill in the `ChatScreen` header bar.
   - Authoritatively reflects the Character permanently bound to the active conversation thread (`conversations.character_instance_id` / `conversations.character_id`).
2. **New Conversations (`New Conversations: [Name]`):**
   - Renders as a secondary subtle pill next to the conversation pill **only when the active Profile Character differs from the current conversation's bound Character**.
   - Informs the user that clicking `+ New Conversation` will start a chat with the newly active Character, without misleading them into thinking the existing conversation was retroactively reassigned.
3. **Session Card Badges:**
   - [`ConversationHistoryDrawer`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/chat/conversation_history_drawer.dart) displays a character name badge on every session card.
4. **Welcome Stage Status Card:**
   - The initial empty conversation screen displays a centered card confirming the bound Character and the active Profile Character.

### 6.2 Truthful Name Resolution
[`DesktopChatController`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart) resolves character names authoritatively from backend IDs:
- Active custom instances $\rightarrow$ `[Name]`
- Neutral Assistant fallback $\rightarrow$ `Neutral Assistant`
- Archived instances $\rightarrow$ `[Name] (Archived)`
- Legacy placeholders $\rightarrow$ `[Name] (Legacy)`
- Deleted records (404) $\rightarrow$ `Missing Character`
- Unresolved cache lookups $\rightarrow$ `Loading...`
- Unconnected runtime $\rightarrow$ `Disconnected`

### 6.3 Corrected Empty-Conversation Reuse
In [`DesktopChatController.createNewConversation()`](file:///d:/OtherProjects/AI-companion-project/frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart#L670):
- **Same Character:** Reuses an untouched empty draft conversation if already active and its bound Character matches the intended Character, preventing duplicate empty threads.
- **Changed Character:** If the active Profile Character has changed since the empty conversation was created, it **does not reuse** the old conversation. Instead, it creates a genuinely new conversation thread bound to the new Character via `createConversation(characterId: intendedInstanceId)`.
- **Title Updates:** Deterministic title generation and AI model refinement strictly preserve `character_id` and `character_instance_id`.

---

## 7. Future Capability Boundaries

To prevent architectural drift, the following capabilities are explicitly classified as deferred future work:

| Capability | Current Status (M3 Batch B) | Target Milestone | Design Authority |
| :--- | :--- | :--- | :--- |
| **3D / VRM / Live2D Companion Rendering** | 2D transparent PNG portraits; stage isolates renderer boundary | PC Later | `04_Emotion_and_Visual_Presence.md` |
| **Persistent Mood Decay Engine** | Unimplemented; baseline traits only | M3 Follow-on (`PC-CHAR-003`) | `characters-personality-and-emotion.md` |
| **Acoustic Voice Synthesis (TTS)** | Unimplemented; text chat only | M4 (`PC-VOICE-003`) | `voice-and-audio.md` |
| **Relationship Progression / Continuity** | Unimplemented; independent persona definitions | PC Later (`PC-CHAR-004`) | `characters-personality-and-emotion.md` |
| **Mobile Character Studio** | Unimplemented; Windows Desktop V1 client target | Mobile Follow-on | `MOBILE_SYSTEM_BASELINE.md` |
