# Backup, Recovery, and Diagnostics Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines disaster recovery, database snapshot mechanics, asset restoration, local admin factory reset, and diagnostic health monitoring for the AI Companion:
- Phased delivery boundary between **Practical Backup & Recovery** (PC V1) and a **Full Diagnostics Center** (unapproved exploratory recommendation).
- Coordinated backup of persistent SQLite database state and referenced profile assets.
- Pre-migration backup guarantee and staged restore verification with automatic pre-restore safety snapshots.
- Exclusion of models, application binaries, and cleartext secrets from backups.
- Local Admin Factory Reset capability with multi-step confirmation and asset retention controls.
- Diagnostic observability, health probes, and runtime state inspection boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Critical Status Distinctions (PC V1 vs. Exploratory)

In accordance with the Feature Promotion Map and Master Decision Register:
- **Practical Backup & Recovery (`APPROVED / PARTIAL / PC V1`):** PC V1 requires coordinated backup of the persistent database and referenced profile assets with integrity-preserving restore verification.
- **Local Admin Factory Reset (`APPROVED / NOT STARTED / PC V1`):** PC V1 requires a local admin-only reset capability to return the companion to first-run state while providing safe controls to preserve or prune large models and past backups.
- **Full Diagnostics / Recovery Center (`EXPLORATORY / UNAPPROVED / FUTURE`):** An exploratory audit recommendation for a dedicated desktop recovery console, deep log visualizer, or automated self-healing center. **This is NOT an approved PC V1 capability.** The presence of "Diagnostics" in this specification's title must **never** be used to silently promote a Diagnostics Center into PC V1.

### 2.2 Coordinated Backup & Asset Referential Coherence

In accordance with Master Decision Register Row 42:
- **Scope of Backup:** The backup archive captures:
  1. Consistent SQLite database snapshot (`companion.db`) captured via the SQLite online backup API;
  2. Referenced profile assets (custom avatars, media attachments, persona cards);
  3. Backup manifest containing timestamp, schema version, profile list, file inventory, and SHA-256 checksums.
- **Excluded Assets:** Backups strictly **exclude**:
  - Model weights (`LIBRARY_ROOT`) due to gigabyte-scale storage;
  - Application distribution binaries (`APP_INSTALL_ROOT`);
  - Ephemeral caches and temporary buffers (`CACHE_ROOT`);
  - Cleartext secrets, device pairing tokens, and API keys.
- **Pre-Migration Safety Snapshot:** A backup snapshot must automatically be taken before applying any schema-altering migration to an active canonical database.

### 2.3 Staged Restore & Safety Snapshot Verification

- **Pre-Restore Safety Snapshot:** Prior to overwriting active database or asset state during a restore, the runtime automatically captures a safety snapshot of current data. If restoration fails or corrupts state, the pre-restore snapshot can be restored immediately.
- **Staged Verification:** The restore process unpacks into a temporary staging folder, validates archive manifest integrity, verifies SHA-256 checksums, and inspects database schema version compatibility before promoting staged files into active canonical directories.

### 2.4 Local Admin Factory Reset

In accordance with Master Decision Register Row 43:
- **First-Run State Restoration:** Returns the companion to a clean, newly installed state (clearing database tables, user profiles, conversation history, and ephemeral caches).
- **Preserved Distribution:** Does not uninstall or corrupt application binaries or runtime engines.
- **Model & Backup Retention Controls:** Large model weights in `LIBRARY_ROOT` and existing backup archives in `BACKUP_DIR` default to **KEEP**. The user must explicitly check separate opt-in checkboxes to delete models or wipe prior backups.
- **Local Admin Authority:** Factory reset can only be executed by a local administrator session on the host PC (never via remote satellite devices). It requires strong multi-step confirmation.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Implemented Backup & Diagnostic Mechanisms

