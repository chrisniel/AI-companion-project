# Walkthrough: Documentation Workflow and Master Plan Reconciliation

- Purpose: Explain the new documentation organization and identify the authoritative project sources.
- Audience: User, future developer, AI-assisted development session, and maintainer
- Status: Verified
- Last Updated: 2026-09-10

## 1. What Was Delivered

- A numbered documentation lifecycle with one canonical architecture plan and clear active-task tracking.
- Lossless preservation of the old roadmap, runtime notes, and static review as drafts.
- An accepted repository/LFS storage decision, a current web cleanup plan, and a checklist of future project inputs.
- Read-only-by-default AI behavior and user-owned commit/push responsibility.

## 2. Authoritative Files

- `AGENTS.md` — repository working rules and authorization boundaries.
- `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` — canonical architecture and delivery sequence.
- `docs/04_Architecture/decisions/` — accepted architectural decisions.
- `docs/01_Tracking/task.md` — current task state.
- `docs/02_Planning/` — task-specific proposals; plans do not authorize implementation by themselves.
- `docs/06_Guides/DOCUMENTATION_MAP.md` — directory and source-of-truth map.

## 3. How the Workflow Operates

1. The user defines a task and states whether it is read-only or authorizes bounded edits.
2. The agent reads the active task, canonical master plan, and only relevant supporting material.
3. Non-trivial edits receive a focused plan and explicit user approval.
4. Execution is tracked in `task.md`; drafts never override canonical architecture.
5. Verification results are recorded without claiming unexecuted manual checks.
6. A completed major change receives a proposed commit message; the user manually commits and pushes.

## 4. Draft and External Work Handling

- `docs/00_Drafts/` contains non-canonical reference material and should not be loaded by default.
- `docs/ProjectWorkflowStarterKit/` remains a permanent human-owned starter guide.
- Google AI Studio output remains external and unverified until exported into the repository and inspected.
- Mock UI behavior never proves backend, database, device, voice, health, or synchronization implementation.

## 5. Verification Performed

- [x] Canonical and migrated paths exist.
- [x] Historical draft contents match their original Git blobs.
- [x] Active path references were checked.
- [x] Markdown code fences and trailing whitespace were checked.
- [x] `git diff --check` passed.
- [x] Application source and starter-kit files were not modified.

## 6. Safe Next Step

Use `docs/06_Guides/PROJECT_INPUTS_CHECKLIST.md` when providing backend work, Android exports, model/runtime material, or another task. The repository remains read-only until the user authorizes a specific change.

