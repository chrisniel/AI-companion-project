# Active Task: MOBILE-ARCH Canonicalization

> **Branch:** `docs/mobile-v1-canonicalization`
> **Status:** ARCHITECTURE IMPLEMENTATION — Batch A Review Pending
> **Objective:** Execute the Mobile V1 Canonical Architecture Pass to define Mobile cross-cutting ecosystem boundaries, offline capabilities, and security rules.

## Current Execution State
- [x] Reconstruct current repository truth (PC-VERIFY-001 merged baseline: `d92b6e4b9b19e957dd419b9968c7ad3ad4cee031`, post-merge CI Run #65 PASS externally/independently verified baseline evidence supplied by Chris/GPT).
- [x] Inspect canonical startup documents (`SYSTEM_BASELINE.md`, `DOCUMENTATION_MAP.md`, `AGENTS.md`, `ci_policy.py`).
- [x] Inspect actual Android implementation (`android/` prototype).
- [x] Initial Plan Creation & Review (User feedback received).
- [x] Inspection Gap Closure (Verified missing governance/architecture files and codebase to find new contradictions).
- [x] Generate the revised formal MOBILE-ARCH plan (`docs/02_Planning/01_Plans/plan-mobile-v1-canonicalization.md`).
- [x] Final Plan Revision (Surgical corrections for mechanism neutrality, D5 transport constraints, and 3-batch implementation split).
- [x] Await Chris's independent GPT review and approval of the revised plan.
- [x] Phase 1: Architecture Implementation (Batch A — Mobile Foundation).
- [ ] Phase 2: Architecture Implementation (Batch B — Offline & Native Reliability).
- [ ] Phase 3: Architecture Implementation (Batch C — Mobile Capabilities & Verification).
- [ ] Phase 4: Documentation & Planning Integration.
- [ ] Closure & PR Preparation.

## Notes & Blockers
- Found multiple contradictions in the prototype (e.g. package identity, SharedPreferences cleartext token, optimistic MutableStateFlow tasks without outbox, ModelsScreen advertising local LLM/TTS). MockHealthDataProvider is PROTOTYPE/REFERENCE only, and Health Connect is an OPEN architecture decision.
- Mobile credentials must use approved platform-protected secure storage (Android Keystore is a candidate, not locked).
- Architecture implementation will proceed in three strictly bounded batches (A, B, C), each requiring independent approval.
- Master planning spine (WBS, Roadmaps, etc.) will NOT be updated until all three batches are approved.
