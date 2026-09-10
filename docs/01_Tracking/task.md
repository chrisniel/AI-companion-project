# Task Tracking: Awaiting User-Authorized Work

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Planning
- Target: Keep the repository read-only until the user requests a specific review or explicitly authorizes a bounded edit.
- Scope Guard: Entire repository is read-only by default. Do not edit application code, documentation, configuration, dependencies, Git state, or external systems without explicit task-specific authorization.

## [CURRENT EXECUTION STATE - HANDOFF]

- Active Files: None
- Current Blocker / Status: Documentation workflow and master-plan reconciliation are complete; awaiting the user's next request.
- Next Immediate Action: Read the user's requested scope and inspect only the relevant canonical documents and files.

## Active Checklist

### Phase 1: Request Intake

- [ ] Receive the exact objective and whether the task is read-only or authorizes edits.
- [ ] Confirm authorized paths, protected boundaries, and expected outcome.

### Phase 2: Task Preparation

- [ ] Read the canonical master plan and only the relevant project material.
- [ ] Create or update an approval-gated plan for non-trivial authorized changes.

### Phase 3: Verification and Handoff

- [ ] Run safe, proportionate checks and report unverified manual areas honestly.
- [ ] For a completed major change, update documentation/tracking and provide a proposed commit message for the user's manual commit and push.

## Verification & QA Gates

- [ ] Automated checks: Select after the next task is defined.
- [ ] Manual/user-owned checks: Select after the next task is defined.

## Archive Instruction

Archive only a completed, verified sprint to `docs/01_Tracking/archive/task-YYYY-MM-DD-feature-name.md`; keep this active file focused and under 80 lines.

