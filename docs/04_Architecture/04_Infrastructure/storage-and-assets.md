# Storage and Assets Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the filesystem layout, persistent storage root resolution, database migration safety, and asset lifecycle management for the AI Companion:
- Single-point resolution of the persistent data root (`COMPANION_DATA_ROOT`).
- Canonical path taxonomy decoupling persistent user assets from transient application code.
- Database engine invariants (SQLite with Write-Ahead Logging and foreign key enforcement).
- Preflight migration safety, ambiguity detection, and rollback snapshot guarantees (Phase 8P).
- Separation of durable storage semantics from machine-specific absolute paths.
- Canonical configuration layering and persistence boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Persistent Storage Decoupling & The Five Storage Roots

In accordance with Phase 8P persistent storage architecture:
- **Code vs. Data Separation:** Application code (Git repository, virtual environment, temporary builds) is strictly decoupled from persistent user data. Updating, moving, or reinstalling the codebase must never mutate, corrupt, or orphan user databases, model weights, or personal attachments.
- **Repository Paths vs. Runtime Paths:** The repository directories `runtime/` and `models/` are **development sources and templates only**. They must never serve as active runtime storage for end users. Active runtime storage is strictly partitioned into five canonical storage roots:
  1. `APP_INSTALL_ROOT`: Read-only application distribution binaries, bundled engines , and static assets.
  2. `DATA_ROOT`: Persistent, profile-isolated SQLite database (`companion.db`), user settings, character avatars, and personal attachments. Defaults to `%LOCALAPPDATA%\AI Companion\Data`.
  3. `LIBRARY_ROOT`: Large, relocatable, host-shared assets (GGUF LLM weights, voice models, vision projectors). May be relocated to a secondary drive (e.g., dedicated SSD/HDD) via `bootstrap.json` without moving `DATA_ROOT`.
  4. `CACHE_ROOT`: Ephemeral working scratchpads, temporary audio buffers, and staging directories. Safe to purge on reboot without data loss.
  5. `LOG_ROOT`: Structured application logs, crash diagnostics, and rotation archives.
- **Machine-Agnostic Storage Semantics:** Architecture defines path families, relative structures, and resolution precedence. Concrete absolute paths on specific developer machines are not canonical.

### 2.2 Database Engine & Storage Configuration (Current Implementation)

The current repository implementation utilizes SQLite operating with:
- **Write-Ahead Logging (`WAL`):** Concurrency mode allowing concurrent readers without blocking background writers (`PRAGMA journal_mode=WAL;`).
- **Foreign Key Enforcement:** Strict referential integrity enforcement on every connection (`PRAGMA foreign_keys=ON;`).
- **Engine-Level Write Serialization & Busy Timeout:** SQLite serializes writes at the engine level. The configured `busy_timeout` allows lock contention to wait for a bounded interval rather than failing immediately; it does not provide an application-level single-writer lock.
- **Implementation Status:** SQLite/WAL represents current verified implementation, not an eternal storage-engine invariant locked across all future phases.

### 2.3 Migration Safety & Preflight Baseline

- **Non-Destructive Schema Evolution:** Database schema migrations must never execute destructively on unverified data.
- **Migration & Schema Preparation Flow:**
  - `execute_migration()` creates a logical SQLite backup snapshot while migrating a legacy database into canonical storage, verifies it, atomically promotes it, and attempts to preserve an additional backup copy in `BACKUP_DIR`; failure of that extra copy is logged (while the original legacy source file remains untouched).
  - `prepare_database_schema()` then upgrades the canonical database to Alembic head.
  - A fresh backup snapshot must precede every destructive or schema-altering migration of an already-canonical database.

### 2.4 Configuration Persistence & Layering

The architecture establishes durable separation between configuration classes to avoid semantic conflation across defaults, machine configuration, user preferences, and transient overrides:

- **Distinct Configuration Categories:** The system conceptually distinguishes between:
  1. *Built-In Defaults:* Static fallback constants packaged with the application distribution.
  2. *Persistent Machine Configuration:* Local host hardware and environment bindings (e.g., resolved `COMPANION_DATA_ROOT`, `LIBRARY_ROOT` relocation pointer, hardware profile preferences, local port allocations).
  3. *Persistent User Configuration:* Profile-owned companion settings and preferences (e.g., active persona choices, notification preferences, quiet-hours rules, tool confirmation thresholds).
  4. *Environment & Developer Overrides:* Transient variables set via process environment or local development files.
  5. *Secrets & Sensitive Credentials:* API keys, device credentials, and access tokens governed strictly by [`02_Data_and_Security/authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md).
  6. *Runtime & Session State:* Transient, in-memory state that does not outlive process or session lifecycles.
- **Categorical Integrity:** These configuration layers must not be silently conflated. In particular, environment variables and `.env` files are suitable for development overrides, containerized deployment flags, and current compatibility needs, but must **not** serve as the primary persistent datastore for end-user settings.
- **Secrets Isolation:** Storage and handling of sensitive secrets remain governed by the authentication and secrets architecture; secrets must never be intermingled with plain-text user settings.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Storage-Root Resolution Precedence

Verified in `backend/app/core/storage.py` (`resolve_data_root()`, `resolve_library_root()`, `resolve_cache_root()`, `resolve_log_root()`, `resolve_app_install_root()`):
1. **Environment Variable Override:** `COMPANION_DATA_ROOT`, `COMPANION_LIBRARY_ROOT`, `COMPANION_CACHE_ROOT`, `COMPANION_LOG_ROOT`, and `COMPANION_APP_INSTALL_ROOT` take highest precedence (used in testing and custom hosting).
2. **Bootstrap Locator File:** Reads `data_root` and optional `library_root` pointers from `bootstrap.json` located at `%LOCALAPPDATA%\AI Companion\bootstrap.json` on Windows. Fail-closed inspection validates `library_root` when present (`companion_core`).
3. **Approved OS Default:** On Windows, `DATA_ROOT` defaults to `%LOCALAPPDATA%\AI Companion\Data`, `LIBRARY_ROOT` defaults to `<DATA_ROOT>\library` (when no `library_root` override is set), `CACHE_ROOT` defaults to `%LOCALAPPDATA%\AI Companion\Cache`, `LOG_ROOT` defaults to `%LOCALAPPDATA%\AI Companion\Logs`, and `APP_INSTALL_ROOT` resolves to the runtime installation root (`Path(__file__).resolve().parents[3]`).

### 3.2 Canonical Path Taxonomy

Verified in `app.core.storage.CanonicalPaths`:
- `APP_INSTALL_ROOT`: Application/runtime installation root
- `DATA_ROOT`: Active database and core profile state root
- `LIBRARY_ROOT`: Relocatable heavy-weight library root (`LIBRARY_DIR`)
- `CACHE_ROOT`: Regenerable caches root
- `LOG_ROOT`: Rotating runtime diagnostics root
- `DATABASE_DIR`: `<DATA_ROOT>/database`
- `DATABASE_PATH`: `<DATA_ROOT>/database/companion.db`
- `LIBRARY_DIR`: `<LIBRARY_ROOT>`
- `MODEL_LIBRARY_DIR`: `<LIBRARY_ROOT>/models/llm`
- `INSTALLED_REGISTRY_PATH`: `<LIBRARY_ROOT>/registry/models.json`
- `VOICE_LIBRARY_DIR`: `<LIBRARY_ROOT>/voices`
- `ATTACHMENT_DIR`: `<DATA_ROOT>/attachments`
- `IMPORT_INBOX_DIR`: `<LIBRARY_ROOT>/imports/inbox`
- `IMPORT_STAGING_DIR`: `<LIBRARY_ROOT>/imports/staging`
- `CHARACTER_DIR`: `<DATA_ROOT>/characters`
- `MEMORY_DIR`: `<DATA_ROOT>/memory`
- `BACKUP_DIR`: `<DATA_ROOT>/backups`

### 3.3 Database Migrations & Safety Runner

Verified in `backend/app/core/storage.py` and `backend/migrations/`:
- **Current Migration Head:** `006_add_attachments` is the current repository migration head *(current verified reality, not a permanent identifier)*.
- **Preflight & Legacy Migration Functions:**
  - `inspect_legacy_candidate()` verifies candidate SQLite database files, checksums, and schema versions.
  - `assess_migration_preflight()` inspects potential legacy databases and guards against ambiguous multi-candidate states.
  - `execute_migration()` copies legacy SQLite data into canonical storage, verifies integrity, promotes it atomically, and attempts to preserve an additional backup copy in `BACKUP_DIR`; failure of that extra copy is logged (while the original legacy source file remains untouched).
  - `prepare_database_schema()` executes Alembic upgrades on the canonical database.

---


### 3.4 Resolved D6 Import Path Layout
- **Current Implementation:** `IMPORT_INBOX_DIR` (`<LIBRARY_ROOT>/imports/inbox`) and `IMPORT_STAGING_DIR` (`<LIBRARY_ROOT>/imports/staging`) now reside directly under `LIBRARY_ROOT` (resolved via `resolve_library_root()` in `backend/app/core/storage.py`), resolving the former `DATA_ROOT/imports` technical debt and keeping atomic D6 staging on the same volume as `MODEL_LIBRARY_DIR`.

## 4. Storage Implementation & Management Status (PC V1)

Implemented in M2 Batch E (`PC-HOST-004`):

1. **Five Storage Roots & Relocatable `LIBRARY_ROOT`:** `CanonicalPaths` resolves all five roots (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`, `CACHE_ROOT`, `LOG_ROOT`). Optional `library_root` pointers in `bootstrap.json` (plus `COMPANION_LIBRARY_ROOT` env overrides) allow relocating `LIBRARY_ROOT` to an alternate drive/volume via `GET /api/v1/system/storage`, `PUT /api/v1/system/storage/library-root`, and Desktop `SettingsStorageSection` while `DATA_ROOT` stays anchored on fast OS storage. Fail-closed `bootstrap.json` inspection (`companion_core`) validates optional `library_root` entries. *(Physical alternate-drive relocation on a multi-volume Windows host awaits manual QA.)*
2. **Pre-Migration Safety Snapshot Guarantee:** Ensure an automatic SQLite backup snapshot is captured in `BACKUP_DIR` prior to executing any schema-altering migration on an existing database.
3. **Distribution Separation:** Windows installer packages separate read-only binaries into `APP_INSTALL_ROOT` (`%ProgramFiles%\AI Companion` or per-user local app dir) and runtime mutable data into `DATA_ROOT`, completely decoupled from git repository working copies.
4. **Self-Contained Windows Installer & Bundled Runtime (`PC-HOST-006`):**
   - **Consumer Distribution Requirement:** Target end users install AI Companion via a self-contained Windows installer without needing to install Python manually, configure virtual environments, or modify global system paths.
   - **Three Identifiable Supervised Components:** The Windows installation deploys three distinct, identifiable, and independently supervised components that remain transparently visible in Windows Task Manager for user inspection and diagnostic control:
     1. `AI Companion.exe`: Flutter Desktop user interface client.
     2. `AI Companion Runtime.exe`: Dedicated Python host executing the FastAPI Local AI Runtime.
     3. `AI Companion Inference.exe`: Dedicated native `llama.cpp` inference engine server.
   - **No Console Windows & No Task Manager Concealment:** Normal application startup operates entirely without visible console windows (e.g. no command prompt or PowerShell shells appearing during runtime execution or model loading). However, processes must never be intentionally concealed from Windows Task Manager; all three components remain clearly named and accountable.
   - **Process Separation & Crash Isolation:** The UI client, runtime host, and native inference engine run in separate operating system processes. This ensures complete crash isolation: an inference segfault or engine failure does not take down the runtime supervisor or UI, and a client UI exit or restart leaves background runtime tasks unharmed.
   - **Bundled Execution Environment:** The distribution packages a private, isolated Python execution environment, backend dependencies, the Flutter Desktop production client, and required native inference binaries into `APP_INSTALL_ROOT`.
   - **Environment Isolation:** Operates hermetically without global `PATH` modifications or developer virtual environment prerequisites.
   - **Single Windowless Local Runtime:** Operates exactly one independent windowless Local AI Runtime per PC installation, preserving runtime process supervision, kernel lockfile coordination, and file-based rotating diagnostics in `LOG_ROOT`.
   - **User Asset Preservation Across Lifecycle:** In-place updates, component repairs, and reinstalls strictly preserve persistent user data in `DATA_ROOT` (`companion.db`, profiles, chat history, attachments) and relocatable model assets in `LIBRARY_ROOT`. Uninstallation provides a safe option to preserve or archive user databases and models.
   - **Model Provisioning Compliance:** Model delivery strictly adheres to approved Decision D6 (manual inbox/import pipeline) and vendor licensing requirements; model weights are never silently bundled in proprietary binaries without licensing verification.
   - **Lifecycle Management:** Supports standard Windows installation, version updates, integrity repair, and safe uninstallation.
   - **Open Design Status:** Specific installer technology (e.g., Inno Setup, WiX / MSI, MSIX, NSIS), private Python bundling approach (embedded distribution vs. standalone freeze), prerequisite verification, and code-signing infrastructure are explicitly designated **OPEN DESIGN** and deferred (`PC-HOST-006` / `DEBT-V1-09`). Installer packaging does not exist in current development or the M2-H1 milestone (developer venv remains the development baseline).

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Self-Contained Windows Installer & Bundled Runtime Packaging (`PC-HOST-006` / `DEBT-V1-09`):** Packaging mechanism, private Python bundling strategy, code signing, and update mechanics for self-contained Windows distribution.
- **Storage Relocation Utility & UX:** Client UI workflow enabling users to safely relocate `LIBRARY_ROOT` or `DATA_ROOT` across volumes with progress feedback and integrity verification.
- **Attachment Trash-Cleanup & Garbage Collection:** Automated sweep mechanisms coordinating between chat deletion, profile soft-delete windows, and physical file unlinking.
- **Encryption-at-Rest Strategy:** Optional whole-database or sensitive-field encryption (evaluating SQLCipher vs. application-layer AES-GCM envelope encryption).
- **Asset Deduplication:** Content-addressable storage (CAS) or hash-based deduplication for identical image attachments uploaded across conversations.

---

## 6. Security & Ownership Boundaries

- **Strict Path Containment:** Access to stored files (attachments, models, avatars) strictly enforces path containment checks (`path.is_relative_to(base_dir)`) to prevent directory traversal attacks.
- **Filesystem Permissions:** The current implementation creates required directories using standard OS permissions; bespoke or custom filesystem ACL management is not currently implemented.
- **Verified Atomic Writers:** `write_bootstrap()` uses a temporary file and `os.replace` for atomic replacement; atomic file replacement is limited to verified writers rather than globally across all files.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Decision Spine
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Phase 8P persistent data decoupling.
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) — Master Decision Register (Row 26 Storage Roots & Relocatable Assets).
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — Open storage technical debt.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/04_Infrastructure/runtime-and-models.md`](runtime-and-models.md) — Model library paths and Decision D6 import pipeline.
- [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../01_Domains/multimodal-and-media.md) — Attachment binary storage rules.
- [`docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md`](backup-recovery-and-diagnostics.md) — Snapshot engine and disaster recovery.
- [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) — Multi-profile storage isolation.
- [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md) — Secrets management, token storage, and credential isolation.

