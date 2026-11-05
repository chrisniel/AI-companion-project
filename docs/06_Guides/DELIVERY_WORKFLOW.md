# AI Companion — Engineering Delivery Workflow & Contributor Guide

> **Document Role:** Canonical engineering delivery process guide, quality gate definitions, Git interaction protocols, and verification standards for all human contributors and authorized AI implementation agents.
> **Status:** Active Canonical Guide
> **Authority Precedence:** Normative architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md). Active planning resides in [`docs/02_Planning/00_Master/`](../02_Planning/00_Master/). Operational agent rules are anchored in [`AGENTS.md`](../../AGENTS.md).

---

## 1. Overview & Core Philosophy

The AI Companion project balances rapid, autonomous local iteration with strict architectural integrity, reproducible testing, and truthful delivery tracking.

### Core Governance Roles
This workflow is AI-provider-agnostic. No vendor or model receives exclusive implementation, review, or delivery authority. Roles are defined by responsibility:
- **Human Owner:** Authorizes product direction, significant scope, material design decisions, sensitive operations, and final merges (`develop` and `master`).
- **Implementing Agent:** Any authorized AI coding agent that plans, implements, tests, documents, and prepares a delivery candidate.
- **Independent Reviewer:** An appropriate reviewer who did not author the implementation under review (another AI agent or human contributor).
- **CI System:** Executes automated verification and supplies empirical qualification evidence; it does not grant implementation or merge approval.

### Key Working Principles
- **Test-Driven & Evidence-Based:** No production code without failing tests first; no completion claim without passing test evidence.
- **Human-Controlled Version Control:** The Human Owner retains exclusive authority over final merges and destructive repository mutations.
- **Strict Separation of Concerns:** Implemented reality (source code and tests) is never confused with target architecture (canonical specifications) or delivery roadmaps.
- **No Self-Verification:** Implementing agents must stop after mechanical verification and submit complete delivery candidates for independent review.
- **Autonomous Continuation within Scope:** Once authorized at the plan gate, implementing agents continue autonomously through implementation, testing, documentation, and draft PR creation without requiring repetitive micro-approvals for ordinary in-scope steps.

---

## 2. The Four-Phase Engineering Delivery Lifecycle & Quality Gates

All non-trivial implementation across any authorized implementing agent must follow the four-phase delivery lifecycle:

```text
PHASE 1: PLAN AND AUTHORIZATION
  │
  ▼  [Gate: Human Plan Approval for substantial / sensitive design]
PHASE 2: AUTONOMOUS IMPLEMENTATION AND VERIFICATION
  │
  ▼  [Prerequisite: All automated checks pass cleanly before Phase 3]
PHASE 3: DOCUMENTATION, CLOSURE, AND DRAFT PR
  │
  ▼  [Output: Complete delivery package presented for review]
PHASE 4: COMBINED INDEPENDENT REVIEW AND HUMAN MERGE
  │
  ▼  [Gate: Human Owner squash merge; read-only post-merge verification]
```

---

### Phase 1: Plan and Authorization

For substantial work, an authorized Implementing Agent prepares a feature-specific implementation plan under [`docs/02_Planning/01_Plans/plan-[feature-name].md`](../02_Planning/01_Plans/README.md) using the standard template in [`docs/02_Planning/02_Templates/implementation-plan-template.md`](../02_Planning/02_Templates/implementation-plan-template.md).

#### Plan Requirements
Every plan must contain:
1. **Scope and Acceptance Criteria:** Clear boundaries of what will and will not be changed, with testable acceptance criteria.
2. **Relevant Canonical Requirements:** Direct citations of normative domain specifications, architecture baselines, and accepted ADRs.
3. **Architecture and Technical Approach:** Structural breakdown of proposed code changes, data models, state flows, and contracts.
4. **Risks, Dependencies, and Assumptions:** Explicit operational risks, dependency constraints, and external assumptions.
5. **Affected Components, Contracts, and Files:** Complete inventory of target paths, generated contracts, and migrations.
6. **Verification Strategy:** Precise local test commands, static analysis checks, and manual verification steps.
7. **Risk Classification:** Explicit designation of the delivery level (**Level A, B, C, or D** per Section 3).
8. **Required Permissions and Genuine Stop Conditions:** Stated Git permissions needed and explicit boundaries that require stopping.

