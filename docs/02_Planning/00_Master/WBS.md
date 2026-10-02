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
- **`DOC-001`**: PC V1 Documentation Canonicalization Pass (Execute handoff, create Master planning spine, retire temporary manifests).
- **`DOC-002`**: ADR Reconciliation (Codify ADR-0017..0019, annotate supersessions on ADR-0002..0012).
- **`DOC-003`**: Compact `SYSTEM_BASELINE.md` Rewrite (Establish compact cross-cutting anchor and link focused specs).
- **`DOC-004`**: Focused Domain Specs Reconciliation (Reconcile 18 canonical architecture specifications with frozen decisions).
- **`DOC-005`**: Root & Developer Guide Alignment (Rewrite conventional README, thin AGENTS.md, author DELIVERY_WORKFLOW.md, update DOCUMENTATION_MAP.md, align setup and testing guides).

### Stream: `PC-CLIENT` — Flutter Desktop Primary Client
- **`PC-CLIENT-001`**: Flutter Windows Desktop Project Scaffolding (target path TBD, build targets, dependencies).
- **`PC-CLIENT-002`**: Window Management, System Tray Integration & Close-to-Tray Lifecycle.
- **`PC-CLIENT-003`**: SoftGlass / Neumorphic Desktop Design System, Dark/Light Themes & Typography.
- **`PC-CLIENT-004`**: API Client Layer (OpenAPI-derived Dart client, SSE token stream consumer, WebSocket duplex client).
- **`PC-CLIENT-005`**: Multi-Profile Navigation & Local Admin Switcher UI (PIN / Windows Hello challenge).
- **`PC-CLIENT-006`**: Conversation View & Multimodal Attachment Composer with Lightbox.
- **`PC-CLIENT-007`**: Character Studio & Personality Trait Editor (8 continuous sliders, preset templates).
- **`PC-CLIENT-008`**: Schedule, Reminder, Alarm & Routine Management View.
- **`PC-CLIENT-009`**: Memory Inspection, Correction & Deletion Control Center.
- **`PC-CLIENT-010`**: Model Management UI (D6 manual scan trigger, bundle install confirmation, VRAM metrics).
- **PC-CLIENT-011**: Settings, Remote Access & Backup/Reset UI.
- **`PC-CLIENT-012`**: Windows Native Notification Presentation (Toasts/Action Center delivery).

### Stream: `PC-HOST` — Windows Host Infrastructure
- **`PC-HOST-001`**: Local AI Runtime Process Supervision & Launch Coordinator.
- **`PC-HOST-002`**: Windows Task Scheduler Autostart at User Login Registration.
- **`PC-HOST-003`**: Runtime Notification-Event & Durable Backlog Responsibility.
- **`PC-HOST-004`**: Storage Roots Manager (Resolves `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`).
- **`PC-HOST-005`**: Host Administration Separation (Loopback binding, local admin permission guards).

### Stream: `PC-API` — Client ↔ Runtime Contracts
- **`PC-API-001`**: OpenAPI Schema 3.1 Hardening & Route Contract Regeneration.
- **`PC-API-002`**: Typed Server-Sent Events (SSE) Protocol (Normalized event envelope for tokens, lifecycle, actions).
- **`PC-API-003`**: Duplex WebSocket Protocol for Audio Streaming & Session Coordination.
- **`PC-API-004`**: Durable FIFO Conversation Work Queues (Turn submission, disconnect survival, execution status).
- **`PC-API-005`**: Structured Error Codes & Diagnostic Correlation IDs.

### Stream: `PC-IDENTITY` — Multi-Profile & Accounts
- **`PC-IDENTITY-001`**: Account & Multi-Profile Database Schema Migration (`owner_id` → `profile_id` transition).
- **`PC-IDENTITY-002`**: Strict Profile Authorization Context Middleware & Isolation Enforcement.
- **`PC-IDENTITY-003`**: Satellite Device Enrollment & Single-Profile Binding (Individually revocable credentials).
- **`PC-IDENTITY-004`**: Local PC Admin Profile Management Service (Create, rename, PIN protect, delete).
- **`PC-IDENTITY-005`**: 7-Day Recoverable Profile Deletion Lifecycle & Hard Purge Maintenance.

### Stream: `PC-MODEL` — Model Library & D6 Import
- **`PC-MODEL-001`**: Model Library Storage Derivation (`LIBRARY_ROOT/models/llm`, relocatable path support).
- **`PC-MODEL-002`**: D6 Manual Scan & Inbox Discovery Service (No automatic watcher).
- **`PC-MODEL-003`**: GGUF Binary Header Metadata & Modality Capability Detection.
- **`PC-MODEL-004`**: Multi-File Bundle Staging & Atomic Installation (Model + `mmproj` pairing).
- **`PC-MODEL-005`**: Installed Model Registry Schema v3 Storage & Updating (`library/registry/models.json`).
- **`PC-MODEL-006`**: Single-Resident Model Lifecycle Policy & Advanced Multi-Model Warning Guard.

### Stream: `PC-CHAR` — Character, Personality & Mood
- **`PC-CHAR-001`**: Character Template (App-Owned) & Character Instance (Profile-Owned) Storage Schema.
- **`PC-CHAR-002`**: 8 Continuous Personality Traits Scoring & Prompt Modulator.
- **`PC-CHAR-003`**: Persistent Bounded Emotion & Mood Engine (Restart persistence, decay over elapsed time).
- **`PC-CHAR-004`**: Appraisal Engine & Typed Emotion Events (Ensuring mood cannot alter system correctness).
- **`PC-CHAR-005`**: Immutable Neutral Assistant Fallback Definition.

