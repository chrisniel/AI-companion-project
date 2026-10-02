# AI Companion — PC V1 Master Readiness Checklist

> **Document Role:** Canonical tracking checklist auditing readiness across architecture, implementation, automated testing, documentation, and Golden PC V1 release evidence.  
> **Status:** Active Canonical Tracking Matrix  
> **Governance Invariant:** Never claim target architecture is implemented. State categories: `IMPLEMENTED / VERIFIED`, `IN PROGRESS`, `APPROVED TARGET (NOT STARTED)`, `LATER / DEFERRED`.

---

## 1. Readiness Audit Matrix

| Domain Area | Target Capability | Architecture Spec | Implemented Source / Tests | Automated CI Gate | Golden Release Gate | Overall Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Governance** | Human-only Git write authority | `AGENTS.md`, `DELIVERY_WORKFLOW.md` | Process rules | N/A | Human review | **VERIFIED** |
| **PC Client** | Flutter Windows Desktop App | `windows-host-and-notifications.md` | Pending Flutter scaffold / target path TBD | Flutter CI lane | G1 | **NOT STARTED** |
| **PC Client** | React Web Supported Client | `SYSTEM_BASELINE.md` §1 | `frontend/web/` | Vitest / Build | G14 | **VERIFIED** |
| **PC Host** | Task Scheduler Autostart at Login | `windows-host-and-notifications.md` | Pending implementation | Host tests | G1 | **NOT STARTED** |
| **PC Host** | Native Windows Action Center Toasts| `windows-host-and-notifications.md` | Pending implementation | Adapter tests | G8 | **NOT STARTED** |
| **PC Host** | Storage Roots (`APP`, `DATA`, `LIBRARY`)| `storage-and-assets.md` | `app.core.storage` (Partial)| Pytest storage | G1 | **PARTIAL** |
| **Contracts** | OpenAPI Schema 3.1 & Drift Check | `DOCUMENTATION_MAP.md` | `contracts/openapi/openapi.json` | Python drift check| G1 | **VERIFIED** |
| **Contracts** | Durable FIFO Conversation Queues | `assistant-and-conversations.md` | Pending implementation | Queue unit tests | G4 | **NOT STARTED** |
| **Identity** | Multi-Profile PC V1 Model | `profiles-and-devices.md` | Migration 007 (Pending) | Adversarial test | G2 | **NOT STARTED** |
| **Identity** | Satellite Device Revocable Token | `profiles-and-devices.md` | Pending implementation | Auth unit tests | G2 | **NOT STARTED** |
| **Models** | Local `llama.cpp` Vulkan GPU Offload | `runtime-and-models.md` | `llama_cpp.py` (b10936 RX 580) | Pytest mocks | G3 | **VERIFIED** |
| **Models** | D6 Controlled Manual Import (Bundles)| `runtime-and-models.md` | GGUF parser done; service gap | Import unit tests| G3 | **PARTIAL** |
| **Models** | Default Single Resident Model | `runtime-and-models.md` | Router `--models-max 1` | Router tests | G3 | **VERIFIED** |
| **Multimodal**| Image Attachment Ingestion & History | `multimodal-and-media.md` | Phase 8B verified | Attachment tests | G4 | **VERIFIED** |
| **Persona** | Character Templates & Profile Instances| `characters-personality-and-emotion.md`| Pending DB schema | Model unit tests | G5 | **NOT STARTED** |
| **Persona** | 8 Continuous Personality Traits | `characters-personality-and-emotion.md`| Pending trait engine | Prompt tests | G5 | **NOT STARTED** |
| **Persona** | Persistent Bounded Mood & Decay | `characters-personality-and-emotion.md`| Pending mood service | State tests | G5 | **NOT STARTED** |
| **Persona** | Immutable Neutral Assistant Fallback | `characters-personality-and-emotion.md`| Prompt baseline | Fallback tests | G5 | **PARTIAL** |
| **Memory** | Profile & Character Scopes | `memory-and-personalization.md` | SQLite+FTS5 baseline exists | FTS5 tests | G6 | **PARTIAL** |
| **Memory** | Selective Automatic Memory Extraction | `memory-and-personalization.md` | Pending policy engine | Extraction tests | G6 | **NOT STARTED** |
| **Memory** | Temporary Memory Validity & Expiry | `memory-and-personalization.md` | Pending schema columns | Expiry tests | G6 | **NOT STARTED** |
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
| **Resilience**| Coordinated DB + Profile Asset Backup | `backup-recovery-and-diagnostics.md` | Migration backup exists | Backup tests | G13 | **PARTIAL** |
| **Resilience**| Staged Restore Verification | `backup-recovery-and-diagnostics.md` | Pending restore validator | Restore tests | G13 | **NOT STARTED** |
| **Resilience**| Local Admin Factory Reset | `backup-recovery-and-diagnostics.md` | Pending reset service | Reset tests | G13 | **NOT STARTED** |
| **Remote** | Tailscale Mesh & Cloudflare Tunnel | `authentication-and-secrets.md` | Tailscale installed on host | Remote tests | G14 | **PARTIAL** |
| **Golden Gate**| 14-Group End-to-End Release Gate | `SYSTEM_BASELINE.md` §5 | Verification Guide | Release Run | All 14 Groups | **NOT STARTED** |

---

## 2. Release Blocker Audit

- [ ] **M0 Docs & Architecture Reset Pass:** Complete canonicalization, verify fresh-agent startup, and obtain Chris approval.
- [ ] **M1 Flutter Scaffolding:** Initial Flutter Windows app operational and connecting to Local AI Runtime.
- [ ] **M2 Host Autostart & Notifications:** Proved working without open browser tab.
- [ ] **M2 Multi-Profile Migration:** Database schema updated with full privacy isolation.
- [ ] **M2 D6 Model Import:** Proved working with GGUF + mmproj paired bundle.
- [ ] **M3 Character Studio & 8 Traits:** Proved modulating prompt without functional corruption.
- [ ] **M3 Persistent Mood:** Proved surviving restart with natural decay.
- [ ] **M3 Memory & Scheduling:** Proved auto-extraction and alarm dispatch.
- [ ] **M4 Voice Pipeline:** Proved live spoken turn with instant barge-in cancellation.
- [ ] **M4 D9 Policy Engine:** Proved DEFAULT DENY and Risk 2 confirmation prompts.
- [ ] **M4 Web Security:** Proved SSRF containment and source provenance.
- [ ] **M5 Low-Impact Mode:** Proved automatic activation on heavy app focus and model swap.
- [ ] **M5 Backup & Factory Reset:** Proved clean restore and first-run reset.
- [ ] **GATE-PC-V1:** Full 14-group Golden Journey executed with formal evidence recorded.
