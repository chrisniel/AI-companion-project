# Architecture Navigation & Authoring Guide

> **Document Role:** Canonical architecture navigation hub and domain specification authoring standard.  
> **Status:** Active Standard (Pass R11.0 Baseline)  
> **Authority Precedence:** This document governs how architecture specifications are authored, organized, and navigated. Normative system baseline is anchored in [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md). Active execution state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md). Detailed feature promotion dispositions are recorded in [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../02_Planning/FEATURE_PROMOTION_MAP.md).

---

## 1. Role of Architecture

Architecture in the AI Companion repository is not merely an observational description of currently written code. Instead, architecture owns:

- **Durable Product & Domain Semantics:** What concepts mean, how they relate, and their life cycles.
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
├── 01_Domains/                                        # Domain models, lifecycles, and business semantics
├── 02_Data_and_Security/                              # Database, persistence, crypto, and security boundaries
├── 03_Integrations/                                   # External services, bridges, and provider abstractions
└── 04_Infrastructure/                                 # Runtime supervisors, inference engines, and recovery
```

### Functional Group Descriptions

1. **`01_Domains/` (Core Experience Domains):**
   - Companion character profile, identity, and system prompt composition.
   - Conversation lifecycle, turns, and context assembly.
   - Long-term memory, episodic storage, and selective recall.
   - Tasks, reminders, and schedule lifecycle.
   - Emotional state, mood dynamics, and non-blocking expressions.
2. **`02_Data_and_Security/` (Data & Security Architecture):**
   - SQLite database schema, Alembic migration invariants, and transaction boundaries.
   - Full-text search and vector retrieval architecture.
   - File attachment storage, deduplication, and lifecycle.
   - Security model, credential isolation, and tool execution policy.
3. **`03_Integrations/` (External Services & Bridges):**
   - Voice and audio pipeline (provider-independent STT, TTS, VAD).
   - Read-only Web Search and weather integration.
   - Android Companion Bridge and cross-device communication protocol.
4. **`04_Infrastructure/` (Host Runtime & Hardware):**
   - Local LLM inference engine (llama.cpp / ONNX) and model management.
   - Process supervision, lifecycle management, and background tasks.
   - Practical Backup & Recovery architecture.
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
- **Diagnostics / Recovery Center:** An exploratory audit recommendation; **NOT** automatically approved for PC V1.
- Future infrastructure documents must maintain strict separation between these items and must not promote a Diagnostics Center to PC V1 without explicit human authorization.

### 4.6 Voice Privacy Invariant

- **Durable Invariant:** *"Raw user audio is not persistently retained by default without explicit user consent."*
- Architecture must **not** permanently lock a single specific buffering implementation (e.g., claiming all PCM audio exists strictly in RAM and is immediately destroyed).
- Buffering mechanics, debug audio capture, transcript retention, opt-in recording, and cleanup duration remain implementation details or open design.

---

## 5. Staged Migration Invariant & Authority Transfer Gate

To guarantee continuity, documentation migration follows a two-step transfer pattern:

1. **Semantics First (Sub-slices R11.0–R11.3):**
   - Author new focused domain specifications under the target directory structure.
   - Maintain existing legacy canonical documents as authoritative until replacements are complete and verified.
   - Do not delete legacy canonical architecture, do not narrow substantive content, and do not declare new documents the sole authority before review.
2. **Authority Transfer Gate (Sub-slice R11.4):**
   - Authority transfer occurs only after explicit human review and authorization following completion of R11.0, R11.1, R11.2, and R11.3.
   - Once authorized, legacy monolithic documents are safely narrowed or retired, transferring canonical authority to the focused specifications.

---

## 6. Architecture Catalog & Legacy Mapping

Until the R11.4 Authority Transfer Gate is reached, the following documents retain primary canonical authority:

| Current Canonical Document | Target Destination Group | Domain Scope |
| :--- | :--- | :--- |
| [`SYSTEM_BASELINE.md`](SYSTEM_BASELINE.md) | Shared Baseline | System baseline, platform vocabulary, Decisions D1–D11. |
| [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](MEMORY_AND_CHARACTER_ARCHITECTURE.md) | `01_Domains/` | Companion personality, memory tiers, and context assembly. |
| [`VOICE_AND_AUDIO_ARCHITECTURE.md`](VOICE_AND_AUDIO_ARCHITECTURE.md) | `03_Integrations/` | STT, TTS, VAD, audio buffering, and voice conversation. |
| [`SECURITY_AND_TRUST_ARCHITECTURE.md`](SECURITY_AND_TRUST_ARCHITECTURE.md) | `02_Data_and_Security/` | Threat model, tool execution policy, and credential isolation. |
| [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | `04_Infrastructure/` | Runtime supervisor, configuration, assets, and storage paths. |
| [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](LLAMA_CPP_RUNTIME_ARCHITECTURE.md) | `04_Infrastructure/` | Local LLM execution, offloading profiles, and model management. |
| [`ANDROID_COMPANION_ARCHITECTURE.md`](ANDROID_COMPANION_ARCHITECTURE.md) | `03_Integrations/` | Android Companion architecture, bridge protocol, and sync. |
| [`decisions/`](decisions/) | `decisions/` | Architectural Decision Records (ADRs). |
