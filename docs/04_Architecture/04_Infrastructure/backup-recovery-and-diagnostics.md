# Backup, Recovery, and Diagnostics Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines disaster recovery, database snapshot mechanics, asset restoration, and diagnostic health monitoring for the AI Companion:
- Phased delivery boundary between **Practical Backup & Recovery** (PC V1) and a **Full Diagnostics Center** (unapproved exploratory recommendation).
- Coordinated backup of persistent database state and required referenced assets.
- Restore verification and recovery-safety boundaries prior to modifying active state.
- Diagnostic observability, health probes, and runtime state inspection boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Critical Status Distinctions (PC V1 vs. Exploratory)

In accordance with the Feature Promotion Map and README authoring standards:
- **Practical Backup & Recovery (`APPROVED / NOT STARTED / PC V1`):** PC V1 requires practical backup and recovery of the persistent database and required referenced assets with integrity-preserving restore verification. The archive and export mechanism remains open design.
- **Full Diagnostics / Recovery Center (`EXPLORATORY / UNAPPROVED / FUTURE`):** An exploratory audit recommendation for a dedicated desktop recovery console, deep log visualizer, or automated self-healing center. **This is NOT an approved PC V1 capability.** The presence of "Diagnostics" in this specification's title must **never** be used to silently promote a Diagnostics Center into PC V1.

### 2.2 Backup Consistency Invariants (PC V1 Durable Requirement)

- **Practical Recovery Requirement:** PC V1 requires practical backup and recovery of the persistent database and required referenced assets with integrity-preserving restore verification.
- **Database-Asset Referential Coherence:** Backup and recovery mechanisms must preserve referential coherence between database records (conversations, messages, attachments) and required referenced physical assets (such as attachments and character assets).
- **Safe Restore Verification:** Restoration procedures must perform preflight checks (such as integrity verification and schema compatibility checks) before overwriting active database state to prevent data corruption.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Implemented Backup & Diagnostic Mechanisms

Verified in `backend/app/core/storage.py`, `backend/app/core/logging.py`, and `backend/app/api/v1/`:
- **Legacy Migration Backup Snapshot:** In `backend/app/core/storage.py`, `execute_migration()` creates a logical SQLite backup of a legacy source into a temporary canonical file, verifies it, promotes it, and attempts to preserve an additional backup copy in `BACKUP_DIR` with naming equivalent to `companion.db.backup-<timestamp>`; failure of that extra copy is logged (while the original legacy source file remains untouched).
  *(Note: This backup is not automatically performed before every Alembic schema upgrade on an already-canonical database).*
- **Canonical Backup Directory:** `BACKUP_DIR` is canonically derived under `COMPANION_DATA_ROOT/backups` and is created as needed by migration/backup execution paths.
- **Health & Status Endpoints:**
  - `GET /api/v1/health`: Public probe returning basic service liveness: `{"status": "healthy"}`.
  - `GET /api/v1/system/status`: Authenticated endpoint returning system diagnostic telemetry: `status`, `platform`, `python_version`, `hostname`, `cpu_count`, `version`, `database_connected`, and `timestamp`. *(Current `/api/v1/system/status` does NOT report model-state or storage-path telemetry).*
- **Diagnostic Logging:** Configured in `backend/app/core/logging.py` emitting standard Python console logs.

### 3.2 Implemented Reality Boundaries

- **User-Facing Backup Status:** **NOT IMPLEMENTED**. The current codebase contains no endpoint, CLI command, or UI control allowing a user to create a comprehensive backup archive, schedule automated backups, or restore from a past snapshot.
- **Asset Packaging Status:** **NOT IMPLEMENTED**. Migration backups copy only the SQLite database file; no mechanism currently bundles attachments, character lore cards, or settings into a unified archive.
- **Diagnostics Center Status:** **NOT IMPLEMENTED**. No graphical diagnostic dashboard, log viewer UI, or interactive recovery console exists in the application.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the backup and recovery capability provides:

1. **Practical Database & Asset Recovery:** Coordinated backup capability capturing the companion's persistent database along with required referenced assets on disk.
2. **Safe Restore Verification:** Restoration routine that verifies backup integrity and schema compatibility before safely restoring the database and associated assets.

---

## 5. OPEN DESIGN

The following implementation choices remain open design for future technical specification:

- **Backup Snapshot Mechanism:** Choice of snapshot implementation (e.g., SQLite online backup API, read-locked snapshot, or file copy).
- **Archive Format & Compression:** Selection of archive container format (e.g., standard `.zip`, `.tar.gz`, or directory bundle) and compression algorithms.
- **Archive Manifest & Checksums:** Exact schema of the backup manifest file, version identifiers, and asset checksum algorithms.
- **Included Directory Coverage:** Exact list of included asset folders and exclusions (e.g., whether to include ephemeral caches or thumbnail variants).
- **User Control Surface:** Whether backup and restore are triggered via a dedicated CLI command, a web settings UI, or both.
- **Snapshot Scheduling & Retention:** Cadence and trigger mechanisms for automatic background backups, along with rotation/pruning policies for old backups in `BACKUP_DIR`.
- **Passphrase Encryption:** Design and cipher choices for optional passphrase-encrypted archives (e.g., AES-256).
- **Restoration Semantics:** Full-profile replacement vs. selective entity merge during restore operations.
- **Exploratory Diagnostics Center:** Future conceptual exploration of self-test suites, GPU benchmark viewers, or crash dump analyzers (post-V1, `EXPLORATORY / UNAPPROVED / FUTURE`).

---

## 6. Security & Ownership Boundaries

- **Backup Credential Protection:** Backup archives must **never** package cleartext API keys, third-party credentials, or environment secrets. When restored on a new machine, authentication tokens must be re-established.
- **Restore Authorization:** Restore operations require explicit local authorization/confirmation and must preserve integrity. Exact restoration semantics (full-profile replacement vs. selective merge vs. entity-level restore) remain open design.
- **Encryption for Offsite Storage:** Passphrase encryption for archives placed in untrusted storage remains an open design candidate.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Practical Backup & Recovery (PC V1).
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Storage paths, backup directory, migration preflight rules.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Persistent storage layout, data root resolution, and migration snapshots.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md) — Retention periods and interaction with restored backups.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Background resource utilization during backup compression.
