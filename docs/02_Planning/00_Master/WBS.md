# AI Companion — PC V1 Work Breakdown Structure (WBS)

> **Document Role:** Canonical granular work breakdown structure cataloging stable work IDs across all PC V1 implementation streams.  
> **Status:** Active Canonical Planning Baseline  
> **Batching Principle:** Use the largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost. Do not enforce arbitrary LOC or file quotas.

---

## 1. Stream Index

| Stream Prefix | Domain Scope | Primary Responsibility |
| :--- | :--- | :--- |
| **`DOC`** | Documentation & Architecture | Authority models, specs, guides, ADRs, and navigation integrity. |
| **`PC-CLIENT`** | Flutter Desktop Primary Client | Windows desktop UI, tray management, window states, theme, navigation. |
| **`PC-HOST`** | Windows Host Infrastructure | Task Scheduler autostart, background supervision, native notifications. |
| **`PC-API`** | Client ↔ Runtime Contracts | REST endpoints, SSE typed streaming, WebSocket transport, OpenAPI parity. |
| **`PC-IDENTITY`** | Multi-Profile & Accounts | Account admin, Profile isolation, PIN/Hello protection, device pairing. |
| **`PC-MODEL`** | Model Library & D6 Import | Manual scan, inbox pipeline, bundle install, GGUF/mmproj, registry v3. |
| **`PC-CHAR`** | Character, Personality & Mood | Character instances, 8 traits, persistent bounded mood, neutral fallback. |
| **`PC-MEM`** | Memory & Continuity | Profile/Character scopes, selective auto-memory, temporary expiry, recall. |
| **`PC-ACTION`** | D9 Typed Action Engine | DEFAULT DENY, 5-stage pipeline, Risk 0/1/2 policy, kill switch, audit. |
| **`PC-SCHED`** | Productivity & Routines | SchedulerService, distinct Task/Reminder/Alarm/Routine, quiet hours. |
| **`PC-VOICE`** | Conversational Voice Pipeline | Native audio devices (Flutter), STT/TTS providers, mandatory barge-in. |
| **`PC-WEB`** | Read-Only Web Current Info | WebSearch, WebFetch, Weather adapters, SSRF containment, provenance. |
| **`PC-CLOUD`** | Optional Cloud Fallback | Local-first routing, explicit credentials, background-cloud defaults OFF. |
| **`PC-RESILIENCE`**| Backup, Restore & Reset | DB + Profile asset snapshot, staged restore verification, Factory Reset. |
| **`PC-RESOURCE`**  | Resource Governance & Gaming | Normal / Low Impact / Auto, heavy app triggers, Low-Impact model role. |
| **`PC-VERIFY`**    | Verification & Golden Gate | Scoped CI matrix, contract tests, adversarial privacy, 14 Golden groups. |

---

## 2. Granular Work Item Catalog

### Stream: `DOC` — Documentation & Architecture
- **`DOC-01`**: PC V1 Documentation Canonicalization Pass (Execute handoff, create Master planning spine, retire temporary manifests).
- **`DOC-02`**: ADR Reconciliation (Codify ADR-0017..0019, annotate supersessions on ADR-0002..0012).
- **`DOC-03`**: Compact `SYSTEM_BASELINE.md` Rewrite (Establish compact cross-cutting anchor and link focused specs).
- **`DOC-04`**: Focused Domain Specs Reconciliation (Reconcile 18 canonical architecture specifications with frozen decisions).
- **`DOC-05`**: Root & Developer Guide Alignment (Rewrite conventional README, thin AGENTS.md, author DELIVERY_WORKFLOW.md, update DOCUMENTATION_MAP.md, align setup and testing guides).

### Stream: `PC-CLIENT` — Flutter Desktop Primary Client
- **`PC-CLIENT-01`**: Flutter Windows Desktop Project Scaffolding (`client/pc/` or `frontend/desktop/`, build targets, dependencies).
- **`PC-CLIENT-02`**: Window Management, System Tray Integration & Close-to-Tray Lifecycle.
- **`PC-CLIENT-03`**: SoftGlass / Neumorphic Desktop Design System, Dark/Light Themes & Typography.
- **`PC-CLIENT-04`**: API Client Layer (OpenAPI-derived Dart client, SSE token stream consumer, WebSocket duplex client).
- **`PC-CLIENT-05`**: Multi-Profile Navigation & Local Admin Switcher UI (PIN / Windows Hello challenge).
- **`PC-CLIENT-06`**: Conversation View & Multimodal Attachment Composer with Lightbox.
- **`PC-CLIENT-07`**: Character Studio & Personality Trait Editor (8 continuous sliders, preset templates).
- **`PC-CLIENT-08`**: Schedule, Reminder, Alarm & Routine Management View.
- **`PC-CLIENT-09`**: Memory Inspection, Correction & Deletion Control Center.
- **`PC-CLIENT-10`**: Model Management UI (D6 manual scan trigger, bundle install confirmation, VRAM metrics).
- **`PC-CLIENT-11`**: Settings, Remote Access & Backup/Reset UI.

