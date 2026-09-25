# AI Companion — Canonical Product & Milestone Delivery Roadmap

> **Document Role:** Canonical product and milestone delivery roadmap for the AI Companion ecosystem.  
> **Status:** Active Canonical (Decisions D1–D9 Locked)  
> **Last Updated:** 2026-09-21 (Reconciliation Pass R4)  
> **Authority Precedence:** Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md). Active sprint state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md). Detailed feature implementation steps reside in active plans under [`docs/02_Planning/`](./).

---

## 1. Roadmap Status Taxonomy

| Status Label | Canonical Meaning |
| :--- | :--- |
| **`COMPLETE`** | Fully implemented, tested, and repository-verified. |
| **`CURRENT GATE`** | Active prerequisite gate currently in progress; blocks subsequent implementation. |
| **`NEXT`** | Immediate next delivery milestone to commence upon clearing the current gate. |
| **`V1 REQUIRED`** | Mandatory delivery milestone required for the AI Companion V1 PC release. |
| **`PLANNED POST-V1`** | Approved architectural direction scheduled for post-V1 release milestones. |
| **`RECOMMENDED / NOT YET APPROVED`** | Technical audit finding under evaluation; requires formal approval before scheduling. |
| **`OPEN DESIGN`** | Approved functional requirement whose exact implementation mechanism remains open. |
| **`DEFERRED`** | Intentionally excluded from current and near-term milestones. |

---

## 2. Active Delivery Sequence (Current Milestone Path)

```text
[Phase 8A: UI Foundation] ─────────► COMPLETE / VERIFIED
              │
[Phase 8P: Runtime Config] ────────► COMPLETE / VERIFIED
              │
[Reconciliation Passes R0–R8] ─────► COMPLETE / VERIFIED
              │
[Phase 8B: Multimodal Vision] ─────► IN PROGRESS (8B.0–8B.6 VERIFIED; 8B.7 NEXT)
              │
[Phase 8C: Integration & Polish] ──► V1 REQUIRED (BLOCKED BY 8B)
              │
[V1 Hardening & D6 Import Gap] ────► V1 REQUIRED
              │
[AI Companion V1 Release] ─────────► V1 PC-HOSTED RELEASE
```

### 2.1 Completed Milestones
- **Phase 8A — Frontend Architecture & UX Harmonization (`COMPLETE`):** Decomposed Assistant views into focused components, removed stale mock conversations, implemented time-derived home greetings, added truthful system states, annotated mock files as `@deprecated`.
- **Phase 8P — Runtime Configuration & Persistent Asset Foundation (`COMPLETE`):** Unified subsystem terminology to *Local AI Runtime*, resolved `COMPANION_DATA_ROOT` precedence and bootstrap locator, derived atomic storage layout, implemented Model Registry Schema v3, and verified migration safety.
- **Repository Documentation Reconciliation Passes R0–R8 (`COMPLETE / VERIFIED`):** Conducted full repository forensic audit, locked architectural decisions D1–D9, established canonical documentation routing, purged obsolete terminology, validated Android cleartext/network boundaries, audited and cleaned local legacy database data, verified automated test suites (175 backend pytest, 147 frontend vitest, 124 Android unit/Robolectric), confirmed OpenAPI schema synchronization, and locked the fresh verified baseline.
- **Phase 8B Foundation (Slices 8B.0–8B.6) (`COMPLETE / VERIFIED`):** Delivered multimodal attachment foundation via PR #13: database migration `006_add_attachments`, Attachment ORM model with 4 mixins, Pillow image validation (MIME, dimension, megapixel, bomb guards), route-specific upload limit (12 MiB envelope, 10 MiB payload), authenticated Blob preview/delete endpoints, transactional pre-stream turn binding, media resolver, llama.cpp image translation, and Web composer staging with Blob previews. Verified by CI Run #23 on merged `develop` SHA `4b2f5fe` (321 backend pytest, 185 frontend vitest across 9 files, 22-route OpenAPI parity with zero drift).

### 2.2 Immediate Next Milestone
- **Phase 8B — Multimodal Image Attachment Foundation (`IN PROGRESS`):**
  - *Current Status:* Slices 8B.0–8B.6 are COMPLETE and VERIFIED. Slice 8B.7 (Persistent Message Attachment Rendering) is NEXT / UNBLOCKED. Slice 8B.8 (Full Integration & Phase Closure) is PLANNED. Phase 8B as a whole is NOT yet complete.
  - *Next Slice Scope (8B.7):* Add `AttachmentRef` to frontend types and `AssistantMessage`, extend `ConversationMessageItem` with authenticated Blob preview fetching and `URL.revokeObjectURL()` cleanup, connect message history loading in `AssistantView`, and verify persistence across reload.
  - *Authoritative Feature Plan:* [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md).

