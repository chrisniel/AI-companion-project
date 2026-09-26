# Architecture Navigation & Authoring Guide

> **Document Role:** Canonical architecture navigation hub and domain specification authoring standard.
> **Status:** Active Standard (Pass R11.0 Baseline)
> **Authority Precedence:** This document governs how architecture specifications are authored, organized, and navigated. Normative system baseline is anchored in [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md). Active execution state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md). Detailed feature promotion dispositions are recorded in [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../02_Planning/FEATURE_PROMOTION_MAP.md).

---

## 1. Role of Architecture

Architecture in the AI Companion repository is not merely an observational description of currently written code. Instead, architecture owns:

- **Durable Product & Domain Semantics:** What concepts mean, how they relate, and their lifecycles.
- **Data & Ownership Boundaries:** What subsystem owns which records, where mutations are permitted, and how persistence guarantees apply.
- **Security & Trust Boundaries:** Permission models, tool execution confirmation rules, credential boundaries, and privacy protections.
- **Provider & Runtime Boundaries:** Abstractions separating business logic from interchangeable third-party engines, hardware drivers, or hosted endpoints.
- **Persistent-Data Invariants:** Schema guarantees, database migration integrity, encryption requirements, and retention constraints.
- **Approved Target Behavior:** Desired future system behavior formally approved by human review, distinguished from temporary prototype shortcuts.

---

## 2. Authority Model

Documentation in this repository follows a strict hierarchy of authority. Each document category answers a specific question:

| Artifact Category | Primary Question Answered | Canonical Owner / Purpose |
| :--- | :--- | :--- |
| **Source Code, Contracts, & Tests** | *What exists right now?* | Authoritative for implemented reality, runtime behavior, and verified test assertions. |
| **Architecture (`docs/04_Architecture/`)** | *What should be true?* | Authoritative for durable semantics, trust boundaries, persistence invariants, and approved target capabilities. |
| **Design (`docs/05_Design/`)** | *How do people see and interact with it?* | Defines user experience, interface presentation, visual language, and interaction flows. Cross-references Architecture; cannot redefine system authority. |
| **Product Roadmap (`docs/02_Planning/ROADMAP.md`)** | *When should capabilities ship?* | Defines release milestones, platform delivery phasing (e.g., PC V1 vs. Android V1), and sequencing. |
| **Task Tracker (`docs/01_Tracking/task.md`)** | *What is actively being worked on now?* | Tracks current execution state, active sub-slices, and immediate blockers. |
| **Implementation Plans (`docs/02_Planning/`)** | *How will approved work be built?* | Feature-specific technical execution plans, step-by-step logic, and verification criteria. |
| **Walkthroughs (`docs/03_Walkthroughs/`)** | *What was delivered at a point in time?* | Point-in-time delivery records and historical verification evidence. Ignored during normal startup. |
| **Drafts & Archives (`docs/00_Drafts/`, `docs/07_Archive/`)** | *What historical context exists?* | Raw notes, superseded plans, and deprecated ideas. Strictly non-authoritative reference only. |

---

## 3. Staged Architecture Structure & Groups

To preserve modularity and prevent monolithic document drift, architecture specifications are organized into focused functional groups:

```text
docs/04_Architecture/
├── README.md                                          # This navigation hub and authoring standard
├── SYSTEM_BASELINE.md                                 # Canonical cross-cutting system baseline
├── decisions/                                         # Architectural Decision Records (ADRs)
├── 01_Domains/                                        # Focused product & domain semantics
├── 02_Data_and_Security/                              # Profiles, authentication, tool permissions, privacy
├── 03_Integrations/                                   # Web information, health & wearables, external bridges
└── 04_Infrastructure/                                 # Host runtime, models, storage, platform infrastructure
```

### Functional Group Descriptions

1. **`01_Domains/` (Focused Product & Domain Semantics):**
   - **Assistant and conversations:** Turn lifecycle, session context assembly, conversation state, and multilingual interaction ([`01_Domains/assistant-and-conversations.md`](01_Domains/assistant-and-conversations.md)).
   - **Memory and personalization:** Profile-owned persistent memory, selective automatic capture, and retrieval boundaries ([`01_Domains/memory-and-personalization.md`](01_Domains/memory-and-personalization.md)).
   - **Characters / personality / emotion:** Persona lore, behavioral style traits, and lightweight conceptual emotion / companion-state semantics ([`01_Domains/characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md)).
   - **Tasks / reminders / alarms / routines:** Stateful completion lifecycle, independent or task-associated reminders, native scheduling, and routine check-ins ([`01_Domains/tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md)).
   - **Voice and audio:** Provider-independent STT and TTS capabilities, audio buffering, speech turn detection, and conversation cadence ([`01_Domains/voice-and-audio.md`](01_Domains/voice-and-audio.md)).
   - **Multimodal and media:** Message image attachments, multimodal vision understanding, and media metadata ([`01_Domains/multimodal-and-media.md`](01_Domains/multimodal-and-media.md)).
   - **Android Companion:** Connected synchronization protocol, offline LLM execution boundaries, and mobile companion behavior ([`01_Domains/android-companion.md`](01_Domains/android-companion.md)).
