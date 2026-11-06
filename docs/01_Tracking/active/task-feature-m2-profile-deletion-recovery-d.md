# Active Branch Execution Tracker — Milestone M2 Profile Deletion & Recovery Batch D

- **Branch:** `feature/m2-profile-deletion-recovery-d`
- **Base Integration Branch:** `develop` (`2104d5c05ad1a7b47d2b008d4e74ca5cb88595e6`)
- **Delivery Level:** Level C — Sensitive Design (Special Boundary: Irreversible physical deletion of real user data requires explicit human authorization under Level D operational governance)
- **Work Breakdown Structure ID:** `PC-IDENTITY-005` (30-Day Recoverable Profile Deletion Lifecycle & Hard Purge Maintenance)
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-profile-deletion-recovery-d.md`](../../02_Planning/01_Plans/plan-m2-profile-deletion-recovery-d.md)
- **Current Lifecycle Phase:** **PHASE 1 — REVISED PLAN READY FOR HUMAN OWNER APPROVAL**

---

## Phase 1: Planning & Design Authorization (REVISED / AWAITING APPROVAL)

- [x] Verify clean `develop` baseline at `2104d5c05ad1a7b47d2b008d4e74ca5cb88595e6` and passing post-merge GitHub Actions CI (`Run 42024505569`).
- [x] Create and switch to dedicated delivery branch `feature/m2-profile-deletion-recovery-d`.
- [x] Map Profile ownership graph, foreign-key cascade dependencies (`ondelete="RESTRICT"` on `conversations.character_instance_id`, `ondelete="SET NULL"` on `Profile.active_character_instance_id`), and FTS5 triggers (`memories_fts_delete`).
- [x] Revise Phase 1 plan to incorporate Human Owner product decisions and technical corrections:
  - **30-day recovery period:** `purge_after = deleted_at + 30 days`; distinguish **Move to Recently Deleted** from **Permanently Delete**.
  - **Recovery authority boundary:** Local Account Admin recovery applies strictly to Profile-level state and preserves prior user-initiated content deletions (`is_deleted` / `deleted_at` on child conversations, messages, memories, tasks, and attachments remain untouched).
  - **Backup restoration semantics & asset consistency:** Restoring a backup restores the snapshot as it existed when created (superseding tombstone anti-resurrection rules for backups, while preserving mobile delta-sync tombstones) and restores only data/assets contained in the backup. Reconciled in `privacy-retention-and-audit.md` and `backup-recovery-and-diagnostics.md`, noting that current SQLite backups do not bundle `ATTACHMENT_DIR`.
  - **Purge ordering, upload-race SQLite concurrency & 5-phase execution:**
    - Controlled concurrency under SQLite single-writer WAL model (`DEL-19`): Case A (upload wins write lock first, commits, and purge Phase C reconciles newly committed row) vs. Case B (purge wins write lock first, transitions Profile, and upload lifecycle validation fails closed with 401).
    - Phase A: Pre-validate all attachment paths before modifying state; aborts before status transition if invalid, preserving restorability (`DEL-08`).
    - Phase B: Atomic transition to `status = "purging"` and active session revocation, making profile permanently non-restorable (`DEL-11`).
    - Phase C: Post-transition attachment reconciliation re-querying attachment rows to capture any just-committed upload from Case A (`DEL-19`).
    - Phase D: Physical file unlinking with pre-unlink containment revalidation; halt on `OSError` with DB rows retained for safe retry without a separate ledger (`DEL-09`, `DEL-10`); comprehensive inspection of dedicated Profile directory unlinking `.tmp_*` artifacts and crash-orphaned promoted files without Attachment rows (`DEL-20`), with strict symlink and containment safety.
    - Phase E: Atomic relational database deletion in strict FK order only after directory is confirmed completely clean.
  - **Periodic automatic purge scheduling:** Background maintenance task `run_periodic_profile_purge(interval_seconds=3600)` running in FastAPI lifespan context while Runtime remains open (hourly sweep, default 3600s), in addition to startup lifespan sweep and manual maintenance endpoint (`DEL-18`).
  - **Concrete isolation assertions (`DEL-14`):** Explicit verification of byte-for-byte asset hash preservation, exact database row and active session retention for other profiles, and untouched shared templates.
  - **Accurate cancellation & confirmation boundaries:** Document cooperative 250ms polling + pre-commit validation without claiming a hard 250ms real-time latency cap; separate Host Admin API enforcement from Desktop UI typed confirmation safeguards.
  - **UUIDv4 / UUIDv7 direction:** Record approved entity UUID allocation and Python 3.11 `uuid6` recommendation without expanding Batch D into an identifier migration.
  - **Documentation status accuracy & Phase 3 inventory:** Reconciled 2 canonical documents in Phase 1; inventoried 9 canonical specifications and trackers for Phase 3 documentation closure.
  - **Status & governance accuracy:** Replaced premature "Blockers: None" with accurate outstanding Phase 1 corrections and Phase 3 closure tracking.
- [ ] Present revised Phase 1 package and await Human Owner approval before Phase 2 implementation.

---

## Phase 2: Autonomous Implementation & Verification (PENDING REVISED PLAN APPROVAL)

- [ ] **Step 1 — Backend Deletion, Restore & Physical-First Hard-Purge Logic:**
  - [ ] Write failing integration tests (`DEL-01`–`DEL-15`, `DEL-18`, `DEL-19`, `DEL-20`) in `backend/tests/test_profile_deletion.py`.
  - [ ] Implement `resolve_and_verify_profile_attachment_path(storage_path, profile_id)` in `backend/app/api/v1/endpoints/attachments.py`.
  - [ ] Implement `ProfilePurgeService` in `backend/app/services/profile_purge_service.py` (30-day soft delete, Profile-level restore, pre-validation before `status = "purging"`, post-transition reconciliation, physical-first file cleanup with pre-unlink containment revalidation, crash-orphaned file cleanup & `.tmp_*` sweep, failure retention without a separate ledger, periodic background maintenance worker `run_periodic_profile_purge`, and 10-step relational deletion transaction).
  - [ ] Implement `DELETE /api/v1/profiles/{id}`, `GET /api/v1/profiles/deleted`, `POST /api/v1/profiles/{id}/restore`, `POST /api/v1/profiles/{id}/purge`, `POST /api/v1/system/maintenance/purge-profiles`, and startup lifespan hook & periodic background task in `backend/app/main.py`.
- [ ] **Step 2 — OpenAPI Contract & Dart Client Parity (`companion_api`):**
  - [ ] Export updated `contracts/openapi/openapi.json`.
  - [ ] Update `companion_api` DTOs and `CompanionClient`.
  - [ ] Update `scripts/check_dart_openapi_parity.py` and add client unit tests.
- [ ] **Step 3 — Desktop Profile Controller & UI:**
  - [ ] Extend `DesktopProfileController` with `deletedProfiles`, `deleteProfile`, `restoreProfile`, and `purgeProfileImmediately`.
  - [ ] Implement `showMoveToRecentlyDeletedDialog` and `showPermanentDeleteProfileDialog`.
  - [ ] Update `ProfileAccessCard` with **Move to Recently Deleted** action and **Recently Deleted** section showing remaining recovery time, **Restore**, and **Permanently Delete**.
  - [ ] Add widget and controller tests (`DEL-16`–`DEL-17`) in `frontend/flutter/apps/desktop/test/desktop_profile_deletion_test.dart`.
- [ ] **Step 4 — Full Local Verification Gate:**
  - [ ] Verify `pytest`, `check_dart_openapi_parity.py`, `flutter analyze`, and `flutter test` across all packages.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2 COMPLETION)

- [ ] Reconcile 9 remaining canonical docs and trackers with 30-day recovery window and implemented Batch D behavior:
  1. `docs/04_Architecture/01_Core_and_Control/profiles-and-devices.md`
  2. `docs/05_Design/02_Profile_Selector_and_Privacy.md`
  3. `docs/04_Architecture/decisions/0018-profile-administration-and-local-isolation.md`
  4. `docs/04_Architecture/decisions/README.md`
  5. `docs/02_Planning/00_Master/WBS.md`
  6. `docs/02_Planning/00_Master/DECISION_REGISTER.md`
  7. `docs/04_Architecture/02_Data_and_Security/memory-and-personalization.md`
  8. `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
  9. `docs/02_Planning/00_Master/MOBILE_WBS.md`
- [ ] Update `CHANGELOG.md` and `docs/01_Tracking/task.md`, archive active branch tracker to `docs/01_Tracking/archive/`, and open Draft PR.

---

## Operational Safeguards: Level C vs. Level D Boundaries

- **Level C (Planned Autonomous Implementation after Plan Approval):**
  - All test and development activities operate strictly on temporary disposable SQLite databases (`tmp_path`) and isolated mock filesystem roots.
- **Level D (Human-Controlled Destructive Operations):**
  - Irreversible deletion operations on live human user data remain under exclusive Human Owner control. Automated tests and agents must never target production data paths.
