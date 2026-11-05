# Active Branch Execution Tracker — Milestone M2 Profile Administration Batch C

- **Branch:** `feature/m2-profile-admin-c`
- **Base Integration Branch:** `develop` (`a3b206767f813344a35b1e0663a9c4a93e333d1f`)
- **Delivery Level:** Level C — Sensitive Design
- **Work Breakdown Structure IDs:** `PC-IDENTITY-004` (Local Profile Administration & Persistent Selection), `PC-CLIENT-005` (Desktop Profile Selector & Management UI)
- **Implementation Plan:** [`docs/02_Planning/01_Plans/plan-m2-profile-admin-c.md`](../../02_Planning/01_Plans/plan-m2-profile-admin-c.md)
- **Current Lifecycle Phase:** **PHASE 1 — REVISED PLAN PUBLISHED (AWAITING HUMAN OWNER & INDEPENDENT REVIEWER APPROVAL)**

---

## Phase 1: Planning & Design Authorization (COMPLETED — REVISED)

- [x] Verify clean `develop` baseline at `a3b206767f813344a35b1e0663a9c4a93e333d1f` and passing post-merge GitHub Actions CI (`Run 41988869571`).
- [x] Create and switch to dedicated delivery branch `feature/m2-profile-admin-c`.
- [x] Publish initial Phase 1 plan checkpoint (`2b2846299204ea15c286e08f5d2bb426c08dcba2`).
- [x] Apply Human Owner Phase 1 scope revision:
  - Defer Profile PIN implementation (`profile_pin.py`, PIN endpoints, lockouts, and PIN dialogs) from Batch C while preserving existing `profiles.pin_hash` column and fail-closed rejection (`403`) on any pre-existing PIN-protected Profile.
  - Prioritize persistent selected-Profile UUID across Flutter and Windows restarts (`DesktopClientSettings`), initial Personal Profile context (`is_default == true`), bounded one-shot natural-expiry Host Admin startup re-establishment, and acquire-before-teardown Profile switching that preserves the current Profile if destination authorization fails.
- [x] Commit and push revised Phase 1 planning artifacts to `origin/feature/m2-profile-admin-c` and halt at the Level C Plan Approval Gate.

---

## Phase 2: Autonomous Implementation & Verification (PENDING PLAN APPROVAL)

- [ ] **Step 1 — Backend Local Profile Creation & Rename (`backend/app/api/v1/endpoints/profiles.py`):**
  - [ ] Write failing integration tests in `backend/tests/test_profile_admin.py` covering `POST /api/v1/profiles` (Host Admin check, `1..32` char trimmed name validation, control-character rejection, case-insensitive duplicate name `409 Conflict`, `is_default=False` preservation, Neutral Assistant fallback compatibility), `PATCH /api/v1/profiles/{profile_id}` (in-place rename preserving UUID and all owned conversations/memories/tasks/characters/sessions), and existing PIN-protected Profile fail-closed check (`403`).
  - [ ] Implement `POST /api/v1/profiles`, `PATCH /api/v1/profiles/{profile_id}`, and deterministic catalog ordering in `backend/app/api/v1/endpoints/profiles.py`.
- [ ] **Step 2 — OpenAPI Contract & Dart Client Parity (`companion_api`):**
  - [ ] Export updated `contracts/openapi/openapi.json`.
  - [ ] Add `frontend/flutter/packages/companion_api/lib/dto/profile_dto.dart` (`ProfileMetadata`, `ProfileCreateRequest`, `ProfileUpdateRequest`) and update `CompanionClient` (`createProfile`, `renameProfile`, acquire-before-teardown session helpers).
  - [ ] Update `scripts/check_dart_openapi_parity.py` and `scripts/tests/test_check_dart_openapi_parity.py` (`32` verified routes) and add `companion_client_test.dart` coverage.
- [ ] **Step 3 — Persistent Profile Preference & Acquire-Before-Teardown Switching (`apps/desktop`):**
  - [ ] Extend `DesktopClientSettings` with `selectedProfileId`, `selectedProfileSessionExpiry`, and `profileExplicitlyLocked`.
  - [ ] Update `DesktopChatController` (acquire-before-teardown `selectProfile`, `authenticatedProfileName`, `authenticatedSessionExpiry`) and `DesktopProfileController` (startup restoration, bounded natural-expiry re-bootstrap, explicit lock preservation, `createProfile`, `renameProfile`, `switchToProfile`, `lockActiveProfile`).
  - [ ] Add automated tests in `frontend/flutter/apps/desktop/test/desktop_profile_admin_test.dart` and update switch mutation-order assertions in `desktop_profile_session_test.dart` and `desktop_profile_restore_test.dart`.
- [ ] **Step 4 — Flutter Desktop Profile Management & Selector UI:**
  - [ ] Implement `profile_dialogs.dart` (Create Profile & Rename Profile dialogs), `profile_selector_header.dart`, `profile_access_card.dart`, `desktop_navigation_rail.dart`, `desktop_shell.dart`, `chat_screen.dart`, and `main.dart`.
  - [ ] Verify all 16 required acceptance criteria in `desktop_profile_admin_test.dart`.
- [ ] **Step 5 — Full Local Verification Gate:**
  - [ ] Verify `pytest`, `check_dart_openapi_parity.py`, `flutter analyze`, and `flutter test` across `companion_core`, `companion_api`, and `apps/desktop`.

---

## Phase 3: Documentation, Closure & Draft PR (PENDING PHASE 2 COMPLETION)

- [ ] Reconcile canonical documentation (`profiles-and-devices.md`, `authentication-and-secrets.md`, `WBS.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `MASTER_CHECKLIST.md`, `task.md`, `CHANGELOG.md`).
- [ ] Archive this tracker to `docs/01_Tracking/archive/task-feature-m2-profile-admin-c.md`.
- [ ] Push implementation + closure commits to `origin/feature/m2-profile-admin-c` and open Draft PR against `develop`.

---

## Phase 4: Combined Independent Review & Human Merge (PENDING PHASE 3)

- [ ] Present complete delivery package, test evidence, and CI status for Independent Review and Human Owner squash-merge approval.
