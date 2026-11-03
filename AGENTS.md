# AI Agent Working Rules

Template Component: Docs_ProjectWorkflowStarterKit_v2.0

These rules establish the master repository-wide governance contract and operational baseline for AI-assisted engineering across the AI Companion project.

### Core Governance Hierarchy
1. Host environment and system requirements
2. Repository ROOT `AGENTS.md` (authoritative across the entire repository)
3. Valid scoped/nested repository agent rules, where supported
4. Explicit current-task human authorization and constraints
5. Activated skills / plugins / procedural workflows
6. Default agent behavior

The root `AGENTS.md` is binding on all tasks performed anywhere in this repository unless a more specific valid scoped rule applies. Scoped rules may specialize behavior in their valid scope, but cannot silently weaken repository-wide safety, authority, or scope rules. Skills and plugins are subordinate procedural aids, not independent authorities.

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
- **Git Authority:** Default read-only for AI agents. The Human Owner retains exclusive authority over repository mutations, destructive Git operations, and final merges (`develop` and `master`). For a named delivery scope, the Human Owner may grant the Implementing Agent task-bounded Git permissions on a dedicated feature branch. Skills cannot self-authorize Git mutations.
- **Governance Roles:**
  - **Human Owner:** Authorizes product direction, significant scope, material design decisions, sensitive operations, and final merges.
  - **Implementing Agent:** Any authorized AI coding agent that plans, implements, tests, documents, and prepares a delivery.
  - **Independent Reviewer:** An appropriate reviewer who did not author the implementation under review (another AI agent or human).
  - **CI System:** Executes automated verification and supplies evidence; does not grant implementation or merge approval.
- **Protected Boundaries:** Never expose secrets; preserve uncommitted user work; do not alter Git/LFS configurations, remotes, external services, or dependencies without an approved task-specific plan. `SYSTEM_BASELINE.md` and canonical domain architecture own normative truth.

---

## 1. Documentation Hierarchy & Numbering Scheme

Documentation must adhere to the zero-padded two-digit numbering scheme under `docs/`:
- `docs/00_Drafts/` (Scratchpads and unreviewed notes; strictly ignored by default)
- `docs/01_Tracking/` (Shared `task.md`, active branch execution in `active/`, historical delivery in `archive/`)
- `docs/02_Planning/` (Master Spine in `00_Master/`, active plans in `01_Plans/`, templates in `02_Templates/`, archives in `03_Archive/`)
- `docs/03_Walkthroughs/` (Delivery walkthroughs; ignored during normal startup context)
- `docs/04_Architecture/` (System Baseline, ADRs in `decisions/`, and 20 focused canonical specifications)
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
[OR]

On an ordinary short-lived task branch:
docs/01_Tracking/active/task-[branch-slug].md
  │  (Verify transient branch execution state)
  ▼
  (The shared task.md may be consulted only when integration/milestone state is specifically relevant)
Relevant Active Implementation Plan (in docs/02_Planning/01_Plans/)
```

---

## 4. Four-Phase Engineering Delivery Lifecycle & Quality Gates

All non-trivial implementation across any authorized implementing agent must follow the canonical four-phase delivery lifecycle defined in [`docs/06_Guides/DELIVERY_WORKFLOW.md`](docs/06_Guides/DELIVERY_WORKFLOW.md):

```text
PHASE 1: PLAN AND AUTHORIZATION
  │  (Scope, canonical alignment, risk level, architecture, verification strategy)
  ▼  [Gate: Human Plan Approval for substantial / sensitive design]
PHASE 2: AUTONOMOUS IMPLEMENTATION AND VERIFICATION
  │  (Surgical implementation, tests, static analysis, contract drift, automated fixes)
  ▼  [Prerequisite: All automated checks pass cleanly before Phase 3]
PHASE 3: DOCUMENTATION, CLOSURE, AND DRAFT PR
  │  (Canonical doc sync, tracking, changelog, walkthrough if complex, push, draft PR)
  ▼  [Output: Complete delivery package presented for review]
