# Shared Milestone & Integration Tracking

> **Status:** Active integration state.
> **Scope:** Durable milestone-level direction.

## Current Delivery State

- **Phase 8:** COMPLETE / VERIFIED
- **M0 Documentation & Architecture Reset:** COMPLETE / VERIFIED
- **MOBILE-ARCH — Mobile V1 Canonical Architecture Pass:** COMPLETE / VERIFIED (Architecture specs, Mobile WBS, and Mobile Checklist completed; Closure Gate passed).
- **M1 Flutter Client Foundation:** COMPLETE / SQUASH-MERGED (Delivered via PR #23 at commit `7c1d1a2ddb5c57ddaae9bbacbcab2e25f9938fe1`; local monorepo pub workspace, Win32 desktop shell, system tray, fail-closed auth, chat streaming, Markdown tables, and post-turn AI title parity; Closure Gate reconciled post-merge with documented tracker archival exception).
- **M2-H1 Windows Runtime Supervision:** COMPLETE / SQUASH-MERGED (Delivered via PR #24 at commit `d0f96fc533326f02112a28c4246dfe0c9cd7647d`; independent windowless runtime launch, kernel lockfile supervision, tray lifecycle, truthful model unload, request-scoped finish reasons, and Flutter chat quality follow-up).
- **M2 Batch A Profile Schema Foundation & WAL Backup:** COMPLETE / SQUASH-MERGED (Delivered via PR #25 at commit `369d787019f2a7a51c4a796a5cae9849514782bb`; Multi-Profile schema, migration safety, and pre-migration WAL backup).
- **M2 Batch B Profile Sessions & Cross-Profile Isolation:** COMPLETE / SQUASH-MERGED (Delivered via PR #27 at commit `5cb2fe6891ebdf1c5a31d87e0767e7c8ec1b0f51`, with follow-up PR #28 at commit `0bb0894578b87ce01da7a92fb42dfa8eb3309a47`; session authentication, ownership filtering, and isolation).
- **M3 Batch A Character Foundation & Immutable Neutral Assistant:** COMPLETE / SQUASH-MERGED (Delivered via PR #29 at commit `d22dd7e1dbbd0a50c9a4e6fd28ab5fbdbcce34de`; character template seed, profile instances, immutable neutral fallback, and selection API).
- **M2 Batch C Local Profile Administration & Persistent Selection:** COMPLETE / SQUASH-MERGED (Delivered via PR #33 at commit `2104d5c05ad1a7b47d2b008d4e74ca5cb88595e6`; profile create/rename, persistent last-selected profile, acquire-before-teardown switching, and desktop UI).
- **M2 Batch D Recoverable Profile Deletion & Safe Purge:** COMPLETE / SQUASH-MERGED (Delivered via PR #34 at commit `f3752a3`; 30-day recoverable soft-delete, session revocation, administrative restore, 5-phase safe physical-first purge pipeline, automatic startup/hourly background sweeps, and Desktop UI confirmation dialogs).
- **M3 Batch C1 Memory Foundation, Scoping & Context Assembly:** COMPLETE / SQUASH-MERGED (Delivered via PR #35 at commit `b3d31d7`; Migration 010 adding scope, character_instance_id, valid_from, expires_at, last_verified_at, is_core, scoped context assembly with bound :now temporal exclusion, 5-fact core memory injection under 100-token budget, REST endpoints, RESTRICT FK purge order, and companion_api Dart parity across 42 verified routes).
- **M3 Batch C2 Selective Automatic Memory Extraction & Slot Reconciliation:** COMPLETE / VERIFIED (Implemented on branch `feature/m3-memory-extraction-c2`, PR #36; disclosure-aware heuristic skip gate, structured LLM extraction prompt, secrets filtering, deterministic slot reconciler DUPLICATE/NEW/MERGE/UPDATE/CONFLICT, zero-latency background execution, session isolation with rollback, single-flight profile lock, 27/27 extraction tests, 755/755 backend tests passed, CI passed; ready for squash merge).

## Next Milestone / Current Focus

- **M2 PC Companion Foundation:** ACTIVE / IN PROGRESS — Batch A (`PC-IDENTITY-001`, PR #25), Batch B (`PC-IDENTITY-002`, PR #27, PR #28), `PC-HOST-005` (PR #32), Batch C (`PC-IDENTITY-004`, `PC-CLIENT-005`, PR #33), and Batch D (`PC-IDENTITY-005`, PR #34) are squash-merged to develop. Wider Milestone M2 tracks remain planned and in progress (Profile PIN, device enrollment `PC-IDENTITY-003`, autostart `PC-HOST-002`, native notifications `PC-HOST-003`, storage roots manager, and D6 model import `PC-MODEL-002`).
- **M3 Companion Character & Intelligence:** ACTIVE / IN PROGRESS — Batch A Character Foundation (`PC-CHAR-001`, `PC-CHAR-005`) delivered via PR #29 (`d22dd7e`); Batch B Character Studio V1 & Personality Modulator (`PC-CHAR-002`, `PC-CLIENT-007`) completed on branch; Batch C1 Memory Foundation (`PC-MEM-001`, `PC-MEM-003`, `PC-MEM-005`, `PC-API-001`) delivered via PR #35 (`b3d31d7`); Batch C2 Selective Automatic Extraction & Slot Reconciliation (`PC-MEM-002`) completed in PR #36. Next immediate focus: Batch C3 Desktop Memory Control Center UI (`PC-CLIENT-009`) + turn extraction ON with per-profile toggle. Wider Milestone M3 tracks remain planned (persistent bounded mood simulation `PC-CHAR-003` and `SchedulerService` engine `PC-SCHED-001`..`004`).
- **Mobile Companion Implementation:** Independent follow-on track scheduled per `docs/02_Planning/00_Master/MOBILE_WBS.md` without blocking PC V1.
