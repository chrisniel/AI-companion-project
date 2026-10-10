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
| **Flutter Desktop** | `flutter_test` + `dart analyze` | `frontend/flutter/` | Windows desktop shell, tray lifecycle, navigation rail, widgets, fail-closed auth, chat streaming, Markdown tables |
| **React Web** | `vitest` + React Testing Library | `frontend/web/src/` | Developer test harness, components, state hooks, control panels, soft-glass rendering |
| **Android** | `JUnit4` + `Robolectric` + `Roborazzi` | `android/app/src/test/` | ViewModels, repository contracts, MVI state flow, Compose UI screenshot regression |
| **Contract** | Python drift detection script | `contracts/openapi/` | OpenAPI 3.1 schema equality between FastAPI routes and committed specification |
| **Migrations** | `alembic` + SQLite preflight runners | `backend/migrations/` | Schema migration safety, preflight legacy detection, non-destructive upgrades |

### 1.2 Two-Tier Verification Hierarchy

The project distinguishes two complementary verification tiers:

- **Level 1 — Automated CI (Code, Contract & Build Gatekeeper):** Pull requests to `develop` use scoped checks; every push to `develop` runs all existing lanes against the integrated tree. Covers unit tests, component tests, static typing, build verification, and OpenAPI contract drift detection. Automated CI provides repeatable code-level protection, but cannot substitute for integrated release acceptance.
- **Level 2 — Golden PC V1 Acceptance Checklist (Release Gatekeeper):** Comprehensive, end-to-end companion verification path proving seamless operation across the **14 Golden Acceptance Checkpoint Groups** covering all mandatory PC V1 capabilities (defined in [`SYSTEM_BASELINE.md §5`](../04_Architecture/SYSTEM_BASELINE.md#5-golden-pc-v1-acceptance-gate-14-verification-groups)). Evaluates real Windows host processes, physical/virtual audio devices, native OS notifications, user interactive journeys, and restart/restore persistence that headless CI environments cannot fully simulate. Passing the Golden Gate is the mandatory prerequisite for tagging a PC V1 release.

- G1 Installation / startup / process lifecycle
- G2 Account / multi-Profile / privacy isolation
- G3 Runtime / models / D6
- G4 Conversation / durable queues / multimodal
- G5 Character / Personality / Emotion
- G6 Memory / historical continuity
- G7 Typed actions / D9 policy
- G8 Scheduler / native notifications
- G9 Voice / real barge-in
- G10 Current information / web security
- G11 Local-only + optional cloud
- G12 Low-Impact / Gaming
- G13 Backup / deletion / restore / Factory Reset
- G14 Remote client + final resilience

---

## 2. Local Verification Commands

Run these commands locally before opening pull requests or handing over tasks:

### A. Backend Verification
From repository root, use `$qualificationPython` from [DEVELOPMENT_SETUP.md §4](DEVELOPMENT_SETUP.md#4-backend-development-startup-fastapi), pointing to the separate temporary Python 3.11 environment. No activation is required:

```powershell
# Select disposable configuration and storage BEFORE application imports
$testRoot = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $testRoot | Out-Null
$env:COMPANION_ENV_FILE = Join-Path $testRoot "synthetic.env"
New-Item -ItemType File -Path $env:COMPANION_ENV_FILE | Out-Null
$env:COMPANION_API_KEY = "ci-ephemeral-test-key"
$env:COMPANION_DATA_ROOT = Join-Path $testRoot "data"
$env:LOCALAPPDATA = Join-Path $testRoot "local-appdata"

# Prove import/collection isolation before running the application suite
& $qualificationPython -I -B backend/tests/test_import_isolation.py -v
if ($LASTEXITCODE -ne 0) { throw "Import/collection isolation failed; do not run the suite." }

# Run full backend test suite
& $qualificationPython -B -m pytest backend/tests -q -p no:cacheprovider -o log_file=NUL
if ($LASTEXITCODE -ne 0) { throw "Backend verification failed." }

# Verify existing CI coverage policy separately
& $qualificationPython -B -m unittest scripts/tests/test_ci_policy.py
if ($LASTEXITCODE -ne 0) { throw "CI policy verification failed." }

# Verify exact dependency closure and lock validation separately
& $qualificationPython -I -B scripts/python_dependency_lock.py verify
if ($LASTEXITCODE -ne 0) { throw "Installed dependencies differ from the qualified lock." }
& $qualificationPython -I -B scripts/tests/test_python_dependency_lock.py
if ($LASTEXITCODE -ne 0) { throw "Lock validation regressions failed." }
```

Use the explicit selected Python 3.11 environment executable for every command. The isolation regression installs guards around real imports and collection; `backend/tests/conftest.py` establishes synthetic authentication/configuration before application imports. On CPython 3.11, guarded children cache read-only Windows platform metadata before installing the guard; application imports retain the subprocess, authentication and database restrictions. Local Python 3.13 results remain secondary evidence. Install `backend/requirements.lock` as described in the setup guide: it contains the qualified Windows x64 CPython 3.11.9 runtime/test wheel closure and pinned installer, rather than unconstrained declaration ranges. Exact installed-set verification and `pip check` are required in addition to hash-checked installation.

### B. OpenAPI Contract Drift Verification
FastAPI routes must strictly match the committed OpenAPI specification. Use the disposable configuration/storage above before importing the application:

```powershell
# Check mode: Exit code 0 if synchronized; exit code 1 if drift detected
& $qualificationPython -B scripts/check_openapi_contract.py --check
if ($LASTEXITCODE -ne 0) { throw "OpenAPI contract verification failed." }

# Write mode: Regenerates contracts/openapi/openapi.json to match current FastAPI definitions
& $qualificationPython -B scripts/check_openapi_contract.py --write
```

### C. Flutter Desktop Verification (Primary Client)
From `frontend/flutter/` (Monorepo Pub Workspace):

```powershell
# 1. Fetch workspace dependencies
flutter pub get

# 2. Run static analysis across packages and apps
dart analyze .

# 3. Run all unit and widget tests across the workspace
flutter test

# Optional: Run tests for a specific workspace package
flutter test packages/companion_core
flutter test packages/companion_api
flutter test packages/companion_design
flutter test apps/desktop
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

### 3.1 Implemented Workflow Reality
The automated GitHub Actions workflow is defined in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) and relies on a script-driven classification architecture.
- **Concurrency:** `cancel-in-progress: true` cancels superseded runs. Every replacement `develop` push runs all existing lanes against its integrated tree, including docs-only pushes, so cancellation cannot replace earlier required backend verification with a scoped docs-only green gate. Cancellation alone does not establish cumulative coverage.
- **Active Jobs:**
  1. **`classifier` (Ubuntu):** Executes static tests for `scripts/ci_policy.py`, then classifies PR diffs to output boolean requirements (`needs_backend`, `needs_frontend`, `needs_flutter`, etc.). Pushes to `develop`, events targeting `master`, and manual dispatch require all lanes without relying on a path diff.
  2. **`docs-integrity` (Ubuntu):** Conditionally executed if `needs_docs` is true. Performs fast file-presence and diff-formatting checks.
  3. **`backend` (Windows x64 / CPython 3.11.9):** Conditionally executed if `needs_backend` is true. Disposable authentication/configuration and storage, a fresh runner-temporary environment, hash-checked wheel-only installation from `backend/requirements.lock`, exact dependency closure, interpreter metadata and `pip check`, lock regressions, guarded import/collection isolation, then the backend pytest suite.
  4. **`contract` (Windows x64 / CPython 3.11.9):** Conditionally executed if `needs_contract` is true. Its own fresh environment and disposable configuration/storage, the same locked installation/closure checks and `pip check`, guarded import/collection isolation, then OpenAPI contract equality.
  5. **`frontend` (Windows / Node 22.22.2):** Conditionally executed if `needs_frontend` is true. Records Node/npm versions, then clean npm ci, Vitest suite, TypeScript compilation check, and Vite production bundle build.
  6. **`flutter` (Windows / Flutter 3.47.1):** Conditionally executed if `needs_flutter` is true (`frontend/flutter/**`). Fetches workspace dependencies, executes `dart analyze .`, and runs all `flutter test` suites across the workspace.
  7. **`ci-gate` (Ubuntu):** Downstream aggregation job that evaluates the aggregate status of all required and skipped jobs.

### 3.2 Event Policy Matrix

To eliminate redundant runner minute consumption while hardening release integrity, the CI implements the following execution policy:

| Git Event / Trigger | Execution Policy | Governance Rationale |
| :--- | :--- | :--- |
| **Push ordinary short-lived branch** (`feature/**`, `chore/**`, `docs/**`, `fix/**`, `refactor/**`, etc.) | **No automatic CI workflow.** | Primary verification occurs locally. Prevents burning expensive runner minutes on rapid, WIP branch commits. |
| **Pull Request → `develop`** | **Path-aware / scoped CI.** | Targets verification strictly to the subsystems modified in the PR diff (e.g., frontend only, backend only, flutter only). |
| **Push to `develop`** | **Full integration CI: all existing lanes.** | Each integrated tree is verified cumulatively, including a later docs-only push replacing a cancelled backend run. |
| **Pull Request → `master`** | **Full PC V1 CI.** | Critical release boundary. Must pass completely before merge approval. Target branch extraction overrides diff scopes. |
| **Push to `master`** | **Full PC V1 CI.** | Production baseline verification. Required before any release packaging. |
| **`workflow_dispatch`** | **Full CI anywhere.** | Allows manual, explicit invocation of the full pipeline on any branch via strict parameter override. |
| **Docs-only PR → `develop`** | **classifier + docs-integrity + ci-gate** | Fast validation for `.md`/repo docs. `backend`, `frontend`, `flutter`, and `contract` are intentionally skipped. |

### 3.3 Path Mapping Rules
These rules scope PRs to `develop`; integration pushes retain full verification.
- **Backend changes** (`backend/**`) require both `backend` and `contract` lanes.
- **Contract changes** (`contracts/**`, `scripts/check_openapi_contract.py`) independently require the `contract` lane.
- **Frontend changes** (`frontend/web/**`) require the `frontend` lane.
- **Flutter changes** (`frontend/flutter/**`) require the `flutter` lane.
- **Mixed changes** (e.g., frontend + docs) correctly trigger both `frontend` and `docs-integrity`.
- **Unknown/Shared changes** (e.g., `.github/**`, `android/**`, unmapped `scripts/**`) trigger conservative **Full Verification** (all lanes active).

### 3.4 Qualification Evidence Boundaries

After authorized publication, review the actual candidate SHA's hosted Windows CPython 3.11.9 backend and contract results and Node 22.22.2 frontend result (a PR or explicit full `workflow_dispatch`). Review full `develop` integration CI separately after merge. Authored workflow policy and local classifier tests do not prove hosted execution. Python 3.13 local tests and contract generation do not replace Python 3.11 qualification; successful installation from version ranges also does not establish a complete dependency lock. Local and hosted results, published revisions and independent gates remain separate evidence in the active delivery record.

---

## 4. CI Gate Governance & Branch Protection Prerequisite

### 4.1 Strict `ci-gate` Failure-Aggregation Semantics
The `ci-gate` job enforces the CI matrix validity securely:
1. **Always-Running Execution:** `ci-gate` executes unconditionally via an always-run condition (`if: always()`).
2. **Explicit Dependency Inspection:** It feeds the boolean requirements (from the classifier) and the actual step results (success, skipped, failed, cancelled) into the `ci_policy.py gate` command.
3. **Deterministic Evaluation:**
   - **SUCCESS:** `ci-gate` exits 0 if and only if the classifier completed successfully, all required jobs explicitly report `success`, and all unrequired jobs explicitly report `skipped`.
   - **FAILURE:** `ci-gate` fails (exit 1) if requirements strings are missing/malformed, the classifier crashed, required jobs skipped/failed, or unrequired jobs unexpectedly ran. This ensures fail-closed CI gate evaluation.

> [!NOTE]
> **Branch Protection Separation:** Repository branch-protection configuration is separate from workflow implementation and must not be inferred from the existence of the `ci-gate` job. `ci-gate` merely provides a consolidated status check.
