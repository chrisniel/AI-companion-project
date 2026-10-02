# V1 Release Boundary

**Status:** Accepted (Refined by [`ADR-0017`](ADR-0017-flutter-production-windows-client.md))
**Decision ID:** D1
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`SYSTEM_BASELINE.md §2`](../SYSTEM_BASELINE.md)
**Related Specifications:** [`DELIVERY_INDEX.md`](../../02_Planning/00_Master/DELIVERY_INDEX.md) (owns delivery sequencing only), [`ADR-0017`](ADR-0017-flutter-production-windows-client.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Delivery sequencing reconciled during R12.
- Codified during R13.1.
- Refined by `ADR-0017` (2026-10-03): Flutter Desktop approved as primary production Windows client for PC V1; React Web is retained as supported dev harness.

## Context
PC V1 forms the primary ecosystem capability baseline. Android V1 is a subsequent mobile-specific release.

## Decision
PC V1 is established as the first complete ecosystem release (incorporates conversational voice without wake word, bounded routines, read-only web info, selective automatic memory, multilingual interaction, optional cloud fallback, autostart, and native notifications). Android V1 is an independent follow-on production release.

## Consequences
Establishes the release scope and scheduling milestones for PC V1 and Android V1.

## Open Design / Non-Goals
Capabilities beyond PC V1 and Android V1 remain open design or are deferred to later milestones.

## Canonical Relationships
Primary normative ownership resides in SYSTEM_BASELINE.
The Master Planning Spine owns delivery sequencing and does not become a competing primary owner.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
