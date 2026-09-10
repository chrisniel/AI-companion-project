# AI Agent Working Rules

These rules govern AI-assisted work in the AI Companion Project. Explicit system instructions and the user's immediate request take precedence.

## Project Profile

- Project Name: AI Companion Project
- Project State: Existing early-stage monorepo; React web prototype is repository-verified, Android UI/UX Batch 12 is in progress in Google AI Studio but not yet available in this repository, and backend/runtime integrations are planned
- Active Task File: docs/01_Tracking/task.md
- Task Archive Directory: docs/01_Tracking/archive/
- Implementation Plan Directory: docs/02_Planning/
- Walkthrough Folder: docs/03_Walkthroughs/
- Canonical Architecture Document: docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
- Changelog File: CHANGELOG.md
- Major Change Commit Policy: Every completed major change must be committed as one coherent user-owned Git commit; the AI supplies a proposed commit message, while the user manually reviews, commits, and pushes
- Execution Mode: Read-only by default; inspect and report unless the user explicitly authorizes the specific edit or other state-changing action
- Implemented Stack: React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4
- Planned Stack: Python, FastAPI, Pydantic, SQLAlchemy 2, Alembic, SQLite/FTS5; Kotlin and Jetpack Compose for Android; llama.cpp for local inference
- Manual Verification Areas: Responsive desktop UI, themes and accessibility, Windows runtime behavior, RX 580 model benchmarks, microphone/Bluetooth audio, Android physical-device behavior, alarms, Health Connect, and remote authentication
- Protected Boundaries: Preserve uncommitted user work; never expose secrets; do not alter Git/LFS policy, external services, dependencies, branches, remotes, or source code without an approved task-specific plan

## 1. Documentation Structure

- Use lowercase `docs/` paths consistently.
- New documentation belongs in the numbered lifecycle directories:
  - `docs/00_Drafts/` — raw ideas and unapproved material
  - `docs/01_Tracking/` — the active task and per-task archives
  - `docs/02_Planning/` — feature-specific plans, technical designs, and acceptance criteria
  - `docs/03_Walkthroughs/` — verified delivery walkthroughs and handoffs
  - `docs/04_Architecture/` — canonical architecture, contracts, schemas, and ADRs
  - `docs/05_Design/` — product, UX, visual, voice, character, and interaction design
  - `docs/06_Guides/` — setup, contributor, testing, and maintenance guides
  - `docs/07_Archive/` — superseded documents retained for history
- `docs/ProjectWorkflowStarterKit/` is a permanent user-owned starter reference and is exempt from the numbered layout. Do not move, rewrite, or delete it unless the user explicitly requests that exact change.
- Historical planning material is preserved under `docs/00_Drafts/` as non-canonical reference. Do not promote draft claims over the canonical master plan.

## 2. Context Boundaries

- Do not load `docs/00_Drafts/`, `docs/07_Archive/`, or `docs/01_Tracking/archive/` unless the active request requires a specific file there.
- Treat `docs/ProjectWorkflowStarterKit/` as a human reference. Use root `AGENTS.md` for normal repository work.
- Read only the top portion of `CHANGELOG.md` needed to place a new entry under `Unreleased`; do not load its full history by default.
- Architecture and design documents remain available when relevant to the active task.

## 3. Planning and Approval

- For non-trivial features, refactors, migrations, or bug fixes, create or update a feature-named plan in `docs/02_Planning/`.
- Plans must identify evidence, scope, affected files, step-by-step pseudocode, acceptance criteria, verification, risks, and rollback.
- Update a plan in place. Do not prepend duplicate plans or status blocks.
- Obtain explicit user approval before implementing the plan.
- After approval, use `docs/01_Tracking/task.md` for execution state. Reopen the full plan only when revising scope or architecture.
- Planned architecture is not implemented behavior. Mark claims as Planned, In Progress, Implemented, Verified, Deferred, or Unverified as appropriate.

## 4. Active Task Continuity

- Read `docs/01_Tracking/task.md` before resuming implementation work.
- Keep its handoff block, status, checklist, blockers, and next action current by editing them in place.
- Keep the active task focused on the current sprint and preferably under 80 lines.
- After a delivery is verified, move its completed checklist into `docs/01_Tracking/archive/task-YYYY-MM-DD-feature-name.md` and reset the active task for the next sprint.

## 5. Source of Truth and Documentation Alignment

- Prefer one canonical document for each decision or contract and link to it rather than duplicating it.
- Treat drafts, prototype labels, mock telemetry, and external work as non-authoritative until verified.
- When behavior, setup, contracts, configuration, or architecture changes, update the closest canonical document in the same delivery.
- Do not silently resolve contradictions. Record the evidence and obtain user direction when the choice affects architecture, security, data, cost, hardware, or external systems.

## 6. Surgical Changes and User Work

- Default to read-only inspection and reporting. Do not edit files, install dependencies, run write-producing commands, or change local/external state unless the user explicitly authorizes that specific work.
- An authorization to edit documentation does not authorize application-code changes, and an authorization to edit one subsystem does not authorize adjacent subsystems.
- Touch only files required by the approved task.
- Preserve unrelated and uncommitted user changes, including the current `README.md` working-tree edit.
- Do not rewrite working code, add dependencies, or populate placeholder subsystems without task-specific approval.
- Do not remove or relocate existing documentation unless its destination and canonical status are approved.

## 7. Verification

- Run only safe checks proportionate to the change.
- Never claim a check passed unless it was executed and confirmed.
- Separate automated results from manual, visual, hardware, Android-device, health, and audio checks.
- Documentation-only work should at minimum verify paths, links or references where practical, `git diff --check`, and the final working-tree scope.

## 8. Changelog, Walkthroughs, and Commit Handoff

- Record completed user-visible or structural deliveries under the current `Unreleased` section in `CHANGELOG.md`.
- Preserve historical changelog entries; do not rewrite them.
- Create a walkthrough in `docs/03_Walkthroughs/` when a completed delivery needs developer or user handoff.
- Treat a major change as a coherent feature, architecture update, workflow migration, substantial refactor, or other reviewable delivery—not every small save or intermediate edit.
- At the end of every completed major change, provide a concise Conventional Commit-style message describing the delivered scope.
- The user owns commit and push execution. Do not claim work is committed merely because a commit message was prepared.

## 9. Privacy, Security, and Data Integrity

- Never expose, log, or commit passwords, tokens, API keys, credentials, private health data, personal conversations, signing keys, or private certificates.
- Use environment-variable names and sanitized placeholders in documentation.
- Do not give an LLM unrestricted shell, filesystem, database, device, or network authority in the product architecture.
- Sensitive tools require backend validation, authorization, and auditable execution.

## 10. Git and External Boundaries

- Read-only Git inspection is allowed when relevant.
- Do not run `git add`, `git commit`, `git push`, branch switching/creation, tags, history rewrites, or pull-request mutations unless the user explicitly authorizes that specific action.
- By default, stop after verification and give the user the proposed commit message for manual commit and push.
- The accepted model-storage policy keeps Git source and LFS pointers on GitHub while the private Hugging Face dataset stores LFS objects. Do not change `.gitattributes`, `.lfsconfig`, model tracking, either remote, or that policy without explicit authorization.
- Treat paths outside this workspace, package caches, and external repositories as read-only unless the user explicitly places them in scope.