2. **`02_Data_and_Security/` (Data & Security Architecture):**
   - **Profiles and devices:** Identity boundaries, device registration, and single-primary-user baseline ([`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md)).
   - **Authentication and secrets:** Credential isolation, token handling, and trusted network boundaries ([`02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md)).
   - **Tool permissions and actions:** Risk tiers, deterministic policy evaluation (`ALLOW` / `CONFIRM` / `DENY`), and elevated action restrictions ([`02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md)).
   - **Privacy / retention / audit:** Data minimization, user consent, audit logging, and deletion policies ([`02_Data_and_Security/privacy-retention-and-audit.md`](02_Data_and_Security/privacy-retention-and-audit.md)).
   *(Boundary note: General memory retrieval, attachment lifecycles, and multimodal storage belong to their respective domain and infrastructure specifications, not to this security/governance group.)*
3. **`03_Integrations/` (External Services & Integrations):**
   - **Read-only Web / current information:** Provider-independent search, page fetch, and weather context ([`03_Integrations/web-current-information.md`](03_Integrations/web-current-information.md)).
   - **Health / wearables:** Biometric context data contracts for PC V1; physical wearable synchronization for Android V1 ([`03_Integrations/health-and-wearables.md`](03_Integrations/health-and-wearables.md)).
   - **Future external / device integrations:** Explicitly evaluated and approved future service connections *(planned)*.
   *(Boundary note: Voice/audio pipelines and the Android Companion are core experience domains owned by `01_Domains/`, not external integrations.)*
4. **`04_Infrastructure/` (Host Runtime, Hardware & Platform):**
   - **Runtime and models:** Local LLM inference via llama.cpp / ONNX, hardware offloading profiles, model management, and optional cloud fallback ([`04_Infrastructure/runtime-and-models.md`](04_Infrastructure/runtime-and-models.md)).
   - **Storage and assets:** Host filesystem paths, application asset storage, and database migration mechanics ([`04_Infrastructure/storage-and-assets.md`](04_Infrastructure/storage-and-assets.md)).
   - **Windows host and notification infrastructure:** Native OS notification delivery, background autostart at login, and host lifecycle ([`04_Infrastructure/windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md)).
   - **Practical backup / recovery:** Database snapshot and asset recovery mechanisms for PC V1 ([`04_Infrastructure/backup-recovery-and-diagnostics.md`](04_Infrastructure/backup-recovery-and-diagnostics.md)). *(Note: A full Diagnostics / Recovery Center is an exploratory recommendation and is NOT an approved PC V1 capability.)*
   - **Performance / capacity:** Resource governance, background throttling, and low-impact gaming modes ([`04_Infrastructure/performance-and-capacity.md`](04_Infrastructure/performance-and-capacity.md)).
5. **`decisions/` (Architectural Decision Records):**
   - Formal records of architecturally significant decisions, context, trade-offs, and consequences.

> [!IMPORTANT]
> Planned directory paths and files do not automatically exist or become canonical until authored, reviewed, verified for semantic coverage, and formally transferred in the staged migration process.

---

## 4. Global Domain Authoring Rules

Every focused domain specification authored under `docs/04_Architecture/` must adhere to these authoring standards:

### 4.1 Four-Tier Truthfulness Separation

Domain documents must clearly separate content across the following sections (or equivalent functional sections):

1. **Purpose / Scope:** What domain problem this document addresses and what boundaries it owns.
2. **Durable Architecture / Invariants:** What is permanently true about the domain regardless of implementation or release milestone.
3. **Current Verified Implementation:** What is currently implemented, merged into baseline, and verified by tests.
4. **Approved Target Architecture / Not Yet Implemented:** Approved capabilities targeted for specific milestones (e.g., PC V1, Android V1) that are not yet built.
5. **OPEN DESIGN:** Approved functional requirements whose exact technical mechanism remains open for investigation or design.
6. **Security / Ownership Boundaries (when relevant):** Explicit trust assumptions, permission levels, and data ownership.
7. **Canonical Relationships / Cross-links:** References to related architecture specifications and ADRs.

### 4.2 Distinguishing Durable Invariants from Implementation Details

