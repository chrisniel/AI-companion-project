# AI Agent Working Rules

Template Component: Docs_ProjectWorkflowStarterKit_v2.0

These rules establish the operational baseline and boundaries for AI-assisted engineering across the AI Companion project. Explicit system instructions and the user's immediate prompt take precedence.

For comprehensive procedural details on delivery gates, pull requests, walkthrough authoring, and commit workflows, consult [`docs/06_Guides/DELIVERY_WORKFLOW.md`](docs/06_Guides/DELIVERY_WORKFLOW.md).

---

## Project Profile

- **Project Name:** AI Companion Project
- **Shared Milestone Task:** [`docs/01_Tracking/task.md`](docs/01_Tracking/task.md)
- **Active Branch Task Directory:** [`docs/01_Tracking/active/`](docs/01_Tracking/active/)
- **Task Archive:** [`docs/01_Tracking/archive/`](docs/01_Tracking/archive/)
- **Implementation Plan Directory:** [`docs/02_Planning/01_Plans/`](docs/02_Planning/01_Plans/)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/`](docs/02_Planning/00_Master/)
- **Walkthrough Folder:** [`docs/03_Walkthroughs/`](docs/03_Walkthroughs/)
- **Changelog File:** [`CHANGELOG.md`](CHANGELOG.md)
- **Documentation Map:** [`docs/06_Guides/DOCUMENTATION_MAP.md`](docs/06_Guides/DOCUMENTATION_MAP.md)
- **Canonical Architecture Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](docs/04_Architecture/SYSTEM_BASELINE.md)
- **Primary Tech Stack:**
  - **Local AI Runtime:** Python 3.11, FastAPI, SQLAlchemy 2, Alembic, SQLite/FTS5, `llama.cpp`.
  - **PC V1 Client Target:** Flutter Desktop (Windows), Dart.
  - **Supported Web Client & Dev Harness:** React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4 (`frontend/web/`).
  - **Mobile Companion Prototype:** Kotlin, Jetpack Compose (`android/`, V1 follow-on).
- **Execution Mode:** Read-only by default; inspect and report unless the user explicitly authorizes specific file edits or command execution.
- **Git Authority:** Strictly read-only for AI agents. Chris alone executes all Git mutations (`add`, `commit`, `push`, `branch`, `merge`, `rebase`, `stash`, `tag`, `PR`).
- **Protected Boundaries:** Never expose secrets; preserve uncommitted user work; do not alter Git/LFS configurations, remotes, external services, or dependencies without an approved task-specific plan. `SYSTEM_BASELINE.md` and canonical domain architecture own normative truth.

---

## 1. Documentation Hierarchy & Numbering Scheme

Documentation must adhere to the zero-padded two-digit numbering scheme under `docs/`:
- `docs/00_Drafts/` (Scratchpads and unreviewed notes; strictly ignored by default)
- `docs/01_Tracking/` (Shared `task.md`, active branch execution in `active/`, historical delivery in `archive/`)
- `docs/02_Planning/` (Master Spine in `00_Master/`, active plans in `01_Plans/`, templates in `02_Templates/`, archives in `03_Archive/`)
- `docs/03_Walkthroughs/` (Delivery walkthroughs; ignored during normal startup context)
- `docs/04_Architecture/` (System Baseline, ADRs in `decisions/`, and 18 focused domain specifications)
- `docs/05_Design/` (Product UI/UX, visual language, and interaction specs)
- `docs/06_Guides/` (Contributor guides, setup instructions, delivery workflow, testing standards)
- `docs/07_Archive/` (Superseded legacy drafts, old audits, and historical plans; strictly ignored)

*Permanent Exception:* `docs/ProjectWorkflowStarterKit/` is a user-owned permanent starter reference. Do not move, rewrite, or delete it.

---

## 2. Context Ignore Boundaries & Token Preservation

- `docs/00_Drafts/` is strictly ignored by default. Never scan or load files here without explicit user prompt.
- `docs/07_Archive/` and `docs/01_Tracking/archive/` are strictly ignored unless an explicit retrospective is requested.
- `docs/03_Walkthroughs/` records point-in-time delivery evidence and is ignored during normal startup.
- `CHANGELOG.md` is append-only. Never read the full history; read only the top 15 lines when matching entry format.
- Canonical domain specs in `docs/04_Architecture/` and design specs in `docs/05_Design/` are consulted on-demand when relevant to the active task.

---

## 3. Canonical Startup Routing

When starting a session or resuming work, AI agents must route context through the following entry-point sequence:

```text
AGENTS.md
  │
  ▼
docs/06_Guides/DOCUMENTATION_MAP.md
  │
  ▼
docs/04_Architecture/SYSTEM_BASELINE.md
  │
  ▼
docs/02_Planning/00_Master/DELIVERY_INDEX.md
  │  (Consulted when milestone sequencing, WBS ID, or backlog status matters)
  ▼
Relevant Focused Domain Specification & Accepted ADR(s)
  │  (Load only the specific domain relevant to the active task)
  ▼
On develop/master:
docs/01_Tracking/task.md
  │  (Verify shared milestone goals and integration state)
  ▼
On an ordinary short-lived task branch:
docs/01_Tracking/active/task-[branch-slug].md
  │  (Verify transient branch execution state)
  ▼
