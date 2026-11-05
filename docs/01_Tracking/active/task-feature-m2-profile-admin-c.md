# Active Branch Execution Tracker — Milestone M2 Profile Administration Batch C

- **Branch:** `feature/m2-profile-admin-c`
- **Base Integration Branch:** `develop` (`a3b206767f813344a35b1e0663a9c4a93e333d1f`)
- **Delivery Level:** Level C — Sensitive Design
- **Work Breakdown Structure IDs:** `PC-IDENTITY-004` (Profile Administration & PIN Protection), `PC-CLIENT-005` (Desktop Profile Selector & Management UI)
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-profile-admin-c.md`](../../02_Planning/01_Plans/plan-m2-profile-admin-c.md)
- **Current Lifecycle Phase:** **PHASE 1 — PLAN PUBLISHED (AWAITING HUMAN OWNER & INDEPENDENT REVIEWER APPROVAL)**

---

## Phase 1: Planning & Design Authorization (COMPLETED)

- [x] Verify clean `develop` baseline at `a3b206767f813344a35b1e0663a9c4a93e333d1f` and passing post-merge GitHub Actions CI (`Run 41988869571`).
- [x] Create and switch to dedicated delivery branch `feature/m2-profile-admin-c`.
- [x] Inspect canonical identity/security specs (`profiles-and-devices.md`, `authentication-and-secrets.md`, `ADR-0005`, `ADR-0018`, `02_Profile_Selector_and_Privacy.md`, `WBS.md`, `DECISION_DEBT.md`).
- [x] Inspect current backend implementation (`profile.py`, `profile_session.py`, `session_ticket.py`, `profiles.py`, `auth.py`, `profile_sessions.py`, `host_admin.py`, `character_service.py`) and Flutter implementation (`companion_client.dart`, `desktop_chat_controller.dart`, `desktop_profile_controller.dart`, `profile_access_card.dart`, `desktop_navigation_rail.dart`, `desktop_studio_controller.dart`).
- [x] Author implementation plan [`docs/02_Planning/01_Plans/plan-m2-profile-admin-c.md`](../../02_Planning/01_Plans/plan-m2-profile-admin-c.md).
- [x] Author active branch tracker `docs/01_Tracking/active/task-feature-m2-profile-admin-c.md`.
- [x] Commit and push Phase 1 planning artifacts to `origin/feature/m2-profile-admin-c` and halt at the Level C Plan Approval Gate.

---

## Phase 2: Autonomous Implementation & Verification (PENDING PLAN APPROVAL)

- [ ] **Step 1 — Backend PIN Cryptography & Lockout (`backend/app/core/profile_pin.py`):**
  - [ ] Write failing unit tests in `backend/tests/test_profile_admin_and_pin.py` for 4/6-digit numeric PIN validation, `hashlib.scrypt` hashing, constant-time verification, and 5-attempt per-Profile cooldown lockout (`429` + `retry_after_seconds`).
  - [ ] Implement `backend/app/core/profile_pin.py` and verify tests pass.
- [ ] **Step 2 — Backend Profile CRUD, PIN Management & Ticket Unlock (`profiles.py`, `auth.py`):**
  - [ ] Write failing integration tests for `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{id}`, `PUT /api/v1/profiles/{id}/pin`, and PIN-verified `POST /api/v1/auth/bootstrap/ticket` -> `POST /api/v1/auth/session/exchange`.
  - [ ] Implement backend routes and verify all backend pytest suites pass.
- [ ] **Step 3 — OpenAPI Contract & Dart Client Parity (`companion_api`):**
  - [ ] Export updated `contracts/openapi/openapi.json`.
  - [ ] Add `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` and update `CompanionClient` (`createProfile`, `renameProfile`, `updateProfilePin`, `establishProfileSession(profileId, {pin})`, `approveBrowserRequest(requestId, profileId, {pin})`).
  - [ ] Update `scripts/check_dart_openapi_parity.py` and `scripts/tests/test_check_dart_openapi_parity.py` (33 verified routes) and add `companion_client_test.dart` coverage.
- [ ] **Step 4 — Flutter Desktop Controllers (`DesktopChatController`, `DesktopProfileController`):**
  - [ ] Write failing controller tests in `frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart`.
  - [ ] Implement Profile creation, rename, PIN update, PIN-aware switching, active Profile locking, and `authenticatedProfileName` synchronization.
- [ ] **Step 5 — Flutter Desktop UI & 8 User Journeys:**
  - [ ] Write failing widget tests in `frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart` covering all 8 required user journeys.
  - [ ] Implement `profile_dialogs.dart`, `profile_selector_header.dart`, `profile_access_card.dart`, `desktop_navigation_rail.dart`, `desktop_shell.dart`, and `chat_screen.dart`.
- [ ] **Step 6 — Full Local Verification Gate:**
  - [ ] Verify `pytest`, `check_dart_openapi_parity.py`, `flutter analyze`, and `flutter test` across `companion_core`, `companion_api`, and `apps/desktop`.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2 COMPLETION)

- [ ] Reconcile canonical documentation (`profiles-and-devices.md`, `authentication-and-secrets.md`, `WBS.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `MASTER_CHECKLIST.md`, `DECISION_DEBT.md`, `task.md`, `CHANGELOG.md`).
- [ ] Archive this tracker to `docs/01_Tracking/archive/task-feature-m2-profile-admin-c.md`.
- [ ] Push implementation + closure commits to `origin/feature/m2-profile-admin-c` and open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Human Merge (PENDING PHASE 3)

- [ ] Present complete delivery package, test evidence, and CI status for Independent Review and Human Owner squash-merge approval.
