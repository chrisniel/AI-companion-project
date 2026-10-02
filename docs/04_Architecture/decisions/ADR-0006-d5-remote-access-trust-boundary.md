# Remote Access Trust Boundary

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D5
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md)
**Related Specifications:** [`android-companion.md`](../01_Domains/android-companion.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): Remote access is supported via Tailscale private mesh (for trusted mobile/desktop clients) and Cloudflare Tunnel with Cloudflare Access (for authenticated remote browser access). Direct port forwarding is permanently REJECTED. Rate limiting is required on all non-loopback endpoints.

## Context
Remote connections to the PC host must be secured without exposing the host to the public internet.

## Decision
Localhost/loopback default. Tailscale private mesh (for paired satellite devices) and Cloudflare Tunnel with Access (for remote browser access) are the approved remote topologies. Direct router port forwarding to the public internet is permanently REJECTED. Rate limiting is mandatory.

## Consequences
Limits connectivity to authenticated, encrypted overlay tunnels, eliminating exposed inbound ports and significantly reducing the host attack surface.

## Open Design / Non-Goals
Public ingress relays without identity authentication are permanently non-goals.

## Canonical Relationships
Primary normative ownership resides in `authentication-and-secrets.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
