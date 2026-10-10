# PC Desktop Shell & System Tray Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`ADR-0017`](../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md).

---

## 1. Overview & Shell Philosophy

The PC V1 companion experience is anchored by a native Windows Flutter desktop application. The desktop shell provides:
1. A distraction-free, elegant primary window for conversation, memory management, schedule coordination, and settings.
2. A persistent Windows System Tray icon ensuring the companion remains accessible, displays real-time runtime status, and clearly conveys the core lifecycle invariant: **"Quit UI != Stop Runtime"**.

---

## 2. Window Framing & Navigation Layout

### 2.1 Window States & Sizing
- **Default Resolution:** 1280 × 800 (16:10 aspect ratio), centered on the active display.
- **Minimum Resolution:** 1024 × 640.
- **Window Controls:** Custom title bar adhering to Windows 11 Fluent design principles, including minimize, maximize/restore, and close buttons.
- **Close Action Behavior:** Clicking the title bar close button (`×`) minimizes/hides the window to the System Tray. A subtle toast or first-run tooltip explains: *"AI Companion is still running in your system tray to deliver scheduled reminders and alarms."*

### 2.2 Primary Navigation Rail (Left Sidebar)
The desktop shell utilizes a compact, collapsible left navigation rail:
- **Top:** Companion avatar, active profile switcher chip, and current companion mood accent.
- **Navigation Items:**
  1. **Chat:** Primary conversational interface with text and media attachments.
  2. **Voice:** Hands-free duplex conversational voice mode.
  3. **Schedule:** Tasks, Reminders, Alarms, and daily Routines.
  4. **Memory:** User-visible memory browser, fact verification, and forgetting controls.
  5. **Studio:** Character Studio (traits, lore, avatar, voice selection).
  6. **Settings:** Hardware profile, remote pairing, backup/reset, and performance toggles.
- **Bottom:** System runtime health indicator (Green = Connected, Yellow = Reconnecting, Red = Stopped) and quick Performance Mode icon (Normal / Low-Impact).

---

## 3. Windows System Tray Integration

### 3.1 Tray Icon Appearance
- **Normal State:** Companion icon with a subtle status pip.
- **Low-Impact / Gaming Mode:** Muted icon with a discrete feather or shield pip.
- **Muted Audio State:** Icon with a discrete mute slash.
- **Disconnected / Offline:** Grayscale icon with warning indicator.

### 3.2 System Tray Context Menu (Right-Click)
1. **Open AI Companion** *(Default double-click action)* — Restores and focuses the main window.
2. **Active Profile:** Shows current profile name with quick flyout to switch profiles.
3. --- (Separator) ---
4. **Mute Audio:** Immediate toggle to silence speech output and chime alerts.
5. **Performance Mode:** Quick toggle (`Normal` / `Low-Impact` / `Auto`).
6. --- (Separator) ---
7. **Runtime Status:** Informational label (e.g., *"Runtime: Active (PID 14220)"*).
8. **Stop Runtime:** Stops the background Python runtime service and model server.
9. **Exit Companion:** Quits the Flutter desktop UI application while keeping the background runtime running, with an explicit confirmation dialog if the user also wants to stop the runtime.

---

## 4. Visual Design Identity & Invariants

### 4.1 Approved Product Design Language
The approved visual design language across the companion ecosystem is:
**Neumorphism + Glassmorphism / Liquid Glass + Minimalism**, maintaining strict visual parity with the primary `frontend/web/` reference implementation.

- **Neumorphic Raised Surfaces:** Directional dual light/dark outer shadow pairs (`NeumorphicSurface`) providing physical tactile elevation that adapts dynamically to Dark and Light theme modes.
- **Neumorphic Recessed Wells:** Deep, authentic physical inset depth rendered via inner shadow masks (`NeumorphicSurface(isRecessed: true)`) for input wells (chat composer) and diagnostic cards.
- **Glassmorphism / Liquid Glass:** Backdrop blur (16px), subtle ambient radial glow matching the active accent color, and translucent border highlights.
- **Minimalism:** Uncluttered layouts, clean typographic hierarchy, generous padding, and absence of jarring saturated blocks.
- **Theme Palettes & Accents:** Light and Dark themes with four curated accent presets: *Ocean Sky*, *Cobalt Indigo*, *Emerald Teal*, and *Amethyst Violet*.

### 4.2 Theme & Accessibility Invariants

- **System Theme Synchronization:** Automatic switching between Windows Dark Mode and Light Mode based on OS preference, with manual override in Settings.
- **Keyboard Navigation:** Full keyboard focus traversal (`Tab` / `Shift+Tab`), shortcut keys (`Ctrl+N` for new conversation, `Ctrl+M` to toggle mute, `Ctrl+,` for settings, `Esc` to hide window).
- **High-Contrast Support:** Compatible with Windows High Contrast mode themes.
