# Storage and Assets Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Execution Baseline, Phase 8P) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the filesystem layout, persistent storage root resolution, database migration safety, and asset lifecycle management for the AI Companion:
- Single-point resolution of the persistent data root (`COMPANION_DATA_ROOT`).
- Canonical path taxonomy decoupling persistent user assets from transient application code.
- Database engine invariants (SQLite with Write-Ahead Logging and foreign key enforcement).
- Preflight migration safety, ambiguity detection, and rollback snapshot guarantees (Phase 8P).
- Separation of durable storage semantics from machine-specific absolute paths.

---

## 2. Durable Architecture & Invariants

### 2.1 Persistent Storage Decoupling (Phase 8P)

In accordance with Phase 8P persistent storage architecture:
- **Code vs. Data Separation:** Application code (Git repository, virtual environment, temporary builds) is strictly decoupled from persistent user data. Updating, moving, or reinstalling the codebase must never mutate, corrupt, or orphan user databases, model weights, or personal attachments.
- **Single Source of Truth (`COMPANION_DATA_ROOT`):** All persistent application paths derive deterministically from a single root path. Subsystems must never invent independent storage directories outside this canonical hierarchy.
- **Machine-Agnostic Storage Semantics:** Architecture defines path families, relative structures, and resolution precedence. Concrete absolute paths on specific developer machines are not canonical.

### 2.2 Database Engine & Transaction Invariants

- **SQLite Engine Baseline:** The primary database is SQLite, operating with:
  - **Write-Ahead Logging (`WAL`):** Concurrency mode allowing concurrent readers without blocking background writers (`PRAGMA journal_mode=WAL;`).
  - **Foreign Key Enforcement:** Strict referential integrity enforcement on every connection (`PRAGMA foreign_keys=ON;`).
  - **Single Writer Isolation:** Serialized write access prevents database lock contention across concurrent background tasks.

### 2.3 Migration Safety & Preflight Invariants

- **Non-Destructive Schema Evolution:** Database schema migrations must never execute destructively on unverified data.
- **Preflight Inspection:** Before applying Alembic migrations or initializing a database, the runtime inspects existing candidates, verifies SQLite integrity (`PRAGMA integrity_check;`), and evaluates migration lineage.
- **Pre-Migration Safety Snapshot:** Before executing any migration step that alters schema or rewires data, the storage layer creates an atomic copy of the active database into `BACKUP_DIR`.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Data-Root Resolution Precedence

Verified in `backend/app/core/storage.py` (`resolve_data_root()`):
1. **Environment Variable Override:** `COMPANION_DATA_ROOT` environment variable takes highest precedence (used in testing and custom hosting).
2. **Bootstrap Locator File:** Reads `.companion_data_root` located in the backend root directory.
3. **OS-Default User Path:** On Windows, defaults to `%LOCALAPPDATA%\AICompanion\data` (resolved via `os.environ.get("LOCALAPPDATA")`).

### 3.2 Canonical Path Taxonomy

Verified in `app.core.storage.CanonicalPaths` and `app.core.config.Settings`:
- `DATABASE_DIR` / `DATABASE_PATH`: Directory and file for primary SQLite database (`companion.db`).
- `DATABASE_URL`: SQLAlchemy connection URI (`sqlite+aiosqlite:///...`).
- `LIBRARY_DIR`: Root for media and asset libraries.
- `MODEL_LIBRARY_DIR`: Permanent directory for installed GGUF models (`models/`).
- `INSTALLED_REGISTRY_PATH`: Persistent user model registry (`models/installed_registry.json`).
- `VOICE_LIBRARY_DIR`: Voice model weights and speaker profiles (`voice/`).
- `ATTACHMENT_DIR`: Stored image files associated with messages (`attachments/`).
- `IMPORT_INBOX_DIR`: User drop directory for new GGUF models (`inbox/`).
- `IMPORT_STAGING_DIR`: Verification scratch directory during D6 model import (`staging/`).
- `CHARACTER_DIR`: Persistent character lore cards and avatars (`characters/`).
- `MEMORY_DIR`: Vector/lexical index storage artifacts (`memory/`).
- `BACKUP_DIR`: Automatic pre-migration database snapshots (`backups/`).

### 3.3 Database Migrations & Safety Runner

Verified in `backend/app/core/storage.py` and `backend/alembic/`:
- **Current Migration Head:** `006_add_attachments` is the current repository migration head *(current verified reality, not a permanent identifier)*.
- **Preflight Verifier:** `inspect_database_candidate(path)` verifies SHA256 checksum, reads `alembic_version`, and executes `PRAGMA integrity_check`.
- **Ambiguity Guard:** If multiple legacy databases are detected with differing contents, `assess_migration()` raises `MigrationAmbiguityError` requiring manual user resolution, preventing silent data overwrite.
- **Snapshot Generator:** Copies active database to `pre_migration_backup_<timestamp>.db` before migration execution.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1:

1. **Storage Relocation Utility:** A safe management command or settings action allowing users to move their `COMPANION_DATA_ROOT` to another drive (e.g., secondary SSD) with automatic file relocation and bootstrap pointer update.
2. **Automated Trash Cleanup Integration:** Storage hooks coordinating with the retention policy to unlink orphaned or permanently deleted attachment files from `ATTACHMENT_DIR`.
3. **Integrated Asset Verification Tool:** Command-line diagnostic that checks all database attachment records against physical files on disk, reporting missing or unreferenced assets.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Storage Layout Versioning:** Migration strategies for evolving the physical directory structure (e.g., transitioning from flat `attachments/` to sharded `attachments/{year}/{month}/`).
- **Relocation User Interface:** Frontend visual settings screen for viewing disk space consumption and initiating data-root migration.
- **Encryption-at-Rest Strategy:** Optional whole-database or sensitive-field encryption (evaluating SQLCipher vs. application-layer AES-GCM envelope encryption).
- **Asset Deduplication:** Content-addressable storage (CAS) or hash-based deduplication for identical image attachments uploaded across conversations.

---

## 6. Security & Ownership Boundaries

- **Strict Path Containment:** Access to stored files (attachments, models, avatars) strictly enforces path containment checks (`path.is_relative_to(base_dir)`) to prevent directory traversal attacks.
- **Restricted Directory Permissions:** The persistent data root is initialized with user-private filesystem permissions, preventing other unprivileged local OS accounts from inspecting companion databases.
- **Atomicity Guarantees:** File writes to configuration and registry files use atomic write-and-rename patterns (`tempfile` $\rightarrow$ `replace`) to prevent file corruption during sudden system crashes or power losses.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Phase 8P persistent data decoupling.
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Detailed path specifications, environment variables, and migration scenarios.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Model library paths and Decision D6 import pipeline.
- [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../01_Domains/multimodal-and-media.md) — Attachment binary storage rules.
- [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](backup-recovery-and-diagnostics.md) — Snapshot engine and disaster recovery.
