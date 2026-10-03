# Character Studio & Personality Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`ADR-0012`](../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md).

---

## 1. Overview & Studio Philosophy

Character Studio is the dedicated creative workspace where users craft, tune, and personalize their companion's persona, conversational style, and expressive behavior.

The design strictly reflects the architectural separation between:
1. **Character Templates:** Read-only system distributions packaged with the application.
2. **Character Instances:** Mutable, profile-owned companion personas customized by the user.

---

## 2. Studio Layout & Primary Panels

The Character Studio is structured into three coordinated panels:
- **Left Panel (Template & Instance Selector):** Card list of installed Character Templates and user-created Character Instances.
- **Center Panel (Personality Tuning & Lore):** Trait sliders, preset pickers, lore card descriptions, and system prompt parameters.
- **Right Panel (Interactive Preview & Playground):** Real-time conversational scratchpad allowing immediate test interactions to evaluate personality changes before saving.

---

## 3. Eight Continuous Personality Traits

Exactly eight continuous (0–100) dimensions: Warmth, Teasing, Guardedness, Directness, Expressiveness, Affection, Formality, Verbosity.

### Slider Interaction Design
- Each slider features a real-time numerical indicator and descriptive tooltip describing how extreme positions manifest in speech.
- Sliders snap to 5-point increments for tactile precision.
- Double-clicking any slider resets it to its template default value.

---

## 4. Presets as Template Configurations

A prominent **"Load Preset Style"** dropdown at the top of the personality panel allows users to quickly configure the eight sliders:
- **Warm Companion:** High Warmth (85), High Empathy (80), Moderate Humor (60), Low Formality (30).
- **Professional Assistant:** High Formality (85), High Directness (80), High Patience (85), Low Playfulness (15), Low Humor (20).
- **Sarcastic Scholar:** High Humor (85), High Directness (75), High Curiosity (85), Moderate Warmth (40), Low Formality (35).
- **Creative Collaborator:** High Playfulness (80), High Curiosity (90), Moderate Formality (40), High Warmth (70).

*Behavioral Rule:* Selecting a preset **copies** the preset's baseline trait values into the active configuration. The user remains free to adjust any individual slider afterwards.

---

## 5. Immutable Neutral Assistant Fallback

A prominent button and safety toggle labeled **"Reset to Neutral Assistant"** is permanently accessible:
- Instantly sets all behavioral traits to a neutral, balanced baseline.
- Strips custom roleplay lore cards and reverts to the immutable, objective system assistant prompt.
- Serves as an unalterable fallback if custom prompt tuning leads to erratic, repetitive, or confusing behavior.

---

## 6. Lore Card & Prompt Customization

- **Persona Lore Editor:** Multi-line markdown text area for background story, world lore, and specific conversational preferences (e.g., *"Loves retro computers and gardening"*).
- **Token Counter & Budget Warning:** Real-time token counter comparing the character definition against the model's active context window (e.g., *"Character prompt uses 412 / 4096 context tokens"*). Warns if persona text consumes more than 25% of available context.
- **Safety Framing Note:** Clear inline reminder that personality traits modulate social and expressive tone only and **never bypass safety policies or system tool permissions**.
