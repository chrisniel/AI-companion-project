# Documentation Authority Model & Repository Navigation Map

> **Document Role:** Canonical entry-point guide for all human contributors and AI agents.
> **Status:** Active Canonical
> **Last Updated:** 2026-09-28 (Reconciliation Pass R13)

---

## 1. Where to Start (New Contributors & AI Agents)

New contributors and AI agents must navigate the repository through this explicit entry hierarchy rather than reading historical drafts, superseded plans, or monolithic implementation logs:

```text
AGENTS.md
  │  (Process rules, token boundaries, delivery gates, user-owned git constraints)
  ▼
docs/06_Guides/DOCUMENTATION_MAP.md  [YOU ARE HERE]
  │  (Authority model, question-type routing, directory roles)
  ▼
docs/04_Architecture/SYSTEM_BASELINE.md
  │  (Product identity, V1 boundary, host topology, locked D1–D11 decisions, Golden Gate)
  ▼
docs/02_Planning/ROADMAP.md
  │  (Consulted only when sequencing / release scope / milestone ownership matters)
  ▼
Relevant Focused Canonical Domain Specification & Accepted ADR(s)
  │  (Load only the domain relevant to active task, e.g., runtime-and-models.md, voice-and-audio.md, tool-permissions-and-actions.md)
  ▼
docs/01_Tracking/task.md
  │  (Active sprint, current state, immediate blockers)
  ▼
Relevant ACTIVE Implementation Plan
  (Located via docs/02_Planning/ index, e.g., in phase-08/ or feature plan)
```

> [!IMPORTANT]
> **Context & Reality Invariants:**
> - **SOURCE / TESTS / GENERATED CONTRACTS** remain authoritative for implemented reality. Implementation reality must never be invented from documentation.
> - **Historical Context Discipline:** Historical walkthroughs (`docs/03_Walkthroughs/`), archives (`docs/07_Archive/`), completed task checklists (`docs/01_Tracking/archive/`), working drafts (`docs/00_Drafts/`), and the historical Master Implementation Plan are **NOT** normal startup context.
> - **Domain Focus:** Do not require an AI agent to load every domain architecture document; load only the specific focused domain specification relevant to the active task.

---

## 2. Documentation Authority Hierarchy

When seeking the authoritative answer to a question, consult documents and artifacts according to this explicit authority model:

| Authority Tier | Artifact / Document | Role & Authority Scope |
| :--- | :--- | :--- |
| **Implemented Reality** | **Source Code, Automated Tests & Generated Contracts** (`backend/`, `frontend/web/`, `android/`, `contracts/openapi/openapi.json`, Alembic migrations) | **Authoritative for what actually exists.** Implementation reality must never be inferred or invented from documentation intent. |
| **System Architecture & Release Boundary** | **Canonical System Baseline** ([`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md)) | **Authoritative for cross-cutting ecosystem architecture, platform release boundaries, locked decisions D1–D11, and the Golden PC V1 Acceptance Gate (§8).** |
| **Normative Domain Architecture** | **Focused Canonical Domain Specifications** ([`docs/04_Architecture/`](../04_Architecture/README.md): `01_Domains/`, `02_Data_and_Security/`, `03_Integrations/`, `04_Infrastructure/`) & **Accepted ADRs** (`docs/04_Architecture/decisions/`) | **Authoritative for domain-specific architecture, data ownership, invariants, security policies, and approved target capabilities.** |
| **UX & Presentation** | **Design Specifications** ([`docs/05_Design/`](../05_Design/README.md)) | **Authoritative for user experience, interface presentation, visual language, and interaction flows.** Cross-references architecture; cannot redefine system authority. |
| **Delivery & Release Sequencing** | **Canonical Product Roadmap** ([`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md)) | **Authoritative for milestone delivery sequence, phase ordering, delivery bands, and post-V1 release tracks.** |
| **Active Execution** | **Active Task File** ([`docs/01_Tracking/task.md`](../01_Tracking/task.md)) | **Authoritative for current execution state, active sub-slices, and immediate blockers.** Target under 80 lines. |
| **Approved Implementation Method** | **Active Implementation Plans** (`docs/02_Planning/plan-[feature].md`, `phase-08/`) | **Authoritative for approved step-by-step logic, technical execution methods, and verification criteria for non-trivial features.** |
| **Historical Evidence (Non-Normative)** | **Walkthroughs, Task Archives & Legacy References** (`docs/03_Walkthroughs/`, `docs/01_Tracking/archive/`, `docs/07_Archive/`, legacy architecture monoliths) | **Point-in-time delivery evidence, archived sprint checklists, and historical context only.** Ignored during normal startup; never normative. |
| **Working Scratchpads (Non-Normative)** | **Drafts** (`docs/00_Drafts/`) | **Unreviewed brainstorms and working notes.** Strictly ignored by default. |

