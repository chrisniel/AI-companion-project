# Documentation Authority Model & Repository Navigation Map

> **Document Role:** Canonical entry-point guide for all human contributors and AI agents.  
> **Status:** Active Canonical  
> **Last Updated:** 2026-09-21 (Reconciliation Pass R4)

---

## 1. Where to Start (New Contributors & AI Agents)

New contributors and AI agents must navigate the repository through this explicit entry hierarchy rather than reading historical drafts, superseded plans, or monolithic implementation logs:

```text
AGENTS.md
  │  (Process rules, token boundaries, git constraints)
  ▼
docs/06_Guides/DOCUMENTATION_MAP.md  [YOU ARE HERE]
  │  (Authority model, question-type routing, directory roles)
  ▼
docs/04_Architecture/SYSTEM_BASELINE.md
  │  (Product identity, V1 boundary, host topology, locked D1–D9 decisions)
  ▼
docs/02_Planning/ROADMAP.md (when product sequencing or delivery milestones matter)
  ▼
Domain Architecture / ADRs (as relevant to task)
  │  (docs/04_Architecture/LLAMA_CPP_*, VOICE_*, decisions/ADR-*)
  ▼
docs/01_Tracking/task.md  ──►  docs/02_Planning/plan-*.md
  (Current sprint & state)       (Task-specific implementation plan)
```

The reader does **not** need to consume giant historical master plans, retrospective audits, walkthroughs, or old drafts to understand current system architecture.

---

## 2. Documentation Authority Hierarchy

When seeking the authoritative answer to a question, consult documents in the following order of precedence:

### A. Process & Agent Behavior
1. **`AGENTS.md`** instructions and project profile constraints (Highest)
2. `CONTRIBUTING.md` / repository workflow rules
3. Approved task-specific implementation plan (`docs/02_Planning/plan-[feature].md`)

### B. Implemented Reality
1. **Source code** (`backend/`, `frontend/web/`, `android/`)
2. Generated contracts and schema configuration (`contracts/openapi/openapi.json`, Alembic versions)
3. Automated test suites (`pytest`, `vitest`, Android unit tests)
4. CI and runtime verification evidence

> [!IMPORTANT]
> **Implementation reality must never be invented from documentation.** If documentation describes a feature as working but source code or tests prove it is absent, the source code represents reality.

### C. Normative Architecture & Contracts
1. **Accepted ADRs** (`docs/04_Architecture/decisions/`)
2. **Canonical System Baseline** (`docs/04_Architecture/SYSTEM_BASELINE.md`)
3. Domain technical specifications (`docs/04_Architecture/*.md`)

### D. Product Intent & Scope
1. **Canonical System Baseline** (`docs/04_Architecture/SYSTEM_BASELINE.md` — defines locked V1 boundary)
2. **Canonical Product Roadmap** (`docs/02_Planning/ROADMAP.md` — defines milestone delivery sequence and post-V1 roadmap)
3. Master reference plan (`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` — historical reference candidate for R5 archive)

### E. Current Execution
1. **`docs/01_Tracking/task.md`** (Active sprint, immediate blockers, current state)
2. Active approved implementation plan (`docs/02_Planning/plan-[feature].md`)

### F. Historical Evidence (Non-Normative)
1. Delivery walkthroughs (`docs/03_Walkthroughs/`)
2. Completed and archived sprint tasks (`docs/01_Tracking/archive/`)
3. Archived historical drafts (`docs/07_Archive/`)

### G. Working & Unapproved Ideas (Non-Normative)
1. Scratchpads and brainstorms (`docs/00_Drafts/`) — Strictly ignored by default.

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
| `docs/00_Drafts/` | **Non-Canonical** | Raw ideas, scratchpads, unreviewed notes, forensic audits. | **Strictly ignored** unless explicitly requested by user. |
| `docs/01_Tracking/` | **Canonical (Execution)** | Active `task.md` (target < 80 lines) and per-feature `archive/`. | Active `task.md` read on resume; `archive/` ignored. |
| `docs/02_Planning/` | **Canonical (Planning)** | Canonical `ROADMAP.md`, planning catalog, feature plans (`plan-[feature].md`). | Active plan read during planning; ignored during execution. |
| `docs/03_Walkthroughs/` | **Historical Evidence** | Verified delivery explanations and developer handoffs (7-section format). | Ignored unless investigating PR implementation history. |
| `docs/04_Architecture/` | **Canonical (Normative)** | System baseline, core contracts, API schemas, ADRs (`decisions/`). | Read on demand when relevant to active domain. |
| `docs/05_Design/` | **Canonical (Design)** | Product UI/UX, wireframes, character visual specs, narrative guides. | Read on demand when building frontend/mobile UI. |
| `docs/06_Guides/` | **Canonical (Guides)** | Contributor guides, setup instructions, documentation map, testing standards. | Read on demand for repository process guidance. |
| `docs/07_Archive/` | **Historical Reference** | Superseded drafts, old audits, deprecated documentation. | **Strictly ignored** unless performing a retrospective. |

