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

## 2. The 7-Stage Delivery Gate Lifecycle

For all non-trivial implementation, refactoring, or bug fixes, contributors and AI agents must follow the explicit delivery lifecycle:

```text
┌────────┐     ┌───────────┐     ┌─────────────────────┐     ┌──────────┐
│  PLAN  │ ──► │ IMPLEMENT │ ──► │ IMPLEMENTATION GATE │ ──► │ DOCUMENT │
└────────┘     └───────────┘     └─────────────────────┘     └──────────┘
                                                                  │
┌──────────────┐     ┌─────────┐     ┌────────────────────┐       │
│ CLOSURE GATE │ ◄── │ CLOSURE │ ◄── │ DOCUMENTATION GATE │ ◄─────┘
└──────────────┘     └─────────┘     └────────────────────┘
```

### Stage 1: PLAN
- **Action:** Formulate the implementation strategy before touching product code.
- **Plan File:** Create a feature-named plan under [`docs/02_Planning/01_Plans/plan-[feature-name].md`](../02_Planning/01_Plans/README.md) using the standard template in [`docs/02_Planning/02_Templates/implementation-plan-template.md`](../02_Planning/02_Templates/implementation-plan-template.md).
- **Contents:** Affected files, acceptance criteria, step-by-step pseudocode, error-handling paths, test strategies, and manual verification steps.
- **Approval Gate:** Explicit human (Chris) approval must be secured before implementation begins.

### Stage 2: IMPLEMENT
- **Action:** Execute the approved plan using Test-Driven Development (Red-Green-Refactor).
- **Discipline:**
  - Write a focused failing test demonstrating desired behavior (RED).
  - Verify failure for expected reason.
  - Implement minimal code to pass (GREEN).
  - Clean up duplication and structure while maintaining all green tests (REFACTOR).
- **Surgical Changes:** Modify only lines and files required for the approved scope. Preserve unrelated working behavior and user code.

### Stage 3: IMPLEMENTATION GATE
- **Action:** Mechanical and functional verification of code.
- **Checks:**
  - Automated test suites pass cleanly with zero ignored regressions.
  - Linters and static analysis report zero errors.
  - Generated API contracts (`contracts/openapi/openapi.json`) and database migrations match code reality.
- **Review:** Independent architectural review (Chris and independent reviewer GPT) evaluates implementation quality before documentation begins.

### Stage 4: DOCUMENT
- **Action:** Synchronize canonical technical documentation to reflect verified changes.
- **Rules:**
  - Update the closest canonical owner document (e.g. focused domain spec under `docs/04_Architecture/`).
  - Do not create substitute documentation files or loose notes.
  - If a delivery walkthrough is required for knowledge transfer, draft it under `docs/03_Walkthroughs/` using the 7-section template.

### Stage 5: DOCUMENTATION GATE (No Self-Verification)
- **Principle:** An authoring agent **MUST NOT** self-certify its own canonical documentation edits as complete or verified.
- **Action:** The agent stops after mechanical verification (valid markdown, working links, accurate code references) and presents the exact diff and rationale for human inspection.
- **Approval:** Chris and reviewer verify that documentation accurately reflects implemented reality without speculative claims.

### Stage 6: CLOSURE
- **Action:** Prepare delivery tracking updates.
- **Tracker Updates:**
  - Mark delivered items complete in the active [`docs/01_Tracking/task.md`](../01_Tracking/task.md).
  - Surface any manual hardware verification steps (audio, physical device, GPU benchmarks) or known non-blocking issues.
  - Append an entry to [`CHANGELOG.md`](../../CHANGELOG.md) under `## [Unreleased]`.

### Stage 7: CLOSURE GATE & ARCHIVING
- **Verification:** Independent check confirming:
  - Tracker state matches independently verified code and documentation.
  - Delivered scope matches approved requirements with zero unverified claims.
- **Archiving:** Move completed sprint checklists into a dedicated archive file under `docs/01_Tracking/archive/task-[YYYY-MM-DD]-[feature-name].md`.
- **Git Handoff:** Provide proposed Conventional Commit message to Chris.

---

## 3. Task Sizing & Subsystem Batching Principle

To prevent both microscopic over-ceremony and unwieldy, unreviewable pull requests, tasks must be sized according to the **Subsystem Batching Principle**:

> *"Scope tasks and documentation passes to the largest tightly related task or batch that preserves reliable first-pass accuracy, reviewability, and bounded correction cost."*

- **Prefer Cohesive Subsystem Batches:** Group tightly coupled domain changes (e.g., model schema + CRUD endpoint + unit tests) into a single coherent delivery slice.
- **Reduce Batch Size When Risk Rises:** If cross-domain ambiguity, unfamiliar technology, or high correction cycles occur, immediately shrink slice boundaries.
- **Proportionality for Trivial Fixes:** Already-approved surgical fixes (e.g., typo fix, single bug regression) do not require heavyweight RFC planning; use engineering judgment proportional to risk.

---

## 4. Git Ownership & PR Handoff Protocol

### 4.1 Strict Human-Only Git Authority
Chris owns all repository mutations. AI agents operate under a **Strict Read-Only Git Policy**:
- **Prohibited Agent Commands:** `git add`, `git commit`, `git push`, `git merge`, `git rebase`, `git branch`, `git checkout`, `git switch`, `git tag`, `git stash`, `git reset`, `git restore`, and PR creation/merge.
- **Permitted Agent Commands (Read-Only):** `git status`, `git diff`, `git log`, `git show`, `git rev-parse`, `git branch` (list only), `git worktree list`.
- **Handoff Mechanism:** When verification passes, the agent stops, displays command evidence, and supplies a formatted Conventional Commit proposal for Chris to review, commit, and push manually.

### 4.2 Conventional Commit Proposals
All proposed commits must adhere to the Conventional Commits specification:
```text
<type>(<scope>): <short imperative summary>

- <bullet detail 1>
- <bullet detail 2>
- <verification evidence summary>
```
*Valid types:* `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`.

### 4.3 Pull Request Protocol
When a milestone or major feature batch is ready for upstream integration:
1. **Before PR Creation:** Verify base branch (`develop` or `main`); verify head branch and pushed HEAD SHA; verify all local test suites pass; provide structured PR title and markdown body.
2. **After PR Opens:** Inspect reported status of CI checks and linters.
3. **Before Merge:** Confirm zero merge conflicts and all required status checks green; provide squash commit message.
4. **After Merge:** Verify target branch commit SHA and ensure clean local working tree state.

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