> [!IMPORTANT]
> **Implementation reality must never be invented from documentation.** If documentation describes a feature as working but source code or tests prove it is absent, the source code represents reality.

---

## 3. Conflict Reconciliation Principle

Historical documentation does not override normative architecture. However, when conflicts arise across layers, apply this nuanced rule:

> [!CAUTION]
> If historical evidence, implementation reality, and canonical architecture conflict, **do not blindly declare that "canonical architecture always wins."**
> Such a conflict must trigger an explicit reconciliation step:
> - **Source code** establishes what is *currently implemented*.
> - **Canonical architecture** establishes the *intended normative design*.
> - **Historical evidence** explains *why divergence occurred* (e.g., intermediate refactoring, unmerged branches, temporary bridges).

When divergence is identified, the contributor or agent must report the mismatch and seek approval to reconcile code to architecture or update architecture to match intended changes.

---

## 4. Lifecycle Directories (Strict Numbered Hierarchy)

Per `AGENTS.md`, all documentation directories adhere to a zero-padded two-digit numbering scheme:

| Directory | Canonical Status | Role & Content | AI Default Context Rule |
| :--- | :--- | :--- | :--- |
| `docs/00_Drafts/` | **Non-Canonical** | Raw ideas, scratchpads, unreviewed working notes (forensic audits archived to `docs/07_Archive/audits/`). | **Strictly ignored** unless explicitly requested by user. |
| `docs/01_Tracking/` | **Canonical (Execution)** | Active `task.md` (target < 80 lines) and per-feature `archive/`. | Active `task.md` read on resume; `archive/` ignored. |
| `docs/02_Planning/` | **Canonical (Planning)** | Canonical `ROADMAP.md`, planning catalog, feature plans (in root or nested hubs like `phase-08/`), and post-V1 sources (`post-v1/`). | Active plan read during planning; ignored during execution. |
| `docs/03_Walkthroughs/` | **Historical Evidence** | Verified delivery explanations and developer handoffs (7-section format); indexed in [`README.md`](../03_Walkthroughs/README.md). | Ignored unless investigating PR implementation history. |
| `docs/04_Architecture/` | **Canonical (Normative)** | System baseline, core contracts, API schemas, ADRs (`decisions/`), and 18 focused canonical domain specifications. | Read on demand when relevant to active domain. |
| `docs/05_Design/` | **Canonical (Design)** | Product UI/UX, wireframes, character visual specs, narrative guides. | Read on demand when building frontend/mobile UI. |
| `docs/06_Guides/` | **Canonical (Guides)** | Contributor guides, setup instructions, documentation map, testing standards. | Read on demand for repository process guidance. |
| `docs/07_Archive/` | **Historical Reference** | Superseded drafts, old audits, deprecated documentation. | **Strictly ignored** unless performing a retrospective. |

### Permanent Exception
- `docs/ProjectWorkflowStarterKit/` is a user-owned permanent starter reference and is exempt from the numbered layout. It is ignored by default and protected from modification; it may be inspected only when Chris explicitly asks about the StarterKit.

---

## 5. Documents That Must NOT Be Treated as Authority

The following documents exist for historical, forensic, or template purposes and must **never** be treated as normative product or architectural authority:

1. **`docs/00_Drafts/09-16-2026-roadmap.md`**
   An old user-authored working draft. It contains historical brainstorms and table status markers, but is non-normative and superseded by `docs/04_Architecture/SYSTEM_BASELINE.md` and `docs/02_Planning/ROADMAP.md`.
2. **`docs/07_Archive/audits/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`**
   A forensic reconciliation audit document (Pass R0–R1). It records diagnostic evidence and reconciliation history, but the resulting decisions are codified in `SYSTEM_BASELINE.md`.
