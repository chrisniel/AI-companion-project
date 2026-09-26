# Privacy, Retention, and Audit Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the privacy preservation principles, data retention lifecycles, and security auditing requirements for the AI Companion:
- Data minimization and user-controlled deletion ("forget" capabilities).
- Entity lifecycle states (active, soft-deleted, permanently purged).
- Distinctions between current implemented retention mechanisms and future comprehensive lifecycle policies.
- Audit logging requirements for state-changing operations and security events.
- Privacy-safe auditing rules preventing indiscriminate logging of sensitive personal payloads.

---

## 2. Durable Architecture & Invariants

### 2.1 Privacy Principles & User Deletion Authority

- **Data Minimization:** The companion collects, retains, and transmits only the minimal data necessary to fulfill conversational and functional duties.
- **Explicit User Deletion Authority:** Users must have appropriate inspect, correct, delete, and forget controls over Profile-owned personal data across all domain models (conversations, memories, tasks, attachments). Deletion operations do not promise immediate permanent hard deletion across every domain, cache, and backup snapshot; exact soft-delete vs. hard-purge lifecycles remain governed by explicit retention and privacy policy.
- **Owner Isolation Invariant:** Deletion and purge operations must preserve authenticated ownership boundaries, either through direct owner filtering or through an already owner-authorized parent/resource relationship. A purge operation initiated by or on behalf of one user can never affect records belonging to another. Host-controlled maintenance jobs may operate across the single-primary-user database when explicitly designed as global maintenance.

### 2.2 Privacy-Safe Auditing Invariants

- **Auditable State Mutations (Principle P1):** Tool executions and companion actions that modify system state, access external networks, or perform elevated operations require deterministic, auditable action governance where required by policy.
- **Redaction of Sensitive Payloads:** Audit logs and application telemetry must **never** indiscriminately persist raw private message bodies, full memory texts, personal photographs, cleartext credentials, or authentication tokens. Audit entries record structured metadata (actor, timestamp, action type, resource identifier, policy evaluation result) rather than full sensitive content.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality, distinguishing implemented mechanisms from broad policy:

### 3.1 Task Retention & Recycle Bin Purge

Verified in `backend/app/models/task.py`, `backend/app/core/config.py`, and `backend/app/services/retention.py`:
- **Soft-Delete Support:** `Task` includes `is_deleted: Mapped[bool]` and `deleted_at: Mapped[Optional[datetime]]` via `SoftDeleteMixin`.
- **Recycle Bin Lifespan:** `settings.DATA_RETENTION_DAYS = 30` configures the default retention window.
- **Remaining Days Calculation:** `calculate_remaining_days(deleted_at, retention_days)` calculates days remaining before permanent purge.
- **Task Purge Service Function:** `purge_expired_trash(db, retention_days=None, owner_id=None)` permanently removes (`DELETE FROM tasks`) soft-deleted tasks older than the retention threshold. It supports an optional `owner_id` filter: when `owner_id` is supplied, the purge is owner-scoped; when omitted, the host maintenance runner can sweep expired soft-deleted Tasks globally across the database.
- **Standalone Purge Runner:** Implemented in `backend/app/services/retention.py` through `run_retention_purge_job()` and its `__main__` CLI runner (`python -m app.services.retention`). There is NO periodically scheduled runtime retention job currently wired into the application.
- **Scope Boundary:** `DATA_RETENTION_DAYS` and `purge_expired_trash` **currently govern only Tasks**. They do **not** automatically apply to or purge memories, conversations, or attachments.

### 3.2 Memory Deletion Reality

Verified in `backend/app/models/memory.py` and `backend/app/api/v1/endpoints/memories.py`:
- **Soft-Delete Flag:** `DELETE /api/v1/memories/{memory_id}` sets `memory.is_deleted = True` and `memory.deleted_at = now()`.
- **Search Filtering:** The FTS retrieval query joins `Memory` and defensively filters `m.deleted_at IS NULL`, immediately removing soft-deleted memories from search results.
- **Purge Status:** Automated background hard-purging of soft-deleted memories is **NOT IMPLEMENTED**. Soft-deleted memory rows remain in the database until manual intervention.