Relevant Active Implementation Plan (in docs/02_Planning/01_Plans/)
```

---

## 4. Engineering Delivery Lifecycle & Quality Gates

All non-trivial implementation must pass through the 7-stage delivery lifecycle defined in [`docs/06_Guides/DELIVERY_WORKFLOW.md`](docs/06_Guides/DELIVERY_WORKFLOW.md):
```text
PLAN → IMPLEMENT → IMPLEMENTATION GATE → DOCUMENT → DOCUMENTATION GATE → CLOSURE → CLOSURE GATE
```

- **Implementation Gate:** Inspect code, tests, schema contracts, and migrations before claiming completion. Implementation intent is never documentation evidence.
- **Documentation Gate (No Self-Verification):** An agent authoring or materially editing canonical documentation **MUST NOT** self-certify it as complete. The agent stops after mechanical verification and presents the diff for independent review.
- **Closure Gate:** Final task closure occurs only after independent human approval. Active `task.md` must accurately reflect verified delivery.
- **Subsystem Batching:** Scope tasks to the largest tightly related batch that preserves reliable first-pass accuracy and reviewability. Avoid microscopic over-ceremony for trivial fixes.

---

## 5. SHARED MILESTONE VS BRANCH TRACKING

- **Shared `task.md`:** Tracks milestone/integration direction. Does not track every temporary branch heartbeat. Should avoid volatile "PR pending", "current HEAD", and temporary branch-state wording.
- **Branch active task:** Tracks plan execution, implementation, verification, documentation, independent review, closure, blockers, and relevant evidence.
- **One coherent delivery branch owns:**
  `PLAN → IMPLEMENT → IMPLEMENTATION GATE → DOCUMENT → DOCUMENTATION GATE → CLOSURE → CLOSURE GATE`
  Do not create new branches merely because the delivery moves between those stages.

## 5.1 SAME-BRANCH CLOSURE & POST-MERGE RECONCILIATION

- Planning, implementation, verification, review fixes, documentation, and closure normally stay on the same short-lived branch.
- Before PR/merge, reconcile branch-owned tracking so the delivery does not knowingly land with stale execution state.
- Archive/remove the branch active task on that same branch when closure is verified.
- Do not create a follow-up branch merely to replace: pending, uncommitted, current HEAD, awaiting review, PR pending, merge pending, or similar transient wording.
- Historical records preserve point-in-time truth. Use labels such as "implementation checkpoint", "reviewed revision", or "publication checkpoint" rather than claiming a SHA is eternally current.

## 5.2 POST-MERGE INTEGRATION & CI EVIDENCE

- After merge, perform read-only integration verification. Verify develop contains the expected squash/integration.
- Do NOT create a cleanup branch solely to add a merge SHA, post-merge CI result, or replace harmless historical pending-at-the-time wording.
- Only create a corrective delivery if current canonical/master planning is materially false, dependent work is blocked, or a real integration defect exists.
- **CI is evidence, not shared task state.** Record separately: local verification, PR/candidate CI, post-merge/integration CI, Golden release verification.
- Never infer one from another. A delivery may truthfully record "PR-head CI PASSED, Post-merge CI NOT VERIFIED" without reopening the delivery solely to update that historical fact.

## 6. Single Source of Truth & Stable Tense

- **Implemented Reality:** Source code, automated tests, and generated contracts are authoritative for what actually exists. Never invent reality from documentation.
- **Stable Canonical Tense:**
  - Verified past work in **past tense** (*"implemented"*, *"added"*).
  - Durable architecture and policies in **present tense** (*"owns"*, *"enforces"*).
  - Target/future capabilities in **target wording** (*"target design"*, *"will support"*).
- **Reference Integrity:** Link to canonical owners instead of duplicating content across documents.

---

## 7. Surgical Changes & Verification Rigor

- Touch only files and lines necessary for the approved task.
- Preserve existing working code, tests, docstrings, and comments.
- **Never claim tests passed without confirmation:** Run actual non-destructive verification commands and report exact output. Clearly separate automated results from pending manual/hardware checks.

---

## 8. Privacy, Secrets & Data Integrity

- Never expose, log, or commit API keys, tokens, passwords, credentials, or private user data.
- Use environment variables and documented placeholders for configuration.
- The model must never receive unrestricted shell, database, device, or network authority.
- Sensitive tools require deterministic policy validation, user confirmation, and auditable logging.

---

## 9. Git Authority & External Boundaries

- **Chris Owns Git Writes:** Do NOT execute `git add`, `commit`, `push`, `branch`, `merge`, `checkout`, `switch`, `tag`, `stash`, `reset`, `restore`, or PR commands.
- **Git Mutation Clarification:** `git checkout <ref> -- <path>` and `git restore ...` are Git mutations and MUST NOT be used by agents. Historical content must be read using `git show` and written through normal file editing only.
- **Git Branch Preflight:** Before non-trivial edits, inspect the current Git branch (`git branch --show-current`). If on `develop` or `master`, STOP before editing. Recommend an appropriate task branch, ask Chris to create/switch/push it, and resume only after Chris confirms. Agents still perform no Git mutations.
- **Stop After Verification:** Provide a clean Conventional Commit message proposal and stop for human execution.
- **Read-Only External Environment:** Treat system paths, external repositories, and package caches outside the workspace as strictly read-only.
- **Model Storage Policy:** Git repository and LFS pointers reside on GitHub; private Hugging Face dataset stores LFS model binaries. Do not alter Git/LFS configurations without explicit authorization.
