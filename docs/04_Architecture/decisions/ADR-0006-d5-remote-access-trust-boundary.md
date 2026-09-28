# Remote Access Trust Boundary

**Status:** Accepted
**Decision ID:** D5
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md
**Related Specifications:** android-companion.md where remote-device behavior matters

## Decision History
- Accepted/relocked during R10.
- Focused-domain authority transferred during R11.4.
- Codified during R13.1.
- (R12 mentioned only where it actually refined related sequencing/acceptance/governance).

## Context
See primary canonical owner.

## Decision
Localhost, trusted LAN, and Tailscale private mesh supported for V1. Direct public internet exposure / port forwarding is outside the supported trust model.

## Consequences
See primary canonical owner.

## Open Design / Non-Goals
See primary canonical owner.

## Canonical Relationships
See primary canonical owner.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
