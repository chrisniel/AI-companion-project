# Windows Host Model

**Status:** Accepted (Refined by [`ADR-0017`](ADR-0017-flutter-production-windows-client.md))
**Decision ID:** D2
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md)
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md), [`ADR-0017`](ADR-0017-flutter-production-windows-client.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined by `ADR-0017` (2026-10-03): Flutter Desktop approved as primary production Windows client for PC V1 with system tray integration and the invariant "Quit UI != Stop Runtime". Autostart is implemented via Windows Task Scheduler `At log on`.

## Context
The application must run reliably in the background to provide continuous assistant features independent of a visible UI.

## Decision
Independent long-running Windows host process; decoupled from client lifetime; autostart at login required; native Windows notification delivery required. Refined by ADR-0017: Flutter Desktop provides the primary native UI and tray integration for PC V1, while React Web is retained as a supported developer harness.

## Consequences
Requires an independent background host and dedicated notification integration rather than relying on browser-based execution.

## Open Design / Non-Goals
Packaging and installer automation (e.g. Inno Setup or MSIX) remain implementation-level details.

## Canonical Relationships
Primary normative ownership resides in `windows-host-and-notifications.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
