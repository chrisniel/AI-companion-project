# Multi-Profile PC V1 Ownership Model

**Status:** Accepted (Supersedes [`ADR-0009`](ADR-0009-d8-single-primary-user-baseline.md))  
**Decision ID:** ADR-0018  
**Codification Date:** 2026-10-03  
**Primary Canonical Owner:** [`profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md)  
**Related Specifications:** [`privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md), [`storage-and-assets.md`](../04_Infrastructure/storage-and-assets.md)

## Decision History
- Supersedes `ADR-0009` (D8 Single Primary User Baseline).
- Approved during PC V1 Architecture Decision Pass (2026-10-03).
- Recorded in Master Decision Register (`DECISION_REGISTER.md`, Rows 23 & 31).

## Context
`ADR-0009` originally locked a single-primary-user constraint for PC V1, deferring multi-user or multi-profile support to future releases. However, practical evaluation of desktop companion usage indicates that multiple individuals in a household often share a single workstation account without creating separate Windows OS user accounts. Deferring profile separation would lead to extensive schema debt, merged memories, and complex post-V1 data migrations.

## Decision
- **PC V1 adopts a 1 Local Account, Multiple Isolated Profiles model.**
- A single companion installation supports multiple distinct Profiles (e.g., for different family members sharing the installation). One human = one Profile.
- **Profile Scope & Isolation:**
  - Conversations, selective memories, turn queues, emotion states, character instances, and notification preferences are strictly scoped to a `profile_id`.
  - Large model assets in `LIBRARY_ROOT` remain shared host-wide across all profiles.
  - The local PC user possesses administrator authority to create, switch, export, and delete profiles.
  - Normal satellite devices (such as Android companions) bind to exactly one Profile during pairing.
- **Strict Profile Deletion Lifecycle:**
  - Deleting a profile enters a 7-day recoverable soft-delete window.
  - During this window, only the local PC admin can restore the profile.
  - After 7 days, a hard purge permanently destroys all database records, embeddings, and referenced assets for that profile.
- **Schema Migration Path:**
  - Existing database columns referencing `owner_id` map directly to `profile_id`.
  - Existing single-user databases migrate seamlessly into the "Default Profile" upon upgrade.

## Consequences
- Clean data separation is established from PC V1, preventing memory leakage between household members.
- Avoids future breaking database migrations when expanding beyond a single user.
- Satellite devices receive a simplified pairing experience bound to a dedicated profile.

## Canonical Relationships
Normative authority for profile ownership and device binding resides in [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../02_Data_and_Security/profiles-and-devices.md) and [`privacy-retention-and-audit.md`](../02_Data_and_Security/privacy-retention-and-audit.md).

## Change Control
Modifying profile scoping or isolation rules requires a formal decision record and independent security review.
