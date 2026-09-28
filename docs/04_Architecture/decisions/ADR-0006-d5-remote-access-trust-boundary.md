# Remote Access Trust Boundary

**Status:** Accepted
**Decision ID:** D5
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md)
**Related Specifications:** [`android-companion.md`](../01_Domains/android-companion.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
Remote connections to the PC host must be secured without exposing the host to the public internet.

## Decision
Localhost, trusted LAN, and Tailscale private mesh supported for V1. Direct public internet exposure / port forwarding is outside the supported trust model.

## Consequences
Limits connectivity to secure, private overlay networks or local networks, significantly reducing attack surface.

## Open Design / Non-Goals
Cloud relay architectures or public ingress are explicitly non-goals for V1.

## Canonical Relationships
Primary normative ownership resides in `authentication-and-secrets.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
