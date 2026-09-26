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

### 2.2 Database Engine & Storage Configuration (Current Implementation)

The current repository implementation utilizes SQLite operating with:
- **Write-Ahead Logging (`WAL`):** Concurrency mode allowing concurrent readers without blocking background writers (`PRAGMA journal_mode=WAL;`).
- **Foreign Key Enforcement:** Strict referential integrity enforcement on every connection (`PRAGMA foreign_keys=ON;`).
- **Engine-Level Write Serialization & Busy Timeout:** SQLite serializes writes at the database engine level; the current configuration sets `busy_timeout` and `synchronous=NORMAL` to prevent database locks from failing under concurrent operations. There is no custom application-level write-serialization lock in `session.py`.
- **Implementation Status:** SQLite/WAL represents current verified implementation, not an eternal storage-engine invariant locked across all future phases.

### 2.3 Migration Safety & Preflight Baseline

- **Non-Destructive Schema Evolution:** Database schema migrations must never execute destructively on unverified data.
- **Migration & Schema Preparation Flow:**
  - `execute_migration()` creates a logical SQLite backup snapshot while migrating a legacy database into canonical storage, verifies it, atomically promotes it, and preserves a backup copy.
  - `prepare_database_schema()` then upgrades the canonical database to Alembic head.
  - Current source does **not** guarantee a fresh backup snapshot immediately before every Alembic schema migration of an already-canonical database.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Data-Root Resolution Precedence

Verified in `backend/app/core/storage.py` (`resolve_data_root()`):
1. **Environment Variable Override:** `COMPANION_DATA_ROOT` environment variable takes highest precedence (used in testing and custom hosting).
2. **Bootstrap Locator File:** Reads the `data_root` field from `bootstrap.json` located at `%LOCALAPPDATA%\AI Companion\bootstrap.json` on Windows.
3. **Approved OS Default:** On Windows, defaults to `%LOCALAPPDATA%\AI Companion\Data` (resolved via `LOCALAPPDATA`).

### 3.2 Canonical Path Taxonomy

Verified in `app.core.storage.CanonicalPaths`:
- `DATABASE_DIR`: `<root>/database`
- `DATABASE_PATH`: `<root>/database/companion.db`
- `LIBRARY_DIR`: `<root>/library`
- `MODEL_LIBRARY_DIR`: `<root>/library/models/llm`
- `INSTALLED_REGISTRY_PATH`: `<root>/library/registry/models.json`
- `VOICE_LIBRARY_DIR`: `<root>/library/voices`
- `ATTACHMENT_DIR`: `<root>/attachments`
- `IMPORT_INBOX_DIR`: `<root>/imports/inbox`
- `IMPORT_STAGING_DIR`: `<root>/imports/staging`
- `CHARACTER_DIR`: `<root>/characters`
- `MEMORY_DIR`: `<root>/memory`
- `BACKUP_DIR`: `<root>/backups`

### 3.3 Database Migrations & Safety Runner

Verified in `backend/app/core/storage.py` and `backend/alembic/`:
- **Current Migration Head:** `006_add_attachments` is the current repository migration head *(current verified reality, not a permanent identifier)*.
- **Preflight & Legacy Migration Functions:**
  - `inspect_legacy_candidate()` verifies candidate SQLite database files, checksums, and schema versions.
  - `assess_migration_preflight()` inspects potential legacy databases and guards against ambiguous multi-candidate states.
  - `execute_migration()` copies legacy SQLite data into canonical storage, verifies integrity, promotes it atomically, and preserves a backup copy.
  - `prepare_database_schema()` executes Alembic upgrades on the canonical database.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1:

1. **Canonical Data-Root Containment:** Continued strict enforcement that all persistent application data derives deterministically from `COMPANION_DATA_ROOT`.
2. **Safe Schema Evolution:** Schema migration procedures that preserve data integrity without unverified destructive alterations.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Storage Relocation Utility & UX:** Design of management commands or settings UI enabling users to relocate `COMPANION_DATA_ROOT` across drives.
- **Integrated Asset Verification Tool:** Diagnostic tooling checking database records against physical files on disk.
- **Attachment Trash-Cleanup System:** Automated trash sweep mechanisms coordinating between retention policy and physical file unlinking.
- **Storage Layout Versioning:** Migration strategies for evolving the physical directory structure (e.g., sharding attachments by date).
- **Encryption-at-Rest Strategy:** Optional whole-database or sensitive-field encryption (evaluating SQLCipher vs. application-layer AES-GCM envelope encryption).
- **Asset Deduplication:** Content-addressable storage (CAS) or hash-based deduplication for identical image attachments uploaded across conversations.

---

## 6. Security & Ownership Boundaries

- **Strict Path Containment:** Access to stored files (attachments, models, avatars) strictly enforces path containment checks (`path.is_relative_to(base_dir)`) to prevent directory traversal attacks.
- **Filesystem Permissions:** The current implementation creates required directories using standard OS permissions; bespoke or custom filesystem ACL management is not currently implemented.
- **Verified Atomic Writers:** `write_bootstrap()` uses a temporary file and `os.replace` for atomic replacement; atomic file replacement is limited to verified writers rather than globally across all files.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Phase 8P persistent data decoupling.
- [`docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`](../AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md) — Detailed path specifications, environment variables, and migration scenarios.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Model library paths and Decision D6 import pipeline.
- [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../01_Domains/multimodal-and-media.md) — Attachment binary storage rules.
- [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](backup-recovery-and-diagnostics.md) — Snapshot engine and disaster recovery.
