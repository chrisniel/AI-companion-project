# M2 Batch B — Profile Sessions, Authorization and Cross-Profile Isolation

> **Status:** IMPLEMENTED / LOCALLY VERIFIED — final independent PR-ready review pending.
> **Branch:** `feature/m2-profile-foundation-b`
> **Owner / authorization:** Chris; scoped correction, documentation and closure preparation, ordinary branch commits and HTTPS push authorized on 2026-10-15. No force-push, PR creation or merge.
> **Plan:** [Batch B implementation plan](../../02_Planning/01_Plans/plan-m2-profile-foundation-b.md)
> **Milestone:** Wider M2 remains **IN PROGRESS**.

## 1. Delivery and Review Checkpoints

- Initial Batch B implementation checkpoint: `806125bd5b2ba914afc93734173d2606f3208c17`.
- Saved-Profile startup correction checkpoint: `92225c86f7deb5f25b077e60f207f047eb8ab512`. Chris relayed independent confirmation that the original restart defect was corrected. This is not recorded as approval of the final expiry correction or all delivery gates.
- Final correction: authenticated `/auth/session/me` retains Profile metadata and returns the freshly validated persisted UTC `expires_at`. It does not renew expiry, `created_at` or `last_active_at`, including when an ORM identity map contains stale values.
- Flutter restoration uses the actual Profile identity and absolute server deadline. Expiry clears authority, conversations, messages, drafts, scroll positions, cached errors and subscriptions. Late asynchronous loads/switch completion cannot reinstate expired state. Typed SSE completion leaves transport cleanup intact; invalidation closes retained subscriptions.
- Saved expired/rejected credentials remain inert until explicit authorization, preventing restart from turning rejection into first-run Default bootstrap. Explicit switching still revokes old authority and clears private state; genuinely fresh authorized Default bootstrap remains supported.

## 2. Implemented Batch Boundary

- [x] Migration 008: session/grant tables, explicit ownership without SQLite/ORM defaults, synthetic migration preservation/rollback tests and fail-closed startup recovery.
- [x] Independent Windows Host Admin authority, Profile Session validation and Host Admin-only catalog.
- [x] Browser claim-secret proof, exact Origin/CSRF checks, explicit Desktop approval and atomic single-use exchange; no bearer credentials in URLs or persisted browser storage.
- [x] Personal-data and service isolation for conversations, messages, tasks, memories/FTS5 and attachments; continuing stream/download validation and trusted retention maintenance.
- [x] Flutter DPAPI Profile Session storage, existing-Profile selection, safe restart restoration and absolute-expiry cleanup; React in-memory session cutover.
- [x] Additive API response contract, generated OpenAPI and native/React client tests.
- [x] Canonical documentation and milestone/checklist/WBS/debt reconciliation prepared.
- [x] PR title, extended summary-only description and Conventional Commit squash message prepared below.
- [ ] Independent approval of final Implementation Gate.
- [ ] Independent Documentation Gate approval.
- [ ] Independent Closure Gate / final PR-ready approval; retain this active task until approved closure.

## 3. Local Verification Receipt — 2026-10-15

All data-bearing checks used synthetic credentials and disposable databases/storage. No production credentials or user data were used. Focused suite totals overlap with full suites.

