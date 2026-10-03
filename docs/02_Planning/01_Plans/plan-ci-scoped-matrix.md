# Implementation Plan: PC-VERIFY-001 CI Scoped Matrix

## 1. Objective
Execute PC-VERIFY-001 to modernize the continuous integration pipeline into a cost-conscious, path-aware matrix driven by a deterministic, testable Python policy, aligning implemented CI reality with the target architecture defined in `TESTING_AND_CI.md`.

## 2. PC-VERIFY-001 Scope
- Restructure `.github/workflows/ci.yml` into a classifier-driven model.
- Prevent heavy CI executions on WIP feature branch pushes.
- Introduce isolated contract verification and docs-integrity lanes.
- Enforce strict `ci-gate` failure/success aggregation across conditionally required jobs.
- Extract gating and classification logic into `scripts/ci_policy.py`.

## 3. Current Behavior
- Workflow triggers unconditionally on `push` to `feature/**`, `develop`, `master` and `pull_request` to `develop`, `master`.
- `backend` and `frontend` jobs execute fully regardless of modified paths.
- OpenAPI drift checking is embedded sequentially within the `backend` job.
- `ci-gate` job evaluates implicitly by depending on upstream success, lacking explicitly defined `if: always()` handling for skips vs. failures.

## 4. Target Behavior
- Workflow is governed by a `classifier` job. This job must execute `python -m py_compile scripts/ci_policy.py` and `python -m unittest scripts/tests/test_ci_policy.py` BEFORE using `ci_policy.py` for classification. A broken policy script/test fails the classifier, causing `ci-gate` to fail.
- `push` to `feature/**` does not trigger heavy CI.
- Conditionally executed `backend`, `frontend`, `contract`, and `docs-integrity` jobs.
- `ci-gate` evaluates upstream results strictly (failing on unexpected skips, cancellations, or failures in required lanes, passing on success or intentional skips).

## 5. Exact Event Matrix
| Event | Base | Head | Scope |
| :--- | :--- | :--- | :--- |
| `push` (`develop`, `master`) | `github.event.before` | `github.sha` | Scoped integration CI if develop. Full CI if master. |
| `push` (`feature/**`) | N/A | N/A | No automatic full CI (excluded at workflow trigger level). |
| `pull_request` | `github.event.pull_request.base.sha` | `github.event.pull_request.head.sha` | Scoped CI if develop. Full CI if master. |
| `workflow_dispatch` | N/A | N/A | Immediate Full CI override; no diff performed. |

## 6. Exact Path-Classification Matrix & Semantics
Explicit docs allowlist: `docs/**`, `*.md` in repository root (`AGENTS.md`, `CHANGELOG.md`, `README.md`, `CONTRIBUTING.md`).

- **docs_changed:** Any changed file matches the explicit docs allowlist.
- **docs_only:** All changed files match the explicit docs allowlist.

Classification outcomes based on changed paths:
- `backend/**` -> `needs_backend=true`, `needs_contract=true`
- `frontend/**` -> `needs_frontend=true`
- `contracts/**` or `scripts/check_openapi_contract.py` -> `needs_contract=true`
- **docs_changed** -> `needs_docs=true`
- Unknown/Unmapped (`.github/**`, `android/**`, `scripts/**` (excluding openapi), future flutter, etc.) -> Conservative **Full Verification** (all lanes forced `true`).

Combinations (Examples):
- **Docs only** -> `docs-integrity` only (`needs_docs=true`, others `false`).
- **Backend only** -> `backend` + `contract` (`needs_backend=true`, `needs_contract=true`, others `false`).
- **Backend + Docs** -> `backend` + `contract` + `docs-integrity`.
- **Frontend + Docs** -> `frontend` + `docs-integrity`.

## 7. Git Comparison Algorithm
Workflow orchestration handles fetching and producing the file list based on event type:
- **pull_request:** `git diff --name-only <base>...<head>`
- **push (develop/master):** `git diff --name-only <before>..<head>`
- **workflow_dispatch:** full verification override; no diff required for classification.

If the comparison range cannot safely be resolved, the pipeline will fall back conservatively to Full Verification.

## 8. Conservative Fallback Behavior
- If `base` SHA is empty/zero (e.g. `0000000000000000000000000000000000000000` on new branch), diffing is unsafe. Fallback to Full Verification.
- If event is `workflow_dispatch` or target branch is `master`, fallback to Full Verification.
- If changed files include unmapped/unknown paths, fallback to Full Verification.

## 9. Classifier Outputs
The classifier job sets standard GitHub Actions outputs:
- `needs_backend` (boolean string)
- `needs_frontend` (boolean string)
- `needs_contract` (boolean string)
- `needs_docs` (boolean string)

## 10. Contract Lane Setup
- New parallel job `contract`.
- Runs on `windows-latest` (maintaining current platform parity).
- Requires `backend` Python environment to execute `scripts/check_openapi_contract.py` (which imports `app.main`). Acknowledged dependency duplication tradeoff in favor of independent contract isolation.

## 11. Docs-Integrity Commands
Lightweight, repository-owned assertions (runs on `ubuntu-latest` for speed as it is purely Git/filesystem operations):
1. Diff check using the exact event comparison range:
   - **pull_request:** `git diff --check <base>...<head>`
   - **push:** `git diff --check <before>..<head>`
   - **workflow_dispatch:** `git diff --check` is explicitly N/A. (Do not invent `HEAD~1` as a substitute. Lack of a diff range must not fail an otherwise valid manual run).
   For push/pull_request, if the comparison range cannot safely be resolved, fall back conservatively rather than claiming docs integrity passed.
