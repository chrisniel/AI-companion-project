# AI Companion — Engineering Delivery Workflow & Contributor Guide

> **Document Role:** Canonical engineering delivery process guide, quality gate definitions, Git interaction protocols, and verification standards for all human contributors and AI implementation agents.  
> **Status:** Active Canonical  
> **Authority Precedence:** Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md). Active planning resides in [`docs/02_Planning/00_Master/`](../02_Planning/00_Master/). Operational agent rules are anchored in [`AGENTS.md`](../../AGENTS.md).

---

## 1. Overview & Core Philosophy

The AI Companion project balances rapid local iteration with strict architectural integrity, reproducible testing, and truthful delivery tracking. 

Key working principles:
- **Test-Driven & Evidence-Based:** No production code without failing tests first; no completion claim without passing test evidence.
- **Human-Owned Version Control:** Chris retains exclusive authority over all Git write operations and repository mutation.
- **Strict Separation of Concerns:** Implemented reality (source code/tests) is never confused with target architecture (canonical specifications) or delivery roadmaps.
- **No Self-Verification:** Agents authoring code or canonical documentation must stop after mechanical verification and submit diffs for independent human/reviewer gate approval.

---

## 2. The Unified Engineering Delivery Lifecycle & Quality Gates

For all non-trivial implementation, refactoring, or bug fixes, contributors and AI implementation agents (Gemini, Codex, etc.) must follow the unified delivery lifecycle:

```text
PLAN
  │
  ▼
PLAN APPROVAL
  │
  ▼
IMPLEMENTATION
  │
  ▼
RISK-BASED INDEPENDENT IMPLEMENTATION REVIEW
  │
  ▼
DOCUMENTATION + PROVISIONAL CLOSURE
  │
  ▼
DRAFT PR
  │
  ▼
COMBINED INDEPENDENT DOCUMENTATION/CLOSURE/PR REVIEW
  │
  ▼
FINAL PRE-MERGE CLOSURE RECONCILIATION
  │
  ▼
HUMAN SQUASH MERGE
  │
  ▼
READ-ONLY POST-MERGE VERIFICATION
```

### Stage 1: PLAN
- **Action:** Formulate the implementation strategy before touching product code.
- **Plan File:** Create a feature-named plan under [`docs/02_Planning/01_Plans/plan-[feature-name].md`](../02_Planning/01_Plans/README.md) using the standard template in [`docs/02_Planning/02_Templates/implementation-plan-template.md`](../02_Planning/02_Templates/implementation-plan-template.md).
- **Contents:** Affected files, acceptance criteria, step-by-step implementation phases, error-handling paths, test strategies, and manual verification steps.

### Stage 2: PLAN APPROVAL
- **Action:** Independent evaluation of the proposed plan.
- **Gate:** Explicit human (Chris) approval must be secured before implementation begins. Unapproved plans must not be implemented.

### Stage 3: IMPLEMENTATION
- **Action:** Execute the approved plan using Test-Driven Development (Red-Green-Refactor).
- **Discipline:**
  - Write a focused failing test demonstrating desired behavior (RED).
  - Verify failure for the expected architectural reason.
  - Implement minimal code to pass (GREEN).
  - Clean up duplication and structure while maintaining all green tests (REFACTOR).
- **Surgical Changes:** Modify only lines and files required for the approved scope. Preserve unrelated working behavior and user code.

### Stage 4: RISK-BASED INDEPENDENT IMPLEMENTATION REVIEW
- **Action:** Mechanical and architectural verification of code before documentation begins.
- **Review Scope:** Review effort scales with change risk. High-risk, architectural, database schema, migration, or security-sensitive changes retain a dedicated independent implementation review.
- **Checks:**
  - Automated test suites pass cleanly with zero ignored regressions.
  - Linters and static analysis report zero errors.
  - Generated API contracts (`contracts/openapi/openapi.json`) and database migrations match code reality.
- **Gate:** Independent architectural evaluation (Chris and independent reviewer) evaluates implementation quality and issues an explicit gate verdict (APPROVED or CHANGES REQUIRED). The authoring agent must not self-approve this gate.

