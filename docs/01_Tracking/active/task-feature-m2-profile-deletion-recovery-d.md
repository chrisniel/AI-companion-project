# Active Branch Execution Tracker — Milestone M2 Profile Deletion & Recovery Batch D

- **Branch:** `feature/m2-profile-deletion-recovery-d`
- **Base Integration Branch:** `develop` (`2104d5c05ad1a7b47d2b008d4e74ca5cb88595e6`)
- **Delivery Level:** Level C — Sensitive Design (Special Boundary: Irreversible physical deletion of real user data requires explicit human authorization under Level D operational governance)
- **Work Breakdown Structure ID:** `PC-IDENTITY-005` (7-Day Recoverable Profile Deletion Lifecycle & Hard Purge Maintenance)
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-profile-deletion-recovery-d.md`](../../02_Planning/01_Plans/plan-m2-profile-deletion-recovery-d.md)
- **Current Lifecycle Phase:** **PHASE 1 — PLAN PUBLISHED (AWAITING HUMAN OWNER & INDEPENDENT REVIEWER APPROVAL)**

---

## Phase 1: Planning & Design Authorization (COMPLETED / VERIFIED)

- [x] Verify clean `develop` baseline at `2104d5c05ad1a7b47d2b008d4e74ca5cb88595e6` and passing post-merge GitHub Actions CI (`Run 42024505569`).
- [x] Create and switch to dedicated delivery branch `feature/m2-profile-deletion-recovery-d`.
- [x] Map Profile ownership graph, foreign-key cascade dependencies (`ondelete="RESTRICT"` on `conversations.character_instance_id`, `ondelete="SET NULL"` on `Profile.active_character_instance_id`), and FTS5 triggers (`memories_fts_delete`).
- [x] Resolve critical design decisions:
  - Prohibit deleting default Profile (`is_default == True`) and last remaining active Profile.
  - Reuse existing `status`, `is_deleted`, `deleted_at`, `purge_after` schema without database migrations.
  - Implement decoupled startup and Host Admin maintenance purge without waiting for `SchedulerService`.
  - Provide immediate permanent purge with typed confirmation for soft-deleted profiles.
  - Document backup archive immutability boundary.
- [x] Formulate 13-step deterministic hard-purge execution sequence preventing foreign-key violations.
- [x] Author comprehensive implementation plan in `docs/02_Planning/01_Plans/plan-m2-profile-deletion-recovery-d.md`.
- [x] Commit and push planning artifacts to `origin/feature/m2-profile-deletion-recovery-d` and halt at Phase 1 approval gate.

---

## Phase 2: Autonomous Implementation & Verification (PENDING PLAN APPROVAL)

- [ ] **Step 1 — Backend Deletion, Restore & Hard-Purge Logic (`backend/app/services/profile_purge_service.py` & endpoints):**
  - [ ] Write failing integration tests in `backend/tests/test_profile_deletion.py`.
  - [ ] Implement `ProfilePurgeService` with atomic 13-step cascade purge and FTS5/asset cleanup.
  - [ ] Implement `DELETE /api/v1/profiles/{id}`, `POST /api/v1/profiles/{id}/restore`, `GET /api/v1/profiles/deleted`, and `POST /api/v1/profiles/{id}/purge`.
  - [ ] Implement `POST /api/v1/system/maintenance/purge-profiles` and startup lifespan hook.
- [ ] **Step 2 — OpenAPI Contract & Dart Client Parity (`companion_api`):**
  - [ ] Export updated `contracts/openapi/openapi.json`.
  - [ ] Update `companion_api` DTOs and `CompanionClient`.
  - [ ] Update `scripts/check_dart_openapi_parity.py` (36 verified routes) and add client tests.
- [ ] **Step 3 — Desktop Profile Controller & UI:**
  - [ ] Extend `DesktopProfileController` with delete, restore, listDeleted, and purge methods.
  - [ ] Implement `showDeleteProfileDialog` and `showPurgeConfirmationDialog`.
  - [ ] Update `ProfileAccessCard` with Delete Profile button and Recently Deleted Profiles card.
  - [ ] Add widget and integration tests in `frontend/flutter/apps/desktop/test/desktop_profile_deletion_test.dart`.
- [ ] **Step 4 — Full Local Verification Gate:**
  - [ ] Verify `pytest`, `check_dart_openapi_parity.py`, `flutter analyze`, and `flutter test` across all packages.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2 COMPLETION)

- [ ] Reconcile canonical documentation (`profiles-and-devices.md`, `privacy-retention-and-audit.md`, `WBS.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `MASTER_CHECKLIST.md`, `task.md`, `CHANGELOG.md`).
- [ ] Archive this tracker to `docs/01_Tracking/archive/task-feature-m2-profile-deletion-recovery-d.md`.
- [ ] Push implementation + closure commits to `origin/feature/m2-profile-deletion-recovery-d` and open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Human Merge (PENDING PHASE 3)

- [ ] Present complete delivery package, test evidence, and CI status for Independent Review and Human Owner squash-merge approval.
