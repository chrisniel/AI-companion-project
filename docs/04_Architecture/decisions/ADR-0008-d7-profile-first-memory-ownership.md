# Profile-First Memory Ownership

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D7
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`memory-and-personalization.md`](../01_Domains/memory-and-personalization.md)
**Related Specifications:** [`characters-personality-and-emotion.md`](../01_Domains/characters-personality-and-emotion.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): Extended with temporary memory validity lifecycle (`valid_from`, `expires_at`, `last_verified_at`) with natural conversational revalidation. Memory extraction defaults to local-only execution.

## Context
A data ownership model is required to separate user data from the AI persona responding to it.

## Decision
Profile-first ownership. Profile owns user identity, memories, preferences, and personal data. Memories belong to Profile (default PROFILE scope, optional CHARACTER scope). Conversation history belongs to Profile but is Character-bound as recorded. Characters do not own data. Temporary memories include validity timestamps and are excluded from retrieval upon expiration.

## Consequences
Deleting or changing a Character does not delete the user's Profile data or memories. Stale temporary facts do not pollute permanent companion context.

## Open Design / Non-Goals
Specific vector indexing engines or hybrid FTS/embedding scoring algorithms are tracked in `DECISION_DEBT.md`.

## Canonical Relationships
Primary normative ownership resides in `memory-and-personalization.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