#### Phase 1 Gate Rules
- **Substantial / Sensitive Work (Levels B & C):** Requires explicit **Human Plan Approval** before implementation begins. Unapproved plans must not be implemented.
- **Routine Low-Risk Tasks (Level A):** May proceed under an explicitly authorized prompt scope without a separate formal plan ceremony.
- **Phase 1 Planning Git Authorization:** When the Human Owner authorizes Phase 1 planning for a named delivery, the Implementing Agent may—without requesting repetitive command-by-command Git approval:
  1. Inspect the repository and verify a clean integration baseline.
  2. Create and switch to one dedicated feature branch from that baseline.
  3. Create or edit the feature implementation plan using [`docs/02_Planning/02_Templates/implementation-plan-template.md`](../02_Planning/02_Templates/implementation-plan-template.md).
  4. Create or update the branch-specific planning tracker (`docs/01_Tracking/active/task-[branch-slug].md`) when appropriate.
  5. Stage only authorized planning files (and any explicitly authorized governance or documentation files in that scope).
  6. Commit those files using Conventional Commits and push the planning commit to the remote feature branch.
  7. Verify the remote branch HEAD SHA and submit the published plan for Human Owner and Independent Reviewer examination.
- **Phase 1 Approval Boundary:** A published planning commit is a review candidate, not implementation approval. Phase 1 planning Git authorization does **not** authorize implementing production features, modifying unrelated code/tests/migrations, bypassing the Level B/C Plan Approval Gate, opening a Pull Request during Phase 1, merging branches, force-pushing or rewriting history, writing to `develop`/`master`, or self-approving the plan.
- **Autonomous Continuation:** Once the plan gate is satisfied, the Implementing Agent is authorized to continue automatically through subsequent phases within the approved scope on the **same** dedicated feature branch. The Human Owner does not need to approve each implementation substep.

---

### Phase 2: Autonomous Implementation and Verification

The Implementing Agent executes the approved plan autonomously using Test-Driven Development (Red-Green-Refactor).

#### Implementing Agent Obligations
1. **Implement Approved Scope:** Build the complete approved scope without skipping edge cases or deferring essential logic.
2. **Test-Driven Discipline:**
   - Write a focused failing test demonstrating desired behavior (**RED**).
   - Verify failure for the expected architectural reason.
   - Implement minimal code to pass (**GREEN**).
   - Clean up duplication and structure while maintaining all green tests (**REFACTOR**).
3. **Comprehensive Automated Verification:** Run applicable unit tests, component tests, static analysis (`dart analyze`, TypeScript `lint`), and OpenAPI contract drift checks (`scripts/check_openapi_contract.py --check`).
4. **Autonomous Defect Resolution:** Diagnose and fix in-scope defects and test failures directly. Ordinary bug fixes within the approved scope do not require another human approval.
5. **Repeat Verification:** Re-verify all checks after fixes to confirm zero regressions across the codebase.
6. **Preserve System Boundaries:** Strictly uphold architecture invariants, Profile isolation, privacy, security defaults, and data integrity.
7. **Truthful Evidence Recording:** Record exact command outputs, passing test counts, and note any unavailable checks (e.g. physical audio devices or native OS toasts).

#### Phase 2 Completion Prerequisite
> [!IMPORTANT]
> The Implementing Agent **MUST** complete implementation and its required automated verification **before beginning canonical documentation and closure preparation**.

#### Mid-Flight Stop Boundaries
- **No Mid-Flight Implementation Stop for Routine Deliveries:** Do not introduce a mandatory independent implementation-review stop between implementation and documentation for ordinary authorized deliveries.
- **Genuine Stop & Escalation Triggers:** The Implementing Agent must halt immediately and escalate to the Human Owner only if:
  - A material scope expansion or unapproved architectural divergence is required.
  - An unresolved security or privacy conflict arises.
  - A required automated test failure cannot be resolved within approved architecture.
  - Only the affected work is halted; unrelated progress should not be unnecessarily blocked.

---

### Phase 3: Documentation, Closure, and Draft PR

Once Phase 2 verification succeeds, the same Implementing Agent proceeds automatically to package the delivery without waiting for intermediate approvals:

#### Phase 3 Actions
1. **Canonical Documentation Reconciliation:** Update the closest canonical owner document (e.g., focused domain spec under `docs/04_Architecture/` or design spec under `docs/05_Design/`) to reflect actual code behavior. Documentation must describe implemented reality, never target behavior as if delivered.
2. **Planning & Tracking Updates:** Update master planning spine files if milestone sequencing is affected. Create or update the branch active task tracker (`docs/01_Tracking/active/task-[branch-slug].md`).
3. **Changelog Update:** Append a concise, factual summary to [`CHANGELOG.md`](../../CHANGELOG.md) under `## [Unreleased]`.
4. **Technical Walkthrough:** Author a technical walkthrough under `docs/03_Walkthroughs/` following the 7-section template when the deliverable introduces new architectural patterns, complex multi-step flows, or developer handovers.
5. **Truthful Closure Evidence:** Record local automated test counts, static analysis results, contract verification status, and manual QA outcomes. Do not invent human acceptance or hosted CI results.
6. **Task Archival:** When closure reconciliation is complete on the feature branch, move the branch tracker to `docs/01_Tracking/archive/task-[branch-slug].md` to preserve point-in-time delivery truth.
7. **Quality & Hygiene Checks:** Validate Markdown links, ensure relative links resolve, and run `git diff --check` to confirm zero whitespace or merge artifact defects.
8. **Commit and HTTPS Push:** Under task authorization, stage changes, commit using Conventional Commits, and push to the remote feature branch.
9. **Draft Pull Request:** Create or update a draft pull request targeting `develop` (`gh pr create --draft`).
10. **Delivery Candidate Presentation:** Present one consolidated review package for Phase 4 evaluation.

---

### Phase 4: Combined Independent Review and Human Merge

Phase 4 consolidates final evaluation into a single rigorous review gate.

#### Review Scope
The Independent Reviewer evaluates the complete candidate package:
- **Implementation Correctness:** Conformance to approved scope, edge-case coverage, and absence of extraneous edits.
- **Regression Tests & Verification Results:** Test suite completeness, assertion quality, and static analysis outputs.
- **Security & Architectural Invariants:** Enforcement of Profile isolation, Default Deny tool policies, credential safety, and database migration hygiene.
- **Canonical Documentation Accuracy:** Factual consistency between committed source code and updated canonical architecture documents.
- **Closure and Tracking Consistency:** Truthful changelog, task tracking, and walkthrough coverage.
- **Manual Acceptance Evidence:** Verification of physical host interactions where required (e.g. Windows tray, UI responsiveness).
- **PR Diff & Hosted CI:** Scoped candidate CI execution results on GitHub Actions.

#### Bounded Review Corrections
If the Independent Reviewer requires changes:
1. The Implementing Agent investigates findings and applies surgical fixes on the **SAME** feature branch.
2. Re-runs affected tests and automated checks.
3. Updates documentation and tracking where relevant.
4. Pushes the corrective commits to update the draft PR.
5. Re-submits the candidate for focused review of the corrected items.
6. **Do NOT restart the entire delivery lifecycle for ordinary review corrections.**

#### Human Squash Merge
Once independent review approval is granted and candidate CI is green:
1. The **Human Owner exclusively executes the squash merge** into `develop` on GitHub.
2. Implementing agents **NEVER** merge branches or modify protected branches.

#### Read-Only Post-Merge Verification
After the merge lands on `develop`:
1. A subsequently invoked agent inspects `develop` to confirm the squash commit landed cleanly.
2. Inspects post-merge `develop` CI workflow runs.
3. Reports a clear integration verdict with commit SHAs.
4. **Never equate pre-merge CI with post-merge CI.** Pre-merge CI runs against the PR branch diff; post-merge CI runs against the integrated tree.
5. **No-Stale-Documentation Rule:** Do NOT create a follow-up cleanup branch or commit solely to replace a historical branch HEAD with a squash SHA, update a historical PR checkpoint, or alter a historically truthful pending status.

---

## 3. Risk-Based Supervision Matrix

Review effort scales proportionally with change risk. The project adopts four portable delivery levels:

| Delivery Level | Scope & Risk Characteristics | Plan Ceremony | Implementation & Verification | Documentation & Closure | Review & Approval Gates | Target Human Reviews |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Level A — Routine Autonomous** | Low-risk mechanical changes, settled requirements, typo/doc fixes, minor isolated test additions, internal refactoring without behavior change. | No separate formal plan ceremony. Work proceeds under explicit prompt authorization. | Autonomous implementation, test execution, and defect fixes. | Autonomous canonical doc sync, tracking, and draft PR. | One combined independent review. | **1 Review** (Final candidate review). |
| **Level B — Planned Autonomous** | Substantial features within established architecture, multi-file enhancements, new UI screens, new CRUD endpoints, standard domain extensions. | Feature-specific implementation plan (`docs/02_Planning/01_Plans/`). | Autonomous implementation, TDD, automated verification, and defect fixes. | Autonomous canonical doc sync, tracking, walkthrough (if complex), and draft PR. | Plan approval + Combined independent review. | **2 Reviews** (Plan approval + Final delivery review). |
| **Level C — Sensitive Design** | High-impact changes: authentication, authorization, multi-Profile isolation, privacy, significant concurrency, public API contracts, DB schema migrations, material architecture decisions. | Comprehensive implementation plan with architecture analysis, migration safety, and security safeguards. | Autonomous implementation within approved design boundaries. Escalate genuine new risks. | Autonomous canonical doc sync, tracking, migration verification, walkthrough, and draft PR. | Plan approval of material design + Combined independent review. | **2 Reviews** (Design approval + Final delivery review). |
| **Level D — Human-Controlled Operations** | Production deployments, production migration execution, destructive operations, secrets/signing-key modifications, irreversible external service actions. | Detailed operational runbook with rollback procedures. | Strictly supervised or manually executed by Human Owner. | Post-operation verification records and audit tracking. | Specific human authorization for exact operation and environment. AI autonomy never overrides. | **Human-Controlled** (Operations require explicit human execution/supervision). |

---

## 4. Agent-Agnostic Git Permissions & PR Protocol

### 4.1 Scope-Based Git Permissions
Git authorization belongs to the **human-approved delivery scope**, not to an AI vendor or model. For a named delivery, the Human Owner may grant the Implementing Agent permission to:
- Create and switch to the dedicated task branch from a verified clean baseline (including during Phase 1 planning publication).
- Stage authorized changes (limited in Phase 1 to the implementation plan, optional branch tracker, and any explicitly authorized governance/documentation files; expanded in Phases 2–3 after required plan approval to the approved implementation and closure scope).
- Create Conventional Commits.
- Push commits to the authorized feature branch.
- Create or update one draft PR against `develop` in Phase 3 after implementation and automated verification pass (never open a PR in Phase 1 merely to publish a plan).
- Perform normal in-scope defect fixes without requesting repeated command-by-command approval.

Any authorized AI agent may perform these actions when its current tools and connection permissions support them. Never assume the presence of a specific connector, IDE, command-line environment, or automation platform. One coherent feature branch owns the entire delivery lifecycle from Phase 1 planning publication through Phase 4 pre-merge review.

### 4.2 Prohibited Git Operations
The following remain strictly prohibited for AI agents without separate explicit authorization:
- Direct protected-branch writes (`develop`, `master`).
- Squash merges, rebase merges, or any other branch merges.
- Force pushes, rebases, resets, or destructive Git history mutations.
- Modifying repository security settings, branch protection rules, or CI workflows outside authorized tasks.
- Secret, credential, production, or sensitive operational actions.
- Permissions must not silently transfer to another repository, branch, unrelated task, or external service.

### 4.3 Conventional Commits Standard
All proposed and executed commits must adhere to the Conventional Commits specification:
```text
<type>(<scope>): <short imperative summary>

- <bullet detail 1>
- <bullet detail 2>
- <verification evidence summary>
```
*Valid types:* `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`.

### 4.4 Pull Request Lifecycle
1. **Draft PR Creation:** In Phase 3, the Implementing Agent pushes verified commits and opens a **draft PR** (`gh pr create --draft`) targeting `develop`. The description links to the branch plan, active/archived tracker, and summarizes automated verification evidence.
2. **Review & Corrections:** In Phase 4, the Independent Reviewer evaluates the candidate. Corrections are pushed to the same branch, automatically updating the draft PR.
3. **Human Squash Merge:** Once approved and candidate CI is green, the Human Owner executes the squash merge.
4. **Post-Merge Verification:** A subsequent agent performs read-only target-branch verification.

---

## 5. Educational Delivery Walkthroughs

When a deliverable introduces new architectural patterns, complex multi-step workflows, or developer handovers, author a walkthrough under `docs/03_Walkthroughs/` following the 7 required sections:

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
