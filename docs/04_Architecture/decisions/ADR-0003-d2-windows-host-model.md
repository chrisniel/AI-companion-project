# Windows Host Model

**Status:** Accepted
**Decision ID:** D2
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md)
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
The application must run reliably in the background to provide continuous assistant features independent of a visible UI.

## Decision
Independent long-running Windows host process; decoupled from browser lifetime; autostart at login required; native Windows notification delivery required; native desktop shells deferred post-PC-V1.

## Consequences
Requires an independent background host and dedicated notification integration rather than relying on browser-based execution.

## Open Design / Non-Goals
Native desktop shells (e.g., WPF, WinUI) remain deferred open design.

## Canonical Relationships
Primary normative ownership resides in `windows-host-and-notifications.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