### 3.3 Attachment Deletion Reality

Verified in `backend/app/models/attachment.py` and `backend/app/api/v1/endpoints/attachments.py`:
- **Soft-Delete Flag:** `DELETE /api/v1/conversations/{id}/attachments/{id}` sets `attachment.is_deleted = True` and `attachment.deleted_at = now()`.
- **Physical File Status:** Soft-deleting an attachment record does **not** delete the binary image file from `settings.ATTACHMENT_DIR`.
- **Purge Status:** Automated trash sweeps or physical file cleanup scripts are **NOT IMPLEMENTED**.

### 3.4 Conversation & Message Deletion Reality

Verified in `backend/app/models/conversation.py` and `backend/app/api/v1/endpoints/conversations.py`:
- **Soft-Delete Support:** Deleting a conversation (`DELETE /api/v1/conversations/{id}`) sets `conversation.deleted_at = now()` and bulk soft-deletes active child `Attachment` records. It does **not** currently soft-delete `Message` rows.
- **Purge Status:** Automated expiration or permanent deletion sweeps are **NOT IMPLEMENTED**.

### 3.5 Security Audit Status

- **Audit Ledger Status:** **NOT IMPLEMENTED**. No `audit_logs` database table, structured security ledger, or immutable event journal exists in the repository.
- **General Logging Reality:** The codebase utilizes standard Python logging (`backend/app/core/logging.py`) emitting diagnostic console lines. These standard application logs must **not** be conflated with a dedicated security audit ledger.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for target milestones:

1. **User Deletion & Forget Controls:** Users have appropriate inspect, correct, delete, and forget controls over Profile-owned personal data.
2. **Auditable Action Governance (Principle P1):** Deterministic, auditable action governance for security-relevant and state-changing actions. The exact audit persistence mechanism remains open design.
3. **Data Retention & Lifecycle Policies:** Explicit retention policy definitions governing personal records across domains.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future technical specification:

- **Soft Delete vs. Hard Purge Timing:** Granular default retention windows and auto-trash policies for conversations vs. tasks vs. memories vs. attachments.
- **Audit Coverage, Schema & Storage:** Specific audit ledger design, including whether audit logs are persisted in a dedicated SQLite table, file append log, or structured event stream, and exact criteria for audit coverage.
- **Physical Asset Cleanup Design:** Architecture and scheduling for attachment physical file garbage collection sweeps following record deletion.
- **Backup Interaction with Deletion:** Handling of deleted records across existing database backup snapshots, including tombstones and restore/deletion reconciliation (ensuring restored backups respect subsequent "forget" requests).
- **Unified Retention Scheduling:** Whether retention cleanup runs via a unified scheduled service or domain-specific maintenance hooks.
- **Data Export & Portability:** Design for single-click user data export (e.g., structured JSON/ZIP archive of conversations, memories, and attachments).

---

## 6. Security & Ownership Boundaries

- **Zero Cleartext Credential Logging:** API keys, pairing tokens, session secrets, and passwords must never appear in application logs or audit records.
- **Owner Scope Isolation:** Deletion and purge operations must preserve authenticated ownership boundaries, either through direct owner filtering or through an already owner-authorized parent/resource relationship.
- **Tamper Resistance:** Where security audit records are maintained, they should be append-only and protected against non-administrative modification.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Decisions D4 (Profile vs Device), D8 (Single-primary-user baseline).
- [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) — Privacy boundaries, retention policies, audit requirements.

### Related Domain & Security Specifications
- [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../01_Domains/memory-and-personalization.md) — Memory capture, editing, and deletion controls.
- [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../01_Domains/multimodal-and-media.md) — Attachment storage and lifecycle.
- [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](tool-permissions-and-actions.md) — Tool execution auditing and confirmation gates.
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md) — Physical storage paths and database file management.
