# Profile Selector & Privacy Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`](../04_Architecture/02_Data_and_Security/profiles-and-devices.md), [`privacy-retention-and-audit.md`](../04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md), [`ADR-0018`](../04_Architecture/decisions/ADR-0018-multi-profile-pc-v1-ownership-model.md).

---

## 1. Overview & Multi-Profile Presentation

PC V1 operates on a **1 Local Account, Multiple Isolated Profiles** model. The desktop client enables household members or individual users to maintain clean separation across memories, conversation history, character configurations, and schedules.

---

## 2. Profile Selection & Switching Surfaces

### 2.1 Header Profile Chip
- Located at the top of the left navigation rail and window header.
- Displays current profile avatar, display name, and a small chevron icon.
- Clicking opens a compact dropdown showing:
  - List of available profiles with last active timestamp.
  - Active checkmark on the currently loaded profile.
  - "Lock / Switch Profile" action.
  - "Manage Profiles..." link opening Profile Management in Settings.

### 2.2 First-Run & Switcher Screen
- If configured to "Always prompt for profile on launch", opening the desktop shell presents a grid of profile cards:
  - Profile avatar, display name, and companion persona badge.
  - Optional lock icon indicating PIN/passcode protection.
  - "Add New Profile" card with a prominent `+` button.

---

## 3. Profile Creation & Configuration Modal

When adding or editing a profile:
1. **Display Name:** Freeform text input (1–32 characters).
2. **Profile Avatar:** Built-in geometric icons, default companion illustrations, or custom image file upload.
3. **Accent Theme Color:** Palette of accessible, WCAG-compliant accent swatches.
4. **PIN Protection (Optional):** 4-digit or 6-digit numeric PIN preventing casual inspection on shared family PCs.
5. **Initial Companion Binding:** Dropdown to select an initial Character Template (e.g., Neutral Assistant, Sarcastic Scholar, Warm Companion) to initialize the profile's character instance.

---

## 4. Profile Privacy & Deletion Lifecycle UX

### 4.1 Deletion Confirmation & 30-Day Soft-Delete Warning
- To prevent accidental data destruction, selecting "Delete Profile" triggers a high-severity dialog:
  - Clearly explains that all memories, conversation threads, tasks, and persona customizations will enter a **30-day soft-delete holding state** (`purge_after = deleted_at + 30 days`).
  - Active profile sessions are immediately revoked, stopping background tasks and access.
  - Highlights that shared model weights in `LIBRARY_ROOT` remain untouched.
  - Requires the user to type the profile name to confirm deletion before moving the profile to Recently Deleted.

### 4.2 Recovery & Admin Restoration
- If a profile is in the 30-day soft-delete state:
  - The Profile Management card in Settings displays a **"Recently Deleted"** section with a countdown badge (e.g., *"30 days remaining"*).
  - An explicit **"Restore"** button allows the local host administrator to reactivate the profile and return it to active selection, while preserving prior user-initiated child content deletions.
  - An explicit **"Permanently Delete"** button allows immediate physical-first hard purge with typed profile name confirmation.

---

## 5. Export & Portability UX

- Users can export their complete profile package into a portable archive (`.zip`) containing their database records and referenced assets.
- Sensitive credentials (cloud API keys, pairing secrets) are explicitly stripped from the export with a clear explanatory notice in the export dialogue.
