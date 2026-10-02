# Scheduling and Notification Semantics

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D10
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`tasks-reminders-alarms-and-routines.md`](../01_Domains/tasks-reminders-alarms-and-routines.md)
**Related Specifications:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): Runtime `SchedulerService` owns canonical scheduling state. Alarms bypass quiet hours by default; Reminders and Routines respect quiet hours by default. Native Windows toasts are dispatched directly by the host runtime.

## Context
Time-based proactivity must clearly distinguish between low-priority reminders and high-priority alarms.

## Decision
Task, Reminder, Alarm, and Routine are distinct entities. Bounded deterministic scheduler proactivity. Native Windows notification delivery target. Quiet hours policy: Alarms bypass quiet hours by default; Reminders and Routines respect quiet hours. Reminder catch-up recovery. Alarm has stronger delivery semantics than an ordinary Reminder; wake support is best-effort (no universal ACPI/firmware wake guarantee).

## Consequences
Provides structured delivery guarantees for time-sensitive events while preventing unexpected interruptions during quiet hours.

## Open Design / Non-Goals
Exact Windows kernel timer APIs and toast deep-link button bindings are tracked in `DECISION_DEBT.md`. Unbounded autonomous proactivity/looping remains rejected.

## Canonical Relationships
Primary normative ownership resides in `tasks-reminders-alarms-and-routines.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