### Stream: `PC-HOST` — Windows Host Infrastructure
- **`PC-HOST-01`**: Local AI Runtime Process Supervision & Launch Coordinator.
- **`PC-HOST-02`**: Windows Task Scheduler Autostart at User Login Registration.
- **`PC-HOST-03`**: Native Windows Toast Notification Dispatcher Adapter (Action Center delivery).
- **`PC-HOST-04`**: Storage Roots Manager (Resolves `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`).
- **`PC-HOST-05`**: Host Administration Separation (Loopback binding, local admin permission guards).

### Stream: `PC-API` — Client ↔ Runtime Contracts
- **`PC-API-01`**: OpenAPI Schema 3.1 Hardening & Route Contract Regeneration.
- **`PC-API-02`**: Typed Server-Sent Events (SSE) Protocol (Normalized event envelope for tokens, lifecycle, actions).
- **`PC-API-03`**: Duplex WebSocket Protocol for Audio Streaming & Session Coordination.
- **`PC-API-04`**: Durable FIFO Conversation Work Queues (Turn submission, disconnect survival, execution status).
- **`PC-API-05`**: Structured Error Codes & Diagnostic Correlation IDs.

### Stream: `PC-IDENTITY` — Multi-Profile & Accounts
- **`PC-IDENTITY-01`**: Account & Multi-Profile Database Schema Migration (`owner_id` → `profile_id` transition).
- **`PC-IDENTITY-02`**: Strict Profile Authorization Context Middleware & Isolation Enforcement.
- **`PC-IDENTITY-03`**: Satellite Device Enrollment & Single-Profile Binding (Individually revocable credentials).
- **`PC-IDENTITY-04`**: Local PC Admin Profile Management Service (Create, rename, PIN protect, delete).
- **`PC-IDENTITY-05`**: 7-Day Recoverable Profile Deletion Lifecycle & Hard Purge Maintenance.

### Stream: `PC-MODEL` — Model Library & D6 Import
- **`PC-MODEL-01`**: Model Library Storage Derivation (`LIBRARY_ROOT/models/llm`, relocatable path support).
- **`PC-MODEL-02`**: D6 Manual Scan & Inbox Discovery Service (No automatic watcher).
- **`PC-MODEL-03`**: GGUF Binary Header Metadata & Modality Capability Detection.
- **`PC-MODEL-04`**: Multi-File Bundle Staging & Atomic Installation (Model + `mmproj` pairing).
- **`PC-MODEL-05`**: Installed Model Registry Schema v3 Storage & Updating (`library/registry/models.json`).
- **`PC-MODEL-06`**: Single-Resident Model Lifecycle Policy & Advanced Multi-Model Warning Guard.

### Stream: `PC-CHAR` — Character, Personality & Mood
- **`PC-CHAR-01`**: Character Template (App-Owned) & Character Instance (Profile-Owned) Storage Schema.
- **`PC-CHAR-02`**: 8 Continuous Personality Traits Scoring & Prompt Modulator.
- **`PC-CHAR-03`**: Persistent Bounded Emotion & Mood Engine (Restart persistence, decay over elapsed time).
- **`PC-CHAR-04`**: Appraisal Engine & Typed Emotion Events (Ensuring mood cannot alter system correctness).
- **`PC-CHAR-05`**: Immutable Neutral Assistant Fallback Definition.

### Stream: `PC-MEM` — Memory & Continuity
- **`PC-MEM-01`**: Profile & Character Scoped Memory Schema Extension.
- **`PC-MEM-02`**: Selective Automatic Memory Extraction Pipeline (Local-only extraction default, confidence heuristics).
- **`PC-MEM-03`**: Temporary Memory Lifecycle, Expiration Tracking & Natural Revalidation.
- **`PC-MEM-04`**: User Inspection, Correction, Deletion & Tombstone Propagation.
- **`PC-MEM-05`**: Bounded Conversation History Recall & Context Assembly.

