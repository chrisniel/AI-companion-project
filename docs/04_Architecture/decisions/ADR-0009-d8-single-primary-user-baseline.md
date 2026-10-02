# Single Primary User Baseline (SUPERSEDED)

> **SUPERSEDED:** This decision record is superseded by [`ADR-0018: Multi-Profile PC V1 Ownership Model`](ADR-0018-multi-profile-pc-v1-ownership-model.md). PC V1 implements a 1 Local Account, Multiple Isolated Profiles model.

**Status:** Superseded by [`ADR-0018`](ADR-0018-multi-profile-pc-v1-ownership-model.md)  
**Decision ID:** D8  
**Codification Date:** 2026-09-29  
**Supersession Date:** 2026-10-03  
**Primary Canonical Owner:** [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md)  
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md), [`ADR-0018`](ADR-0018-multi-profile-pc-v1-ownership-model.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- **Superseded by `ADR-0018` (2026-10-03):** Replaced with 1 Local Account, Multiple Isolated Profiles for PC V1 to prevent cross-user data leakage on shared workstations and eliminate future schema migration debt. Existing `owner_id` fields map to `profile_id`.

## Context
The system requires a defined cardinality for users to scope security and data models.

## Historical Decision (Superseded)
Single-primary-user for V1; schema uses `owner_id` representing profile boundary. Preserved in place.

## Consequences (Historical)
Simplifies authorization by scoping all data to a single primary user for the V1 baseline.

## Current Authority
Authoritative multi-profile PC V1 architecture is defined in [`ADR-0018`](ADR-0018-multi-profile-pc-v1-ownership-model.md) and [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md).

## Canonical Relationships
Primary normative ownership resides in `profiles-and-devices.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