Implementation constants must **never** be promoted into permanent architectural invariants. Examples of implementation facts that belong strictly under *Current Verified Implementation*:
- Specific Task enum strings (current repository implementation: `pending`, `in_progress`, `completed`, `cancelled`).
- Default configuration values (e.g., `MEMORY_BUDGET_TOKENS = 256`, idle timeout `900s`).
- Network ports and addresses (e.g., FastAPI on `localhost:8000`, llama.cpp on port `8085`).
- Hardware-specific offload parameters (e.g., RX 580 VRAM offload layers, specific llama.cpp CLI flags).
- Specific provider binaries, package names, or external vendor endpoints.

### 4.3 Task Lifecycle Invariant

In accordance with Decision D10:
- **Durable Invariant:** *"A Task has a stateful completion lifecycle."*
- Tasks have a stateful completion lifecycle. A Reminder may exist independently or be associated with a Task. Schedule associations are not mandatory for all Tasks.
- Exact status strings and state transitions are implementation details subject to schema evolution.

### 4.4 Tool Execution Policy & Resolution (Decision D9)

- Low-risk personal reads, creates, and updates **MAY** auto-execute when deterministic profile/device policy permits.
- Policy evaluates deterministically to one of three outcomes:
  - **`ALLOW`**: Execute automatically without user intervention.
  - **`CONFIRM`**: Require explicit user confirmation before execution.
  - **`DENY`**: Reject tool execution.
- High-risk, destructive, or external actions (e.g., external API mutations, irreversible file deletions, sending communications) retain mandatory explicit user confirmation.
- Domain specifications must **not** state that all low-risk operations unconditionally auto-execute.

### 4.5 Practical Backup vs. Diagnostics Center

- **Practical Backup & Recovery:** Formally `APPROVED / PC V1` (backup database, assets, and restore verification).
- **Diagnostics / Recovery Center:** An exploratory audit recommendation; **NOT** an approved PC V1 capability.
- Future infrastructure documents must maintain strict separation between these items and must not promote a Diagnostics Center to an approved PC V1 capability without explicit human authorization.

### 4.6 Voice Privacy Invariant

- **Durable Invariant:** *"Raw user audio is not persistently retained by default without explicit user consent."*
- Architecture must **not** permanently lock a single specific buffering implementation (e.g., claiming all PCM audio exists strictly in RAM and is immediately destroyed).
- Buffering mechanics, debug audio capture, transcript retention, opt-in recording, and cleanup duration remain implementation details or open design.

---

## 5. Staged Migration Invariant & Authority Transfer Gate

To guarantee continuity, documentation migration follows a staged transfer pattern:

1. **Semantics First (Sub-slices R11.0–R11.3) — `COMPLETE / VERIFIED`:**
   - New focused domain specifications authored, reviewed, corrected, and verified across four target directories:
     - `R11.0 — Architecture Skeleton & Domain Authoring Rules` (`COMPLETE / VERIFIED`)
     - `R11.1 — Core Experience Domains` (`COMPLETE / VERIFIED`):
       - `tasks / reminders / alarms / routines`
       - `characters / personality / emotion`
       - `memory / personalization`
       - `voice / audio`
     - `R11.2 — Integrations, Host Runtime & Client Domains` (`COMPLETE / VERIFIED`):
       - `assistant / conversations`
       - `multimodal / media`
       - `Android Companion`
       - `web / current information`
       - `Windows host / notifications`
     - `R11.3 — Security, Data & Infrastructure Domains` (`COMPLETE / VERIFIED`):
       - `profiles / devices`
       - `authentication / secrets`
       - `tool permissions / actions`
       - `privacy / retention / audit`
       - `health / wearables`
       - `runtime / models`
       - `storage / assets`
       - `backup / recovery`
       - `performance / capacity`
   - During R11.0–R11.3, legacy documents were preserved as authorities while focused specifications were authored and reviewed.
2. **Authority Transfer Applied (Sub-slice R11.4) — `AUTHORITY TRANSFER APPLIED / INDEPENDENT REVIEW PENDING`:**
   - Following explicit human authorization, canonical domain authority was formally transferred to the 18 focused domain specifications.
   - Legacy monolithic documents have been safely narrowed to subordinate compatibility, implementation, and technical reference roles.
   - The top-level ecosystem baseline remains canonically anchored in [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md).
   - Independent review of the R11.4 authority transfer is pending before final R11 closure.

---

## 6. Architecture Catalog & Post-Transfer Routing

Following the Pass R11.4 authority transfer, canonical domain authority resides in the focused domain specifications. Legacy monolithic files remain at their existing paths as subordinate reference material:

| Canonical Focused Owner | Domain Scope | Legacy / Specialized Reference | Legacy Disposition |
| :--- | :--- | :--- | :--- |
| [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) | Shared Ecosystem Baseline | Retained Top-Level Baseline | Retained canonical baseline; owns cross-cutting decisions D1–D11 and release vocabulary. |
| [`01_Domains/assistant-and-conversations.md`](01_Domains/assistant-and-conversations.md) | Turn lifecycle, context assembly, token streaming, multilingual interaction | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) | Subordinate compatibility / scoping reference. |
| [`01_Domains/tasks-reminders-alarms-and-routines.md`](01_Domains/tasks-reminders-alarms-and-routines.md) | Distinct scheduling semantics, quiet hours, best-effort wake, notifications | — | New focused canonical domain specification. |
| [`01_Domains/characters-personality-and-emotion.md`](01_Domains/characters-personality-and-emotion.md) | Persistent Character config, separate Personality traits, lightweight Emotion | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) | Subordinate compatibility / persona reference. |
| [`01_Domains/memory-and-personalization.md`](01_Domains/memory-and-personalization.md) | Profile-first memory persistence/retrieval, FTS5 baseline, selective auto memory | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) | Subordinate compatibility / scoping reference. |
| [`01_Domains/voice-and-audio.md`](01_Domains/voice-and-audio.md) | Provider-independent STT/TTS, voice resource-isolation policy, PC V1 voice | [`VOICE_AND_AUDIO_ARCHITECTURE.md`](VOICE_AND_AUDIO_ARCHITECTURE.md) | Subordinate design & implementation reference; post-V1 voice wording superseded. |
| [`01_Domains/multimodal-and-media.md`](01_Domains/multimodal-and-media.md) | Vision model ingestion, upload security ceilings, attachment lifecycle | — | New focused canonical domain specification (Phase 8B). |
| [`01_Domains/android-companion.md`](01_Domains/android-companion.md) | Android companion identity, connected sync, Keystore credentials, compact offline LLM | [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) | Subordinate technical / benchmark reference; generic post-V1 wording superseded. |
| [`02_Data_and_Security/profiles-and-devices.md`](02_Data_and_Security/profiles-and-devices.md) | User Profile data boundary (`owner_id`), trusted device enrollment, single-user baseline | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | Subordinate security / trust reference. |
| [`02_Data_and_Security/authentication-and-secrets.md`](02_Data_and_Security/authentication-and-secrets.md) | Token verification, credential hierarchy, network boundaries (localhost/LAN/Tailscale) | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | Subordinate security / trust reference. |
| [`02_Data_and_Security/tool-permissions-and-actions.md`](02_Data_and_Security/tool-permissions-and-actions.md) | DEFAULT DENY 4-tier risk matrix, deterministic policy, generic shell rejection | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | Subordinate security / trust reference. |
| [`02_Data_and_Security/privacy-retention-and-audit.md`](02_Data_and_Security/privacy-retention-and-audit.md) | Data retention schedules, soft-delete lifecycles, privacy/retention lifecycles, and auditable action governance | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | Subordinate security / trust reference. |
| [`03_Integrations/web-current-information.md`](03_Integrations/web-current-information.md) | Read-only WebSearch, Fetch, and weather context retrieval; SSRF containment | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | Subordinate security / trust reference. |
| [`03_Integrations/health-and-wearables.md`](03_Integrations/health-and-wearables.md) | PC health-context readiness (PC V1) and Android Health Connect (Android V1) | [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) | Subordinate technical / benchmark reference. |
| [`04_Infrastructure/runtime-and-models.md`](04_Infrastructure/runtime-and-models.md) | Local AI Runtime, model registry/artifact semantics, controlled local import, optional cloud LLM fallback | [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) & [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | Subordinate implementation specialization (`llama.cpp`) & Phase 8P reference. |
| [`04_Infrastructure/storage-and-assets.md`](04_Infrastructure/storage-and-assets.md) | Canonical filesystem hierarchy (`COMPANION_DATA_ROOT`), asset registry, Phase 8P storage | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | Subordinate Phase 8P technical reference. |
| [`04_Infrastructure/windows-host-and-notifications.md`](04_Infrastructure/windows-host-and-notifications.md) | Independent Windows host process, autostart at login, native OS notification delivery | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | Subordinate host integration reference. |
| [`04_Infrastructure/backup-recovery-and-diagnostics.md`](04_Infrastructure/backup-recovery-and-diagnostics.md) | Practical backup/recovery and restore verification, local diagnostic logging | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | Subordinate technical reference. |
| [`04_Infrastructure/performance-and-capacity.md`](04_Infrastructure/performance-and-capacity.md) | Resource governance, performance/capacity policy, Gaming / Low-Impact Mode | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) & [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) | Subordinate technical / benchmark reference. |
| [`decisions/`](decisions/) | Architectural Decision Records (ADRs) | Historical ADRs | Preserved ADR collection. |