### Stage 5: DOCUMENTATION + PROVISIONAL CLOSURE
- **Action:** Synchronize canonical technical documentation and prepare delivery tracking in a single coordinated pass once implementation is approved.
- **Rules:**
  - Update the closest canonical owner document (e.g. focused domain spec under `docs/04_Architecture/`).
  - Do not create substitute documentation files or loose notes.
  - Author a technical walkthrough under `docs/03_Walkthroughs/` using the established 7-section template.
  - Append an entry to [`CHANGELOG.md`](../../CHANGELOG.md) under `## [Unreleased]`.
  - Update or create the branch active task tracker (`docs/01_Tracking/active/task-[branch-slug].md`) recording provisional closure:
    - Implementation completed and independently approved.
    - Documentation prepared and verified mechanically.
    - Verification evidence recorded.
    - Final combined documentation and closure gate awaiting independent evaluation.
- **Principle (No Self-Verification):** The authoring agent **MUST NOT** mark the documentation or closure gate as passed.

### Stage 6: DRAFT PR
- **Action:** Under explicit task-bounded human authorization, commit scoped documentation and tracking updates, HTTPS-push to the remote branch, and open a draft pull request targeting `develop`.
- **Requirements:**
  - The PR must be created as **draft** (`gh pr create --draft`), clearly indicating it is awaiting combined independent review.
  - Inspect and report GitHub CI status and checks.
  - Never merge, rebase, or force-push.

### Stage 7: COMBINED INDEPENDENT DOCUMENTATION/CLOSURE/PR REVIEW
- **Action:** Independent evaluation of the complete delivery package:
  - Canonical documentation accuracy against committed source code and tests.
  - Walkthrough completeness and clarity.
  - Provisional closure tracking and changelog accuracy.
  - Draft PR diff, target branch (`develop`), and CI status.
- **Gate:** Chris and the independent reviewer evaluate the package and issue approval or request corrections. The authoring agent halts at this boundary.

### Stage 8: FINAL PRE-MERGE CLOSURE RECONCILIATION
- **Action:** Performed on the **SAME** feature branch only after independent review approval and human authorization:
  - Archive the branch active task to `docs/01_Tracking/archive/task-[branch-slug].md`.
  - Reconcile any final tracking details so the branch does not merge with stale or provisional status.
  - Commit and HTTPS-push reconciliation updates to the feature branch.
  - The draft PR updates automatically with the final commit.
  - Supply the final proposed Conventional Commit squash message.

### Stage 9: HUMAN SQUASH MERGE
- **Action:** Exclusive human operation. Chris reviews the final PR diff, verifies passing CI checks, and executes the squash merge into `develop` on GitHub.
- **Invariant:** Agents **NEVER** execute repository merges or modify protected branches.

### Stage 10: READ-ONLY POST-MERGE VERIFICATION
- **Action:** Once merged, a subsequently invoked agent performs read-only verification:
  - Inspect remote `develop` to confirm the PR squash commit landed successfully.
  - Check post-merge / `develop`-push CI status.
  - Report a clear PASS / FAIL / INCOMPLETE integration verdict with traceable commit SHAs.
- **The No-Stale-Documentation Rule:** Do NOT create a follow-up cleanup branch or commit solely to replace a historical branch HEAD with a squash SHA, update a historical PR checkpoint, or alter a historically truthful pending status. Canonical documentation must remain durable and stable across Git lifecycle events.

---

## 3. Task Sizing & Subsystem Batching Principle

To prevent both microscopic over-ceremony and unwieldy, unreviewable pull requests, tasks must be sized according to the **Subsystem Batching Principle**:

> *"Scope tasks and documentation passes to the largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost."*

- **Prefer Cohesive Subsystem Batches:** Group tightly coupled domain changes (e.g., model schema + CRUD endpoint + unit tests) into a single coherent delivery slice.
- **Reduce Batch Size When Risk Rises:** If cross-domain ambiguity, unfamiliar technology, or high correction cycles occur, immediately shrink slice boundaries.
- **Proportionality for Trivial Fixes:** Already-approved surgical fixes (e.g., typo fix, single bug regression) do not require heavyweight RFC planning; use engineering judgment proportional to risk.

---

## 4. Git Ownership & PR Handoff Protocol