### 2.3 Remaining V1 Delivery Milestones
- **Phase 8C — Integration, Accessibility & Polish (`V1 REQUIRED`):**
  - *Scope:* Elimination of deprecated mock files, bundle analysis and code-splitting, comprehensive keyboard navigation and ARIA accessibility, responsive layout hardening across desktop viewports, end-to-end multimodal regression testing.
  - *Authoritative Feature Plan:* [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md).
- **Controlled Local Model Import Service (`V1 REQUIRED — D6 GAP`):**
  - *Scope:* Completing the execution service for the controlled local import pipeline (`inbox` → `preflight` → `staging` → `atomic install` → `library` → `registry`).
  - *Architectural Contract:* [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md).
- **V1 Release Hardening & Verification (`V1 REQUIRED`):**
  - *Scope:* V1 release hardening and verification as approved through dedicated implementation plans (including migration preflight safety, secure configuration defaults, and CI pipeline stability).

---

## 3. AI Companion V1 Scope Boundary (Decision D1)

AI Companion **V1** is strictly defined as a complete, stable, **PC-hosted release**.

### In Scope for V1
1. **Local AI Runtime:** Independent long-running Windows host process.
2. **React Web Primary Client:** Desktop control center, model controls, and streaming chat.
3. **Local Text Inference:** `llama.cpp` Vulkan GPU offload on AMD RX 580.
4. **Conversations & Memory:** SSE token streaming, SQLite persistence, FTS5 keyword retrieval.
5. **Tasks & Reminders:** Personal task lifecycle, soft deletion, retention calculation; automated periodic lifecycle purge and scheduled reminder execution are remaining V1 wiring concerns.
6. **Model Management:** Schema v3 registry, GGUF metadata parsing, runtime profiles.
7. **Controlled Local Model Import:** Validated local filesystem import pipeline (Decision D6).
8. **Phase 8B Multimodal Vision:** Image attachment API and vision model inference.
9. **Phase 8C Polish:** Responsive web cleanup, accessibility, and bundle optimization.
10. **Release Hardening:** Migration safety preflight, secure configuration defaults, and release hardening as approved through dedicated implementation plans.

### Explicitly Post-V1 (Deferred Beyond V1)
- Production Android backend connection and state synchronization.
- Android offline on-device inference and offline/online state reconciliation.
- Real-time voice pipeline (VAD, STT, TTS, wake word).
- Wearables and Health Connect synchronization.
- Proactive companion routines and scheduled autonomous check-ins.
- Controlled autonomous tool execution and external integrations.
- Semantic vector memory and embedding retrieval.
- Managed online model downloading from public hubs.
- Public edge access or port-forwarded remote ingress.
- Native desktop shell container packaging.

---

## 4. Post-V1 Strategic Roadmap Tracks

The tracks below represent approved product directions deferred beyond V1. Order among tracks is not yet locked:

```text
┌────────────────────────────────────────────────────────────────────────┐
│               Post-V1 Strategic Tracks (Unordered)                     │
├────────────────────────────────────────────────────────────────────────┤
│  Track M-Android-Connected   Track M-Android-Offline   Track M-Voice   │
│  (Remote Host Client)        (On-Device Inference)     (Local Speech)  │
│                                                                        │
│  Track M-Tools               Track M-Memory-Semantic   Track M-Health  │
│  (Autonomous Tool Engine)    (Vector / Embeddings)     (Health Connect)│
│                                                                        │
│  Track M-Proactive           Track M-Acquisition       Track M-Desktop │
│  (Companion Check-Ins)       (Online Hub Downloads)    (Native Shell)  │
└────────────────────────────────────────────────────────────────────────┘
```

