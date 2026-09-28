# Profile & Device Credential Boundary

**Status:** Accepted
**Decision ID:** D4
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md)
**Related Specifications:** [`authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
Security boundaries must distinguish between a user's identity (Profile) and the hardware endpoint (Device).

## Decision
Profile represents user identity; Device represents trusted client endpoint. Independent revocable credentials per device; master secrets never distributed.

## Consequences
Compromised devices can be independently revoked without resetting the primary Profile identity.

## Open Design / Non-Goals
Specific cryptographic storage mechanisms on the host remain implementation details.

## Canonical Relationships
Primary normative ownership resides in `profiles-and-devices.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
