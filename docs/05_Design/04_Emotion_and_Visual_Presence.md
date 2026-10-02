# Emotion & Visual Presence Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`ADR-0012`](../04_Architecture/decisions/ADR-0012-d11-persona-and-state-separation.md).

---

## 1. Overview & Visual Philosophy

Companion presence in PC V1 focuses on subtle, elegant, and non-distracting emotional visual cues. The design visually conveys the companion's current mood and attentiveness without incurring high GPU compute costs that could interfere with workstation productivity or gaming.

---

## 2. PC V1 Visual Presence Scope vs. Post-V1 Phasing

In accordance with architectural boundaries:
- **PC V1 Baseline:** Standard high-resolution 2D avatar portraits with expression switching, subtle ambient glow highlights, and conversational state rings.
- **PC Later (Deferred):** Live2D skeletal animation, 3D VRM models, animated desktop screen overlays, and on-demand Stable Diffusion visual generation are explicitly deferred to post-PC-V1.
- **Resource Priority:** Visual presence elements must instantly yield to Low-Impact / Gaming mode, disabling any non-essential CSS/rendering effects.

---

## 3. 2D Avatar Expression System

### 3.1 Expression States
For characters with configured multi-expression asset bundles, the desktop client smoothly cross-fades the companion avatar between six primary expressive states:
1. **Neutral:** Default calm, attentive expression.
2. **Happy / Delighted:** Warm smile, brighter eyes (triggered by positive user milestones or witty banter).
3. **Thoughtful / Analytical:** Slight gaze shift, focused brow (triggered while retrieving memories, searching the web, or executing tools).
4. **Empathetic / Supportive:** Softened features, tilted head (triggered during emotional user disclosures or reassurance).
5. **Concerned / Cautious:** Subtle furrowed brow (triggered when alerting to missed alarms or warnings).
6. **Playful / Mischievous:** Wink, sly smile (triggered by high-humor responses).

### 3.2 Transition Dynamics
- Transitions between expressions utilize a 300ms cubic-bezier cross-fade.
- If a custom character only supplies a single static image, that image is rendered universally across all states without error.

---

## 4. Ambient Mood Glow & Accent Lighting

### 4.1 Subtle Halo / Edge Accents
- The circular avatar frame features a soft 2px radial halo that subtly shifts hue to reflect the current emotion state:
  - *Calm / Content:* Soft azure / cyan glow.
  - *Excited / Engaged:* Warm amber / gold glow.
  - *Reflective / Curious:* Deep indigo / violet glow.
  - *Attentive / Alert:* Coral / emerald accent.
- **Opacity Cap:** Glow opacity is capped at 25% to prevent visual distraction during extended reading or working sessions.

### 4.2 Conversational State Ring
- A thin concentric ring around the avatar communicates runtime operational state:
  - **Dormant / Listening:** Solid, subtle outline.
  - **Thinking / Inferring:** Gentle, slow pulse (1.5s period).
  - **Speaking / Generating:** Dynamic waveform modulation matching audio playback level.

---

## 5. Emotion Decay & Integrity Invariant

- **Visual Indicator of Decay:** As the companion's persistent mood naturally decays back toward equilibrium over elapsed time, the accent halo smoothly shifts back to the baseline theme color.
- **Strict Invariant Notice:** Mood indicators are purely expressive. They **never** indicate that the companion is unwilling to perform a requested task or that safety policies have been compromised.
