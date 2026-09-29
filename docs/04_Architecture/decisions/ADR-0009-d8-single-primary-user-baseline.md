# Single Primary User Baseline

**Status:** Accepted
**Decision ID:** D8
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md)
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
The system requires a defined cardinality for users to scope security and data models.

## Decision
Single-primary-user for V1; schema uses `owner_id` representing profile boundary. Preserved in place.

## Consequences
Simplifies authorization by scoping all data to a single primary user for the V1 baseline.

## Open Design / Non-Goals
Multi-profile capability is Future / Unscheduled. Exact future identity/access model remains open design.

## Canonical Relationships
Primary normative ownership resides in `profiles-and-devices.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
