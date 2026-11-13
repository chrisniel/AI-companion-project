# AI Companion — PC V1 Master Readiness Checklist

> **Document Role:** Canonical tracking checklist auditing readiness across architecture, implementation, automated testing, documentation, and Golden PC V1 release evidence.
> **Status:** Active Canonical Tracking Matrix
> **Governance Invariant:** Never claim target architecture is implemented. State categories: `IMPLEMENTED / VERIFIED`, `IN PROGRESS`, `APPROVED TARGET (NOT STARTED)`, `LATER / DEFERRED`.
> **Mobile Companion Reference:** This checklist tracks PC V1 release readiness. For Mobile Companion readiness across architecture, implementation, and acceptance groups MG1–MG18 (`D-MOBILE-VERIFY-01..03`), consult [`MOBILE_CHECKLIST.md`](./MOBILE_CHECKLIST.md).

---

## 1. Readiness Audit Matrix

| Domain Area | Target Capability | Architecture Spec | Implemented Source / Tests | Automated CI Gate | Golden Release Gate | Overall Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Governance** | Human-only Git write authority | `AGENTS.md`, `DELIVERY_WORKFLOW.md` | Process rules | N/A | Human review | **VERIFIED** |
| **Governance** | Scoped CI Matrix (PC-VERIFY-001) | `TESTING_AND_CI.md` | `ci_policy.py`, CI yaml | Python static tests | N/A | **IMPLEMENTED / VERIFIED** (source/static) |
| **PC Client** | Flutter Windows Desktop App | `windows-host-and-notifications.md` | `frontend/flutter/` (193 tests passed, Win32 debug build verified) | Flutter CI lane (`flutter`) | G1 | **IMPLEMENTED / VERIFIED (PR #23 SQUASH-MERGED)** |
| **PC Client** | React Web Supported Client | `SYSTEM_BASELINE.md` §1 | `frontend/web/` | Vitest / Build | G14 | **VERIFIED** |
| **PC Host** | Host Admin & Lifecycle (`PC-HOST-005`) | `windows-host-and-notifications.md` | `POST /system/shutdown`, `RuntimeLifecycleCoordinator`, `LlamaCppProvider` strict lock, `WindowsRuntimeProcessSupervisor`, Desktop Exit flow, 4-state model sync | 660 pytest, 297 flutter desktop, 81 companion_api, 23 companion_core | G1 | **IMPLEMENTED / VERIFIED (BRANCH feature/m2-secure-host-lifecycle; PR PREPARED)** |
| **PC Host** | Task Scheduler Autostart at Login | `windows-host-and-notifications.md` | Pending implementation | Host tests | G1 | **NOT STARTED** |
| **PC Host** | Native Windows Action Center Toasts| `windows-host-and-notifications.md` | Pending implementation | Adapter tests | G8 | **NOT STARTED** |
| **PC Host** | Storage Roots (`APP`, `DATA`, `LIBRARY`)| `storage-and-assets.md` | `app.core.storage` (Partial)| Pytest storage | G1 | **PARTIAL** |
| **Contracts** | OpenAPI Schema 3.1 & Drift Check | `DOCUMENTATION_MAP.md` | `contracts/openapi/openapi.json` | Python drift check| G1 | **VERIFIED** |
| **Contracts** | Durable FIFO Conversation Queues | `assistant-and-conversations.md` | Pending implementation | Queue unit tests | G4 | **NOT STARTED** |
| **Identity** | Multi-Profile PC V1 Model | `profiles-and-devices.md` | Batch A schema (PR #25) and Batch B sessions/isolation (PR #27, PR #28) squash-merged to develop; Batch C Profile CRUD & persistent selection verified on `feature/m2-profile-admin-c` | Hosted PR CI passed; manual acceptance verified | G2 | **IMPLEMENTED / VERIFIED (PR #25, #27, #28 SQUASH-MERGED; BATCH C VERIFIED ON FEATURE BRANCH; PIN/DEVICE ENROLLMENT FUTURE)** |
| **Identity** | Satellite Device Revocable Token | `profiles-and-devices.md` | Pending implementation | Auth unit tests | G2 | **NOT STARTED** |
| **Models** | Local `llama.cpp` Vulkan GPU Offload | `runtime-and-models.md` | `llama_cpp.py` (b10936 RX 580) | Pytest mocks | G3 | **PARTIAL** (reference/mock evidence only until supported live/packaged verification exists) |
| **Models** | D6 Controlled Manual Import (Bundles)| `runtime-and-models.md` | GGUF parser done; service gap | Import unit tests| G3 | **PARTIAL** |
| **Models** | Default Single Resident Model | `runtime-and-models.md` | Router `--models-max 1` | Router tests | G3 | **VERIFIED** |
| **Multimodal**| Image Attachment Ingestion & History | `multimodal-and-media.md` | Phase 8B verified | Attachment tests | G4 | **VERIFIED** |
| **Persona** | Character Templates & Profile Instances| `characters-personality-and-emotion.md`| Migration 009, models, service, REST API, templates seed, desktop selection & chat integration | Pytest character / Flutter character | G5 | **IMPLEMENTED / VERIFIED (PR #29 SQUASH-MERGED)** |
| **Persona** | 8 Continuous Personality Traits & Studio| `characters-personality-and-emotion.md`| `compile_personality_modulation_block` (8 traits, 5 bands, Autonomy Guard, <=700 bound), Flutter Character Studio V1 (`PC-CLIENT-007`), draft/dirty state, sequential Save & Activate, snapshot PATCH reconciliation, chat identity visibility | 641 pytest (17 modulator), 278 flutter desktop, 248 web (16 files), Windows acceptance 14 PASS | G5 | **IMPLEMENTED / VERIFIED (PR #30 SQUASH-MERGED)** |
| **Persona** | Persistent Bounded Mood & Decay | `characters-personality-and-emotion.md`| Migration 012, `mood_engine.py`, `appraisal.py`, `<character_persona>` grounding, DRY sampling + 4-gram stream circuit breaker, Desktop Chat & Studio live mood badges | 779 pytest, 96 `companion_api`, 350 flutter desktop | G5 | **IMPLEMENTED / VERIFIED (BRANCH feature/m3-emotion-mood-engine-d)** |
| **Persona** | Immutable Neutral Assistant Fallback | `characters-personality-and-emotion.md`| Template 00000000-0000-0000-0000-000000000001, immutable fallback logic, UI fallback safeguards | Unit & API tests | G5 | **IMPLEMENTED / VERIFIED (PR #29 SQUASH-MERGED)** |
| **Memory** | Profile & Character Scopes | `memory-and-personalization.md` | Migration 010/013, 3-tier classification (`knowledge`, `long_term`, `short_term`), FTS5 prefix search + stem lorebooks | Memory foundation, FTS5 & tier tests | G6 | **IMPLEMENTED / VERIFIED (PR #35–#37 SQUASH-MERGED + BATCH E ON `feature/m3-memory-knowledge-e`)** |
| **Memory** | Selective Automatic Memory Extraction | `memory-and-personalization.md` | Extraction gate, explicit boost, Fixed Knowledge protection, cross-session promotion, conflict banner | Extraction, reconciler & tier tests | G6 | **IMPLEMENTED / VERIFIED (PR #36–#37 SQUASH-MERGED + BATCH E ON `feature/m3-memory-knowledge-e`)** |
| **Memory** | Temporary Memory Validity & Expiry | `memory-and-personalization.md` | Deterministic 72h situational TTL, `:now` exclusion, TTL badges & 1-click UI Promote | Foundation & tier TTL tests | G6 | **IMPLEMENTED / VERIFIED (PR #35 SQUASH-MERGED + BATCH E ON `feature/m3-memory-knowledge-e`)** |
| **Actions** | D9 Deterministic 5-Stage Pipeline | `tool-permissions-and-actions.md` | Pending engine | Policy matrix | G7 | **NOT STARTED** |
| **Actions** | DEFAULT DENY & Parameter Confirmation | `tool-permissions-and-actions.md` | Pending engine | Security tests | G7 | **NOT STARTED** |
| **Actions** | Persistent Tool Kill Switch | `tool-permissions-and-actions.md` | Pending engine | Safety tests | G7 | **NOT STARTED** |
| **Actions** | Rejection of Generic OS Shell | `tool-permissions-and-actions.md` | Locked architectural rule | Rejection tests | G7 | **LOCKED / REJECTED**|
| **Schedule** | Runtime `SchedulerService` Engine | `tasks-reminders-alarms-and-routines.md` | Tasks CRUD done; engine gap | Scheduler tests | G8 | **PARTIAL** |
| **Schedule** | Distinct Reminder & Alarm Lifecycles | `tasks-reminders-alarms-and-routines.md` | Pending engine | Alert tests | G8 | **NOT STARTED** |
| **Schedule** | Quiet Hours & Late Alarm Grace Window | `tasks-reminders-alarms-and-routines.md` | Pending engine | Policy tests | G8 | **NOT STARTED** |
| **Schedule** | Bounded Companion Routines | `tasks-reminders-alarms-and-routines.md` | Pending engine | Routine tests | G8 | **NOT STARTED** |
| **Voice** | Local STT (`whisper.cpp`) & Kokoro TTS | `voice-and-audio.md` | whisper.cpp runtime candidate exists locally, Kokoro candidate assets exist; no complete STT model/pipeline staged | Speech unit tests| G9 | **PARTIAL (ASSETS ONLY)** |
| **Voice** | Mandatory Real Voice Barge-In | `voice-and-audio.md` | Pending pipeline | Duplex tests | G9 | **NOT STARTED** |
| **Web Info** | Read-Only WebSearch, Fetch & Weather | `web-current-information.md` | Pending provider adapters | SSRF unit tests | G10 | **NOT STARTED** |
| **Web Info** | Outbound SSRF & Private IP Containment | `web-current-information.md` | Pending network layer | Containment tests| G10 | **NOT STARTED** |
| **Cloud** | Optional Cloud Fallback (`LOCAL_FIRST`) | `runtime-and-models.md` | Pending cloud adapters | Egress mock tests| G11 | **NOT STARTED** |
| **Cloud** | Device-Local Cloud Keys (No sync) | `authentication-and-secrets.md` | Pending secrets manager | Isolation tests | G11 | **NOT STARTED** |
| **Resource** | Low-Impact Mode (Option B App List) | `performance-and-capacity.md` | Pending resource controller | Throttling tests | G12 | **NOT STARTED** |
| **Resource** | Low-Impact Lightweight Model Swap | `performance-and-capacity.md` | Pending swap coordinator | Swap tests | G12 | **NOT STARTED** |
| **Resilience**| Coordinated DB + Profile Asset Backup | `backup-recovery-and-diagnostics.md` | Pre-migration WAL-safe DB backup hook verified (`app.db.backup`); Asset archive pending | Pytest backup | G13 | **PARTIAL (PRE-MIGRATION DB VERIFIED)** |
| **Resilience**| Staged Restore Verification | `backup-recovery-and-diagnostics.md` | Standalone restore utility with pre-restore safety snapshot verified (`restore_database_from_backup`); automatic/live recovery pending quiescence authority | Restore tests | G13 | **PARTIAL (STANDALONE UTILITY VERIFIED)** |
| **Resilience**| Local Admin Factory Reset | `backup-recovery-and-diagnostics.md` | Pending reset service | Reset tests | G13 | **NOT STARTED** |
| **Remote** | Tailscale Mesh & Cloudflare Tunnel | `authentication-and-secrets.md` | Tailscale installed on host | Remote tests | G14 | **PARTIAL** |
| **Golden Gate**| 14-Group End-to-End Release Gate | `SYSTEM_BASELINE.md` §5 | Verification Guide | Release Run | All 14 Groups | **NOT STARTED** |

---

## 2. Release Blocker Audit

- [x] **M1 Flutter Scaffolding:** Flutter Desktop app foundation operational, connecting to Local AI Runtime, delivered via PR #23 (commit `7c1d1a2ddb5c57ddaae9bbacbcab2e25f9938fe1`) with all 193 workspace tests, 0 analyzer issues, Win32 debug build, and hosted PR CI passed.
- [x] **M2 Host Launch & Supervision (PC-HOST-001):** Proved working with single-instance kernel locking, detached rotating logging, process provenance, and crash survival (delivered via PR #24, commit `d0f96fc`).
- [x] **M2 Host Lifecycle (PC-HOST-005):** Proved working with secure graceful loopback exit, real DB quiescence barrier, strict provider lock ownership, external router preservation, handle-bound Windows OS process fallback, desktop tray and settings exit dialogs, and bounded 4-state model loading reliability (implemented and verified on branch `feature/m2-secure-host-lifecycle`, PR prepared). Autostart (`PC-HOST-002`) remains scheduled.
- [ ] **M2 Native Desktop Notifications (PC-HOST-003):** Proved working without open browser tab.
- [ ] **M2 Multi-Profile Migration & G2 Acceptance:** Batch A schema (PR #25) and Batch B session/ownership isolation (PR #27, PR #28) squash-merged to develop. Batch C Profile CRUD, persistent selection, acquire-before-teardown switching, and Desktop UI implemented and verified on branch `feature/m2-profile-admin-c`. PIN challenge, device enrollment, and final G2 manual acceptance remain planned.
- [ ] **M2 D6 Model Import:** Proved working with GGUF + mmproj paired bundle.
- [x] **M3 Character Studio & 8 Traits:** Batch A foundation delivered (PR #29, `d22dd7e`). Batch B 8-trait modulator and immersive Studio V1 delivered via PR #30 (`319ab66`).
- [x] **M3 Persistent Mood:** Proved surviving restart with deterministic step rebalancing, `<1ms` pre-generation turn appraisal, natural companion grounding, DRY sampling + 4-gram stream circuit breaker, and Desktop Chat & Studio live mood badges (implemented and verified on branch `feature/m3-emotion-mood-engine-d` with 779/779 backend tests, 96/96 `companion_api` tests, and 350/350 Flutter desktop tests passing).
- [ ] **M3 Memory & Scheduling:** Memory 3-tier extraction, lorebooks, protection, and Option 2A UI verified on `feature/m3-memory-knowledge-e`; `SchedulerService` and alarm dispatch remain planned.
- [ ] **M4 Voice Pipeline:** Proved live spoken turn with instant barge-in cancellation.
- [ ] **M4 D9 Policy Engine:** Proved DEFAULT DENY and Risk 2 confirmation prompts.
- [ ] **M4 Web Security:** Proved SSRF containment and source provenance.
- [ ] **M5 Low-Impact Mode:** Proved automatic activation on heavy app focus and model swap.
- [ ] **M5 Backup & Factory Reset:** Proved clean restore and first-run reset.
- [ ] **GATE-PC-V1:** Full 14-group Golden Journey executed with formal evidence recorded.