3. **`docs/07_Archive/reference/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`**
   Historical reference master plan. Decomposed in Pass R4 into canonical architecture and `docs/02_Planning/ROADMAP.md`; archived in Pass R5 as historical reference material.
4. **Historical Walkthroughs (`docs/03_Walkthroughs/*`)**
   Walkthroughs are point-in-time snapshots explaining specific past PR deliveries. They do not reflect subsequent refactors or active system architecture. See the historical navigation index in [`docs/03_Walkthroughs/README.md`](../03_Walkthroughs/README.md).
5. **Archived Task Files (`docs/01_Tracking/archive/*`)**
   Completed sprint checklists preserved for tracking continuity only.
6. **Starter Reference (`docs/ProjectWorkflowStarterKit/*`)**
   Reusable workflow templates, not active project documentation.
7. **Legacy Monolithic Architecture Specifications (`docs/04_Architecture/*.md`)**
   The six legacy monolithic architecture documents:
   - [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md)
   - [`ANDROID_COMPANION_ARCHITECTURE.md`](../04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md)
   - [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md)
   - [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md)
   - [`SECURITY_AND_TRUST_ARCHITECTURE.md`](../04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md)
   - [`VOICE_AND_AUDIO_ARCHITECTURE.md`](../04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md)
   These documents were formally narrowed in Pass R11.4 to subordinate historical, technical, and implementation reference roles with clear supersession notices. Canonical domain authority resides completely in the 18 focused domain specifications and `SYSTEM_BASELINE.md`. Do not route normal canonical questions to legacy monoliths.

---

## 6. Canonical Routing Table

When investigating specific questions or subsystems, consult the dedicated canonical document rather than general drafts or legacy monoliths:

