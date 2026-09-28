# AI Agent Working Rules

Template Component: Docs_ProjectWorkflowStarterKit_v2.0

These rules are a reusable baseline for AI-assisted work across software, game, and web projects, whether working solo or in a team of 2 to 5 developers. Explicit system instructions and the user's immediate prompt take precedence.

Configure project-specific paths and boundaries in the Project Profile below. If a path is marked Not used, skip that workflow without creating substitute files.

---

## Project Profile — Configure Per Project

- Project Name: AI Companion Project
- Active Task File: docs/01_Tracking/task.md
- Task Archive Directory: docs/01_Tracking/archive/
- Implementation Plan Directory: docs/02_Planning/
- Walkthrough Folder: docs/03_Walkthroughs/
- Changelog File: CHANGELOG.md
- Documentation Map: docs/06_Guides/DOCUMENTATION_MAP.md
- Canonical Architecture Document: docs/04_Architecture/SYSTEM_BASELINE.md
- Historical Reference Plan (Non-Authoritative): docs/07_Archive/reference/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
- Primary Tech Stack: React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4; Kotlin, Jetpack Compose for Android; Python, FastAPI, SQLAlchemy 2, Alembic, SQLite/FTS5; llama.cpp / ONNX Runtime
- Execution Mode: Read-only by default; inspect and report unless the user explicitly authorizes the specific edit or other state-changing action
- Major Change Commit Policy: Every completed major change must be committed as one coherent user-owned Git commit; the AI supplies a proposed commit message, while the user manually reviews, commits, and pushes
- Manual Verification Areas: Responsive desktop UI, themes and accessibility, Windows runtime behavior, RX 580 model benchmarks, microphone/Bluetooth audio, Android physical-device behavior, alarms, Health Connect, and remote authentication
- Protected Boundaries: Preserve uncommitted user work; never expose secrets; do not alter Git/LFS policy, external services, dependencies, remotes, or source code without an approved task-specific plan. SYSTEM_BASELINE.md, ROADMAP.md, and domain architecture own canonical technical truth.

---

## 1. Strict Numbered Documentation Hierarchy

- When a documentation directory (`docs/`) is maintained, all subdirectories must follow strict two-digit zero-padded numbering:
  - `docs/00_Drafts/` (Raw ideas, scratchpads, unreviewed notes)
  - `docs/01_Tracking/` (Active task.md and archive/ directory)
  - `docs/02_Planning/` (Feature-named implementation plans, TDDs, acceptance criteria)
  - `docs/03_Walkthroughs/` (Delivery walkthroughs, developer handovers)
  - `docs/04_Architecture/` (System contracts, API schemas, core technical specs)
  - `docs/05_Design/` (Product/Game design docs, wireframes, UI/UX, narrative)
  - `docs/06_Guides/` (Contributor onboarding, setup steps, testing standards)
  - `docs/07_Archive/` (Superseded drafts, old audits, deprecated documentation)
- Never create unnumbered directories or loose documentation files at the root of `docs/`.
- `docs/ProjectWorkflowStarterKit/` is a permanent user-owned starter reference and is exempt from the numbered layout. Do not move, rewrite, or delete it unless the user explicitly requests that exact change.

## 2. Context Ignore Boundaries & Token Preservation

- `docs/00_Drafts/` is strictly ignored by default: Never read, scan, or load files in `docs/00_Drafts/` into context unless the user explicitly prompts to inspect a specific draft.
- `docs/07_Archive/` and the `docs/01_Tracking/archive/` directory are strictly ignored: Never load historical archives into context unless explicitly asked to perform a retrospective.
- `docs/03_Walkthroughs/` is historical evidence and ignored during normal startup context: Walkthroughs record point-in-time delivery evidence and should only be consulted for regression investigation, delivery provenance, historical implementation reasoning, or explicit retrospective requests. The reusable walkthrough template may be consulted when authoring a new walkthrough.
- `CHANGELOG.md` is append-only: Never read the full changelog history into context. Read only the top 15 lines if needed to match entry formatting.
- Technical specs in `docs/04_Architecture/` and design specs in `docs/05_Design/` remain accessible on demand when relevant to the active task.
- If `.aiignore`, `.cursorignore`, or `.clineignore` is missing, the agent is authorized to create one with standard token-preservation ignore rules.

