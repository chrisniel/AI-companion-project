# Profiles and Devices Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the identity boundaries, ownership rules, and device enrollment model for the AI Companion:
- Structural separation between human user identity (Profile) and client endpoints (Devices).
- Single-primary-user baseline for PC V1 and Android V1.
- Ownership boundaries governing personal data, conversations, memories, and tasks.
- Device enrollment, trusted credentials, and revocation lifecycles.
- Strict containment of Multi-Profile support as a provisional, unscheduled future track.

---

## 2. Durable Architecture & Invariants

### 2.1 Profile vs. Device Separation (Decision D4)

In accordance with Decision D4:
- **Profile Represents Human Identity:** A Profile models the human companion user. It owns all personal records, conversational histories, long-term memories, user preferences, scheduled tasks, and companion relationship context.
- **Device Represents Client Endpoint:** A Device models a physical or virtual client machine accessing the companion runtime (e.g., local PC browser, Android mobile satellite, future secondary desktop). A Device possesses its own device identity, platform characteristics, and credential lifecycle.
- **Ownership Invariant:** A Device does **not** own Profile personal data. Devices are granted access to interact with the Profile's data under authenticated authority. Revoking, resetting, or decommissioning a Device does not destroy or alter the underlying Profile data.

### 2.2 Single-Primary-User Baseline (Decision D8)

In accordance with Decision D8:
- **PC V1 Baseline:** The system operates strictly as a single-primary-user companion workstation.
- **Owner Boundary Preservation:** Every user-owned entity is bound to an `owner_id` identifier. This preserves strict structural data-ownership boundaries in application code and schema without requiring multi-user tenant administration in V1.
- **Multi-Profile Status:** Multi-Profile architecture is classified as `PROVISIONAL / NOT STARTED / FUTURE / UNSCHEDULED` in the Feature Promotion Map. It is **not** part of PC V1, PC Later, or Android V1. Specifications must not prematurely introduce multi-user access controls, role-based tenant switching, or shared-device multi-tenant complexity into the release baseline.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

- **Entity Ownership (`OwnerMixin`):** Defined in `backend/app/models/base.py`, `OwnerMixin` enforces an indexed `owner_id: Mapped[str] = mapped_column(String(64), nullable=False, default="default_user", index=True)`. This mixin is applied across primary domain models:
  - `Attachment` (`app/models/attachment.py`)
  - `Conversation` (`app/models/conversation.py`)
  - `Memory` (`app/models/memory.py`)
  - `Message` (`app/models/message.py`)
  - `Task` (`app/models/task.py`)
- **Shared Credential Reality:** Authentication does not differentiate between individual client devices. The FastAPI backend validates a single shared pairing key (`COMPANION_API_KEY`), verified via `Authorization: Bearer <token>` or `X-API-Key` headers (`app/core/security.py`).
- **Android Client Connection:** In the Android client codebase, `SharedPreferencesConnectionRepository` (`android/app/src/main/java/com/example/data/repository/SharedPreferencesConnectionRepository.kt`) stores the host URL and the shared pairing token in persistent Android `SharedPreferences`.
- **Device Registry Status:** **NOT IMPLEMENTED**. No `devices` table, ORM model, schema, or API endpoint exists in the repository. The backend has no persistent record of enrolled hardware, device names, or distinct client IDs.
- **Per-Device Credentials Status:** **NOT IMPLEMENTED**. Independent, per-device revocable tokens do not exist in the current codebase; all clients present the same shared pairing token.

---

## 4. Approved Target Architecture / Not Yet Implemented

When implemented for the target companion architecture:

1. **Independent Device Credentials:** Each client endpoint (browser instance, Android phone) receives an independent, distinct device credential during enrollment, rather than possessing the shared master key.
2. **Revocable Device Access:** The host runtime maintains a persistent device registry enabling the user to view active client endpoints and revoke a specific lost, compromised, or decommissioned device without resetting master secrets or interrupting other paired devices.
3. **Master Secret Isolation:** Root host administration secrets and external service provider API keys are never distributed to client devices.

---

## 5. OPEN DESIGN

The following functional and technical mechanisms remain open design for future implementation plans:

- **Device Registry Schema:** Specific schema design for the `devices` table (e.g., device UUID, human-readable name, platform enum, public key / credential hash, last-seen timestamp, enrollment date).
- **Pairing & Enrollment UX:** User interaction flow for introducing a new client device (e.g., camera-scanned QR code, short numeric pairing code entered on PC, local LAN auto-discovery via mDNS vs. manual IP entry).
- **Device Credential Format & Lifecycle:** Token structure for device sessions (e.g., cryptographically signed device tokens, mutual TLS client certificates, or scoped API tokens) and policies for rotation and expiration.
- **Device Capabilities Schema:** Declarative metadata signaling device capabilities (e.g., audio capture, local GPU/NPU acceleration, display resolution, biometrics).
- **Future Multi-Profile Mechanics:** Conceptual mechanisms for eventual multi-profile support (e.g., local account selector UI, PIN/biometric authentication, isolated SQLite database files vs. tenant-filtered rows), preserved as an unscheduled future investigation.

---

## 6. Security & Ownership Boundaries

- **Profile Isolation (Decision D4):** Queries and mutations on Profile-owned personal data must preserve the authenticated ownership boundary, either through direct owner filtering or through an already owner-authorized parent/resource relationship. Broken Object Level Authorization (BOLA) is strictly prohibited.
- **Device Enrollment Gate:** A new device must not enroll solely because of network proximity. Enrollment must be explicitly authorized under the trusted-device policy. The exact authorization/confirmation surface, host/client interaction, pairing UX, and exchange protocol remain open design.
- **Least-Privilege Device Scope:** Enrolled devices are clients of the host runtime; they possess zero authority to alter host OS configuration or inspect master configuration outside their authorized scope.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline architecture, Decisions D4 (Profile vs Device), D8 (Single-primary-user baseline).
- [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) — Security boundaries, credential hierarchy, trust levels.

### Related Domain & Security Specifications
- [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](authentication-and-secrets.md) — Credential storage, token verification, and network topology.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](privacy-retention-and-audit.md) — Data ownership, deletion, and retention rules.
- [`docs/04_Architecture/01_Domains/android-companion.md`](../01_Domains/android-companion.md) — Mobile companion identity and synchronization protocol.
