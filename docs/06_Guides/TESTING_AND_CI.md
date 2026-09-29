# Testing Standards & CI Governance Guide

> **Document Role:** Canonical verification and CI pipeline reference for all contributors and automated agents.  
> **Status:** Active Canonical Guide  
> **Last Updated:** 2026-09-28 (Reconciliation Pass R12.4 CI Governance Target Alignment)

---

## 1. Verification Strategy & Scope

The AI Companion project maintains a strict test-first verification discipline. Changes across backend routes, database models, frontend UI, or mobile components must be accompanied by automated verification before merging or release.

### Verified Test Suites & Last Verified Baselines

> [!NOTE]
> **Baseline Attribution:**
> - **PC Baseline (Backend, Frontend, Contract):** Verified on merged `develop` commit `7dc15286d77c5bb5ee207351974e05b988f746e5` via GitHub Actions CI Run #25 on 2026-09-29 (0 failures, 0 errors, zero OpenAPI drift).
> - **Android Baseline:** Last executed and verified from Reconciliation Pass R8 on 2026-09-21 (124 passed; not rerun during Phase 8B).

| Subsystem | Test Framework | Test Location | Last Verified Baseline | Primary Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Backend** | `pytest` + `httpx` + `pytest-asyncio` | `backend/tests/` | **321 passed** (Merged `develop` / CI #25, 2026-09-29) | Fast REST/SSE endpoints, memory, tasks, storage, models, auth, attachments, media resolver |
| **Frontend** | `vitest` + React Testing Library | `frontend/web/src/` | **185 passed across 9 files** (Merged `develop` / CI #25, 2026-09-29) | Components, hooks, state, navigation, controls, soft-glass rendering, composer attachments |
| **Android** | `JUnit4` + `Robolectric` + `Roborazzi` + `kotlinx-coroutines-test` | `android/app/src/test/` | **124 passed** (Pass R8, 2026-09-21) | ViewModels, repository contracts, MVI state flow, Compose UI components, screenshot regression |
| **Contract** | Python drift detection script | `contracts/openapi/` | **Synchronized (22 routes, zero drift)** (Merged `develop` / CI #23, 2026-09-25) | OpenAPI 3.1 schema equality between FastAPI routes and committed spec |

### Verification Hierarchy: Automated CI vs. Golden Acceptance Gate
The project distinguishes two complementary verification tiers:
- **Level 1 — Automated CI (Code, Contract & Build Gatekeeper):** Automated, fast, deterministic checks running at configured integration and release boundaries per the P25 event matrix (§3.2). Covers unit tests, component tests, static typing, build verification, and OpenAPI contract drift detection. Automated CI provides repeatable code-level protection, but cannot substitute for integrated release acceptance.
- **Level 2 — Golden PC V1 Acceptance Journey (Release Gatekeeper):** Comprehensive, end-to-end companion verification path proving seamless operation across 17 integrated Golden acceptance checkpoint groups covering all mandatory PC V1 capabilities (detailed in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) §8). Evaluates real Windows host processes, physical/virtual audio devices, native OS notifications, user interactive journeys, and restart/restore persistence that headless CI environments cannot fully simulate. Passing the Golden Gate is the mandatory prerequisite for tagging a PC V1 release.

---

## 2. Local Verification Commands

Run these commands locally before opening pull requests or handing over tasks:

### A. Backend Verification
From repository root (ensure virtual environment is active):

```powershell
# Set ephemeral testing configuration (prevents modifying local user database)
$env:COMPANION_API_KEY = "ci-ephemeral-test-key"
$env:COMPANION_DATA_ROOT = Join-Path $env:TEMP "ai-companion-test"

# Run full backend test suite
python -m pytest backend/tests -q
```

### B. OpenAPI Contract Verification
The project enforces schema synchronization between the FastAPI routes and the committed OpenAPI specification:

```powershell
# Check mode: Returns exit code 0 if synchronized; exit code 1 if drift detected
python scripts/check_openapi_contract.py

# Write mode: Regenerates contracts/openapi/openapi.json to match current FastAPI definitions
python scripts/check_openapi_contract.py --write
```

### C. Frontend Verification
From repository root:

```powershell
# 1. Run Vitest unit & component test suite
npm --prefix frontend/web test -- --run

# 2. Run TypeScript static typecheck
npm --prefix frontend/web run lint

# 3. Verify production Vite bundle build
npm --prefix frontend/web run build
```

### D. Android Verification
From repository root:

```powershell
# Run Android unit and Robolectric test suite
cd android
.\gradlew.bat :app:testDebugUnitTest
```

---

## 3. Continuous Integration (CI) Workflow Structure

### 3.1 Current Workflow Reality
The current automated GitHub Actions workflow is defined in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).
- **Execution Environment:** Windows Server (`windows-latest`) for both jobs to preserve Windows host fidelity.
- **Concurrency:** `group: ci-${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true` to prevent redundant in-flight runs.
- **Current Triggers:** Pushes to `develop`, `master`, and `feature/**`; pull requests to `develop` and `master`; manual trigger via `workflow_dispatch`.
- **Jobs:**
  1. **`backend` (Windows / Python 3.11):** Ephemeral data root, dependency installation, OpenAPI contract check (`scripts/check_openapi_contract.py`), and backend pytest suite.
  2. **`frontend` (Windows / Node 22):** Clean npm ci, Vitest suite, TypeScript compilation check (`npm run lint`), and Vite production bundle build (`npm run build`).
  3. **`ci-gate`:** Downstream aggregation job declared with `needs: [backend, frontend]`. (See §4 for current failure aggregation limitation).

### 3.2 Reconciled Target Branch & Event Matrix (P25 Cost-Conscious CI Governance)
To eliminate redundant runner minute consumption while hardening release integrity, Pass R12.4 establishes the approved P25 target event matrix:

| Git Event / Trigger | Target Execution Policy | Governance Rationale |
| :--- | :--- | :--- |
| **Push to `feature/**`** | **No automatic heavy full CI by default.** | Primary verification occurs locally via developer execution of targeted suites (`pytest`, `vitest`, contract check). Prevents burning expensive runner minutes on rapid, iterative, or WIP feature commits. |
| **Pull Request → `develop`** | **No heavy full CI by default.** | Intentionally avoids triplicating full verification across feature push, develop PR, and develop push. Future lightweight metadata, lint, or docs checks may be evaluated, but heavy full CI is reserved for integration points. |
| **Push to `develop`** | **Run full required verification.** | Serves as the primary integration gatekeeper for merged code. A safe docs-only optimization MAY be evaluated to skip expensive test runs on documentation-only changes, provided it is strictly proven never to bypass required protection or code validation. No broad `paths-ignore` that could weaken integration checks. |
| **Pull Request → `master`** | **Run full required verification.** | Critical release and production boundary. Must pass completely before merge approval. Master protection must never be bypassed by broad paths-ignore or skip behavior. |
| **Push to `master`** | **Run full required verification.** | Production baseline verification. Any future automated CD, packaging, or release artifacts may trigger only after full required verification succeeds. |
| **`workflow_dispatch`** | **Full CI available on all branches.** | Allows manual, explicit invocation of the full CI pipeline on demand for any branch or verification requirement. |

### 3.3 Runner Cost Governance & Resource Policy
- **Windows Runner Baseline:** Current execution on `windows-latest` reflects host-runtime parity for the Windows-first PC V1 platform.
- **Linux Runner Offloading as Evaluation Candidate:** Offloading platform-agnostic test suites (e.g., frontend Vitest/lint, backend unit tests) to Linux runners is recognized as an approved cost-optimization evaluation candidate, **not** a locked R12.4 requirement. Any future runner topology shift must preserve mandatory Windows runner verification wherever Windows-specific APIs, paths, or host behaviors are evaluated.
- **Concurrency Protection:** Preserving `cancel-in-progress: true` ensures that superseded commits immediately abort running workflows, preventing wasted runner minutes.

---

## 4. CI Gate Governance & Branch Protection Prerequisite

### 4.1 Current CI Gate Limitation
In the current [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml), the `ci-gate` job specifies `needs: [backend, frontend]` without an explicit failure condition aggregator (such as `if: always()`). Under standard GitHub Actions semantics, if either `backend` or `frontend` fails, `ci-gate` is **skipped** rather than executed as a failure. Consequently, `ci-gate` cannot currently be set as a required status check on GitHub without prematurely passing or being ignored on failure.

### 4.2 Target `ci-gate` Failure-Aggregation Semantics
Pass R12.4 formalizes the required target behavior for `ci-gate` (approved target classification: `APPROVED PRE-V1 GOVERNANCE TARGET (P25)`):
1. **Always-Running Execution:** `ci-gate` must execute unconditionally via an always-run condition (`if: always()`).
2. **Explicit Inspection of Upstream Jobs:** It must inspect the actual result of all required upstream jobs (`backend`, `frontend`, and any future required verification jobs).
3. **Deterministic Evaluation:**
   - **SUCCESS:** `ci-gate` resolves success only if every required upstream verification job succeeded (or was intentionally skipped under an approved, safe, verified policy).
   - **FAILURE:** `ci-gate` fails if any required upstream job failed, timed out, was cancelled, or was unexpectedly skipped.
   - **Skip Distinction:** An intentional policy-based skip (e.g., a safe docs-only push to `develop`) must be programmatically distinguishable from an accidental or broken prerequisite skip.

### 4.3 Branch Protection & Administrative Governance
- **Target Aggregate Status Check:** `ci-gate` is designed as the single aggregate verification surface for branch protection.
- **Reliability Prerequisite:** Its always-running failure-aggregation behavior must be implemented, tested, and verified on a temporary branch before being configured as a required status check in GitHub.
- **Master Branch Invariant:** Branch protection on `master` must never be bypassed by broad `paths-ignore` or skip behavior. Both `pull_request → master` and `push → master` require full verification.
- **Decoupled Develop Policy:** Exact branch-protection configuration on `develop` remains a separate administrative/governance decision and is not prematurely locked to match `master`.
- **Administrative Ownership:** Actual configuration of GitHub branch-protection rules remains user-owned administrative work outside automated agent authority. `ci-gate` is **not** automatically declared required on every protected branch.

> [!IMPORTANT]
> **Implementation Boundary:** Target CI governance and failure aggregation semantics are codified as policy in Pass R12.4. Documenting target governance does **not** constitute workflow implementation. The workflow file [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) remains unchanged during documentation reconciliation; actual YAML modification belongs to a dedicated infrastructure implementation task.