### Stream: `PC-ACTION` — D9 Typed Action Engine
- **`PC-ACTION-01`**: 5-Stage Deterministic Pipeline Implementation ($\text{Model} \rightarrow \text{Typed} \rightarrow \text{Policy} \rightarrow \text{Adapter} \rightarrow \text{Capability}$).
- **`PC-ACTION-02`**: DEFAULT DENY Policy Matrix Engine (Risk 0/1/2 evaluation, Profile permission rules).
- **`PC-ACTION-03`**: Explicit Confirmation Token & Parameter Fingerprint Binding.
- **`PC-ACTION-04`**: Emergency Action Controls (Stop Generation, Stop Action, Stop Queue, Persistent Kill Switch).
- **`PC-ACTION-05`**: Structured Audit Logging with Sensitive Data Redaction.
- **`PC-ACTION-06`**: Generic Shell / OS Admin Execution Blocker & Rejection Guard.

### Stream: `PC-SCHED` — Productivity & Routines
- **`PC-SCHED-01`**: Runtime `SchedulerService` Engine (Timezone aware, persistent state, SQLite WAL).
- **`PC-SCHED-02`**: Distinct Task, Standalone/Task-Associated Reminder & Alarm Lifecycles.
- **`PC-SCHED-03`**: Quiet Hours Policy Engine (Alarms bypass default, Reminders/Routines respect default).
- **`PC-SCHED-04`**: Missed Event Reconciliation & Late Alarm Grace Window Evaluation.
- **`PC-SCHED-05`**: Bounded Companion Routines Engine (Deterministic trigger, Risk 2 create/expand policy).

### Stream: `PC-VOICE` — Conversational Voice Pipeline
- **`PC-VOICE-01`**: Flutter Native Audio Capture & Playback Hardware Controller.
- **`PC-VOICE-02`**: Local STT Provider Adapter (`whisper.cpp` subprocess daemon or C++ runner).
- **`PC-VOICE-03`**: Local TTS Provider Adapter (Kokoro-82M neural synthesis).
- **`PC-VOICE-04`**: Mandatory Voice Barge-In State Machine (Immediate playback stop, stale chunk cancellation).
- **`PC-VOICE-05`**: Duplex Voice Session Orchestrator & Turn Identity Coordination over WebSocket.

### Stream: `PC-WEB` — Read-Only Web Current Info
- **`PC-WEB-01`**: Provider-Independent `WebSearch` Adapter with Privacy Minimization.
- **`PC-WEB-02`**: Outbound `WebFetch` Pipeline with Strict SSRF, DNS Rebinding & Private IP Containment.
- **`PC-WEB-03`**: Weather & Public Bulletin Retrieval Integration.
- **`PC-WEB-04`**: Untrusted External Content Sanitizer & Source Provenance Formatter.

### Stream: `PC-CLOUD` — Optional Cloud Fallback
- **`PC-CLOUD-01`**: Cloud Provider Abstraction (OpenAI / Anthropic / OpenRouter adapters).
- **`PC-CLOUD-02`**: Device-Local Cloud API Key Storage & Per-Profile Routing Policy (`LOCAL_ONLY`, `LOCAL_FIRST`).
- **`PC-CLOUD-03`**: Egress Transparency Indicator & Background Cloud Disable Guard.
- **`PC-CLOUD-04`**: Cloud Usage Quotas & Cost Tracking Estimator.

### Stream: `PC-RESILIENCE` — Backup, Restore & Reset
- **`PC-RESILIENCE-01`**: Coordinated Database & Profile-Asset Backup Snapshotter (Checksummed archive).
- **`PC-RESILIENCE-02`**: Pre-Migration Automatic Safety Snapshot Hook.
- **`PC-RESILIENCE-03`**: Staged Restore Verification & Referential Integrity Preflight.
- **`PC-RESILIENCE-04`**: Local Admin Factory Reset Engine (Wipes Account/Profile data; models/backups default keep).

### Stream: `PC-RESOURCE` — Resource Governance & Gaming
- **`PC-RESOURCE-01`**: Host Resource Policy Controller (Normal / Low Impact / Auto).
- **`PC-RESOURCE-02`**: Option B Configured Game & Heavy App Detection with Cooldown Hysteresis.
- **`PC-RESOURCE-03`**: Background Work Deferral & Durable Queue Throttling.
- **`PC-RESOURCE-04`**: Low-Impact Lightweight Model Substitution (1B–3B text LLM swap with state preservation).

### Stream: `PC-VERIFY` — Verification & Golden Gate
- **`PC-VERIFY-01`**: CI Pipeline Update (Always-running `ci-gate` failure aggregator, scoped PR/push matrix).
- **`PC-VERIFY-02`**: Flutter Windows Desktop Automated Test Suite Integration.
- **`PC-VERIFY-03`**: Multi-Profile Privacy Adversarial Test Suite.
- **`PC-VERIFY-04`**: D9 Security & Permission Policy Exhaustive Test Matrix.
- **`PC-VERIFY-05`**: Integrated 14-Group Golden PC V1 Acceptance Harness & Verification Guide.