| Working directory | Command | Confirmed result |
| :--- | :--- | :--- |
| Repository root | `backend/.venv/Scripts/python.exe -m pytest backend/tests/test_profile_sessions.py backend/tests/test_profile_authorization.py -q` | **90 passed**, exit 0 |
| Repository root | `backend/.venv/Scripts/python.exe -m pytest backend/tests -q` | **600 passed, 1 existing warning**, exit 0 |
| Repository root | `backend/.venv/Scripts/python.exe -m pytest scripts/tests -q` | **38 passed, 49 subtests passed**, exit 0 |
| `frontend/flutter/apps/desktop` | `flutter test --no-pub --concurrency=1 test/desktop_profile_expiry_test.dart test/desktop_profile_restore_test.dart test/desktop_profile_session_test.dart test/desktop_chat_test.dart test/desktop_app_runtime_wiring_test.dart` | **86 passed**, exit 0 |
| Each Flutter package/app listed below | `flutter test --no-pub --concurrency=1 --reporter expanded` | API **63**, core **22**, design **18**, Desktop **231**; **334 total passed**, each exit 0 |
| `frontend/flutter/apps/desktop` | `flutter test --no-pub --concurrency=1 test/desktop_profile_expiry_test.dart` | **11 passed** after final test-fixture resource cleanup, exit 0 |
| `frontend/flutter` | `flutter analyze --no-pub` | **No issues found**, exit 0 |
| `frontend/web` | `npm test` | **242 passed / 15 files**, exit 0 |
| `frontend/web` | `npm run lint` | TypeScript **passed**, exit 0 |
| `frontend/web` | `npm run build` | Production build **passed**, exit 0 |
| Repository root, isolated contract harness | `scripts/check_openapi_contract.py --check` | Exact generated match, **32 paths**, exit 0 |
| Repository root | `backend/.venv/Scripts/python.exe scripts/check_dart_openapi_parity.py` | **13 DTOs / 18 covered route methods**, passed, exit 0 |
| Repository root, changed Markdown only | Local delivery Markdown checker | **12 files / 80 relative links**, balanced fences and referenced headings, passed |
| Repository root | `git diff --check` | **Passed**; Git line-ending advisories only |

Flutter suites ran serially in `frontend/flutter/packages/companion_api`, `companion_core`, `companion_design`, then `frontend/flutter/apps/desktop`. Windows runtime acceptance checks were automated and disposable; they do not constitute manual Desktop/browser acceptance.

The contract harness ran `backend/.venv/Scripts/python.exe .superpowers/sdd/plan-m2-profile-foundation-b/final-expiry-contract-runner.py --check`; it configured an isolated temporary environment before invoking the repository checker. Local raw receipts are ignored files under `.superpowers/sdd/plan-m2-profile-foundation-b/final-expiry-*.log`; the commands and confirmed results above are the portable delivery evidence.

TDD receipts: backend exact-expiry tests first failed because `expires_at` was absent (**2 failed / 5 rejection cases passed**). Flutter expiry/restoration tests first failed (**4 failed**); additional error/subscription/late-switch cases reproduced **3 failures** before correction. All corresponding final regressions passed. Existing chat, admin, browser approval and runtime regression suites passed.

The backend run used the existing **Python 3.13.14** environment; Python 3.11 qualification is **NOT VERIFIED**. The full backend warning is the existing Starlette `HTTP_422_UNPROCESSABLE_ENTITY` deprecation in model selection testing. Initial Flutter analysis found a test fixture sink-close lint; the fixture was corrected, its 11 tests rerun and final analysis passed with no issues.

## 4. Independent Review and Outstanding Acceptance

| Evidence / gate | State |
| :--- | :--- |
| Scoped AI implementation review | No remaining confirmed correctness blocker after expiry/error/subscription/late-switch regressions; advisory review only |
| Final independent Implementation, Documentation and Closure Gates | **PENDING**; no self-approval |
| Hosted PR/candidate CI | **NOT RUN**; no PR created |
| Hosted branch CI | **NOT VERIFIED**; no hosted pass inferred from local checks |
| Post-merge integration / CI | **NOT APPLICABLE / NOT VERIFIED**; no merge performed |
| Windows ACL and native Desktop/browser manual acceptance | **PENDING** |
| Python 3.11 qualification | **NOT VERIFIED** |
| Wider M2 | **IN PROGRESS** |

Manual acceptance still requires trusted-host ACL inspection, Profile B restart with the same server expiry, expiry clearing visible private state/streams, explicit switching, rejection of expired/revoked authority and explicit browser approval/refresh behavior with no credentials in URLs or browser storage. These steps have not been represented as completed.

Full Profile CRUD, PIN enrollment/unlock challenge, device registry/enrollment, recoverable Profile deletion and Character Studio remain future work. This delivery does not close remote-browser authentication design, enrollment, packaging, restore-quiescence or other unrelated decision debt.

Canonical owners: [Profiles and devices](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md), [authentication and secrets](../../04_Architecture/02_Data_and_Security/authentication-and-secrets.md), [privacy and retention](../../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md), [memory](../../04_Architecture/01_Domains/memory-and-personalization.md). Master planning retains the wider milestone and readiness boundaries.

## 5. Prepared PR Handoff — Summary Only