PHASE 4: COMBINED INDEPENDENT REVIEW AND HUMAN MERGE
  │  (Independent review of diff, docs, tests, and CI; focused corrections on same branch)
  ▼  [Gate: Human Owner squash merge; read-only post-merge verification]
```

### Core Lifecycle Governance Principles
- **Risk-Based Supervision:** Supervised by four portable delivery levels:
  - **Level A — Routine Autonomous:** Low-risk mechanical changes and straightforward implementation under settled requirements. No mandatory separate plan ceremony; verified in one combined final review.
  - **Level B — Planned Autonomous:** Substantial features within established architecture. Requires a written plan and human plan approval, followed by autonomous implementation, verification, documentation, closure, and one combined final review.
  - **Level C — Sensitive Design:** High-impact changes (auth, authorization, Profile isolation, privacy, concurrency, public API, database/schema, material architecture). Requires explicit human approval of the material design before implementation, followed by autonomous execution within that approved boundary and independent final review.
  - **Level D — Human-Controlled Operations:** Production deployments, production migration execution, destructive operations, secrets/signing key modifications, and irreversible external actions. Requires specific human authorization for the exact operation and environment; AI autonomy never overrides these controls.
- **Autonomous Continuation within Scope:** Once the applicable Phase 1 plan gate is satisfied, the Implementing Agent continues automatically through Phase 2 (implementation & verification) and Phase 3 (documentation, closure, and draft PR) within its authorized scope without requiring micro-approvals for each implementation substep or ordinary in-scope bug fixes.
- **Prerequisite Gate Before Documentation:** The Implementing Agent must complete implementation and its required automated verification before beginning canonical documentation and closure preparation.
- **No Mid-Flight Implementation Stop:** Do not introduce a mandatory independent implementation-review stop between implementation and documentation for ordinary authorized deliveries. Escalate only for genuine stop conditions: material scope expansion, unapproved architectural decisions, security conflicts, or unresolvable test failures.
- **No Self-Verification:** Implementing agents **MUST NOT** self-certify their own quality gates. Agents complete mechanical checks and present exact diffs, test evidence, documentation, and CI status to an Independent Reviewer.
- **Agent-Agnostic Git Permissions:** Git write permissions belong to the human-approved delivery scope, not to an AI provider. When authorized for a named delivery, an Implementing Agent may branch, stage, commit, push, create/update draft PRs, and apply in-scope fixes on the feature branch. Direct protected-branch writes, merges, force-pushes, and destructive history changes remain strictly prohibited.
- **Human-Controlled Squash Merge:** The Human Owner exclusively controls and executes the squash merge into `develop`.
- **Single Delivery Branch:** One coherent branch owns the entire delivery lifecycle from Phase 1 through Phase 4 pre-merge reconciliation.
- **Read-Only Post-Merge Verification:** Post-merge verification is read-only by default, confirming that squash integration into `develop` succeeded without modifying repository files. Never equate pre-merge CI with post-merge CI.
- **No-Stale-Documentation Rule:** Never create follow-up cleanup commits solely to replace historical branch HEADs with squash SHAs, update historical PR checkpoints, add CI run numbers, or alter historically accurate pending statuses.
- **Subsystem Batching:** Scope tasks to the largest tightly related batch that preserves reliable first-pass accuracy and reviewability. Avoid microscopic over-ceremony for trivial fixes.

---

## 5. Shared Milestone vs Branch Tracking

- **Shared `task.md`:** Tracks milestone/integration direction. Does not track every temporary branch heartbeat. Should avoid volatile "PR pending", "current HEAD", and temporary branch-state wording.
- **Branch active task:** Tracks plan execution, implementation, verification, documentation, independent review, closure, blockers, and relevant evidence.
- **One coherent delivery branch owns:** The entire delivery lifecycle from Phase 1 through Phase 4 pre-merge review. Do not create new branches merely because delivery moves between workflow phases.

## 5.1 Same-Branch Closure & Post-Merge Reconciliation

- Planning, implementation, verification, review fixes, documentation, draft PR, and pre-merge closure reconciliation stay on the same short-lived branch.
- In Phase 3, reconcile branch-owned tracking so the delivery does not knowingly land with stale execution state.
- Archive the branch active task on that same branch under `docs/01_Tracking/archive/` as part of closure preparation.
- Do not create a follow-up branch merely to replace: pending, uncommitted, current HEAD, awaiting review, PR pending, merge pending, or similar transient wording.
- Historical records preserve point-in-time truth. Use labels such as "implementation checkpoint", "reviewed revision", or "publication checkpoint" rather than claiming a SHA is eternally current.

## 5.2 Post-Merge Integration & CI Evidence

- After merge, perform read-only integration verification. Verify `develop` contains the expected squash commit.
- Do NOT create a cleanup branch solely to add a merge SHA, post-merge CI result, or replace harmless historical pending-at-the-time wording.
- Only create a corrective delivery if current canonical/master planning is materially false, dependent work is blocked, or a real integration defect exists.
- **CI is evidence, not shared task state.** Record separately: local verification, PR/candidate CI, post-merge/integration CI, Golden release verification.
- Never infer one from another. A delivery may truthfully record "PR-head CI PASSED, Post-merge CI NOT VERIFIED" without reopening the delivery solely to update that historical fact.

---

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

- **Default Read-Only for AI Agents:** Git operations default strictly to read-only (`git status`, `git diff`, `git log`, `git show`, `git rev-parse`, `git branch --show-current`, read-only history/inspection). Agents MUST NOT execute `git add`, `commit`, `push`, `branch`, `merge`, `checkout`, `switch` (altering state), `tag`, `stash`, `reset`, `restore`, worktree mutation, or PR commands unless the Human Owner explicitly authorizes specific mutations for the current task.
- **Scope-Based Mutation Authorization:** The Human Owner owns Git writes. For an authorized delivery scope, the Human Owner may grant the Implementing Agent permission to:
  1. Create and switch to the dedicated feature branch from a verified clean baseline.
  2. Stage authorized changes.
  3. Create Conventional Commits.
  4. Push commits to the authorized remote feature branch.
  5. Create or update one draft PR against `develop`.
  6. Perform normal in-scope defect fixes without requesting repeated command-by-command approval.
- **Strictly Prohibited Git Operations:** The following remain strictly prohibited for AI agents without separate explicit authorization:
  - Direct protected-branch writes (`develop`, `master`).
  - Squash merges, rebase merges, or other merges.
  - Force pushes, rebases, resets, or destructive history mutations.
  - Modifying repository security settings, branch protections, or CI workflows outside authorized tasks.
  - Secret, credential, production, or sensitive operational actions.
- **Permissions Non-Transferability:** Git permissions granted for a specific delivery scope never transfer silently to another repository, branch, unrelated task, or external service. Generic skill workflows or templates never constitute Git authorization.
- **Git Mutation Clarification:** `git checkout <ref> -- <path>` and `git restore ...` are Git mutations and MUST NOT be used by agents without authorization. Historical content must be read using `git show` and written through normal file editing only.
- **Git Branch Preflight:** Before non-trivial edits, inspect the current Git branch (`git branch --show-current`). If on `develop` or `master`, STOP before editing. Recommend an appropriate task branch, confirm authorization, and resume only on the authorized branch.
- **Stop After Verification:** In Phase 3 / Phase 4 handoff, provide clean Conventional Commit proposals, PR diff summary, and verification evidence, and stop for independent review.
- **Read-Only External Environment:** Treat system paths, external repositories, and package caches outside the workspace as strictly read-only.
- **Model Storage Policy:** Git repository and LFS pointers reside on GitHub; private Hugging Face dataset stores LFS model binaries. Do not alter Git/LFS configurations without explicit authorization.

---

## 10. Automatic Skills, Plugins & Procedural Governance

Skills and plugins are procedural execution aids, subordinate to this master repository governance contract:

- **Repository Governance Authority:**
  - This root `AGENTS.md` is authoritative repository-wide.
  - If no valid scoped/nested rule applies to the active file or task, this root `AGENTS.md` governs completely.
  - Scoped rules may specialize behaviors within their valid subtree, but must not silently weaken safety, authority, or scope boundaries established here.
  - Activated skills and plugins MUST adapt their workflows to comply with repository rules; generic skill instructions never override repository governance.
- **Git Authority Subordination:**
  - Generic skill instructions (e.g., committing per task, merging branches, creating worktrees, opening PRs) do NOT constitute Git write authorization.
  - When Git writes are unauthorized, skills MUST downgrade Git actions to read-only inspection, proposed branch names, proposed commit messages, and human handoff.
  - Skills may never self-authorize Git mutations.
- **Skill Non-Expansion Principle:**
  - An activated skill cannot broaden task scope beyond the explicit user prompt and authorized path boundaries.
  - Skills must strictly respect task file allowlists, task ignore boundaries, approved/frozen architecture decisions, current workflow phase, and explicit `STOP` boundaries.
  - Procedural advice in skills to "also refactor", "also write a plan", "also normalize docs", or "also finish the branch" does not authorize those actions.
- **Task Mode Adaptation:**
  Repository tasks may declare an operational mode, or one may be inferred from prompt intent. Skills must adapt their behavior accordingly:
  - `AUDIT` / `REVIEW` / `VERIFICATION`: Strictly read-only; no file modifications or system mutations unless explicitly authorized.
  - `CORRECTION`: Surgical repair only; make only changes necessary to resolve and verify the identified defect. Do not broaden into unrelated cleanup, redesign, refactoring, or documentation normalization. Do not automatically brainstorm replacement designs or generate new plan suites.
  - `PLANNING` / `OPEN DESIGN`: Brainstorming and plan authoring are permitted (Phase 1).
  - `IMPLEMENTATION`: Execute the approved design/plan (Phase 2). Do not reopen frozen architecture or ADR decisions without an explicit unresolved defect or human instruction.
  - `DEBUGGING`: Systematically investigate root cause. Escalating from a bug fix to architectural redesign requires explicit human approval if outside current task scope.
  - `DOCUMENTATION`: Update closest canonical owner (Phase 3); do not normalize unrelated files or create loose substitute docs.
  - `CLOSURE`: Perform only closure actions defined by the active workflow/task (Phase 3). Do not automatically begin the next lifecycle stage or merge.
- **Explicit Stop Boundaries:**
  - Directives such as `STOP`, `WAIT`, `PAUSE`, `AWAIT REVIEW`, `DO NOT CONTINUE`, or `DO NOT START NEXT STAGE` strictly terminate automatic skill chaining.
  - Continuous-execution skills (`executing-plans`, etc.) must halt at the declared boundary and present results for human review.
- **Semantic Verification vs. Mechanical Evidence:**
  Skills must distinguish mechanical checks from semantic truth:
  - `file exists` $\neq$ file is canonical authority.
  - `section exists` $\neq$ section owns the requirement.
  - `hyperlink resolves` $\neq$ link points to current normative truth.
  - `test command exits 0` $\neq$ all intended business invariants are satisfied.
  - `command succeeded` $\neq$ intended state mutation actually occurred.
  Completion claims must match the evidence actually gathered; never claim semantic verification based solely on superficial mechanical passes.
- **Scan Boundaries & Context Preservation:**
  - Skills performing broad repository scans (`rg --files`, documentation inventories) must first respect project-declared ignore boundaries (`docs/00_Drafts/`, `docs/07_Archive/`, `docs/01_Tracking/archive/`, historical trackers, generated artifacts).
  - Discoverable historical or scratch material must not be treated as current canonical truth.
- **Independent Gates & No Self-Verification:**
  - Where governance requires an independent gate or human approval (e.g. Plan Gate in Phase 1, Combined Review Gate in Phase 4), implementing agents may run mechanical verification but **MUST NOT** self-certify or self-promote the task past that gate.
  - Implementing agents stop after mechanical checks and submit diffs for independent human/reviewer evaluation.
