# Character Studio & Personality Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`ADR-0012`](../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md).

---

## 1. Overview & Studio Philosophy

Character Studio is the dedicated creative workspace where users craft, tune, and personalize their companion's persona, conversational style, and expressive behavior.

The design strictly reflects the architectural separation between:
1. **Character Templates:** Read-only system distributions packaged with the application or seeded via migrations.
2. **Character Instances:** Mutable, profile-owned companion personas customized by the user.

---

## 2. Studio Layout & Primary Panels

The Character Studio is structured into three coordinated panels:
- **Left Panel (Template & Instance Selector):** Card list of installed Character Templates and user-created Character Instances.
- **Center Panel (Personality Tuning & Lore):** Trait sliders, preset pickers, lore card descriptions, and system prompt parameters.
- **Right Panel (Interactive Preview & Playground):** Real-time conversational scratchpad allowing immediate test interactions to evaluate personality changes before saving.

---

## 3. Eight Continuous Personality Traits

The character foundation defines exactly eight continuous (0–100 integer) dimensions:
- `warmth`: Empathy, friendliness, and emotional warmth.
- `teasing`: Playfulness, banter, and lighthearted sarcasm.
- `guardedness`: Emotional reserve and boundary maintenance.
- `directness`: Candor, frankness, and communication directness.
- `expressiveness`: Emotional and linguistic expressiveness.
- `affection`: Affectionate phrasing and emotional closeness.
- `formality`: Grammatical and stylistic formality.
- `verbosity`: Sentence length and elaboration depth.

### Planned Slider Interaction Design (Target UX — PC-CHAR-002)
- Each slider features a real-time numerical indicator and descriptive tooltip describing how extreme positions manifest in speech.
- Sliders snap to 5-point increments for tactile precision.
- Double-clicking any slider resets it to its template default value.
- *Implementation Status:* Backend persistence, API contracts, and Dart client DTOs are implemented; full visual interactive slider widgets are planned for `PC-CHAR-002`.

---

## 4. Presets as Template Configurations
  
A prominent **"Load Preset Style"** dropdown allows users to load initial baseline trait configurations from the approved preset catalog:
- `custom`: User-configured custom trait settings.
- `warm_companion`: Affectionate, empathetic, and encouraging companion baseline.
- `playful`: Witty, humorous, and lighthearted companion baseline.
- `formal_advisor`: Structured, precise, and articulate advisor baseline.
- `tsundere`: High guardedness, sharp teasing, and hidden warmth/affection baseline.
- `kuudere`: High guardedness, extreme formality/directness, and low expressiveness baseline.
- `dandere`: High warmth, low directness, and reserved verbosity baseline.
- `yandere`: Intense affection, extreme warmth, and low guardedness baseline.

*Behavioral Rule:* Selecting a preset **copies** the preset's initial baseline trait values into the active configuration. Presets are provisional numeric initialization baselines, not permanently frozen behavioral definitions; all traits remain fully editable by the user.

---

## 5. Immutable Neutral Assistant Fallback

A prominent button and safety toggle labeled **"Reset to Neutral Assistant"** is permanently accessible:
- Updates the Profile's active character selection to the immutable built-in Neutral Assistant fallback (`is_neutral_fallback = True`).
- Future conversations inherit this Neutral Assistant selection.
- Existing conversations retain their original Character association; no retroactive conversation reassignment occurs.
- Traits are strictly `NULL` (enforced by SQLite CHECK constraints).
- Strips custom roleplay lore cards and reverts to the immutable, objective system assistant prompt (`DEFAULT_PERSONA`).
- Serves as an unalterable, dependable fallback if custom prompt tuning leads to erratic, repetitive, or confusing behavior.
- Activated via `PUT /api/v1/characters/active` (`character_id = "default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.

---

## 6. Lore Card & Prompt Customization

- **Persona Lore Editor:** Multi-line markdown text area for background story, world lore, and specific conversational preferences (e.g., *"Loves retro computers and gardening"*).
- **Token Counter & Budget Warning:** Real-time token counter comparing the character definition against the model's active context window (e.g., *"Character prompt uses 412 / 4096 context tokens"*). Warns if persona text consumes more than 25% of available context.
- **Safety Framing Note:** Clear inline reminder that personality traits modulate social and expressive tone only and **never bypass safety policies or system tool permissions**. User-editable Character persona text is treated strictly as lower-trust configuration data; delimiter escaping alone does not provide complete prompt-injection security, and the system prompt explicitly bounds the persona block.
