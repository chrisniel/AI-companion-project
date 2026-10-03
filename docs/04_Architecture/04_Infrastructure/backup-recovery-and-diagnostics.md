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

## 2. Durable Architecture

### 2.1 Critical Status Distinctions (PC V1 vs. Exploratory)
- **Local Application Lifecycle (PC V1):** Backup, staged restore, and local admin Factory Reset are foundational to PC V1.
- **Continuous Remote/Cloud DB Sync (Deferred):** Transparent remote database synchronization (e.g., streaming WAL replication to mobile or cloud) is explicitly deferred to **PC Later** or the Mobile Architecture pass.

### 2.2 Normal Backup Scope & Asset Referential Coherence
Backup artifacts must encapsulate both database state (SQLite) and associated Profile-owned external file assets to guarantee referential coherence.
- **Included:** Irreplaceable state, Profile-owned personal assets (Character studio avatars, custom images), and manifest/integrity records.
- **Excluded:** Application binaries, provider runtimes, model weights, STT/TTS weights, cache, logs (by default), staging/temp directories, provider keys, and device/session credentials.

### 2.3 Restore Pipeline & Safety
Database schema migrations must execute safely against restored payload data.
- **Restore Pipeline:** Stage first -> verify -> explicit confirm -> quiesce runtime as needed -> pre-restore safety snapshot -> activate -> restart -> verify.
- **Reactivation Guard:** Restore MUST NOT automatically reactivate devices, API/provider keys, sessions, or network credentials. Confirmations are NOT resurrected.
- **Replay Guard:** Do not blindly replay pending turns, pending actions, old notification backlog, or Routine occurrences.
- **Tombstones:** Known deletion tombstones prevent known resurrection from older restore material.
- **Emotion Restore:** Emotion state may be restored, then elapsed-time decay/rebalancing applies.

### 2.4 Local Admin Factory Reset
- **Authority & Security:** Factory Reset is a local AI Companion Account-admin operation (Risk 2). It requires strong local confirmation. There is **no requirement for Windows elevation** unless the implementation later genuinely requires it.
- **Scope:** Removes Account/Profile state, conversations/memories/tasks/schedules, Character customizations, Emotion, pairings, sessions, provider credentials, profile/cloud configuration, queues, and cache/temp state.
- **Persisted Assets:** App/provider binaries remain. Model/Voice Library deletion is a separate explicit choice. Backup deletion is a separate explicit option OFF by default with stronger irreversible confirmation.
- **Outcome:** Successful full reset creates fresh identities.

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

- **Local Admin Authority:** Restore and Factory Reset require authenticated local AI Companion Account-admin authority. Remote/mobile clients and ordinary companion tools cannot invoke them. Windows OS elevation is not an architectural requirement unless a concrete future implementation operation genuinely requires it. Factory Reset remains a Risk 2 operation with strong local confirmation.
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

