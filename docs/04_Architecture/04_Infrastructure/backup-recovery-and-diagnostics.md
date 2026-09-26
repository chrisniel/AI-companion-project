# Backup, Recovery, and Diagnostics Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) (§15) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Execution Baseline, Practical Backup & Recovery) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines disaster recovery, database snapshot mechanics, asset restoration, and diagnostic health monitoring for the AI Companion:
- Phased delivery boundary between **Practical Backup & Recovery** (PC V1) and a **Full Diagnostics Center** (unapproved exploratory recommendation).
- Coordinated backup of SQLite database records and associated binary media assets.
- Verification and dry-run testing of backup archives prior to restoration.
- Diagnostic observability, health probes, and runtime state inspection boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Critical Status Distinctions (PC V1 vs. Exploratory)

In accordance with the Feature Promotion Map and README authoring standards:
- **Practical Backup & Recovery (`APPROVED / NOT STARTED / PC V1`):** A mandatory requirement for PC V1 ensuring users can safely export, backup, and restore their companion database and associated personal assets without data loss.
- **Full Diagnostics / Recovery Center (`EXPLORATORY / UNAPPROVED / FUTURE`):** An exploratory audit recommendation for a dedicated desktop recovery console, deep log visualizer, or automated self-healing center. **This is NOT an approved PC V1 capability.** The presence of "Diagnostics" in this specification's title must **never** be used to silently promote a Diagnostics Center into PC V1.

### 2.2 Backup Consistency Invariants

- **Atomic Database Snapshotting:** SQLite database backups must be taken using SQLite's online backup API or read-locked snapshots to guarantee transaction consistency without database corruption.
- **Database-Asset Referential Coherence:** A backup archive must maintain referential coherence between database rows (conversations, messages, attachments) and associated physical binary files on disk (`ATTACHMENT_DIR`, `CHARACTER_DIR`).
- **Pre-Restoration Verification:** Restoration routines must perform preflight checks (checksum validation, schema version compatibility, SQLite integrity verification) before overwriting an active database.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Implemented Backup & Diagnostic Mechanisms

Verified in `backend/app/core/storage.py`, `backend/app/core/logging.py`, and `backend/app/api/v1/endpoints/health.py`:
- **Pre-Migration Snapshot:** During database startup migration assessment, `storage.py` automatically copies the existing database to `settings.BACKUP_DIR / f"pre_migration_backup_{timestamp}.db"` before executing any schema modifications.
- **Canonical Backup Directory:** `BACKUP_DIR` is derived and created under canonical storage (`%LOCALAPPDATA%\AICompanion\data\backups` by default).
- **Health & Status Endpoints:**
  - `GET /api/v1/health`: Public probe returning basic service liveness (`{"status": "ok"}`).
  - `GET /api/v1/system/status`: Authenticated endpoint returning system diagnostic metrics (database connectivity, model state, storage path status).
- **Diagnostic Logging:** Configured in `backend/app/core/logging.py` emitting structured console logs with log levels.

### 3.2 Implemented Reality Boundaries

- **User-Facing Backup Status:** **NOT IMPLEMENTED**. The current codebase contains no endpoint, CLI command, or UI control allowing a user to create a comprehensive backup archive, schedule automated backups, or restore from a past snapshot.
- **Asset Packaging Status:** **NOT IMPLEMENTED**. Pre-migration snapshots copy only the `.db` file; no mechanism currently bundles attachments, character lore cards, or settings into a unified archive.
- **Diagnostics Center Status:** **NOT IMPLEMENTED**. No graphical diagnostic dashboard, log viewer UI, or interactive recovery console exists in the application.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the backup and recovery capability will provide:

1. **Practical Database & Asset Archiver:** A coordinated backup utility that creates a self-contained archive containing:
   - Consistent snapshot of `companion.db`.
   - All referenced physical files in `ATTACHMENT_DIR` and `CHARACTER_DIR`.
   - Manifest file recording companion version, schema migration head, creation timestamp, and asset checksums.
2. **Restore Verification Engine:** A recovery routine that:
   - Takes a safety snapshot of the currently active state.
   - Inspects the backup archive for checksum and schema compatibility.
   - Restores database and physical files atomically.
   - Executes `PRAGMA integrity_check;` to verify post-restore health.
3. **Backup Management CLI / UI:** User-accessible controls to trigger a backup snapshot, inspect existing backup archives, and restore with confirmation.

---

## 5. OPEN DESIGN

The following implementation choices remain open design for future technical specification:

- **Archive Format & Compression:** Selection of archive container format (e.g., standard `.zip`, `.tar.gz`, or encrypted container) and compression algorithm.
- **Snapshot Scheduling:** Cadence and trigger mechanisms for automatic background backups (e.g., weekly background snapshot, pre-update automatic snapshot, or on-demand only).
- **Retention of Old Backups:** Rotation policy for pruning old automated backups in `BACKUP_DIR` to prevent unbounded disk growth.
- **Cloud / Offsite Export:** Options for users to easily mirror backup archives to their preferred personal cloud storage (e.g., OneDrive, Google Drive folder export) without the companion possessing direct cloud credentials.
- **Exploratory Diagnostics Center:** Future conceptual exploration of self-test suites, GPU benchmark viewers, or crash dump analyzers (post-V1).

---

## 6. Security & Ownership Boundaries

- **Backup Credential Protection:** Backup archives must **never** package cleartext API keys, third-party credentials, or environment secrets. When restored on a new machine, authentication tokens must be re-established.
- **Encryption of Backup Archives:** Where requested by the user, backup archives should support passphrase-based encryption (e.g., AES-256) to protect personal memories and photos during storage on external drives.
- **Owner Scope Validation:** Restoring a backup archive completely replaces the active local profile state; the restoration command requires local host confirmation to prevent unauthorized overwrite.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Practical Backup & Recovery (PC V1).
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Storage paths, backup directory, migration preflight rules.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Persistent storage layout, data root resolution, and migration snapshots.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md) — Retention periods and interaction with restored backups.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Background resource utilization during backup compression.
