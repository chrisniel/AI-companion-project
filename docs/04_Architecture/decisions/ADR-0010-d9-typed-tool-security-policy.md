# Typed Tool Security Policy

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D9
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`tool-permissions-and-actions.md`](../02_Data_and_Security/tool-permissions-and-actions.md)
**Related Specifications:** [`web-current-information.md`](../03_Integrations/web-current-information.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): Emphasized emergency tool execution kill switch in UI/tray, strict profile isolation for tool side-effects, and permanent rejection of Risk 3 arbitrary shell execution.

## Context
Agentic tool execution must be strictly bounded to prevent unauthorized system modification.

## Decision
DEFAULT DENY. 4-tier risk matrix (Risk 0-3). Low-risk Risk 0 and approved Risk 1 actions may auto-execute when enabled and deterministic policy resolves ALLOW; deterministic policy retains ALLOW, CONFIRM, and DENY. Significant state changes require confirmation. Generic arbitrary shell / OS admin is strictly prohibited and permanently rejected. Emergency kill switch allows immediate halting of all automated tool calls.

## Consequences
Enforces a strict permission model where the AI cannot execute arbitrary OS commands. Tools cannot cross profile boundaries.

## Open Design / Non-Goals
The exact tool catalog and specific action schemas remain extensible and tracked in `DECISION_DEBT.md`.

## Canonical Relationships
Primary normative ownership resides in `tool-permissions-and-actions.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
