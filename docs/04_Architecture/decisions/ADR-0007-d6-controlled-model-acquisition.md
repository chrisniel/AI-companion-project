# Controlled Model Acquisition

**Status:** Accepted
**Decision ID:** D6
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`runtime-and-models.md`](../04_Infrastructure/runtime-and-models.md)
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.

## Context
Model files must be safely verified and staged before being exposed to the runtime.

## Decision
Controlled local import pipeline (PC V1 requirement): inbox -> preflight -> staging -> atomic install -> library -> registry. MODEL_LIBRARY_DIR is canonical.

## Consequences
Prevents corruption and unverified execution by ensuring all models pass through a strict staging lifecycle.

## Open Design / Non-Goals
Network-based automated model downloading from external hubs remains an open design.

## Canonical Relationships
Primary normative ownership resides in `runtime-and-models.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
