# Testing Standards & CI Governance Guide

> **Document Role:** Canonical verification and CI pipeline reference for all contributors and automated agents.  
> **Status:** Active Canonical Guide (PC V1 Frozen Baseline).  
> **Authority Precedence:** Implemented reality is owned by source code, automated test suites, and generated schema contracts. Cross-cutting release gates are owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md).

---

## 1. Verification Strategy & Scope

The AI Companion project maintains a strict test-first verification discipline. Changes across backend routes, database schemas, Flutter desktop UI, React developer harness, or mobile components must be accompanied by automated verification before merging or release.

### 1.1 Verified Subsystems & Test Frameworks

| Subsystem | Test Framework | Test Location | Primary Scope |
| :--- | :--- | :--- | :--- |
| **Backend** | `pytest` + `httpx` + `pytest-asyncio` | `backend/tests/` | REST/SSE endpoints, memory, tasks, storage roots, models, auth, attachments, media resolver |
| **Flutter Desktop** | `flutter_test` | `frontend/desktop/test/` | Windows desktop shell, tray lifecycle, navigation rail, widgets, voice audio UI |
| **React Web** | `vitest` + React Testing Library | `frontend/web/src/` | Developer test harness, components, state hooks, control panels, soft-glass rendering |
| **Android** | `JUnit4` + `Robolectric` + `Roborazzi` | `android/app/src/test/` | ViewModels, repository contracts, MVI state flow, Compose UI screenshot regression |
| **Contract** | Python drift detection script | `contracts/openapi/` | OpenAPI 3.1 schema equality between FastAPI routes and committed specification |
| **Migrations** | `alembic` + SQLite preflight runners | `backend/migrations/` | Schema migration safety, preflight legacy detection, non-destructive upgrades |

### 1.2 Two-Tier Verification Hierarchy

The project distinguishes two complementary verification tiers:

- **Level 1 — Automated Scoped CI (Code, Contract & Build Gatekeeper):** Fast, deterministic automated checks running at configured integration boundaries. Covers unit tests, component tests, static typing, build verification, and OpenAPI contract drift detection. Automated CI provides repeatable code-level protection, but cannot substitute for integrated release acceptance.
- **Level 2 — Golden PC V1 Acceptance Checklist (Release Gatekeeper):** Comprehensive, end-to-end companion verification path proving seamless operation across the **14 Golden Acceptance Checkpoint Groups** covering all mandatory PC V1 capabilities (defined in [`SYSTEM_BASELINE.md §8`](../04_Architecture/SYSTEM_BASELINE.md#8-golden-pc-v1-acceptance-checkpoint-groups)). Evaluates real Windows host processes, physical/virtual audio devices, native OS notifications, user interactive journeys, and restart/restore persistence that headless CI environments cannot fully simulate. Passing the Golden Gate is the mandatory prerequisite for tagging a PC V1 release.

---

## 2. Local Verification Commands

Run these commands locally before opening pull requests or handing over tasks:

### A. Backend Verification
From repository root (with active virtual environment):

```powershell
# Set ephemeral testing configuration (prevents modifying local user database)
$env:COMPANION_API_KEY = "ci-ephemeral-test-key"
$env:COMPANION_DATA_ROOT = Join-Path $env:TEMP "ai-companion-test"

# Run full backend test suite
python -m pytest backend/tests -q
```

### B. OpenAPI Contract Drift Verification
FastAPI routes must strictly match the committed OpenAPI specification:

```powershell
# Check mode: Exit code 0 if synchronized; exit code 1 if drift detected
python scripts/check_openapi_contract.py

# Write mode: Regenerates contracts/openapi/openapi.json to match current FastAPI definitions
python scripts/check_openapi_contract.py --write
```

### C. Flutter Desktop Verification (Primary Client)
From `frontend/desktop/` (once scaffolded):

```powershell
# 1. Run static analysis
flutter analyze

# 2. Run widget and unit tests
flutter test
```

### D. React Web Verification (Developer Harness)
From repository root:

```powershell
# 1. Run Vitest unit & component test suite
npm --prefix frontend/web test -- --run

# 2. Run TypeScript static typecheck
npm --prefix frontend/web run lint

# 3. Verify production Vite bundle build
npm --prefix frontend/web run build
```

### E. Android Verification (Reference / Prototype)
From repository root:

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest
```

---

## 3. Continuous Integration (CI) Workflow Structure

### 3.1 Current Workflow Reality
The automated GitHub Actions workflow is defined in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml).
- **Execution Environment:** Windows Server (`windows-latest`) preserving Windows host fidelity.
- **Concurrency:** `cancel-in-progress: true` preventing redundant in-flight runs.
- **Active Jobs:**
  1. **`backend` (Windows / Python 3.11):** Ephemeral data root, dependency installation, OpenAPI contract check, and backend pytest suite.
  2. **`frontend` (Windows / Node 22):** Clean npm ci, Vitest suite, TypeScript compilation check, and Vite production bundle build.
  3. **`ci-gate`:** Downstream aggregation job declared with `needs: [backend, frontend]`.

### 3.2 Target Event Matrix & Cost-Conscious CI Governance (P25)

To eliminate redundant runner minute consumption while hardening release integrity, the project adopts the following CI event policy:

| Git Event / Trigger | Target Execution Policy | Governance Rationale |
| :--- | :--- | :--- |
| **Push to `feature/**`** | **No automatic heavy full CI by default.** | Primary verification occurs locally via developer execution of targeted suites. Prevents burning expensive runner minutes on rapid, WIP feature commits. |
| **Pull Request → `develop`** | **No heavy full CI by default.** | Avoids triplicating full verification across feature push, develop PR, and develop push. Full verification runs on integration. |
| **Push to `develop`** | **Run full required verification.** | Primary integration gatekeeper for merged code. Safe docs-only push skip optimization permitted where proven safe. |
| **Pull Request → `master`** | **Run full required verification.** | Critical release boundary. Must pass completely before merge approval. No skip or paths-ignore allowed. |
| **Push to `master`** | **Run full required verification.** | Production baseline verification. Required before any release packaging. |
| **`workflow_dispatch`** | **Full CI available on demand.** | Allows manual, explicit invocation of the full CI pipeline on any branch. |

### 3.3 Runner Cost Governance
- **Windows Runner Parity:** Windows runner execution reflects host-runtime parity for the Windows-first PC V1 platform.
- **Linux Runner Offloading Candidate:** Offloading platform-agnostic test suites (e.g., frontend Vitest, lint, contract checks) to Linux runners is recognized as an approved cost-optimization evaluation candidate. Mandatory Windows runner verification is preserved wherever Windows-specific APIs or paths are evaluated.

---

## 4. CI Gate Governance & Branch Protection Prerequisite

### 4.1 Target `ci-gate` Failure-Aggregation Semantics
Pass R12.4 formalizes the required target behavior for `ci-gate`:
1. **Always-Running Execution:** `ci-gate` must execute unconditionally via an always-run condition (`if: always()`).
2. **Explicit Inspection of Upstream Jobs:** It must inspect the actual result of all required upstream jobs (`backend`, `frontend`, `contract`, and future `flutter`).
3. **Deterministic Evaluation:**
   - **SUCCESS:** `ci-gate` resolves success only if every required upstream verification job succeeded (or was intentionally skipped under an approved safe policy).
   - **FAILURE:** `ci-gate` fails if any required upstream job failed, timed out, was cancelled, or was unexpectedly skipped.

### 4.2 Implementation Safety Boundary

> [!IMPORTANT]
> **Implementation Boundary:** Target CI governance and failure aggregation semantics are codified as policy in this guide. Documenting target governance does **not** constitute workflow modification. The workflow file [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) remains unchanged during documentation canonicalization; actual YAML updates belong to a dedicated infrastructure implementation task.