| If your question is... | Consult this Canonical Document | Core Topics Owned |
| :--- | :--- | :--- |
| **"What is the product identity, V1 boundary, or host process model?"** | [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) | Ecosystem subsystems, V1 scope vs. post-V1, Windows host process, locked D1–D11 decisions. |
| **"What are the mandatory acceptance requirements for the PC V1 release gate?"** | [`SYSTEM_BASELINE.md` §8](../04_Architecture/SYSTEM_BASELINE.md) | Golden PC V1 Acceptance & Release Gate (§8: 17 integrated Golden acceptance checkpoint groups, portability invariants, pass/fail semantics, CI relationship). |
| **"What comes next / which milestone or band owns this feature?"** | [`ROADMAP.md`](../02_Planning/ROADMAP.md) | Canonical delivery sequence, Phase 8B/8C, Foundation/Capability/Resilience bands, post-V1 roadmap tracks. |
| **"What is being worked on right now / what are the immediate blockers?"** | [`task.md`](../01_Tracking/task.md) | Active execution state, current sprint checklist, execution invariants. |
| **"How is a specific active feature designed and implemented?"** | Active feature plan in [`docs/02_Planning/`](../02_Planning/README.md) | Detailed feature steps, acceptance criteria, component breakdowns. |
| **"How do I set up the environment and run local services?"** | [`DEVELOPMENT_SETUP.md`](DEVELOPMENT_SETUP.md) | Python/Node/Android prerequisites, FastAPI startup, React Web, llama-server. |
| **"How do I run tests, verify contracts, and check CI governance?"** | [`TESTING_AND_CI.md`](TESTING_AND_CI.md) | Pytest, Vitest, Android test suites, OpenAPI verification, P25 cost-conscious CI matrix, target ci-gate aggregation. |
| **"How does the LLM run? What are runtime profiles and model import rules?"** | [`04_Infrastructure/runtime-and-models.md`](../04_Architecture/04_Infrastructure/runtime-and-models.md) | Local AI Runtime, model registry/artifact semantics, D6 import pipeline, hardware offload profiles, optional cloud fallback. |
| **"Where does data live? How do storage, assets, and migrations work?"** | [`04_Infrastructure/storage-and-assets.md`](../04_Architecture/04_Infrastructure/storage-and-assets.md) | Persistent storage paths, configuration layering (`COMPANION_DATA_ROOT`), asset boundaries, database migration safety. *(See `runtime-and-models.md` where model artifact lifecycle is relevant).* |
| **"How do auth tokens, credentials, and network trust boundaries work?"** | [`02_Data_and_Security/authentication-and-secrets.md`](../04_Architecture/02_Data_and_Security/authentication-and-secrets.md) | Credential isolation, token handling, localhost / trusted LAN / Tailscale boundaries, rejection of direct port forwarding. |
| **"How do user profiles and trusted device enrollment work?"** | [`02_Data_and_Security/profiles-and-devices.md`](../04_Architecture/02_Data_and_Security/profiles-and-devices.md) | User Profile data boundary (`owner_id`), trusted device enrollment, single-primary-user baseline (D8). |
| **"How do tool permissions, risk tiers, and action policies work?"** | [`02_Data_and_Security/tool-permissions-and-actions.md`](../04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md) | DEFAULT DENY, 5-stage pipeline, 4-tier risk matrix (ALLOW / CONFIRM / DENY), generic shell rejection (D9). |
| **"How do data retention, soft deletion, and privacy auditing work?"** | [`02_Data_and_Security/privacy-retention-and-audit.md`](../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md) | Data retention schedules, soft-delete lifecycles, privacy minimization, and auditable action logging. |
| **"Who owns memory and how does selective automatic memory work?"** | [`01_Domains/memory-and-personalization.md`](../04_Architecture/01_Domains/memory-and-personalization.md) | Profile-first persistent memory, FTS5 lexical search baseline, selective automatic memory capture under D7. |
| **"How do Character lore, Personality traits, and Emotion work?"** | [`01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md) | Persistent Character config, decoupled Personality style traits, lightweight Emotion state (D11). |
| **"How does conversational voice and audio processing work?"** | [`01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md) | Provider-independent STT/TTS, conversation cadence, barge-in cancellation, no wake word in V1. |
| **"How do turn lifecycles, streaming, and multilingual conversations work?"** | [`01_Domains/assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md) | Turn lifecycle, context assembly, token streaming, multilingual interaction (EN/TL/JA/code-switching). |
| **"How do Tasks, Reminders, Alarms, and Routines work?"** | [`01_Domains/tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md) | Distinct scheduling semantics, quiet hours, best-effort wake, native notifications, bounded routines (D10). |
| **"How do image attachments and multimodal vision work?"** | [`01_Domains/multimodal-and-media.md`](../04_Architecture/01_Domains/multimodal-and-media.md) | Message image attachments, validated upload guards, multimodal vision inference, media persistence (Phase 8B). |
| **"How will the Android Companion connected and offline modes work?"** | [`01_Domains/android-companion.md`](../04_Architecture/01_Domains/android-companion.md) | `com.cnl.aicompanion` (D3), Keystore credentials (D4), connected sync, compact roaming offline LLM. |
| **"How do read-only public search, fetch, and weather work?"** | [`03_Integrations/web-current-information.md`](../04_Architecture/03_Integrations/web-current-information.md) | Provider-independent search/fetch/weather, outbound SSRF containment, untrusted data handling, source provenance. |
| **"How do PC health-context readiness and wearable sync work?"** | [`03_Integrations/health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md) | PC health-context readiness (PC V1 data contracts); Android Health Connect wearable sync (Android V1). |
| **"How do Windows autostart and native OS notifications work?"** | [`04_Infrastructure/windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md) | Independent Windows host process, autostart at login (D2), native OS notification delivery (D2/D10). |
| **"How do backup creation, restore verification, and logging work?"** | [`04_Infrastructure/backup-recovery-and-diagnostics.md`](../04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md) | Practical coordinated backup, isolated restore verification, referential integrity; diagnostic logging. |
| **"How do resource throttling and Gaming / Low-Impact mode work?"** | [`04_Infrastructure/performance-and-capacity.md`](../04_Architecture/04_Infrastructure/performance-and-capacity.md) | Resource governance, background throttling, Gaming / Low-Impact mode, telemetry truthfulness. |

---

## 7. Component Quickstarts (Operational Subsystem Orientation)

Component READMEs provide operational quickstarts and local directory orientation. They are operational entry points, **not** normative architecture authorities:

- **Root [`README.md`](../../README.md):** Repository-level orientation, conceptual product topology, and directory roadmap.
- **Backend [`backend/README.md`](../../backend/README.md):** Local AI Runtime FastAPI developer quickstart and local service startup.
- **Frontend [`frontend/web/README.md`](../../frontend/web/README.md):** React Web desktop control center quickstart, build commands, and local dev server.
- **Android [`android/README.md`](../../android/README.md):** Android companion prototype quickstart, Gradle verification, and build targets.