### Stream: `PC-MEM` — Memory & Continuity
- **`PC-MEM-001`**: Profile & Character Scoped Memory Schema Extension.
- **`PC-MEM-002`**: Selective Automatic Memory Extraction Pipeline (Local-only extraction default, confidence heuristics).
- **`PC-MEM-003`**: Temporary Memory Lifecycle, Expiration Tracking & Natural Revalidation.
- **`PC-MEM-004`**: User Inspection, Correction, Deletion & Tombstone Propagation.
- **`PC-MEM-005`**: Bounded Conversation History Recall & Context Assembly.

### Stream: `PC-ACTION` — D9 Typed Action Engine
- **`PC-ACTION-001`**: 5-Stage Deterministic Pipeline Implementation ($\text{Model} \rightarrow \text{Typed} \rightarrow \text{Policy} \rightarrow \text{Adapter} \rightarrow \text{Capability}$).
- **`PC-ACTION-002`**: DEFAULT DENY Policy Matrix Engine (Risk 0/1/2 evaluation, Profile permission rules).
- **`PC-ACTION-003`**: Explicit Confirmation Token & Parameter Fingerprint Binding.
- **`PC-ACTION-004`**: Emergency Action Controls (Stop Generation, Stop Action, Stop Queue, Persistent Kill Switch).
- **`PC-ACTION-005`**: Structured Audit Logging with Sensitive Data Redaction.
- **`PC-ACTION-006`**: Generic Shell / OS Admin Execution Blocker & Rejection Guard.

### Stream: `PC-SCHED` — Productivity & Routines
- **`PC-SCHED-001`**: Runtime `SchedulerService` Engine (Timezone aware, persistent state, SQLite WAL).
- **`PC-SCHED-002`**: Distinct Task, Standalone/Task-Associated Reminder & Alarm Lifecycles.
- **`PC-SCHED-003`**: Quiet Hours Policy Engine (Alarms bypass default, Reminders/Routines respect default).
- **`PC-SCHED-004`**: Missed Event Reconciliation & Late Alarm Grace Window Evaluation.
- **`PC-SCHED-005`**: Bounded Companion Routines Engine (Deterministic trigger, Risk 2 create/expand policy).

### Stream: `PC-VOICE` — Conversational Voice Pipeline
- **`PC-VOICE-001`**: Flutter Native Audio Capture & Playback Hardware Controller.
- **`PC-VOICE-002`**: Local STT Provider Adapter (`whisper.cpp` subprocess daemon or C++ runner).
- **`PC-VOICE-003`**: Local TTS Provider Adapter (Kokoro-82M neural synthesis).
- **`PC-VOICE-004`**: Mandatory Voice Barge-In State Machine (Immediate playback stop, stale chunk cancellation).
- **`PC-VOICE-005`**: Duplex Voice Session Orchestrator & Turn Identity Coordination over WebSocket.

### Stream: `PC-WEB` — Read-Only Web Current Info
- **`PC-WEB-001`**: Provider-Independent `WebSearch` Adapter with Privacy Minimization.
- **`PC-WEB-002`**: Outbound `WebFetch` Pipeline with Strict SSRF, DNS Rebinding & Private IP Containment.
- **`PC-WEB-003`**: Weather & Public Bulletin Retrieval Integration.
- **`PC-WEB-004`**: Untrusted External Content Sanitizer & Source Provenance Formatter.

### Stream: `PC-CLOUD` — Optional Cloud Fallback
- **`PC-CLOUD-001`**: Cloud Provider Abstraction (OpenAI / Anthropic / OpenRouter adapters).
- **`PC-CLOUD-002`**: Device-Local Cloud API Key Storage & Per-Profile Routing Policy (`LOCAL_ONLY`, `LOCAL_FIRST`).
- **`PC-CLOUD-003`**: Egress Transparency Indicator & Background Cloud Disable Guard.
- **`PC-CLOUD-004`**: Cloud Usage Quotas & Cost Tracking Estimator.

### Stream: `PC-RESILIENCE` — Backup, Restore & Reset
- **`PC-RESILIENCE-001`**: Coordinated Database & Profile-Asset Backup Snapshotter (Checksummed archive).
- **`PC-RESILIENCE-002`**: Pre-Migration Automatic Safety Snapshot Hook.
- **`PC-RESILIENCE-003`**: Staged Restore Verification & Referential Integrity Preflight.
- **`PC-RESILIENCE-004`**: Local Admin Factory Reset Engine (Wipes Account/Profile data; models/backups default keep).

### Stream: `PC-RESOURCE` — Resource Governance & Gaming
- **`PC-RESOURCE-001`**: Host Resource Policy Controller (Normal / Low Impact / Auto).
- **`PC-RESOURCE-002`**: Option B Configured Game & Heavy App Detection with Cooldown Hysteresis.
- **`PC-RESOURCE-003`**: Background Work Deferral & Durable Queue Throttling.
- **`PC-RESOURCE-004`**: Low-Impact Lightweight Model Substitution (1B–3B text LLM swap with state preservation).

### Stream: `PC-VERIFY` — Verification & Golden Gate
- **`PC-VERIFY-001`**: CI Pipeline Update (Always-running `ci-gate` failure aggregator, scoped PR/push matrix).
- **`PC-VERIFY-002`**: Flutter Windows Desktop Automated Test Suite Integration.
- **`PC-VERIFY-003`**: Multi-Profile Privacy Adversarial Test Suite.
- **`PC-VERIFY-004`**: D9 Security & Permission Policy Exhaustive Test Matrix.
- **`PC-VERIFY-005`**: Integrated 14-Group Golden PC V1 Acceptance Harness & Verification Guide.