## 3. Delivery Gate Workflow & Feature Planning

- **Delivery Gate Lifecycle:** For non-trivial implementation work, strictly adhere to the explicit delivery lifecycle:
  ```text
  PLAN → IMPLEMENT → IMPLEMENTATION GATE → DOCUMENT → DOCUMENTATION GATE → CLOSURE → CLOSURE GATE
  ```
- **Proportionality & Trivial Fixes:** Already-approved trivial or surgical fixes do not require performative re-planning; use engineering judgment proportional to risk, uncertainty, and scope. Implementation intent is never documentation evidence.
- **Task Granularity & Subsystem Batching Principle:** Do not enforce an arbitrary numerical slice limit. Scope tasks and documentation passes to:
  > *"The largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost."*
  Prefer cohesive subsystem batches over microscopic ceremony. Reduce batch size when correction cycles or cross-domain ambiguity increase.
- **Documentation Timing Boundary:** Implementation may update narrowly coupled technical artifacts required for correctness during code changes (e.g., generated OpenAPI contracts, migration notes, prerequisite ADRs, inline docstrings, comments, minimum synchronized technical artifacts required to keep the repository truthful). However, broad canonical feature documentation and delivery closure must follow implementation verification, not precede it as substitute evidence.
- **Feature-Named Planning:** For non-trivial features, refactors, or bug fixes, provide step-by-step logic in plain pseudocode for user review before writing code. To prevent team merge conflicts, name implementation plans after the specific feature or fix (e.g., `docs/02_Planning/plan-[feature-name].md`) rather than writing to a single shared document.
- **Update In-Place:** During the planning phase, update existing sections (affected files, acceptance criteria, steps) directly in place. Never prepend duplicate plans or drafts above existing content.
- **Approval Gate:** Obtain explicit user approval on the plan before implementing code.
- **Token Hygiene:** Once the plan is approved, switch execution tracking entirely to the active task file. Do not re-read the implementation plan on subsequent coding turns unless revising architecture or explicitly directed.
- **New Plan Creation:** If no active implementation plan already covers a non-trivial feature, refactor, or bug fix, copy `docs/02_Planning/templates/implementation-plan-template.md` (or the Starter Kit equivalent when bootstrapping a new project) into an appropriately feature-named path under `docs/02_Planning/` or the relevant phase directory, complete it in place, and obtain user approval before implementation. If an applicable active plan already exists, update that plan instead of creating a duplicate.

## 4. In-Place Task Continuity & Per-File Archiving (task.md)

- Read the active task file before resuming work to verify current goals, blockers, and next actions.
- Update In-Place: Check off items, edit line items, and maintain the CURRENT EXECUTION STATE block in place. Never prepend new task blocks, duplicate headings, or status overviews above existing uncompleted tasks.
- Active Sprint Only: The active task file must contain only current work and immediate blockers (target: under 80 lines).
- Per-File Archiving: When a feature or sprint is verified and completed, move its completed checklist into a new dedicated archive file: `docs/01_Tracking/archive/task-[YYYY-MM-DD]-[feature-name].md`. Never accumulate completed checklists in the active `task.md`, and never append to a single monolithic archive file.

## 5. Team Concurrency & Feature Branch Isolation

- Multi-Developer Concurrency: When working concurrently across a team, active tasks must be maintained on dedicated feature branches (e.g., `feature/[feature-name]`).
- Each feature branch owns its active `task.md`. When a feature is completed and merged to main via pull request, its verified tasks are archived into `docs/01_Tracking/archive/`, leaving the `task.md` on main clean for the next sprint.
- User-Owned Git Operations: Chris performs all Git branch and checkout operations manually. The AI agent may suggest branch names and checkout commands for task isolation, but must never execute branch creation, deletion, or switching commands autonomously.

## 6. Append-Only Changelog (CHANGELOG.md)

