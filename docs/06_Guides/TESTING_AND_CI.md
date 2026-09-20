# Testing Standards & CI Governance Guide

> **Document Role:** Canonical verification and CI pipeline reference for all contributors and automated agents.  
> **Status:** Active Canonical Guide  
> **Last Updated:** 2026-09-21 (Reconciliation Pass R4)

---

## 1. Verification Strategy & Scope

The AI Companion project maintains a strict test-first verification discipline. Changes across backend routes, database models, frontend UI, or mobile components must be accompanied by automated verification before merging or release.

### Verified Test Suites & Last Verified Baselines

> [!NOTE]
> **Baseline Attribution:** The passing test counts below represent the last formally executed and verified repository baselines (established during Phase 8 / 8P deliveries). Documentation reconciliation passes (R0–R8) operate under read-only mode and do not freshly execute complete test suites.

| Subsystem | Test Framework | Test Location | Last Verified Baseline | Primary Scope |
| :--- | :--- | :--- | :--- | :--- |
| **Backend** | `pytest` + `httpx` + `pytest-asyncio` | `backend/tests/` | **88 passed** (Phase 8P) | Fast REST/SSE endpoints, memory, tasks, storage, models, auth |
| **Frontend** | `vitest` + React Testing Library | `frontend/web/src/` | **132 passed** (Phase 8A) | Components, hooks, state, navigation, controls, soft-glass rendering |
| **Android** | `JUnit4` + `Robolectric` + `Roborazzi` + `kotlinx-coroutines-test` | `android/app/src/test/` | **110 passed** (Phase 8 UI) | ViewModels, repository contracts, MVI state flow, Compose UI components, screenshot regression |
| **Contract** | Python drift detection script | `contracts/openapi/` | **Deterministic** (CI Verified) | OpenAPI 3.1 schema equality between FastAPI routes and committed spec |

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

The automated GitHub Actions workflow is defined in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). It triggers on:
- Pushes to `develop`, `master`, and `feature/**` branches.
- Pull requests targeting `develop` and `master`.
- Manual execution via `workflow_dispatch`.

### CI Jobs

1. **`backend` (Windows / Python 3.11)**:
   - Sets up Python 3.11 with pip caching.
   - Configures an ephemeral `COMPANION_DATA_ROOT` inside `$env:RUNNER_TEMP`.
   - Installs backend dependencies from `backend/requirements.txt`.
   - Executes `python scripts/check_openapi_contract.py` to guarantee zero contract drift.
   - Runs `python -m pytest backend/tests -q`.

2. **`frontend` (Windows / Node 22)**:
   - Sets up Node.js 22 with npm caching.
   - Installs dependencies cleanly via `npm --prefix frontend/web ci`.
   - Runs Vitest suite: `npm --prefix frontend/web test -- --run`.
   - Runs TypeScript compilation check: `npm --prefix frontend/web run lint`.
   - Runs Vite production build: `npm --prefix frontend/web run build`.

3. **`ci-gate`**:
   - Aggregation job declared as `needs: [backend, frontend]`.
   - Intended as the unified status check for repository branch protection.

---

## 4. CI Gate Governance & Branch Protection Prerequisite

> [!IMPORTANT]
> **Current CI Gate Governance Limitation**:  
> In the current `.github/workflows/ci.yml`, the `ci-gate` job specifies `needs: [backend, frontend]` without an explicit failure condition aggregator (such as `if: always()`). Under standard GitHub Actions semantics, if either `backend` or `frontend` fails, `ci-gate` is **skipped** rather than executed as a failure.

### Required Hardening Steps Before Enabling Branch Protection
Before `ci-gate` can be configured as a required status check in GitHub branch protection rules, the following hardening steps must be executed:

1. **Implement Always-Running Failure Aggregation**:
   Update `ci-gate` with:
   ```yaml
   ci-gate:
     name: CI Gate
     needs: [backend, frontend]
     runs-on: windows-latest
     if: always()
     steps:
       - name: Evaluate pipeline status
         shell: pwsh
         run: |
           if ("${{ needs.backend.result }}" -ne "success" -or "${{ needs.frontend.result }}" -ne "success") {
             Write-Error "One or more verification gates failed. Backend: ${{ needs.backend.result }}, Frontend: ${{ needs.frontend.result }}"
             exit 1
           }
           Write-Host "All verification gates passed successfully."
   ```
2. **Intentional Failure Verification**:
   Trigger a controlled pipeline failure on a temporary branch to verify that `ci-gate` actually fails when a prerequisite fails.
3. **Configure Branch Protection**:
   Only after failure aggregation is verified may repository administrators mark `CI Gate` as a required status check on `develop` or `master`.

> [!CAUTION]
> Do not modify `.github/workflows/ci.yml` or configure branch protection during documentation reconciliation passes (R0–R8). CI changes must be executed as dedicated infrastructure tasks.