| Milestone Track | Scope & Capability Target | Canonical Architecture Owner |
| :--- | :--- | :--- |
| **Track M-Android-Connected** | Productionize and expand prototype connection layer: D3 package migration (`com.cnl.aicompanion`), D4 per-device trusted credentials with Android Keystore, pairing UX, full remote sync (conversations, memory, profiles), Tailscale production validation, and background lifecycle hardening. | [`ANDROID_COMPANION_ARCHITECTURE.md`](../04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md) |
| **Track M-Android-Offline** | On-device GGUF execution (~0.27B–1.24B models), local cache, offline/online two-way reconciliation against PC host authority. | [`ANDROID_COMPANION_ARCHITECTURE.md`](../04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md) |
| **Track M-Voice** | CPU-first speech execution: local VAD, STT, and TTS provider abstractions; candidate technologies include Silero VAD, Whisper STT, Kokoro/Piper TTS (no universal default locked pending formal voice benchmarking); wake word detection. | [`VOICE_AND_AUDIO_ARCHITECTURE.md`](../04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md) |
| **Track M-Tools** | Deterministic DEFAULT DENY tool execution engine, 4-tier risk matrix (Risk 0–3), public web search/fetch, candidate browser automation provider (e.g., local Playwright). | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](../04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md) |
| **Track M-Memory-Semantic** | Vector embeddings, semantic similarity search, hybrid FTS5 + vector retrieval, long-term memory consolidation. | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md) |
| **Track M-Health** | Wearable device synchronization, Health Connect integration on Android, biometric context summaries. | [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) |
| **Track M-Proactive** | Scheduled autonomous check-ins, routine morning/evening summaries, ambient awareness notifications. | [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) |
| **Track M-Acquisition** | In-app model hub search (e.g., Hugging Face or public model hubs), background download manager, pause/resume network downloads, model verification. | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) |
| **Track M-Desktop** | Native Windows desktop packaging (candidate approaches including Tauri, Electron, or lightweight webview container), system tray minification, OS autostart. | [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) |

---

## 5. Open Technical Designs & Decisions

The following architectural directions are approved, while their specific technical designs remain deliberately open for future milestone planning:

1. **Android Sync Conflict Algorithm (`OPEN DESIGN`):** PC host remains canonical persistent authority per the Android / profile / runtime architecture; exact conflict resolution algorithm (last-write-wins vs. field-level merge vs. user prompt) remains open.
2. **Device Pairing Protocol (`OPEN DESIGN`):** Per-device revocable credentials locked (Decision D4); exact enrollment UX (QR code, numeric phrase, LAN discovery) and cryptographic handshake remain open.
3. **Windows Host Process Launcher (`OPEN DESIGN`):** Decoupled background runtime locked (Decision D2); exact mechanism (Windows Service, scheduled task, startup shortcut, or native launcher) remains open.
4. **Mobile Model Selection (`OPEN DESIGN`):** Tested envelope (~0.27B–1.24B) demonstrated viable; permanent model candidate, quantization format, and minimum hardware tier remain open.
5. **Universal Default TTS Engine (`OPEN DESIGN`):** Provider abstraction locked; universal default engine across PC and mobile remains open pending formal voice benchmarking.
6. **Tool Permission Schema & Confirmation UI (`OPEN DESIGN`):** 4-tier risk matrix locked (Decision D9); exact confirmation UI dialogs, token limits, and audit log persistence schema remain open.
7. **Llama-Server Crash Recovery Policy (`OPEN DESIGN`):** Need for crash recovery recognized; exact retry limits, exponential backoff, and driver-hang timeouts remain open.

---

## 6. Technical Hardening Recommendations (Audit Findings)

The following items from the technical reconciliation audit represent valuable operational improvements. They are classified accurately to avoid premature scope lock:

| Recommendation | Classification | Prerequisite / Governance Notes |
| :--- | :--- | :--- |
| **CI Gate Failure Aggregation** | `RECOMMENDED PRE-V1 HARDENING — NOT YET SCHEDULED` | Must precede setting CI Gate as a required branch-protection rule on GitHub. Hardens `ci-gate` to aggregate failures reliably. |
| **Pre-Upgrade Database Snapshot** | `RECOMMENDED PRE-V1 HARDENING — NOT YET SCHEDULED` | Automatic snapshot of `companion.db` prior to running pending Alembic migrations. |
| **Backup & Restore UI** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Web settings interface to trigger manual snapshots and inspect backup health. |
| **Diagnostics & Recovery Center** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Web UI panel displaying runtime health, router logs, and crash diagnostic dumps. |
| **Disk Capacity & Quota Guards** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Pre-import free disk space checks to prevent model download/import exhaustion. |
| **Dependency Lock Workflow** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Formalized pip-compile / poetry lockfile governance for backend dependencies. |
| **API Rate Limiting & Throttling** | `RECOMMENDED — APPROVAL / IMPLEMENTATION PLAN REQUIRED` | Protection against high-frequency local request loops on protected endpoints. |