- For completed code or behavior deliveries, append a single concise, dated entry to the top of `CHANGELOG.md` under `## [Unreleased]`.
- Document user-visible behavior changes, modified architecture, and verification status.
- Preserve historical changelog entries; do not rewrite them.

## 7. Educational Walkthroughs & Handoffs

- When walkthroughs are required, write them into `docs/03_Walkthroughs/` upon delivery.
- Follow the official template structure in `docs/03_Walkthroughs/walkthrough-template.md` (and `docs/ProjectWorkflowStarterKit/walkthrough-template.md`) with the 7 required sections:
  1. What Was Delivered
  2. Files Changed
  3. How the Logic Works (Event trigger, Validation, Core processing, Completion, Recovery/cancellation)
  4. Key Concepts (Define at least three relevant programming, architectural, or domain concepts in accessible language)
  5. Verification Steps (Automated checks, Manual/User-owned checks)
  6. Safe Customization & Invariants (Tunable parameters, Invariants)
  7. Troubleshooting (Symptom, Likely cause, Resolution)
- Explain the core logic flow sequentially without dumping full source files.
- Include exact repository paths, safe customization points, and verified test results.

## 8. Single Source of Truth & Documentation Alignment

- **Startup Context Routing:** Canonical entry-point sequence: Start with [AGENTS.md](AGENTS.md) -> [DOCUMENTATION_MAP.md](docs/06_Guides/DOCUMENTATION_MAP.md) -> [SYSTEM_BASELINE.md](docs/04_Architecture/SYSTEM_BASELINE.md) -> [ROADMAP.md](docs/02_Planning/ROADMAP.md) (only when sequencing / release scope / milestone ownership matters) -> relevant focused canonical domain specification / accepted ADR -> active [task.md](docs/01_Tracking/task.md) -> relevant ACTIVE implementation plan. Drafts, archives, walkthroughs, and legacy monoliths are NOT default startup authority.
- **Canonical Ownership:** Exactly one canonical owner per normative fact or domain. Other documents link to the canonical owner instead of independently redefining or duplicating the rule. Subordinate legacy documents remain historical or technical references only.
- **Stable Canonical Tense:**
  - Delivered, verified work must be documented in **past tense**;
  - Durable architecture, invariants, and policies must be documented in **present tense**;
  - Genuine target, future, or planned capabilities must be documented in **target/future wording**;
  - Temporary PR, review, check, or merge statuses belong in GitHub/tracker metadata, **not** in permanent architecture prose.
- **Implemented Reality:** Source code, automated test suites, and generated schema contracts remain authoritative for implemented reality. Implementation reality must never be inferred or invented from documentation intent.
- **Context Discipline:** Historical walkthroughs, archives, completed tasks, drafts, and the historical Master Implementation Plan are NOT normal startup context. Do not require loading every domain architecture document; load only the specific domain relevant to the task.
- **Gated Documentation Synchronization:** When verified implementation changes require canonical documentation updates, update the closest canonical owner during the DOCUMENT stage after the Implementation Gate and before closure. Narrow generated contracts, migration artifacts, prerequisite ADRs, comments, or minimum synchronized technical artifacts required to keep the repository truthful may be updated during implementation. Implementation intent is never documentation evidence.
- **Reference Integrity:** Prefer linking or referring to canonical documents over duplicating content across multiple markdown files.
- **Draft Status:** Treat drafts, legacy notes, and attached documents as reference material unless explicitly approved as current requirements.

## 9. Surgical & Minimal Changes

- Touch only the files and lines necessary for the approved task.
- Preserve unrelated user edits and existing working behavior.
- Do not refactor functioning code, rewrite serializers, or introduce new dependencies without explicit task justification.
- Adhere strictly to project-specific performance constraints (e.g., zero-allocation per-frame loops, memory budgets, strict typing).

## 10. Truthful Verification & Safety Boundaries

