# Git Branching & Release Workflow

This document defines the official workflow for branching, versioning, and deploying code. Following this process ensures that active development does not disrupt the stable, live application.

---

## Branch Structure

We maintain a separation between ongoing development and stable deployment using three types of branches:

* **`main` (Production)**
  * **Purpose:** Represents the live, deployed environment.
  * **Rule:** Must always be stable and deployable. No direct commits allowed. Code only enters `main` via approved Pull Requests from a release branch.
* **`develop` (Integration)**
  * **Purpose:** The staging ground for the next upcoming release. 
  * **Rule:** This is where completed features accumulate. It contains code that is ahead of production but may still be undergoing internal testing.
* **`feature/*` (Development)**
  * **Purpose:** Isolated branches for individual tasks, fixes, or features (e.g., `feature/login-page`, `bugfix/header-spacing`).
  * **Rule:** Branched off `develop` and merged back into `develop` via a Pull Request once completed and reviewed.

---

## The Release Process (Bundling Features)

Instead of deploying features one by one, we bundle multiple completed features from `develop` into a single deployment release. When ready to deploy, follow these steps:

### 1. Freeze & Branch
Stop merging new features into `develop`. Create a temporary release branch off `develop` named after the target version number:
```bash
git checkout develop
git pull origin develop
git checkout -b release/vX.X.X
```

### 2. Testing & Polish
Deploy the `release/vX.X.X` branch to a testing environment. 
* If bugs are discovered, commit the fixes **directly to this release branch**.
* Do **not** merge new feature branches into this release.

### 3. Deploy to Production
Once the release branch is verified as completely stable, open a Pull Request to merge `release/vX.X.X` into `main`. Once merged, trigger the deployment from the `main` branch.

### 4. Tag the Release
To create a permanent, immutable snapshot of this deployment, tag the commit on `main` using Semantic Versioning (`vMajor.Minor.Patch`):
```bash
git checkout main
git pull origin main
git tag -a vX.X.X -m "Tagging release vX.X.X"
git push origin vX.X.X
```

### 5. Sync & Clean Up
To ensure any bug fixes made during the testing phase are not lost, merge the release branch back into `develop`. Then, delete the temporary release branch:
```bash
git checkout develop
git merge release/vX.X.X
git push origin develop
git branch -d release/vX.X.X
```
