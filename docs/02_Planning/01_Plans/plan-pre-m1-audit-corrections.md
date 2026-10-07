# Implementation Plan: Pre-M1 Audit Corrections

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: B1 authorized; independent isolation review pending.
- Scope Mode: Surgical Fix — supplied audit disposition B1–B6, not M1.
- Planning basis: Chris's supplied F01–F13 disposition and B1–B6 corrective plan.
- Approval: Chris authorized B1 source/test corrections only in the current implementation instruction.
- Execution/evidence owner: [branch tracker](../../01_Tracking/active/task-fix-pre-m1-audit-corrections.md).

## 1. Request Understanding & Goals

Persist the supplied delivery scope once, without a competing plan. Establish safe
verification bootstrap and reproducible toolchain inputs in B1. Stop at the F09
isolation checkpoint before broad application-suite execution. B2–B6 remain pending
execution authorization; their policy proposals remain unapproved.

| Batch | Findings | Supplied scope | Authorization |
| --- | --- | --- | --- |
| B1 | F09, F04, F12 | Import/collection isolation; Python 3.11 dependency qualification; compatible Node inputs | Source/test corrections authorized; installations and broad qualification gated |
| B2 | F01, F02, F07 | Error terminals; provider-owned active work; logging across startup migrations | Pending execution |
| B3 | F05 | Task omission/null semantics and generated contract | Pending execution and semantics approval |
| B4 | F03 | Cumulative integration coverage invariant | Pending execution and CI-policy approval |
| B5 | F10, F11, F13 | Closest-owner documentation reconciliation and resulting setup guidance | Pending execution |
| B6 | F06, F08 | Retention CLI lifecycle; existing-locator integrity | Pending execution and policy approval |

## 2. Current Findings & Technical Root Cause

F09: configuration initializes/persists a token during import, before fixture-level
isolation. F04: declared inputs are open-ended; existing local environments are not
an approved dependency set. F12: generic Node 22 documentation omits the committed
dependency engine minimum. Python 3.13 observations do not prove incompatibility.

## 3. B1 File Allowlist & Invariants

- `backend/app/core/config.py`, `backend/tests/conftest.py`.
- `backend/requirements.txt`, `backend/pyproject.toml`.
- `frontend/web/package.json`, `frontend/web/package-lock.json`.
- `.github/workflows/ci.yml`: interpreter/dependency inputs only, no F03 routing/cancellation.
- Potential additions: `backend/tests/test_import_isolation.py`, `backend/requirements.lock`.
- Governance records: this supplied-scope plan and the designated branch tracker,
  expressly authorized by Chris where required by the delivery workflow.

Preserve AGENTS.md and all existing environments, real authentication files and
user data. No Git mutations, system interpreter replacement, real-model runtime,
OpenAPI regeneration to conceal drift, unrelated upgrades, or M1 implementation.

## 4. Supplied Execution Sequence

1. Verify branch/baseline and user changes; safely reproduce F09 before source edits.
2. Make configuration import non-persisting; select disposable configuration and
   synthetic authentication/storage before test application imports.
3. Prove actual import and collection isolation; submit evidence for independent
   review and STOP before broad application-suite execution.
4. Inspect tool metadata without application settings; consolidate exact installation
   approval only after an interpreter/resolver choice can be established.
5. After safety and environment approvals, resolve declared inputs in a new isolated
   environment and qualify actual imports/tests/OpenAPI and web tests/typecheck/build.
6. Stop at B1 review; never advance automatically to B2.

## 5. Acceptance & Verification

Actual-module subprocess regressions must reject real auth/data access, show import
does not create credentials, preserve valid synthetic credentials, and constrain
explicit credential persistence to supplied disposable configuration. Collection
must establish isolation before application imports. Narrow diagnostics under an
existing Python are not Python 3.11 qualification. Record commands/results in the
branch tracker; no self-approval or hosted-CI claims.

## 6. Risks & Recovery

Failing reproductions must deny real local-state access before importing the faulty
module. Existing environment/configuration changes are prohibited. Missing Python
3.11 or unresolved installation choices are blockers, not permission to substitute
an interpreter, freeze a local environment, or attempt speculative installation.
