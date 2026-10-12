# Milestone M2 Batch A: Profile Foundation & Migration 007 — Implementation Plan

> **Tracking:** Part of `PC-IDENTITY-001` (Account & Multi-Profile Database Schema Migration) and `PC-RESILIENCE-002` (Pre-Migration Automatic Safety Snapshot Hook).
> **Status:** IMPLEMENTATION COMPLETE & VERIFIED; DOCUMENTATION & CLOSURE GATE PASS.
> **Scope:** Schema foundation, Migration 007, per-installation Default Profile, pre-migration WAL backup, fail-closed legacy owner validation, backward-compatible legacy application execution.

---

## 1. Scope & Objective

Batch A establishes the database schema foundation for Multi-Profile identity (`ADR-0018`) while preserving full backward compatibility with existing single-user runtime operations, models, and endpoints.

### In Scope
1. **Database Migration 007 (`migrations/versions/007_profiles_and_owner_id_migration.py`):**
   - Introduces the `profiles` table with stable UUID primary keys.
   - Generates a unique, non-hardcoded Profile UUID per installation/database during migration or fresh database initialization.
   - Enforces a partial unique index (`uq_profiles_single_default`) ensuring exactly one default profile (`is_default = 1`).
   - Adds indexed `profile_id` foreign keys referencing `profiles.id` across existing user entity tables: `conversations`, `messages`, `tasks`, `memories`, and `attachments`.
   - Retains existing `owner_id` columns and indices across all five entity tables for seamless backward compatibility.
   - Populates and backfills `profile_id` for all existing records using the generated default profile ID.
2. **Fail-Closed Legacy Owner Validation (`app/db/legacy_owner_validation.py`):**
   - Validates existing data prior to applying table rebuilding DDL.
   - Accepts only explicitly approved legacy owner aliases: `local_user` and `default_user`.
   - Strictly rejects unexpected, empty, whitespace-only, case-variant, or NULL owner values, aborting migration and preserving source data untouched.
3. **ORM Model Foundation (`app/models/`):**
   - Adds `Profile` SQLAlchemy model (`app/models/profile.py`) with partial unique index and lifecycle hooks for default profile seeding.
   - Extends `ProfileMixin` in `app/models/base.py` with dynamic `resolve_default_profile_id` contextual resolution during flush.
   - Preserves `OwnerMixin` defaulting `owner_id` to `local_user` so all existing application write paths continue functioning unmodified.
4. **Resilient Pre-Migration Backup & Safety (`app/db/backup.py` & `app/core/storage.py`):**
   - Enforces pre-migration WAL-safe SQLite online backup prior to executing Alembic upgrade 007 on existing databases.
   - Generates collision-proof backup filenames using UTC microsecond timestamps and random UUID suffixes (`pre_<label>_<timestamp>_<suffix>.db`).
   - Atomically stages and verifies backups with `PRAGMA integrity_check` before publishing via hardlink (`os.link`), never overwriting prior verified recovery snapshots.
   - Validates existing databases on startup: zero-byte files, invalid SQLite headers, or corrupt databases fail closed and safely abort startup/upgrade before any backup or migration attempts.
   - Provides standalone recovery utility (`restore_database_from_backup`) featuring quiescence probing (`BEGIN EXCLUSIVE`), pre-restore live safety snapshotting, SQLite backup API restoration (preserving WAL/SHM sidecars), and automatic rollback on verification failure.

### Explicitly Out of Scope (Deferred to Batch B & Subsequent Work Items)
- **Profile Sessions & Context Tokens:** `POST /api/v1/auth/profile/session` or token-bound profile context.
- **Profile Administration Endpoints:** Creating, editing, listing, or deleting profiles via REST APIs.
- **Profile PIN / Windows Hello Security:** Salted PIN hashing, challenge verification, or lockout policies.
- **Client Profile Switcher UI:** Multi-profile switching in Flutter or React clients.
- **Character Templates & Instances (`PC-CHAR-001`):** Persona, trait, or character instance modeling.
- **Live / Automatic Restore Automation:** Standalone restore remains a manual/controlled maintenance utility pending host-level writer quiescence controls across the complete restore operation.

---

## 2. Verification & Test Evidence

The Batch A implementation has been verified with disposable, isolated SQLite databases across the complete backend test suite:
- **Backend Test Suite:** 494 passed, 1 warning (pre-existing FastAPI deprecation warning).
- **Targeted Test Coverage:**
  - `test_migration_007.py`: Verifies fresh upgrade to 007, upgrade from v006 with populated data, downgrade to v006, foreign key constraints, and FTS5 search/trigger integrity.
  - `test_default_profile_identity.py`: Verifies unique UUID generation across distinct installations, persistence across restart/backup, and single-default constraint.
  - `test_legacy_owner_validation.py`: Verifies acceptance of approved aliases (`local_user`, `default_user`) and rejection of unexpected, empty, or NULL owner values.
  - `test_backup_restore_safety.py`: Verifies collision-proof filenames, non-overwrite publishing, active writer detection, intact WAL/SHM files, safety snapshot creation, corrupt backup rejection, and rollback on post-restore failure.
  - `test_prepare_database_schema_backup.py`: Verifies preflight checks on existing databases (zero-byte, corrupted headers, damaged pages) and automatic pre-migration backup triggering.
- **Client Regression Checks:**
  - `flutter analyze`: 0 issues found across workspace.
  - `frontend/web`: 234 unit/integration tests passed (Vitest); `tsc --noEmit` clean.
