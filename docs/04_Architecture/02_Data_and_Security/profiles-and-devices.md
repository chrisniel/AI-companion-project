# Profiles and Devices Architecture

> **Document Role:** Canonical domain architecture specification.  
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0004, ADR-0018)  
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for profiles, identity, and client device enrollment.

---

## 1. Purpose & Scope

This specification defines identity boundaries, data ownership partitions, and client device enrollment for the AI Companion:
- Structural separation between human identity (Profile) and client endpoints (Device).
- Multi-Profile PC V1 ownership model (`ADR-0018`).
- Migration roadmap from legacy single-user `owner_id` to `profile_id`.
- Satellite device binding (a normal satellite binds to exactly one Profile).
- Trusted device enrollment, per-device revocable credentials, and lifecycle management (`ADR-0005`).

---

## 2. Durable Architecture & Invariants

### 2.1 Multi-Profile PC V1 Ownership Model (ADR-0018)

In accordance with `ADR-0018`, superseding historical D8 / ADR-0009:
- **Single Account, Multiple Isolated Profiles:**
  - The PC installation operates under a single administrative Account, with first-class support for multiple isolated **Profiles** (e.g., separate household users sharing the installation. One human = one Profile. A Profile may contain multiple Characters/settings/configuration contexts.)
  - Each Profile has complete isolation over:
    - Conversations & turn histories
    - Long-term memories (`PROFILE` and `CHARACTER` scopes)
    - Character Instances & trait customisations
    - Active mood states
    - Tasks, Reminders, Alarms, and Routines
- **PC Desktop Administration:**
  - The primary PC desktop client (Flutter) provides profile switching and profile management (create, edit, delete, export).
  - The local desktop administrator can switch between profiles without restarting the background Local AI Runtime.
- **Migration Path (`owner_id` → `profile_id`):**
  - Database schema transitions from legacy `owner_id` to `profile_id`.
  - Existing legacy `default_user` records migrate into a newly created Profile with a stable UUID. "Default Profile" may be an initial display name; the display name is not identity.

### 2.2 Profile vs. Device Separation (Decision D4)

In accordance with Decision D4:
- **Profile Represents User Context:** A Profile models the companion user identity and owns all personal data.
- **Device Represents Client Endpoint:** A Device models a physical client endpoint (Flutter desktop, browser tab, Android phone).
- **Satellite Device Profile Binding:**
  - A normal mobile satellite device (e.g., Android Companion) is enrolled and paired to **exactly one Profile**.
  - The mobile device interacts with data strictly within its bound profile context; it cannot switch profiles or inspect other profiles on the PC host.
- **Independent Device Credentials:**
  - Devices receive independent, revocable credentials (`ADR-0005`).
  - Revoking or resetting a Device does **not** alter or destroy the underlying Profile data.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

- **Entity Ownership (`OwnerMixin`):** Defined in `backend/app/models/base.py`, `OwnerMixin` enforces an indexed `owner_id: Mapped[str] = mapped_column(String(64), nullable=False, default="default_user", index=True)`. Applied across `Attachment`, `Conversation`, `Memory`, `Message`, and `Task`.
- **Shared Credential Reality:** The FastAPI backend currently validates a single shared pairing key (`COMPANION_API_KEY`) via `Authorization: Bearer <token>` or `X-API-Key` headers (`app/core/security.py`).
- **Android Client Connection:** `SharedPreferencesConnectionRepository` stores the host URL and shared pairing token in unencrypted `SharedPreferences`.
- **Device Registry Status:** `NOT IMPLEMENTED`. No `devices` table or endpoint exists yet.
- **Multi-Profile Schema Status:** `NOT IMPLEMENTED IN SCHEMA`. The database does not yet contain a `profiles` table; code currently relies on `owner_id`.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved for PC V1:

1. **Profiles Table & Migration (`PC-IDENTITY-001`):**
   - New `profiles` table in SQLite (`id`, `name`, `avatar`, `created_at`, `is_active`).
   - Migration script transitioning domain entities from `owner_id` to `profile_id`.
2. **Device Registry & Independent Credentials (`PC-IDENTITY-002`):**
   - `devices` table storing enrolled hardware, client names, platform types, and hashed device tokens.
   - Independent credential generation during pairing, enabling individual device revocation from PC desktop settings.
3. **Satellite Device Binding (`ADR-0018`):**
   - Enrolling an Android satellite binds the device token to a specific `profile_id`.
   - Incoming API requests authenticate the device token and automatically resolve the bound `profile_id`.

---

## 5. Implementation-Open Details (Decision Debt)

The normative architecture for D4 and D8 is frozen. The following implementation-level details are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Pairing & Enrollment UX:** User interaction flow for introducing a new client device (camera-scanned QR code vs. short numeric code entered on PC; `DEBT-V1-013`).
- **Device Credential Format:** Token structure (cryptographically signed JWT device token vs. high-entropy random token hash).
- **Profile Deletion Cascade:** Exact cascade/cleanup implementation during the hard purge phase (ACTIVE -> 7-day recoverable deletion -> hard purge).

---

## 6. Security & Ownership Boundaries

- **Profile Isolation:** All queries on user data mandate `WHERE entity.profile_id = :authenticated_profile_id`. Cross-profile data leakage is strictly prohibited.
- **Satellite Isolation:** Satellite device tokens have access strictly to their bound profile.
- **Admin Boundary:** Profile management (creation, deletion, satellite pairing) requires local PC access or authenticated administrative credentials.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§3 Cross-Cutting Invariants, Decisions D4, D8)
- **Multi-Profile Ownership ADR:** [`docs/04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md`](../decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md)
- **Device Authentication ADR:** [`docs/04_Architecture/decisions/ADR-0005-d4-profile-device-credential-boundary.md`](../decisions/ADR-0005-d4-profile-device-credential-boundary.md)
- **Master Planning Spine:** [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) (Decisions D4, D8), [`WBS.md`](../../02_Planning/00_Master/WBS.md) (`PC-IDENTITY-001`, `PC-IDENTITY-002`)
- **Authentication & Secrets Spec:** [`docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md`](authentication-and-secrets.md)
- **UI Design Presentation:** [`docs/05_Design/02_Profile_Selector_and_Privacy.md`](../../05_Design/02_Profile_Selector_and_Privacy.md)
