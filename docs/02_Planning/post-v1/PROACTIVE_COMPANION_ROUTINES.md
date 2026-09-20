# Proactive Companion Routines / Scheduled Check-ins

> **Classification:** POST-V1 PLANNING SOURCE  
> **Status:** Future Product Planning / Post-V1 Milestone  
> **Authority Notice:** Non-authoritative for V1. Proactive companion routines are explicitly excluded from the AI Companion V1 release boundary per Decision D1. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) owns the locked V1 scope boundary; [`docs/02_Planning/ROADMAP.md`](../ROADMAP.md) owns product milestone sequencing; canonical domain architecture owns normative technical boundaries. Exact proactive-routine implementation and scheduling interfaces must be revalidated before this future milestone begins execution.

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