**Title:** `feat(identity): add Profile sessions and cross-profile isolation`

**Extended description:**

Batch B replaces ambient pairing-key access to personal data with validated Profile Sessions and explicit Profile ownership. Migration 008 adds session and single-use grant persistence, removes implicit Profile defaults from the five personal-data tables and preserves existing records, foreign keys and FTS5 behavior. Startup migration failure retains the verified pre-migration snapshot and fails closed; live restoration requires separately authorized quiesced maintenance.

Pairing diagnostics, independent Windows Host Admin authority and Profile Sessions have distinct permissions. Host Admin owns catalog lookup and explicit Desktop browser approval. Browser authorization binds a short-lived request to the browser's claim secret and exact Origin, applies CSRF/transport controls and consumes the approved grant atomically. Browser sessions remain in memory, and bearer credentials never travel through URL queries or fragments. PIN-protected Profiles fail closed until an authorized unlock challenge exists.

Conversations, messages, tasks, memories/FTS5, attachments, generation streams and persistence enforce validated Profile ownership. Attachment streams and slow provider operations revalidate ongoing authority. Retention requires a validated Profile Session or the trusted maintenance runner's independent authority; arbitrary Profile identifiers do not grant access.

Flutter stores Profile Sessions through DPAPI, selects existing active unprotected Profiles and restores the authenticated Profile identity after restart. `/auth/session/me` preserves Profile metadata and returns the actual validated server expiry without renewal. Restoration and revalidation schedule that absolute deadline; expiry clears private data, drafts, cached errors and subscriptions, and late loads or switch completion cannot restore expired state. Explicit switching revokes prior authority. React uses in-memory sessions and retires persisted pairing keys; OpenAPI and client tests match the additive session metadata response.

Local verification passed: backend 600 tests with one existing deprecation warning; Flutter 334 tests and clean analysis; React 242 tests, typecheck and production build; script tests 38 plus 49 subtests; exact OpenAPI drift and Dart contract parity checks. Focused backend 90 and Desktop 86 tests passed. All data-bearing checks used synthetic credentials and disposable storage. Backend verification used Python 3.13.14; Python 3.11 qualification remains unverified.

Batch B is implemented and locally verified, with canonical documentation and closure records prepared for final independent review. Hosted PR CI has not run; hosted branch CI is unverified; Windows/Desktop/browser manual acceptance and independent delivery gates remain pending. Full Profile CRUD, PIN enrollment, device enrollment, Profile deletion lifecycle and Character Studio remain future work, and wider M2 remains in progress. No PR creation or merge is included in this handoff.

**Conventional Commit squash message:**

```text
feat(identity): add Profile sessions and cross-profile isolation

Establish independent Host Admin and Profile Session authority, proof-bound
Desktop-approved browser access, and explicit personal-data ownership.
Preserve saved Profile identity and server expiry across Desktop restart,
with expiry/switch cache and subscription invalidation.
Reconcile Batch B architecture and delivery evidence while retaining
pending independent gates, hosted PR CI, manual acceptance and wider M2 work.
```

## 6. Stop Boundary

Documentation/closure preparation is submitted for independent semantic review after mechanical checks. Commit and HTTPS-push only this authorized branch delivery, verify local and remote SHA, then **STOP FOR FINAL INDEPENDENT PR-READY REVIEW**. Do not self-approve gates, create a PR, merge, or archive this task before independently approved closure.

## 7. PR #27 CI Correction Checkpoint

- Chris authorized a surgical CI correction, verification, commit and push. PR #27 run `38762836880` failed Desktop acceptance when Windows process inspection exceeded its 3000ms deadline; dependent launch scenarios also failed. Backend, contract, web and documentation jobs passed on that candidate.
- Limited the Desktop CI test command to `--concurrency=1`, matching prior serial local verification and avoiding competing test files during real process inspection. All tests, runtime deadlines, provenance checks and fail-closed behavior remain unchanged.
- Local verification: concurrent baseline and corrected serial Desktop runs each passed **231 tests** on Flutter **3.47.1**, using the existing Python **3.13.14** environment; **24 CI policy tests passed**. The hosted timing failure was not reproduced locally. Hosted confirmation of the scheduling correction remains pending at this publication checkpoint; independent gates and manual acceptance remain pending.