### Permanent Exception
- `docs/ProjectWorkflowStarterKit/` is a user-owned permanent starter reference and is exempt from the numbered layout. It must never be moved, rewritten, deleted, or loaded into AI agent context.

---

## 5. Documents That Must NOT Be Treated as Authority

The following documents exist for historical, forensic, or template purposes and must **never** be treated as normative product or architectural authority:

1. **`docs/00_Drafts/09-16-2026-roadmap.md`**  
   An old user-authored working draft. It contains historical brainstorms and table status markers, but is non-normative and superseded by `docs/04_Architecture/SYSTEM_BASELINE.md` and `docs/02_Planning/ROADMAP.md`.
2. **`docs/00_Drafts/REPOSITORY_DOCUMENTATION_RECONCILIATION_AUDIT.md`**  
   A forensic reconciliation audit document (Pass R0–R1). It records diagnostic evidence and reconciliation history, but the resulting decisions are codified in `SYSTEM_BASELINE.md`.
3. **`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`**  
   Historical reference master plan. Decomposed in Pass R4 into canonical architecture and `docs/02_Planning/ROADMAP.md`; non-authoritative archival candidate for Pass R5.
4. **Historical Walkthroughs (`docs/03_Walkthroughs/*`)**  
   Walkthroughs are point-in-time snapshots explaining specific past PR deliveries. They do not reflect subsequent refactors or active system architecture.
5. **Archived Task Files (`docs/01_Tracking/archive/*`)**  
   Completed sprint checklists preserved for tracking continuity only.
6. **Starter Reference (`docs/ProjectWorkflowStarterKit/*`)**  
   Reusable workflow templates, not active project documentation.

---

## 6. Canonical Routing Table

When investigating specific questions or subsystems, consult the dedicated canonical document rather than general drafts:

| If your question is... | Consult this Canonical Document | Core Topics Owned |
| :--- | :--- | :--- |
| **"What is the product identity, V1 boundary, or host process model?"** | [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) | Ecosystem subsystems, V1 scope vs. post-V1, Windows host process, D1–D9 matrix. |
| **"What comes next / which milestone owns this feature?"** | [`ROADMAP.md`](../02_Planning/ROADMAP.md) | Canonical delivery sequence, Phase 8B/8C, V1 gates, post-V1 roadmap tracks. |
| **"What is being worked on right now / what are the immediate blockers?"** | [`task.md`](../01_Tracking/task.md) | Active execution state, current sprint checklist, execution invariants. |
| **"How is a specific active feature designed and implemented?"** | Active feature plan in [`docs/02_Planning/`](../02_Planning/README.md) | Detailed feature steps, acceptance criteria, component breakdowns. |
| **"How do I set up the environment and run local services?"** | [`DEVELOPMENT_SETUP.md`](DEVELOPMENT_SETUP.md) | Python/Node/Android prerequisites, FastAPI startup, React Web, llama-server. |
| **"How do I run tests, verify contracts, and check CI?"** | [`TESTING_AND_CI.md`](TESTING_AND_CI.md) | Pytest, Vitest, Android test suites, OpenAPI verification, CI gate governance. |
| **"Where does data live? How do model imports and config work?"** | [`AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) | `COMPANION_DATA_ROOT`, bootstrap locator, D6 import pipeline, database migration safety. |
| **"How does the LLM run? What are the VRAM profiles and router states?"** | [`LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md) | `llama-server.exe` lifecycle, Eco/Balanced/Max profiles, port 8085, RX 580 benchmarks. |
| **"How do auth, device pairing, network trust, and tool permissions work?"** | [`SECURITY_AND_TRUST_ARCHITECTURE.md`](../04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md) | Fail-closed auth, D4 per-device credentials, D5 Tailscale trust, D9 4-tier risk matrix, SSRF. |
| **"Who owns memory and character data? How does scoping work?"** | [`MEMORY_AND_CHARACTER_ARCHITECTURE.md`](../04_Architecture/MEMORY_AND_CHARACTER_ARCHITECTURE.md) | Profile-first memory, `PROFILE` vs `CHARACTER` scopes, SQLite+FTS5, persona boundaries. |
| **"How will Android connected and offline modes work?"** | [`ANDROID_COMPANION_ARCHITECTURE.md`](../04_Architecture/ANDROID_COMPANION_ARCHITECTURE.md) | `com.cnl.aicompanion`, Connected vs Offline Mode, Dimensity 920 inference evidence. |
| **"How will voice and audio processing work?"** | [`VOICE_AND_AUDIO_ARCHITECTURE.md`](../04_Architecture/VOICE_AND_AUDIO_ARCHITECTURE.md) | CPU-first speech execution, `TTSProvider` candidates (Kokoro, Piper, KittenTTS), post-V1. |


