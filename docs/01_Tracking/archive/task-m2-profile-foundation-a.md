# Branch Task: M2 Profile Schema Foundation & Pre-Migration Backup (Batch A)

- **Branch:** `feature/m2-profile-foundation-a` (human-authorized).
- **Starting Baseline:** `d0f96fc533326f02112a28c4246dfe0c9cd7647d` (PR #24 squash merge to develop).
- **Milestone:** M2 — PC Companion Foundation.
- **Active Work Items:**
  - `PC-IDENTITY-001` (Account & Multi-Profile Database Schema Migration — Batch A Schema Foundation).
  - `PC-RESILIENCE-002` (Pre-Migration Automatic Safety Snapshot Hook).
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-profile-foundation-a.md`](../../02_Planning/01_Plans/plan-m2-profile-foundation-a.md).
- **Current Stage:** Stage 7: PR-READY (Implementation Gate: APPROVED at `8fa5dc6`; Documentation Gate: APPROVED; Closure Gate: PR-READY; Archived).

---

## Batch A Checkpoints & Boundaries

### Scope Boundaries
- **In Scope:**
  1. Database migration 007 introducing `profiles` table with unique, installation-specific Default Profile UUID and partial unique index (`uq_profiles_single_default`).
  2. Retention of existing `owner_id` columns and indices across `conversations`, `messages`, `tasks`, `memories`, and `attachments` for seamless backward compatibility.
  3. Context-sensitive `resolve_default_profile_id` dynamic flush resolution and `Profile` model lifecycle hooks ensuring consistent, non-NULL `profile_id` association for all new records.
  4. Strict legacy owner validation (`app/db/legacy_owner_validation.py`) accepting only approved single-user aliases (`local_user`, `default_user`) and failing closed on unexpected, empty, or NULL owner values.
  5. Collision-proof, non-overwriting pre-migration SQLite WAL backup integrated into startup (`prepare_database_schema`).
  6. Startup preflight integrity check failing closed on zero-byte, invalid-header, or corrupt existing databases before any backup or migration attempt.
  7. Standalone verified restore utility (`restore_database_from_backup`) featuring quiescence probing (`BEGIN EXCLUSIVE`), pre-restore safety snapshotting, SQLite backup API restoration (preserving WAL/SHM sidecars), and automatic rollback on verification failure.
  8. Isolated disposable SQLite database testing across migration, fresh install, rollback, FTS5 preservation, and legacy application workflows.
- **Strictly Out of Scope & Planned Boundaries:**
  - Profile Sessions and token-bound profile context (`POST /api/v1/auth/profile/session` deferred to Batch B).
  - Multi-profile CRUD endpoints, management routes, or administration APIs (deferred to Batch B).
  - Profile PIN security, salted hashing, or challenge verification (deferred to Batch B).
  - Profile switcher UI in Flutter Desktop or React Web (deferred to subsequent client milestones).
  - Live/automatic restore recovery (standalone restore is not approved for live/automatic recovery until host-level writer quiescence is enforced across the complete restore operation; tracked as a nonblocking future resilience requirement).

---

## Checkpoints & Gates

- [x] Preflight checks verified (clean develop baseline `d0f96fc`, workspace tests passing).
- [x] Branch initialized: `feature/m2-profile-foundation-a` (human-authorized).
- [x] Batch A implementation plan authored under `docs/02_Planning/01_Plans/plan-m2-profile-foundation-a.md`.
- [x] **HUMAN PLAN APPROVAL GATE PASSED:** Approved by Chris (October 12, 2026) with staged backward-compatible Batch A architecture.
- [x] **Task 1 (Migration 007 & Schema):** Introduces `profiles` table, non-hardcoded installation Default Profile UUID, partial unique index, and foreign keys across existing user entity tables.
- [x] **Task 2 (Legacy Compatibility & Models):** Retains `owner_id` columns; implements `resolve_default_profile_id` in `ProfileMixin` and `after_create` seed in `Profile` model.
- [x] **Task 3 (Strict Legacy Owner Validation):** Implements `app/db/legacy_owner_validation.py` rejecting unapproved, empty, or NULL owner values before applying migration DDL.
- [x] **Task 4 (Resilient Pre-Migration Backup):** Implements collision-proof filenames (`pre_<label>_<timestamp>_<suffix>.db`), hardlink publishing without overwrite, startup preflight verification, and staged restore utility with pre-restore safety snapshot.
- [x] **Task 5 (Test Verification):** Verified across 494 passing backend tests (isolated SQLite databases only), `flutter analyze` clean, and 234 passing Vitest tests in `frontend/web`.
- [x] **Implementation Gate:** APPROVED at commit `8fa5dc671aca5638d1ae6d0d2184ec7108a37a35`.
- [x] **Documentation Reconciliation:** Canonical specs updated (`profiles-and-devices.md`, `backup-recovery-and-diagnostics.md`), delivery index updated, and active tracker archived.
- [x] **Documentation Gate:** APPROVED.
- [x] **Stage 6 Closure:** CHANGELOG.md updated, master checklists and WBS updated, PR-ready handoff prepared.
- [x] **Stage 7 Closure Gate & PR-Ready Handoff (STOP HERE):** Delivery reconciled and archived on branch; PR title, body, and squash merge proposal prepared for independent final review.