2. Canonical presence checks:
   - `test -f "docs/04_Architecture/SYSTEM_BASELINE.md"`
   - `test -f "AGENTS.md"`
   - `test -f "docs/06_Guides/DOCUMENTATION_MAP.md"`

## 12. CI-Gate Truth Table
Evaluated for each lane (backend, frontend, contract, docs-integrity):
- **Classifier Result:** success -> continue. failure/cancelled/skipped/unexpected -> FAIL.
- **Required Lane (needs_X = true):**
  - success -> PASS
  - failure / cancelled / skipped / unexpected / empty -> FAIL
- **Non-Required Lane (needs_X = false):**
  - skipped -> PASS
  - success / failure / cancelled / unexpected / empty -> FAIL

## 13. Proposed `ci_policy.py` Interface
Python standard-library script handling deterministic logic.
- `python scripts/ci_policy.py classify --event <event_name> --target-branch <branch> [--files-json <json_array>]`
  Outputs GitHub Actions key=value pairs.
- `python scripts/ci_policy.py gate --classifier-status <status> --requirements-json <json_dict> --results-json <json_dict>`
  Exits 0 (Pass) or 1 (Fail).

## 14. Unit-Test Matrix
Tested via `python -m unittest scripts/tests/test_ci_policy.py` without requiring backend dependencies.
- Verify `docs_changed` sets `needs_docs`.
- Verify `docs_only` excludes other lanes.
- Verify unknown files force Full CI.
- Verify zero-base / workflow_dispatch forces Full CI.
- Verify gate fails if required lane skips.
- Verify gate fails if non-required lane succeeds.
- Verify gate passes when required lanes succeed and non-required skip.

## 15. Expected Implementation Files
- `.github/workflows/ci.yml` (Modified)
- `scripts/ci_policy.py` (Created)
- `scripts/tests/test_ci_policy.py` (Created)
- `docs/01_Tracking/active/task-chore-ci-scoped-matrix.md` (Created)
- `docs/02_Planning/01_Plans/plan-ci-scoped-matrix.md` (Created)

## 16. Implementation Sequence
1. Implement `scripts/ci_policy.py` and `scripts/tests/test_ci_policy.py`.
2. Ensure `python -m unittest scripts/tests/test_ci_policy.py` passes.
3. Update `.github/workflows/ci.yml` to wire orchestration to the policy script.

## 17. Implementation Gate (Local/Static Verification)
- `python -m py_compile scripts/ci_policy.py` (Static syntax check).
- `python -m unittest scripts/tests/test_ci_policy.py` (Deterministic policy test).
- YAML and source code independent review.

## 18. Post-Closure PR Verification
Real event routing validation occurs on the active PR *after* the Closure Gate (no intentionally broken PRs). For this delivery (which modifies `.github/workflows/ci.yml` and scripts), live PR evidence should verify:
- `classifier` succeeds;
- workflow/config changes conservatively require Full Verification;
- `backend` succeeds;
- `frontend` succeeds;
- `contract` succeeds;
- `docs-integrity` succeeds;
- `ci-gate` succeeds.

Docs-only, backend-only, and frontend-only routing must be deterministically covered by `ci_policy` unit tests and may gain live integration evidence naturally on future real PRs.

## 19. Documentation Phase Expectations
- Reconcile `MASTER_CHECKLIST.md` (M0 blocker fix, insert PC-VERIFY-001 CI Gate evidence row). *Note: record only implementation/local/static verification available at this stage. Do NOT claim PR CI, live event-routing, merge, or post-merge evidence before it exists.*
- Reconcile `SPRINT_ROADMAP.md` (M0 Complete, insert Phone Arch Pass before M1).
- Reconcile `DELIVERY_INDEX.md` (Update milestone table sequencing).
- Update `TESTING_AND_CI.md` to indicate target governance is now implemented.

## 20. Closure Phase Expectations
- Finalize the active branch task (`task-chore-ci-scoped-matrix.md`).
- Archive it on the same branch as: `docs/01_Tracking/archive/task-[YYYY-MM-DD]-chore-ci-scoped-matrix.md`.
- Remove the active task file from `active/`.
- Append Unreleased changes to `CHANGELOG.md` as applicable.
- Prepare PR/squash handoff (Conventional Commit proposal).

## 21. Risks
- Fetch depth in CI might fail to resolve required SHAs for PR diffing. Mitigated by explicit `fetch-depth` orchestration and script fallback to Full CI on missing SHAs.
- `git diff --check` could fail unexpectedly on Windows line endings in `ubuntu-latest`. Git configuration in Actions may need `core.autocrlf` normalization.

## 22. Stop Conditions
- Stop immediately after plan creation for human approval.
- Stop after implementation for Implementation Gate review (local/static verification only).
- Stop after documentation edits for human review (Documentation Gate).
- Stop after closure for human review (Closure Gate).
- Remote PR verification happens post-closure.

## 23. Rollback / Recovery Considerations
- **Before merge:** repair/revise workflow on this same delivery branch.
- **After squash merge:** if the workflow is materially broken, use a bounded human-created corrective/hotfix branch from develop to restore known-good CI behavior. (Preserves human-only Git authority).
