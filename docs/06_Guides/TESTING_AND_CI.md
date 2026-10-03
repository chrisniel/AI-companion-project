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
| **Flutter Desktop** | `flutter_test` | `(FUTURE/TARGET path TBD)` | (Target - Not Yet Scaffolded) Windows desktop shell, tray lifecycle, navigation rail, widgets, voice audio UI |
| **React Web** | `vitest` + React Testing Library | `frontend/web/src/` | Developer test harness, components, state hooks, control panels, soft-glass rendering |
| **Android** | `JUnit4` + `Robolectric` + `Roborazzi` | `android/app/src/test/` | ViewModels, repository contracts, MVI state flow, Compose UI screenshot regression |
| **Contract** | Python drift detection script | `contracts/openapi/` | OpenAPI 3.1 schema equality between FastAPI routes and committed specification |
| **Migrations** | `alembic` + SQLite preflight runners | `backend/migrations/` | Schema migration safety, preflight legacy detection, non-destructive upgrades |

### 1.2 Two-Tier Verification Hierarchy

The project distinguishes two complementary verification tiers:

- **Level 1 — Automated Scoped CI (Code, Contract & Build Gatekeeper):** Fast, deterministic automated checks running at configured integration boundaries. Covers unit tests, component tests, static typing, build verification, and OpenAPI contract drift detection. Automated CI provides repeatable code-level protection, but cannot substitute for integrated release acceptance.
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
From the Flutter target path (FUTURE/TARGET, once scaffolded):

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

### 3.1 Implemented Workflow Reality
The automated GitHub Actions workflow is defined in [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) and relies on a script-driven classification architecture.
- **Concurrency:** `cancel-in-progress: true` prevents redundant in-flight runs.
- **Active Jobs:**
  1. **`classifier` (Ubuntu):** Executes static tests for `scripts/ci_policy.py`, then evaluates Git diffs (PR or Push) against a deterministic matrix to output boolean requirements (`needs_backend`, `needs_frontend`, etc.).
  2. **`docs-integrity` (Ubuntu):** Conditionally executed if `needs_docs` is true. Performs fast file-presence and diff-formatting checks.
  3. **`backend` (Windows / Python 3.11):** Conditionally executed if `needs_backend` is true. Ephemeral data root, dependency installation, and backend pytest suite.
  4. **`contract` (Windows / Python 3.11):** Conditionally executed if `needs_contract` is true. Verifies OpenAPI contract equality.
  5. **`frontend` (Windows / Node 22):** Conditionally executed if `needs_frontend` is true. Clean npm ci, Vitest suite, TypeScript compilation check, and Vite production bundle build.
  6. **`ci-gate` (Ubuntu):** Downstream aggregation job that provides the aggregate status intended to serve as the single required CI status when/if repository branch protection requires it.

*Note: Future Flutter desktop verification will be added as an independent Windows job lane.*

### 3.2 Event Policy Matrix

To eliminate redundant runner minute consumption while hardening release integrity, the CI implements the following execution policy:

| Git Event / Trigger | Execution Policy | Governance Rationale |
| :--- | :--- | :--- |
| **Push ordinary short-lived branch** (`feature/**`, `chore/**`, `docs/**`, `fix/**`, `refactor/**`, etc.) | **No automatic CI workflow.** | Primary verification occurs locally. Prevents burning expensive runner minutes on rapid, WIP branch commits. |
| **Pull Request → `develop`** | **Path-aware / scoped CI.** | Targets verification strictly to the subsystems modified in the PR diff (e.g., frontend only, backend only). |
| **Push to `develop`** | **Scoped integration CI.** | Primary integration gatekeeper for merged code, verifying interacting subsystems modified since the last passing baseline. |
| **Pull Request → `master`** | **Full PC V1 CI.** | Critical release boundary. Must pass completely before merge approval. Target branch extraction overrides diff scopes. |
| **Push to `master`** | **Full PC V1 CI.** | Production baseline verification. Required before any release packaging. |
| **`workflow_dispatch`** | **Full CI anywhere.** | Allows manual, explicit invocation of the full pipeline on any branch via strict parameter override. |
| **Docs-only PR → `develop`** | **classifier + docs-integrity + ci-gate** | Fast validation for `.md`/repo docs. `backend`, `frontend`, and `contract` are intentionally skipped. |

### 3.3 Path Mapping Rules
- **Backend changes** (`backend/**`) require both `backend` and `contract` lanes.
- **Contract changes** (`contracts/**`, `scripts/check_openapi_contract.py`) independently require the `contract` lane.
- **Mixed changes** (e.g., frontend + docs) correctly trigger both `frontend` and `docs-integrity`.
- **Unknown/Shared changes** (e.g., `.github/**`, `android/**`, unmapped `scripts/**`) trigger conservative **Full Verification** (all lanes active).

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
