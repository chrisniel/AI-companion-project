> **Historical Note:** Routines were formerly considered post-V1 but were later promoted into PC V1 under D10 and [ADR-0011](../../04_Architecture/decisions/ADR-0011-d10-scheduling-and-notification-semantics.md).

# Proactive Companion Routines / Scheduled Check-ins (Post-V1 Design Note)

> [!NOTE]
> **SUPERSEDED PLANNING NOTE — REFER TO MASTER PLANNING SPINE & CANONICAL DOMAIN SPEC**  
> Proactive routines are formally categorized as **PC Later** in the Master Planning Spine:
> - **Backlog Entry:** [`docs/02_Planning/00_Master/BACKLOG.md`](../00_Master/BACKLOG.md#2-pc-later-backlog-approved-post-v1) (`FEAT-BACKLOG-001`)
> - **Normative Domain Architecture:** [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md)
> - **Decision Register:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../00_Master/DECISION_REGISTER.md) (Decision D10)
>
> Preserved as historical design notes.

> **Classification:** POST-V1 PLANNING SOURCE (Legacy Note)  
> **Status:** Superseded / Historical Design Note  
> **Authority Notice:** Non-authoritative for PC V1. Proactive routines are excluded from PC V1 delivery boundary. Normative scheduling rules reside in `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`.

AI Companion should support configurable recurring personal routines that
trigger proactive character messages or notifications without representing
them as Tasks.

Examples:
- meal check-ins
- hydration breaks
- work/rest breaks
- sleep/wind-down reminders
- exercise/stretch reminders
- custom recurring routines

A routine stores scheduling intent and recurrence separately from presentation.
The Active Character determines how the reminder is phrased.

Message modes may include:
1. fixed message
2. randomized approved template pool
3. character-generated message with template fallback

Routines may expose `next_trigger_at` and later participate as another source
in the unified Schedule view.

The scheduler must remain independent from character/persona configuration:
schedule logic decides WHEN/WHAT intent triggers; the character layer decides
HOW the message is expressed.

Desktop web remains desktop-first rather than desktop-exclusive.
Native Android is the preferred mobile client, while mobile web is a
best-effort responsive fallback. Desktop/device-specific capabilities should
be gated individually rather than blocking the entire web application.