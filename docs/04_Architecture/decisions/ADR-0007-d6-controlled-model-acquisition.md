# Controlled Model Acquisition

**Status:** Accepted (Refined by PC V1 Decision Pass)
**Decision ID:** D6
**Codification Date:** 2026-09-29
**Original Decision Date:** Not separately recorded
**Primary Canonical Owner:** [`runtime-and-models.md`](../04_Infrastructure/runtime-and-models.md)
**Related Specifications:** [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md), [`DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md)

## Decision History
- Accepted/relocked during R10.
- Canonical focused-domain authority transferred during R11.4.
- Codified during R13.1.
- Refined during PC V1 Decision Pass (2026-10-03): D6 import is a manual user-initiated scan (no filesystem watcher polling). Supports atomic installation of multi-file bundles (`.gguf` base model + companion `mmproj` vision projector).

## Context
Model files must be safely verified and staged before being exposed to the runtime.

## Decision
Controlled local import pipeline: inbox -> manual user scan -> preflight & header metadata inspection -> user confirmation -> staging -> atomic install -> library -> registry. Supports atomic multi-file bundles (`.gguf` + `mmproj`). No filesystem watcher.

## Consequences
Prevents corruption, race conditions from partial writes, and unverified execution by ensuring all models pass through a strict staging lifecycle.

## Open Design / Non-Goals
Managed online model downloading from Hugging Face Hub is PC Later. Exact checksum and hash algorithms are tracked in `DECISION_DEBT.md`.

## Canonical Relationships
Primary normative ownership resides in `runtime-and-models.md`.

## Change Control
Superseding an accepted ADR requires explicit human approval and a superseding decision record.