Verified in `backend/app/core/storage.py`, `backend/app/core/logging.py`, and `backend/app/api/v1/`:
- **Legacy Migration Backup Snapshot:** In `backend/app/core/storage.py`, `execute_migration()` creates a logical SQLite backup of a legacy source into a temporary canonical file, verifies it, promotes it, and attempts to preserve an additional backup copy in `BACKUP_DIR` with naming equivalent to `companion.db.backup-<timestamp>`; failure of that extra copy is logged (while the original legacy source file remains untouched).
- **Canonical Backup Directory:** `BACKUP_DIR` is canonically derived under `COMPANION_DATA_ROOT/backups` and is created as needed by migration/backup execution paths.
- **Health & Status Endpoints:**
  - `GET /api/v1/health`: Public probe returning basic service liveness: `{"status": "healthy"}`.
  - `GET /api/v1/system/status`: Authenticated endpoint returning system diagnostic telemetry: `status`, `platform`, `python_version`, `hostname`, `cpu_count`, `version`, `database_connected`, and `timestamp`. *(Current `/api/v1/system/status` does NOT report model-state or storage-path telemetry).*
- **Diagnostic Logging:** Configured in `backend/app/core/logging.py` emitting standard Python console logs.

### 3.2 Implemented Reality Boundaries

- **User-Facing Backup Status:** **NOT IMPLEMENTED**. The current codebase contains no endpoint, CLI command, or UI control allowing a user to create a comprehensive backup archive, schedule automated backups, or restore from a past snapshot.
- **Asset Packaging Status:** **NOT IMPLEMENTED**. Migration backups copy only the SQLite database file; no mechanism currently bundles attachments, character lore cards, or settings into a unified archive.
- **Factory Reset Status:** **NOT IMPLEMENTED**. No reset endpoint, CLI helper, or UI modal exists in the application.
- **Diagnostics Center Status:** **NOT IMPLEMENTED**. No graphical diagnostic dashboard, log viewer UI, or interactive recovery console exists in the application.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the backup, recovery, and diagnostics capability provides:

1. **Practical Database & Profile Asset Backup:** Coordinated snapshot capturing `companion.db` and referenced media/profile assets into a timestamped bundle with SHA-256 checksums.
2. **Pre-Migration Automatic Backup:** Guardrail capturing a fresh backup snapshot prior to applying any Alembic schema migration.
3. **Staged Restore with Pre-Restore Snapshot:** Safe restore workflow staging files, verifying manifest and checksums, and backing up current state before overwriting active data.
4. **Local Admin Factory Reset:** Multi-step reset workflow returning the companion to first-run state with explicit checkboxes for deleting models and past backups.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Archive Format:** Container packaging choice (e.g., standard `.zip` vs. `.tar.gz` with manifest).
- **Passphrase Encryption:** Optional AES-256 encryption for user backup archives exported to external drives or cloud sync folders.
- **Automated Backup Cadence:** Optional background backup schedule (e.g., weekly or pre-update) and rotation limit (e.g., keep last 5 backups).

---

## 6. Security & Ownership Boundaries

- **Local Admin Authority:** Both restore and factory reset operations strictly require local admin authentication on the host workstation. Remote satellite devices and unauthenticated sessions must never be allowed to trigger restore or reset.
- **Backup Credential Protection:** Backup archives must **never** package cleartext API keys, third-party credentials, or environment secrets. When restored on a new machine, authentication tokens must be re-established.
- **Safe Pre-Restore Verification:** A restore must never proceed if manifest checksums fail or database version is forward-incompatible with the currently installed application code.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Decision Spine
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Practical Backup & Recovery (PC V1), Factory Reset.
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) — Master Decision Register (Row 42 Practical Backup & Restore, Row 43 Local Admin Factory Reset).
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — Open backup technical debt.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Persistent storage layout, 5 roots, and migration safety.
- [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) — Multi-profile storage and isolation.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md) — Retention periods, soft-delete windows, and interaction with restored backups.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Background resource utilization during backup compression.