### 4.1 Human Git Authority & Agent Boundaries
Chris owns all repository mutations. AI agents operate under a **Strict Read-Only Git Policy by Default**:
- **Default Read-Only:** Git operations default strictly to read-only (`git status`, `git diff`, `git log`, `git show`, `git rev-parse`, `git branch --show-current`, read-only history/inspection).
- **Task-Bounded Authorization:** Agents may commit/push ONLY with explicit, task-bounded human authorization for the active task (e.g. narrow: *"commit these changes"* or bounded: *"commit scoped closure updates and HTTPS-push to the branch"*). Generic skills or procedural templates never constitute Git authorization.
- **Separate PR & Merge Authority:** PR creation, review approvals, and merge operations require separately authorized action by Chris. Agents must not create PRs or execute merges without explicit instruction.
- **Mandatory Gates & No Self-Approval:** Independent Implementation, Documentation, and Closure Gates remain mandatory. Agents never self-certify or claim self-approved quality gates. The delivery destination after passing these gates is **PR-READY**.
- **Git Branch Preflight:** Before non-trivial edits, inspect the current Git branch (`git branch --show-current`). If on `develop` or `master`, STOP before editing. Recommend an appropriate task branch, ask Chris to create/switch/push it (or confirm authorization), and resume only after Chris confirms.
- **Handoff Mechanism:** When verification passes, the agent stops, displays command evidence, and supplies a formatted Conventional Commit and PR summary proposal for Chris to review, commit, and push manually unless specific task-bounded mutation authorization was granted.

### 4.2 Conventional Commit Proposals
All proposed commits must adhere to the Conventional Commits specification:
```text
<type>(<scope>): <short imperative summary>

- <bullet detail 1>
- <bullet detail 2>
- <verification evidence summary>
```
*Valid types:* `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`.

### 4.3 Pull Request & Integration Protocol
When a milestone or major feature batch is ready for upstream integration:
1. **Draft PR Creation:** Under explicit task authorization, the agent pushes verified commits to the feature branch and creates a **draft PR** (`gh pr create --draft`) targeting `develop`. The draft PR clearly states that it is awaiting combined independent documentation/closure review.
2. **Review & CI Verification:** Independent reviewer and human owner evaluate the diff, walkthrough, and CI checks. Any corrections remain on the same branch.
3. **Pre-Merge Reconciliation:** Upon review approval, branch-owned tracking is updated on the same branch to record final closure. The draft PR updates automatically.
4. **Human Squash Merge:** Chris executes the squash merge into `develop` using GitHub's UI or CLI.
5. **Read-Only Post-Merge Verification:** A subsequent agent verifies that the squash commit landed on `develop` and inspects post-merge CI.
6. **No-Stale-Documentation Rule:** Post-merge verification must not trigger cleanup branches or commits solely to update historical SHAs, PR numbers, or CI run counters.

---

## 5. Educational Delivery Walkthroughs

When a deliverable introduces new architectural patterns, complex workflows, or developer handovers, author a walkthrough under `docs/03_Walkthroughs/` following the 7 required sections:

1. **What Was Delivered:** High-level summary of capabilities and user-facing behavior.
2. **Files Changed:** Granular table of modified, added, or deleted files with purpose.
3. **How the Logic Works:** Sequential explanation of the execution pipeline:
   - Event Trigger / Input
   - Validation & Authorization
   - Core Domain Processing
   - Completion & Output State
   - Error Handling & Recovery / Cancellation
4. **Key Concepts:** Plain-language definitions for at least three relevant architectural or technical concepts.
5. **Verification Steps:** Reproducible automated test commands and manual hardware/UI verification steps.
6. **Safe Customization & Invariants:** Tunable parameters, configuration keys, and immutable constraints.
7. **Troubleshooting:** Symptom → Likely Cause → Resolution table.

---

## 6. Documentation Standards & Canonical Tense

- **Single Canonical Owner:** Exactly one canonical specification owns each normative domain or operational policy. Other documents link to the canonical owner rather than duplicating text.
- **Stable Canonical Tense:**
  - **Delivered & Verified Work:** Document in **past tense** (*"implemented"*, *"added"*, *"migrated"*).
  - **Durable Architecture & Policies:** Document in **present tense** (*"operates"*, *"validates"*, *"owns"*).
  - **Planned Capabilities:** Document in **target/future wording** (*"target design"*, *"will support"*, *"planned"*).
  - **No Ephemeral State:** Never embed temporary branch names, volatile test run counts, or in-flight PR numbers into permanent canonical documentation.

### PR & Integration Summary
- **Before PR:** Provisional closure tracking and canonical documentation prepared on feature branch.
- **Draft PR:** Candidate CI and independent combined review evidence.
- **Before Merge:** Final pre-merge reconciliation on same branch; confirm required checks green.
- **After Merge:** Read-only target-branch verification by default. Do not require a dedicated post-merge documentation commit.
