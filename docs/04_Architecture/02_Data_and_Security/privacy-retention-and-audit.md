# Privacy, Retention, and Audit Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) (§7, §8) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, §3 Execution Baseline) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

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
- **Explicit User Deletion Authority:** The user maintains sovereign authority to inspect, edit, soft-delete, and permanently erase personal records across all domain models (conversations, memories, tasks, attachments).
- **Owner Isolation Invariant:** Retention policies, trash purges, and deletion operations must execute strictly within the authenticated `owner_id` boundary. A purge operation initiated by or on behalf of one user can never affect records belonging to another.

### 2.2 Privacy-Safe Auditing Invariants

- **Auditable State Mutations:** Tool executions that modify system state, access external networks, or perform elevated actions must be auditable by construction where required by the security policy.
- **Redaction of Sensitive Payloads:** Audit logs and application telemetry must **never** indiscriminately persist raw private message bodies, full memory texts, personal photographs, cleartext credentials, or authentication tokens. Audit entries record structured metadata (actor, timestamp, action type, resource identifier, policy evaluation result) rather than full sensitive content.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality, distinguishing implemented mechanisms from broad policy:

### 3.1 Task Retention & Recycle Bin Purge

Verified in `backend/app/models/task.py`, `backend/app/core/config.py`, `backend/app/services/retention.py`, and `scripts/purge_data.py`:
- **Soft-Delete Support:** `Task` includes `is_deleted: Mapped[bool]` and `deleted_at: Mapped[Optional[datetime]]` via `SoftDeleteMixin`.
- **Recycle Bin Lifespan:** `settings.DATA_RETENTION_DAYS = 30` configures the default retention window.
- **Remaining Days Calculation:** `calculate_remaining_days(deleted_at, retention_days)` calculates days remaining before permanent purge.
- **Automated Purge Service:** `purge_expired_trash(db, retention_days, owner_id)` permanently removes (`DELETE FROM tasks`) soft-deleted tasks older than the retention threshold with strict owner filtering.
- **Standalone Purge Script:** `scripts/purge_data.py` provides a manual command-line runner for trash cleanup.
- **Scope Boundary:** `DATA_RETENTION_DAYS` and `purge_expired_trash` **currently govern only Tasks**. They do **not** automatically apply to or purge memories, conversations, or attachments.

### 3.2 Memory Deletion Reality

Verified in `backend/app/models/memory.py` and `backend/app/api/v1/endpoints/memories.py`:
- **Soft-Delete Flag:** `DELETE /api/v1/memories/{memory_id}` sets `memory.is_deleted = True` and `memory.deleted_at = now()`.
- **Search Filtering:** The FTS retrieval query joins `Memory` and filters `m.is_deleted = 0`, immediately removing soft-deleted memories from search results.
- **Purge Status:** Automated background hard-purging of soft-deleted memories is **NOT IMPLEMENTED**. Soft-deleted memory rows remain in the database until manual intervention.

### 3.3 Attachment Deletion Reality

Verified in `backend/app/models/attachment.py` and `backend/app/api/v1/endpoints/attachments.py`:
- **Soft-Delete Flag:** `DELETE /api/v1/conversations/{id}/attachments/{id}` sets `attachment.is_deleted = True` and `attachment.deleted_at = now()`.
- **Physical File Status:** Soft-deleting an attachment record does **not** delete the binary image file from `settings.ATTACHMENT_DIR`.
- **Purge Status:** Automated trash sweeps or physical file cleanup scripts are **NOT IMPLEMENTED**.

### 3.4 Conversation & Message Deletion Reality

Verified in `backend/app/models/conversation.py` and `backend/app/api/v1/endpoints/conversations.py`:
- **Soft-Delete Support:** Deleting a conversation sets `deleted_at = now()` and soft-deletes associated messages.
- **Purge Status:** Automated expiration or permanent deletion sweeps are **NOT IMPLEMENTED**.

### 3.5 Security Audit Status

- **Audit Ledger Status:** **NOT IMPLEMENTED**. No `audit_logs` database table, structured security ledger, or immutable event journal exists in the repository.
- **General Logging Reality:** The codebase utilizes standard Python logging (`backend/app/core/logging.py`) emitting diagnostic console lines. These standard application logs must **not** be conflated with a dedicated security audit ledger.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for target milestones:

1. **Unified Retention Governance:** Extension of retention lifecycle management across all personal data domains, with configurable retention windows per data class.
2. **Physical Attachment Trash Sweeps:** Automated background garbage collection that purges physical attachment files when their associated database records are hard-purged.
3. **Structured Security Audit Ledger:** A dedicated, queryable audit log recording security-critical events (device pairing, token rotation, tool execution confirmation outcomes, configuration updates) with strict payload redaction.
4. **Permanent Purge Confirmation:** User-initiated "hard delete" actions that immediately and permanently erase selected items without awaiting retention expiration.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Audit Event Schema:** Specific fields and format for security audit records (e.g., event UUID, UTC timestamp, actor device ID, action name, target resource ID, outcome enum, signature).
- **Retention Periods by Data Class:** Granular default retention and auto-trash policies for conversations vs. tasks vs. memories vs. attachments.
- **Attachment Hard-Purge Cadence:** Scheduling and batching strategy for background physical file unlink sweeps.
- **Memory Hard-Purge Lifecycle:** Protocol for permanently vacuuming or removing soft-deleted entries from SQLite tables and FTS virtual indexes.
- **Backup Interaction with Deletion:** Handling of deleted records across existing database backup snapshots (e.g., ensuring restored backups respect subsequent "forget" requests).
- **Data Export & Portability:** Design for single-click user data export (e.g., structured JSON/ZIP archive of conversations, memories, and attachments).

---

## 6. Security & Ownership Boundaries

- **Zero Cleartext Credential Logging:** API keys, pairing tokens, session secrets, and passwords must never appear in application logs or audit records.
- **Owner Scope Isolation:** Deletion and purge routines must always include `owner_id` constraints to prevent accidental multi-user or cross-profile data leakage.
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
