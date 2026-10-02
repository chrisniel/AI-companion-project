# Persona and State Separation

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D11
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`characters-personality-and-emotion.md`](../01_Domains/characters-personality-and-emotion.md)
**Related Specifications:** [`SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): Character Templates (read-only app assets) vs. Character Instances (Profile-owned mutable instances). Eight continuous traits (0–100 scale). Presets copy baseline trait values into custom configurations. Persistent bounded mood survives restart and decays over time, affecting expressive tone only without ever altering system correctness or security policy. Neutral Assistant is immutable fallback.

## Context
The internal state of the assistant must be clearly separated to allow independent tuning of personality, voice, and mood.

## Decision
Clear separation: Profile (owns personal data/memories/tasks), Conversation (belongs to Profile, Character-bound history), Character Template vs Instance, Personality (8 continuous traits 0–100), Emotion (persistent bounded mood with natural decay), Voice (acoustic/TTS configuration), Presence (avatar/presentation state), and Relationship State (separate, opt-in, PC LATER). Neutral Assistant is immutable fallback.

## Consequences
Decouples visual identity from behavioral traits, enabling granular customization. Persona and mood can never bypass safety constraints or cause system malfunction.

## Open Design / Non-Goals
Relationship progression levels and multi-speaker voice synthesis are tracked in `DECISION_DEBT.md`.

## Canonical Relationships
Primary normative ownership resides in `characters-personality-and-emotion.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
