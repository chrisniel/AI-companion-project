# Scheduling and Notification Semantics

**Status:** Accepted
**Decision ID:** D10
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md
**Related Specifications:** windows-host-and-notifications.md

## Decision History
- Accepted/relocked during R10.
- Focused-domain authority transferred during R11.4.
- Codified during R13.1.
- (R12 mentioned only where it actually refined related sequencing/acceptance/governance).

## Context
See primary canonical owner.

## Decision
Task, Reminder, Alarm, and Routine are distinct. Bounded deterministic scheduler proactivity. Native Windows notification delivery target. Quiet hours with per-item overrides. Reminder catch-up recovery. Alarm has stronger delivery semantics than an ordinary Reminder; wake support is best-effort (no universal ACPI/firmware wake guarantee).

## Consequences
See primary canonical owner.

## Open Design / Non-Goals
See primary canonical owner.

## Canonical Relationships
See primary canonical owner.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
