# Persona and State Separation

**Status:** Accepted
**Decision ID:** D11
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`characters-personality-and-emotion.md`](../01_Domains/characters-personality-and-emotion.md)
**Related Specifications:** [`SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
The internal state of the assistant must be clearly separated to allow independent tuning of personality, voice, and mood.

## Decision
Clear separation: Profile (owns personal data/memories/tasks), Conversation (belongs to Profile, Character-bound history), Character (persona identity/lore/avatar/presentation), Personality (behavioral style/traits), Emotion (lightweight transient mood), Voice (acoustic/TTS configuration), Presence (contextual/presentation state), and Relationship State (separate, opt-in, PC LATER).

## Consequences
Decouples visual identity from behavioral traits, enabling granular customization.

## Open Design / Non-Goals
Specific quantitative implementations of Emotion or Relationship State remain open design.

## Canonical Relationships
Primary normative ownership resides in `characters-personality-and-emotion.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
