# AI Companion — PC V1 Work Breakdown Structure (WBS)

> **Document Role:** Canonical granular work breakdown structure cataloging stable work IDs across all PC V1 implementation streams.
> **Status:** Active Canonical Planning Baseline
> **Batching Principle:** Use the largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost. Do not enforce arbitrary LOC or file quotas.
> **Mobile Companion Reference:** This WBS tracks PC V1 work streams (`DOC`, `PC-*`). For Mobile V1 companion implementation work streams (`MOB-FOUNDATION` through `MOB-VERIFY`), consult [`MOBILE_WBS.md`](./MOBILE_WBS.md).

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
- **`PC-CLIENT-005`**: Multi-Profile Navigation & Local Admin Switcher UI (Navigation Rail `ProfileSelectorHeader`, Settings `ProfileAccessCard`, Create & Rename Profile dialogs, Sign out, and persistent selection across restarts; Batch C implemented and verified on `feature/m2-profile-admin-c`; PIN / Windows Hello deferred).
- **`PC-CLIENT-006`**: Conversation View, Multimodal Attachment Composer, Episode Digest / Compact Context Controls & 1-Click Message Bookmarking (M3 Batch F added Episode Digest badge/dialog, responsive Compact Context button, and per-bubble memory/knowledge bookmark menu on `feature/m3-context-compaction-memory-f`).
- **`PC-CLIENT-007`**: Character Studio & Personality Trait Editor (Immersive 2D showcase stage, 8 continuous sliders, presets, Illustrative Style Summary, sequential Save & Activate, chat dual-indicator visibility; implemented and independently approved for provisional closure on `feature/m3-character-studio-personality-b`, not yet merged into develop).
- **`PC-CLIENT-008`**: Schedule, Reminder, Alarm & Routine Management View (Delivered in M3 Batch G2 on `feature/m3-schedule-ui-windows-toasts-g2`: Option 2A 5-section `ScheduleScreen`, `ScheduleSidebar`, `ScheduleEditDialogs`, Tasks Trash/Restore, Routines `[ Run Now ]`, `NotificationBacklogDrawer`, top utility strip & urgent alert banner, and Settings `QuietHoursSettingsCard`).
- **`PC-CLIENT-009`**: Memory Inspection, Correction & Deletion Control Center (Delivered via PR #37 `64ac521`, extended with Option 2A 3-tier inner sub-menu UI in M3 Batch E via PR #39 `ea4441c`, and updated with safe Short-Term `clear_expires_at` Promote contract in M3 Batch F on `feature/m3-context-compaction-memory-f`).
- **`PC-CLIENT-010`**: Model Management UI (D6 manual scan trigger, bundle install confirmation, VRAM metrics).
- **`PC-CLIENT-011`**: Settings, Remote Access & Backup/Reset UI.
- **`PC-CLIENT-012`**: Windows Native Notification Presentation (Delivered in M3 Batch G2 on `feature/m3-schedule-ui-windows-toasts-g2` via native C++/WRL WinRT `WindowsToastChannel` + `WindowsWinRtToastAdapter`, resolving `DEBT-V1-02` with interactive Action Center callbacks and history sync).

### Stream: `PC-HOST` — Windows Host Infrastructure
- **`PC-HOST-001`**: Local AI Runtime Process Supervision, Launch & Single-Instance Attach Coordinator (Kernel locking, detached rotating logging, double-checked recheck, safe failure behavior without client shutdown authority).
- **`PC-HOST-002`**: Windows Task Scheduler Dual Autostart at User Login (Starts Local AI Runtime & Flutter Desktop minimized to tray; intentional-exit restart suppression).
- **`PC-HOST-003`**: Runtime Notification-Event & Durable Backlog Responsibility (`NotificationEvent` ORM, Migration `015`, `/api/v1/notifications*` REST endpoints, `companion_api` Dart SDK, and `ProfilePurgeService` cascade delivered in M3 Batch G1 via PR #41 `fe1526e`; Flutter WinRT Toast presentation client half delivered in M3 Batch G2 on `feature/m3-schedule-ui-windows-toasts-g2`).
- **`PC-HOST-004`**: Storage Roots Manager (Resolves `APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`).
- **`PC-HOST-005`**: Host Administration Separation & Secure Lifecycle Authority (Dedicated local host admin control, loopback-only authenticated `POST /api/v1/system/shutdown`, graceful runtime termination, provider lock ownership & router cleanup, handle-bound Windows OS process fallback, tray & settings "Exit Companion" with confirmed warning, and bounded 4-state model-loading reliability; implemented and verified on `feature/m2-secure-host-lifecycle`).
- **`PC-HOST-006`**: Self-Contained Windows Installer & Bundled Runtime (Provisional deferred PC V1 packaging: bundle private Python execution environment, dependencies, Flutter Desktop, and native inference binaries without manual Python installation or global PATH changes; three distinct and identifiable supervised components transparently visible in Windows Task Manager for crash isolation and diagnostic accountability: `AI Companion.exe` UI, `AI Companion Runtime.exe` Python host, `AI Companion Inference.exe` llama.cpp engine; no console windows in normal use, no intentional concealment from Task Manager; preserve DATA_ROOT and LIBRARY_ROOT across updates, safe install/update/repair/uninstall; packaging technology and distribution format OPEN DESIGN; not implemented in M2-H1).

### Stream: `PC-API` — Client ↔ Runtime Contracts
- **`PC-API-001`**: OpenAPI Schema 3.1 Hardening & Route Contract Regeneration.
- **`PC-API-002`**: Typed Server-Sent Events (SSE) Protocol (Normalized event envelope for tokens, lifecycle, actions).
- **`PC-API-003`**: Duplex WebSocket Protocol for Audio Streaming & Session Coordination.
- **`PC-API-004`**: Durable FIFO Conversation Work Queues (Turn submission, disconnect survival, execution status).
- **`PC-API-005`**: Structured Error Codes & Diagnostic Correlation IDs.

### Stream: `PC-IDENTITY` — Multi-Profile & Accounts
- **`PC-IDENTITY-001`**: Account & Multi-Profile Database Schema Migration (`owner_id` → `profile_id` transition; delivered via PR #25, commit `369d787`).
- **`PC-IDENTITY-002`**: Strict Profile Authorization Context Middleware & Isolation Enforcement (Delivered via PR #27, commit `5cb2fe6`, stabilized in PR #28, commit `0bb0894`).
- **`PC-IDENTITY-003`**: Satellite Device Enrollment & Single-Profile Binding (Individually revocable credentials).
- **`PC-IDENTITY-004`**: Local PC Admin Profile Management Service (Host Admin `POST /api/v1/profiles` create, `PATCH /api/v1/profiles/{profile_id}` in-place rename, persistent selection preference, and acquire-before-teardown switching; delivered via PR #33, commit `2104d5c`; PIN protection deferred).
- **`PC-IDENTITY-005`**: Recoverable Profile Deletion (30-day window) & Safe 5-Phase Permanent Purge Maintenance (Soft-delete with 30-day holding window, immediate session revocation, administrative restore preserving prior content deletions, 5-phase safe physical-first purge pipeline, startup and hourly background maintenance sweeps, and Desktop confirmation UI; delivered in M2 Batch D on `feature/m2-profile-deletion-recovery-d`).

### Stream: `PC-MODEL` — Model Library & D6 Import
- **`PC-MODEL-001`**: Model Library Storage Derivation (`LIBRARY_ROOT/models/llm`, relocatable path support).
- **`PC-MODEL-002`**: D6 Manual Scan & Inbox Discovery Service (No automatic watcher).
- **`PC-MODEL-003`**: GGUF Binary Header Metadata & Modality Capability Detection.
- **`PC-MODEL-004`**: Multi-File Bundle Staging & Atomic Installation (Model + `mmproj` pairing).
- **`PC-MODEL-005`**: Installed Model Registry Schema v3 Storage & Updating (`library/registry/models.json`).
- **`PC-MODEL-006`**: Single-Resident Model Lifecycle Policy & Advanced Multi-Model Warning Guard.

### Stream: `PC-CHAR` — Character, Personality & Mood
- **`PC-CHAR-001`**: Character Template (App-Owned) & Character Instance (Profile-Owned) Storage Schema (Delivered via PR #29, commit `d22dd7e`).
- **`PC-CHAR-002`**: 8 Continuous Personality Traits Scoring & Prompt Modulator (Deterministic 5-band modulation, Autonomy Guard, <= 700 char bound, context budgeting; delivered via PR #30, commit `319ab66`, with natural companion conversational grounding and DRY/stream anti-repetition safeguards added in M3 Batch D on `feature/m3-emotion-mood-engine-d`).
- **`PC-CHAR-003`**: Persistent Bounded Emotion & Mood Engine (Alembic Migration 012, SQLite `ck_character_instances_mood_invariants`, restart persistence, deterministic integer step rebalancing toward trait-derived baseline over elapsed time; implemented and verified in M3 Batch D on `feature/m3-emotion-mood-engine-d`).
- **`PC-CHAR-004`**: Appraisal Engine & Typed Emotion Events (`<1ms` lexical/heuristic pre-generation turn appraisal across 6 bounded mood states, strict Decision D11 Mood Isolation ensuring mood cannot alter system correctness; implemented and verified in M3 Batch D on `feature/m3-emotion-mood-engine-d`).
- **`PC-CHAR-005`**: Immutable Neutral Assistant Fallback Definition (Delivered via PR #29, commit `d22dd7e`).

### Stream: `PC-MEM` — Memory & Continuity
- **`PC-MEM-001`**: Profile & Character Scoped Memory Schema Extension (Delivered via PR #35 `b3d31d7`; extended with `trigger_keywords`, `recall_count`, and 3-tier helpers via Migration 013 in M3 Batch E via PR #39 `ea4441c`; extended with `conversation_summaries` Migration 014 for rolling episode compaction in M3 Batch F on `feature/m3-context-compaction-memory-f`).
- **`PC-MEM-002`**: Selective Automatic Memory Extraction Pipeline (Delivered via PR #36 `f7de198` & PR #37 `64ac521`; strengthened with explicit `"Remember that..."` priority boost, Fixed Knowledge write-protection, and cross-session promotion in M3 Batch E via PR #39 `ea4441c`; enhanced with emotion-weighted `+0.3` importance scoring, bounded `(previously: ... until YYYY-MM)` temporal evolution trail, and Batch E extraction/reconciler hardening in M3 Batch F on `feature/m3-context-compaction-memory-f`).
- **`PC-MEM-003`**: Temporary Memory Lifecycle, Expiration Tracking & Natural Revalidation (Delivered via PR #35 `b3d31d7`; extended with deterministic 72h situational TTL and 1-click UI promotion in M3 Batch E via PR #39 `ea4441c`; hardened with explicit `MemoryUpdate.clear_expires_at` promote semantics in M3 Batch F on `feature/m3-context-compaction-memory-f`).
- **`PC-MEM-004`**: User Inspection, Correction, Deletion & Tombstone Propagation (Delivered via PR #37 `64ac521`; updated with Option 2A 3-tier inner sub-menu UI in M3 Batch E via PR #39 `ea4441c`; extended with 1-click chat bubble memory/knowledge bookmarking in M3 Batch F on `feature/m3-context-compaction-memory-f`).
- **`PC-MEM-005`**: Bounded Conversation History Recall & Context Assembly (Delivered via PR #35 `b3d31d7`; upgraded with stem/prefix lorebook matching, FTS5 prefix ranking + `recall_count`, and 4-section XML context assembly in M3 Batch E via PR #39 `ea4441c`; extended with pre-limit conversation compaction, rolling `<recent_episode_digest>` XML injection with delimiter escaping, `GET /summary` & `POST /compact`, and retrieval query hardening in M3 Batch F on `feature/m3-context-compaction-memory-f`).

### Stream: `PC-ACTION` — D9 Typed Action Engine *(M4 Batch A Delivered on `feature/m4-d9-tools-and-web-a`)*
- **`PC-ACTION-001`**: 5-Stage Deterministic Pipeline Implementation ($\text{Model} \rightarrow \text{Typed} \rightarrow \text{Policy} \rightarrow \text{Adapter} \rightarrow \text{Capability}$) — Delivered in M4 Batch A (`backend/app/services/tools/registry.py`, `executor.py`, bounded orchestrator loop).
- **`PC-ACTION-002`**: DEFAULT DENY Policy Matrix Engine (Risk 0/1/2 evaluation, Profile permission rules, Quiet Hours check, `EXTERNAL_CONTENT` deny) — Delivered in M4 Batch A (`backend/app/services/tools/policy.py`).
- **`PC-ACTION-003`**: Explicit Confirmation Token & Parameter Fingerprint Binding (`ToolConfirmation`, 120s TTL, atomic single-winner CAS claim, unambiguous conversational confirmation) — Delivered in M4 Batch A.
- **`PC-ACTION-004`**: Emergency Action Controls (Stop Generation + persistent Global Tool Kill Switch with Host-Admin-only unlock across top bar, tray, and Settings) — Delivered in M4 Batch A.
- **`PC-ACTION-005`**: Structured Audit Logging with Sensitive Data Redaction (`tool_audit_logs`, Migration `017`, `ProfilePurgeService` cascade) — Delivered in M4 Batch A.
- **`PC-ACTION-006`**: Generic Shell / OS Admin Execution Blocker & Rejection Guard (`PROHIBITED_RISK3_CATEGORIES`) — Enforced & verified in M4 Batch A.

### Stream: `PC-SCHED` — Productivity & Routines
- **`PC-SCHED-001`**: Runtime `SchedulerService` Engine (Timezone aware with zero-dependency `resolve_timezone()` Windows fallback, persistent SQLite state, FastAPI `lifespan` background tick, `DEBT-V1-08` expired memory sweep; backend runtime delivered in M3 Batch G1 on `feature/m3-scheduler-notifications-g1`).
- **`PC-SCHED-002`**: Distinct Task, Standalone/Task-Associated Reminder & Alarm Lifecycles (ORM models, Migration `015`, UUIDv4 + REST CRUD, snooze/acknowledge/dismiss, recurring weekday alarm re-arm, `[ Mark Done ]` & soft-delete Task synchronization, and `companion_api` Dart SDK delivered in M3 Batch G1 on `feature/m3-scheduler-notifications-g1`; Desktop Schedule UI deferred to Batch G2).
- **`PC-SCHED-003`**: Quiet Hours Policy Engine (Half-open `[start, end)` window across same-day and overnight spans, per-Profile settings on `/api/v1/profiles/me/quiet-hours`, Alarms bypass default, Reminders/Routines respect default; backend delivered in M3 Batch G1 on `feature/m3-scheduler-notifications-g1`).
- **`PC-SCHED-004`**: Missed Event Reconciliation & Late Alarm Grace Window Evaluation (`reconcile_missed_events` startup catch-up, bounded grace window evaluation, and durable `missed_catchup` backlog notifications delivered in M3 Batch G1 on `feature/m3-scheduler-notifications-g1`).
- **`PC-SCHED-005`**: Bounded Companion Routines Engine (Deterministic `fallback_message` trigger with zero LLM delay and manual `/run` endpoint delivered in M3 Batch G1 on `feature/m3-scheduler-notifications-g1`; Risk 2 D9 conversational creation remains Milestone M4).

### Stream: `PC-VOICE` — Conversational Voice Pipeline *(M4 Batch B Delivered on `feature/m4-voice-pipeline-b`)*
- **`PC-VOICE-001`**: Flutter Native Audio Capture & Playback Hardware Controller *(Remaining for M4 Batch C alongside Option A Chat/Settings/Studio Voice UI)*.
- **`PC-VOICE-002`**: Local STT Provider Adapter (`WhisperCppSttProvider` running windowless localhost `whisper-server.exe -ng` with truthful unavailable reporting) — Delivered in M4 Batch B (`backend/app/services/voice/stt.py`).
- **`PC-VOICE-003`**: Local TTS Provider Adapter (`KokoroOnnxTtsProvider` + `WindowsSapiTtsProvider` fallback & `CharacterInstance.voice_id` resolution) — Delivered in M4 Batch B (`backend/app/services/voice/tts.py`, Migration `018`).
- **`PC-VOICE-004`**: Mandatory Voice Barge-In State Machine (`BargeInGate`, `SileroOnnxVadProvider`/`AdaptiveEnergyVadProvider`, stale `turn_id` discard in `VoiceSessionClient`) — Delivered in M4 Batch B (`backend/app/services/voice/vad.py`, `voice_session_client.dart`).
- **`PC-VOICE-005`**: Duplex Voice Session Orchestrator & Turn Identity Coordination over WebSocket (`VoiceSessionOrchestrator`, `WS /api/v1/voice/ws` without `Depends(get_db)`, D9 tool policy parity, shared `_get_lock(conversation_id)` concurrency guard, & Profile revoke/purge WS termination) — Delivered in M4 Batch B.

### Stream: `PC-WEB` — Read-Only Web Current Info *(M4 Batch A Delivered on `feature/m4-d9-tools-and-web-a`)*
- **`PC-WEB-001`**: Provider-Independent `WebSearch` Adapter with Privacy Minimization (`public_search` default, Host-Admin SearXNG / optional ACL-protected Tavily & Brave) — Delivered in M4 Batch A.
- **`PC-WEB-002`**: Outbound `WebFetch` Pipeline with Strict SSRF, DNS Rebinding, Private/CGNAT/IPv6-Mapped IP Containment & TLS SNI IP-Pinning — Delivered in M4 Batch A (`backend/app/services/web/ssrf_guard.py`).
- **`PC-WEB-003`**: Weather & Public Bulletin Retrieval Integration (zero-key Open-Meteo default adapter) — Delivered in M4 Batch A (`backend/app/services/web/providers.py`).
- **`PC-WEB-004`**: Untrusted External Content Sanitizer (`<untrusted_web_content>`) & Normalized `WebSourceRefOut` Source Provenance UI — Delivered in M4 Batch A.

### Stream: `PC-CLOUD` — Optional Cloud Fallback
- **`PC-CLOUD-001`**: Cloud Provider Abstraction (provider-agnostic CloudProvider abstraction).
- **`PC-CLOUD-002`**: Device-Local Cloud API Key Storage & Per-Profile Routing Policy (`LOCAL_ONLY`, `LOCAL_FIRST`).
- **`PC-CLOUD-003`**: Egress Transparency Indicator & Background Cloud Disable Guard.
- **`PC-CLOUD-004`**: Cloud Usage Quotas & Cost Tracking Estimator.

### Stream: `PC-RESILIENCE` — Backup, Restore & Reset
- **`PC-RESILIENCE-001`**: Coordinated Database & Profile-Asset Backup Snapshotter (Checksummed archive).
- **`PC-RESILIENCE-002`**: Pre-Migration Automatic Safety Snapshot Hook (Delivered & verified in Batch A via `prepare_database_schema` and `app.db.backup`).
- **`PC-RESILIENCE-003`**: Staged Restore Verification & Referential Integrity Preflight (Standalone verified utility delivered; automatic/live recovery pending host-level writer quiescence).
- **`PC-RESILIENCE-004`**: Local Admin Factory Reset Engine (Wipes Account/Profile data; models/backups default keep).

### Stream: `PC-RESOURCE` — Resource Governance & Gaming
- **`PC-RESOURCE-001`**: Host Resource Policy Controller (Normal / Low Impact / Auto).
- **`PC-RESOURCE-002`**: Option B Configured Game & Heavy App Detection with Cooldown Hysteresis.
- **`PC-RESOURCE-003`**: Background Work Deferral & Durable Queue Throttling.
- **`PC-RESOURCE-004`**: Low-Impact Lightweight Model Substitution (compatible lightweight local text model substitution. 1B-3B is an example/reference range only).

### Stream: `PC-VERIFY` — Verification & Golden Gate
- **`PC-VERIFY-001`**: CI Pipeline Update (Always-running `ci-gate` failure aggregator, scoped PR/push matrix).
- **`PC-VERIFY-002`**: Flutter Windows Desktop Automated Test Suite Integration.
- **`PC-VERIFY-003`**: Multi-Profile Privacy Adversarial Test Suite.
- **`PC-VERIFY-004`**: D9 Security & Permission Policy Exhaustive Test Matrix.
- **`PC-VERIFY-005`**: Integrated 14-Group Golden PC V1 Acceptance Harness & Verification Guide.
