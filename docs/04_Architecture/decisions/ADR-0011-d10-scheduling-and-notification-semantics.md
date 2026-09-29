# Scheduling and Notification Semantics

**Status:** Accepted
**Decision ID:** D10
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md)
**Related Specifications:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
Time-based proactivity must clearly distinguish between low-priority reminders and high-priority alarms.

## Decision
Task, Reminder, Alarm, and Routine are distinct. Bounded deterministic scheduler proactivity. Native Windows notification delivery target. Quiet hours with per-item overrides. Reminder catch-up recovery. Alarm has stronger delivery semantics than an ordinary Reminder; wake support is best-effort (no universal ACPI/firmware wake guarantee).

## Consequences
Provides structured delivery guarantees for time-sensitive events while respecting system quiet hours.

## Open Design / Non-Goals
Exact scheduler engine, schemas, wake integration, and bounded routine phrasing remain open design. Unbounded autonomous proactivity/looping remains rejected.

## Canonical Relationships
Primary normative ownership resides in `tasks-reminders-alarms-and-routines.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
