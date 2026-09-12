# Git Branching & Engineering Workflow Guide

This document defines the official engineering workflow for branching, commit conventions, versioning, and releases. Designed as a universal standard, this workflow ensures that active development remains isolated, traceable, and stable across projects.

---

## 1. Core Branch Hierarchy

We maintain strict separation between development, integration, and production environments:

| Branch Type | Name Pattern | Base Branch | Merges Into | Purpose & Rules |
| :--- | :--- | :--- | :--- | :--- |
| **Production** | `main` (or `master`) | — | — | **Always stable and deployable.** Direct commits are strictly prohibited. Code enters only via approved Pull Requests from a release or hotfix branch. |
| **Integration** | `develop` | `main` | `main` | **Staging and integration ground.** Where verified feature branches accumulate. May contain work ahead of production undergoing integration testing. |
| **Feature** | `feature/<domain-or-topic>` | `develop` | `develop` | **New capabilities, UI/UX polish, and domain work.** Isolated development. Merged back into `develop` via PR once verified. |
| **Bugfix** | `fix/<issue-name>` | `develop` | `develop` | **Non-critical defect resolution.** Isolated fixes during regular sprints. |
| **Release** | `release/vX.Y.Z` | `develop` | `main` & `develop` | **Version freeze & stabilization.** Testing, documentation, and polish for a planned production cut. |
| **Hotfix** | `hotfix/<critical-issue>` | `main` | `main` & `develop` | **Emergency production fixes.** Patches deployed directly to live environments outside normal release cycles. |

---

## 2. Branch Naming Standards (Industry Best Practice)

> [!IMPORTANT]
> **Rule: Never put version numbers in feature branch names.**
> - ❌ *Incorrect:* `feature/v1.3-login`, `feature/v1.4-ui-update`
> - ✅ *Correct:* `feature/login-authentication`, `feature/android-ui-ux-adjustments`
>
> *Why?* Version numbers belong strictly to **Release Branches** (`release/v1.4.0`) and **Git Tags** (`v1.4.0`). Features can be reprioritized or bundled into different releases; naming feature branches by domain or capability keeps your Git history clean, professional, and decoupled from release scheduling.

### Recommended Naming Conventions:
* `feature/<domain>-<topic>` — (e.g. `feature/android-ui-ux-adjustments`, `feature/chat-composer`)
* `fix/<subsystem>-<defect>` — (e.g. `fix/topbar-double-padding`, `fix/auth-token-refresh`)
* `refactor/<subsystem>` — (e.g. `refactor/neumorphic-shadow-engine`)
* `docs/<topic>` — (e.g. `docs/architecture-reconciliation`)
* `perf/<area>` — (e.g. `perf/helio-g99-page-transitions`)

---

## 3. Iterative Work & Branch Continuation

When polishing or refining a subsystem across consecutive sessions:
1. **Continue on the Active Feature Branch**: Do not create fragmented micro-branches for related iterative feedback. Keep working on the existing domain branch (e.g., `feature/android-ui-ux-adjustments`) until the entire milestone is verified.
2. **Rename if Scope Expands**: If a feature branch's scope broadens beyond its initial title, rename it locally and remotely using:
   ```bash
   git branch -m <old-name> <new-generalized-name>
   ```
3. **Keep Commits Coherent**: Commit each meaningful milestone as a self-contained unit following Conventional Commits before moving to the next task.

---

## 4. Conventional Commit Standards

Every commit must use structured, semantic prefixes:

* `feat(...)`: A new user-facing feature or enhancement.
* `fix(...)`: A bug or defect resolution.
* `refactor(...)`: Code improvement that neither fixes a bug nor adds a feature.
* `perf(...)`: Performance optimization.
* `test(...)`: Adding or correcting tests.
* `docs(...)`: Documentation additions or updates.
* `chore(...)`: Tooling, configuration, or dependency maintenance.

**Example Format:**
```text
feat(android): implement dual-shadow neumorphic engine and glass parity

- Cast physical top-left light and bottom-right dark drop shadows via BlurMaskFilter.
- Remove opaque fills across secondary screens to restore ambient glass background.
- Normalize top insets to eliminate double status bar padding.
```

---

## 5. Release Process (Bundling & Deploying)

When a collection of features on `develop` is ready for release:

### 1. Cut the Release Branch
```bash
git checkout develop
git pull origin develop
git checkout -b release/vX.Y.Z
```

### 2. Test & Stabilize
Deploy to staging/test hardware. Fix any release-blocking defects directly on `release/vX.Y.Z`. Do **not** merge new unrelated features into this branch.

### 3. Deploy to Production & Tag
Merge into `main`, deploy, and create an annotated tag:
```bash
git checkout main
git merge --no-ff release/vX.Y.Z
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main --tags
```

### 4. Back-Merge into Integration
Sync any release fixes back into `develop` and delete the temporary release branch:
```bash
git checkout develop
git merge --no-ff release/vX.Y.Z
git push origin develop
git branch -d release/vX.Y.Z
```

---

## 6. AI Agent Pair-Programming Protocol

When working alongside an AI coding assistant:
1. **Branch Alignment**: The AI operates on an agreed feature branch (`feature/<domain>`). Branch creation or renaming requires user approval.
2. **Read-Only by Default**: The AI inspects and reports; state-changing commands or code edits require an approved plan.
3. **Automated Checkpoints**: When authorized, the AI commits completed major changes with clear Conventional Commit messages, leaving push and pull-request merging to the user.
4. **Verification Requirement**: No change is marked complete without running automated tests (`./gradlew.bat testDebugUnitTest`) and, where applicable, physical hardware verification.