- **Implementation Gate:** Before canonical delivery documentation claims implemented behavior, explicitly inspect actual source code, automated tests, generated schema contracts, database migrations where applicable, and verified runtime/CI evidence where relevant. A plan or specification stating that something should exist is not proof that it exists.
- **Documentation Gate / No Self-Verification:** An agent that authors or materially edits canonical documentation **MUST NOT** mark that same documentation `COMPLETE / VERIFIED` without independent review. The authoring agent stops after its own mechanical verification and supplies the exact diff and evidence for independent human review. Tracker closure occurs only in a subsequent pass after independent approval.
- **Closure Gate & Tracker Integrity:** Final task closure (`CLOSURE`) occurs only after independent Documentation Gate approval. An agent performing substantive implementation or canonical documentation must not self-verify final closure. The Closure Gate independently verifies:
  - Active tracker (`task.md`) state accurately reflects independently verified implementation and documentation;
  - Delivered scope matches approved requirements with zero unverified claims;
  - Unresolved blockers, manual verification areas, or hardware checks are truthfully surfaced;
  - Preserved next-work states and prerequisites remain intact;
  - Required Git, PR, or CI evidence is confirmed where applicable.
  Only after the Closure Gate passes may a slice or sprint be treated as `COMPLETE / VERIFIED` and archived where appropriate. (Proportionality applies: trivial or surgical fixes do not require heavyweight ceremony).
- **Execution Truthfulness:** The AI agent may author test fixtures, run non-destructive automated checks, and provide manual checklists.
- **Never Claim Tests Passed Without Confirmation:** Never simulate engine execution, fabricate test results, or mark user-assigned checks as passed without explicit confirmation.
- **Verification Separation:** Clearly separate automated script/command results from pending manual or hardware-dependent user checks.
- **Reproducibility:** Provide step-by-step reproduction and verification steps for all visual, physical, or experiential checks.

## 11. Clarify Material Unknowns

- If missing information impacts security, architecture, performance, data integrity, or costs, ask before proceeding.
- When risk is low, proceed with clearly labeled non-blocking assumptions and record them in the active task file.

## 12. Privacy, Secrets & Data Integrity

- Never expose, log, or commit passwords, tokens, private API keys, credentials, or personal data.
- Always use documented environment variables and placeholder names for sensitive configurations.
- Do not give an LLM unrestricted shell, filesystem, database, device, or network authority in the product architecture.
- Sensitive tools require backend validation, authorization, and auditable execution.

## 13. Git & External Boundary Protections

- **User-Owned Git Authority:** Chris alone performs all Git write operations. Do NOT execute `git add`, `git commit`, `git push`, `git merge`, `git rebase`, `git branch`, `git checkout`, `git switch`, `git tag`, `git stash`, `git reset`, `git restore`, pull request creation, or pull request merge. The AI agent may inspect Git state, inspect diffs/history/checks, suggest branch names, suggest commands, and supply proposed Conventional Commit messages.
- **Stop After Verification:** Stop after mechanical verification and provide the user with a concise Conventional Commit-style message describing the delivered scope. The user manually reviews, commits, and pushes.
- **PR & Merge Handoff Protocol:** When preparing or reviewing Pull Requests and merges, adhere to this durable handoff protocol (the agent inspects and guides, Chris performs the actions):
  - **Before PR Creation:** Verify exact base branch; verify exact head branch and pushed HEAD SHA; verify delivered scope matches the approved task; verify all required local/CI checks pass; provide an exact, reviewable PR title and structured description.
  - **After PR Opens:** Inspect and verify the exact pushed head SHA and the reported status of all CI/status checks on the PR.
  - **Before Squash / Merge:** Verify mergeability, absence of merge conflicts, and that all required status checks have succeeded; provide the exact squash commit title and commit body.
  - **After Merge:** Verify the merged commit SHA on the target branch (e.g., `develop` or `master`); verify expected post-merge workflow execution and status.
  Agents do not create or merge the PR.
- **Read-Only External Environment:** Treat external repositories, package caches, and system paths outside the workspace as strictly read-only.
- **Destructive Action Safety:** Resolve exact target paths before executing any file deletion or overwrite.
- **Model Storage Policy:** The accepted model-storage policy keeps Git source and LFS pointers on GitHub while the private Hugging Face dataset stores LFS objects. Do not change `.gitattributes`, `.lfsconfig`, model tracking, either remote, or that policy without explicit authorization.
