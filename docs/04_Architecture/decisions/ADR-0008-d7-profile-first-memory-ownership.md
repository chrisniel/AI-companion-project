# Profile-First Memory Ownership

**Status:** Accepted
**Decision ID:** D7
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`memory-and-personalization.md`](../01_Domains/memory-and-personalization.md)
**Related Specifications:** [`characters-personality-and-emotion.md`](../01_Domains/characters-personality-and-emotion.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
A data ownership model is required to separate user data from the AI persona responding to it.

## Decision
Profile-first ownership. Profile owns user identity, memories, preferences, and personal data. Memories belong to Profile (default PROFILE scope, optional CHARACTER scope). Conversation history belongs to Profile but is Character-bound as recorded. Characters do not own data.

## Consequences
Deleting or changing a Character does not delete the user's Profile data or memories.

## Open Design / Non-Goals
Specific vectorization techniques or database representations of memory remain open design.

## Canonical Relationships
Primary normative ownership resides in `memory-and-personalization.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
