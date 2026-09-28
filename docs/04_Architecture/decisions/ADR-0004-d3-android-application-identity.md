# Android Application Identity

**Status:** Accepted
**Decision ID:** D3
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`android-companion.md`](../01_Domains/android-companion.md)
**Related Specifications:** [`SYSTEM_BASELINE.md §2.3`](../SYSTEM_BASELINE.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
The Android application requires a locked namespace and unified product identity.

## Decision
Application ID & package: `com.cnl.aicompanion`; product-oriented, character-independent, model-independent.

## Consequences
The mobile app acts as a unified platform entry point rather than being branded per-character.

## Open Design / Non-Goals
Detailed mobile inference formats (GGUF or otherwise) remain open design.

## Canonical Relationships
Primary normative ownership resides in `android-companion.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
