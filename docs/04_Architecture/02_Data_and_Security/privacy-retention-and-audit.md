# Privacy, Retention, and Audit Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0018)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for privacy, retention lifecycles, and auditing.

---

## 1. Purpose & Scope

- **Backup Restoration & Deletion Invariant:** Deleting or permanently purging live records or Profiles removes them from the active operational database and target live storage directories. Restoring a backup restores the snapshot as it existed when that backup was created (including any Profile or records present in that snapshot that were deleted afterward), and restores only the data and assets actually contained in the selected backup. This supersedes prior requirements that deletion tombstones prevent resurrection from older database backups. Note: This backup restore semantic is strictly distinct from multi-device and mobile synchronization tombstones (`mobile-offline-and-sync.md`), which remain active for delta synchronization and conflict resolution across live connected clients.


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
- **Owner Isolation Invariant:** Deletion/purge initiated for one Profile must never affect another Profile's private records or shared host resources.
- **Profile Deletion & 30-Day Recovery Lifecycle (`PC-IDENTITY-005`):** Deleting a Profile moves it into **Recently Deleted**, immediately revoking its active sessions, invalidating pending session tickets, and stopping in-flight generation for that Profile once revocation is observed. A soft-deleted Profile remains recoverable for **30 days** (`purge_after = deleted_at + 30 days`). Expired Profiles are permanently purged by Runtime maintenance; local Account administrators may also trigger **Permanently Delete** immediately with explicit confirmation. The default Profile and the last remaining active Profile cannot be deleted.
- **Recovery Authority & Ownership Separation:** Local Account Admin authority can recover deleted Profiles during the 30-day recovery window, limited strictly to the Profile deletion lifecycle. Restoring a Profile restores its Profile-level state, but must not undo individual content deletions (such as soft-deleted conversations, messages, memories, tasks, or attachments) that occurred before the Profile was deleted. Individual messages, attachments, and other user-owned files are governed by their owning user's lifecycle rather than the administrative Profile recovery interface.
- **Permanent Profile Purge & Attachment Cleanup Ordering:** Permanent Profile deletion validates that every attachment `storage_path` belongs strictly to the target Profile's storage directory (`ATTACHMENT_DIR/<profile_id>/...`) **before** modifying Profile state. Once paths are validated, the service transitions the Profile to a non-restorable state (`status = "purging"`), revalidates containment immediately before unlinking each file, deletes physical files first (treating already-missing files as cleaned, and halting on `OSError` with database records retained for retry without a separate ledger), and finally deletes the Profile's database records in foreign-key dependency order within an atomic transaction.
- **Backup & Asset Consistency Limitation:** Coordinated database-and-asset packaging remains the intended architecture. However, current SQLite backups (`app.db.backup`) snapshot only `companion.db` without bundling external files under `ATTACHMENT_DIR`. If an old backup snapshot is restored after permanent Profile deletion, attachment database rows will return while physical files remain deleted.
- **Host Maintenance:** Account-wide host maintenance may operate across Profiles only when explicitly designed as host maintenance, while preserving strict Profile privacy and never exposing one Profile's private content to another companion session. 
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
- **Task Purge Service Function:** `purge_expired_trash(db, retention_days=None, *, authority: ProfileSession | _MaintenanceAuthority)` permanently removes (`DELETE FROM tasks`) soft-deleted tasks older than the retention threshold. A validated Profile Session restricts the purge to its `profile_id` and is revalidated before commit. Only the exact in-process authority owned by the trusted standalone maintenance runner permits an account-wide sweep. An arbitrary Profile identifier, legacy `owner_id` or newly constructed authority object grants no maintenance authority.
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
3. **Data Retention & Lifecycle Policies:** Explicit retention policy definitions governing personal records across domains, including the 30-day Profile recovery lifecycle (`PC-IDENTITY-005`).
4. **Entity Identifier Allocation Direction:** Stable random identities use **UUIDv4** (`Account`, `Profile`, `Character`), while time-oriented records are approved to adopt **UUIDv7** (`Conversation`, `Message`, `Attachment`, `Memory` records, `Emotion` records) in dedicated follow-on work without mass-migrating existing identifiers.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future technical specification:

- **Soft Delete vs. Hard Purge Timing (Individual Content):** Granular default retention windows and user-facing recycle bin policies for individual conversations, messages, memories, and attachments (distinct from the 30-day Profile deletion lifecycle).
- **Audit Coverage, Schema & Storage:** Specific audit ledger design, including whether audit logs are persisted in a dedicated SQLite table, file append log, or structured event stream, and exact criteria for audit coverage.
- **Physical Asset Cleanup Design (Individual Content):** Architecture and scheduling for individual soft-deleted attachment physical file garbage collection sweeps outside full Profile purge.
- **Unified Retention Scheduling:** Whether retention cleanup runs via a unified scheduled service or domain-specific maintenance hooks.
- **Data Export & Portability:** Design for single-click user data export (e.g., structured JSON/ZIP archive of conversations, memories, and attachments).

---

## 6. Security & Ownership Boundaries

- **Zero Cleartext Credential Logging:** API keys, pairing tokens, session secrets, and passwords must never appear in application logs or audit records.
- **Profile Scope Isolation:** Deletion and purge operations must preserve authenticated ownership boundaries, strictly enforcing `entity.profile_id == authenticated_profile_id`. Cross-profile deletion or purge is strictly prohibited.
- **Tamper Resistance:** Where security audit records are maintained, they should be append-only and protected against non-administrative modification.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, ADR-0018, Decision D9)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Tool Security & Deterministic Policy ADR:** [`docs/04_Architecture/decisions/ADR-0010-d9-typed-tool-security-policy.md`](../decisions/ADR-0010-d9-typed-tool-security-policy.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-IDENTITY-001`, `PC-ACTION-001`)
- **Memory Domain Specification:** [`docs/04_Architecture/01_Domains/memory-and-personalization.md`](../01_Domains/memory-and-personalization.md)
- **Multimodal Domain Specification:** [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../01_Domains/multimodal-and-media.md)
- **Tool Permissions & Actions Spec:** [`docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`](tool-permissions-and-actions.md)
- **Storage & Assets Specification:** [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md)
