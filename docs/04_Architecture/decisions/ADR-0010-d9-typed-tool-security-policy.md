# Typed Tool Security Policy

**Status:** Accepted
**Decision ID:** D9
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md
**Related Specifications:** web-current-information.md

## Decision History
- Accepted/relocked during R10.
- Focused-domain authority transferred during R11.4.
- Codified during R13.1.
- (R12 mentioned only where it actually refined related sequencing/acceptance/governance).

## Context
See primary canonical owner.

## Decision
DEFAULT DENY. 4-tier risk matrix (Risk 0-3). Low-risk Risk 0 and approved Risk 1 actions may auto-execute when enabled and deterministic policy resolves ALLOW; deterministic policy retains ALLOW, CONFIRM, and DENY. Significant state changes require confirmation. Generic arbitrary shell / OS admin is strictly prohibited by default.

## Consequences
See primary canonical owner.

## Open Design / Non-Goals
See primary canonical owner.

## Canonical Relationships
See primary canonical owner.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
