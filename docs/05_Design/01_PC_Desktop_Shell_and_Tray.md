# PC Desktop Shell & System Tray Design

> **Document Role:** UX/UI presentation and interaction design specification.<br>
> **Status:** Active Baseline (PC V1).<br>
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

### 3.2 System Tray Context Menu (Right-Click) & Lifecycle Distinctions
The system tray menu strictly distinguishes three distinct lifecycle concepts:
1. **Open AI Companion** *(Default click / double-click action)* — Restores and focuses the main window.
2. **Hide to System Tray** — Minimizes/hides the desktop UI window to the system tray. Both the Flutter UI process and the Local AI Runtime host process remain active and executing.
3. **Active Profile:** Shows current profile name with quick flyout to switch profiles.
4. --- (Separator) ---
5. **Mute Audio:** Immediate toggle to silence speech output and chime alerts.
6. **Performance Mode:** Quick toggle (`Normal` / `Low-Impact` / `Auto`).
7. --- (Separator) ---
8. **Runtime Status:** Informational label (e.g., *"Runtime: Active (PID 14220)"* or *"Runtime: Remote Host"*).
9. **Quit UI Only (Developer Test Only):** Exits or terminates the Flutter UI desktop process only. The Local AI Runtime host process survives independently and continues executing in the background ("Quit UI != Stop Runtime").
10. **Exit Companion (`PC-HOST-005` Planned):** Triggers explicit confirmation dialog: *"Exit Companion will stop the AI Companion and all scheduled reminders and alarms on this PC. Continue?"*. Upon user confirmation, it gracefully and securely stops the Flutter UI, the verified Local AI Runtime host, and its owned local inference engine (`llama-server.exe`). *(Note: Disabled in M2-H1 with label "Exit Companion (Full Shutdown - Planned PC-HOST-005)" until dedicated local host administration authority is delivered in PC-HOST-005).*

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

---

## 5. Desktop Conversation Experience & Chat Quality Design (`PC-CLIENT-006` / `PC-CLIENT-010`)

### 5.1 Chat Composer & Keyboard Interactions
- **Enter vs. Shift+Enter Semantics:** Pressing `Enter` in the chat input well submits the active message draft. Pressing `Shift+Enter` inserts a soft newline, allowing comfortable authoring of multiline prompts without premature submission.
- **Draft Persistence:** Unsent input text drafts persist locally across conversation switching and window minimization.
- **Asynchronous Scroll Restoration:** Scroll restoration is layout-aware. When opening a conversation or navigating between Chat and Settings, the viewport awaits authoritative message population and layout completion before applying scroll restoration, guaranteeing that reading positions in long conversation histories (30+ messages) are never jumpily overwritten.

### 5.2 Wide Markdown Tables
- **Horizontal Scrollbar:** Wide Markdown tables rendered in `AssistantMarkdownView` (via `_MarkdownTableWidget`) include a visible, interactive horizontal `Scrollbar` with `thumbVisibility: true`.
- **Gesture Support:** Supports mouse drag, trackpad pan, and horizontal wheel scrolling through explicit `ScrollConfiguration` configuration.
- **Cell Width Constraints:** Table cells enforce bounded width constraints (`minWidth: 80, maxWidth: 360`) with word-wrapping, preventing wide tables from clipping, overflowing message bubble bounds, or corrupting desktop layouts on compact viewports (1024×640).

### 5.3 Professional Mathematical Typesetting & LaTeX Syntax
- **Rendering Engine:** Mathematical expressions are rendered using `flutter_math_fork` (`SelectableMath`), delivering textbook-grade typography for scientific and mathematical formulations.
- **Supported Delimiters:**
  - **Display Math:** `\[ ... \]` and `$$ ... $$` (rendered centered with horizontal scroll capacity for long equations).
  - **Inline Math:** `\( ... \)` and `$...$`.
- **Supported Syntax:** Standard LaTeX math syntax including fractions (`\frac{a}{b}`), definite/indefinite integrals (`\int_{a}^{b}`), limits (`\lim_{x \to \infty}`), summations (`\sum`), text annotations (`\text{...}`), square roots, matrices, and greek symbols.
- **Copy & Inspection:** The raw LaTeX source remains accessible via selection and copy actions.
- **Code Block Isolation:** Fenced code blocks with language tags (e.g. ` ```latex `) remain literal code blocks and are never converted to math widgets.
- **Graceful Fallback:** Syntax errors or unsupported TeX commands fall back cleanly to formatted monospace text without throwing exceptions or corrupting adjacent message flow.

### 5.4 Scoped Conversation Text Zoom
- **Zoom Range & Stepping:** Conversation text zoom scales between **0.8× (80%)** and **1.6× (160%)** in 0.1× increments, defaulting to **1.0× (100%)**.
- **Keyboard & Mouse Controls:**
  - `Ctrl + Mouse Wheel Up`: Zoom in (+0.1×).
  - `Ctrl + Mouse Wheel Down`: Zoom out (-0.1×).
  - `Ctrl + =` or `Ctrl + +`: Zoom in.
  - `Ctrl + -`: Zoom out.
  - `Ctrl + 0`: Reset zoom to 1.0×.
- **Strict Scope Isolation:** Text scaling is applied strictly to the conversation viewport (`MediaQuery(textScaler: TextScaler.linear(zoom))`). It does **not** scale or distort navigation rails, title bars, dialogs, composer wells, or settings forms.
- **Persistence:** The active zoom level is persisted across application restarts in `%LOCALAPPDATA%\AI Companion\client_settings.json` under JSON key `chatZoomLevel`. The client settings path also respects explicit file overrides via the `COMPANION_CLIENT_SETTINGS_FILE` environment variable or custom file path constructor injection.

### 5.5 Generation Limits & Continuation Turns
- **Truthful Finish Reason Propagation:** The full generation pipeline (inference engine $\rightarrow$ provider $\rightarrow$ orchestrator SSE $\rightarrow$ Flutter client) preserves and propagates genuine completion reasons (`stop`, `length`, `cancelled`, `error`).
- **Terminal Status vs. Client Interrupted State:** Backend terminal statuses persisted in SQLite are `"completed"`, `"length"`, `"cancelled"`, or `"failed"` (`"streaming"` placeholder during turn generation). If an active SSE stream drops unexpectedly or transport disconnects before the terminal `done` event is received, Flutter transitions the in-memory client turn to a client-side transient `"interrupted"` state without falsely claiming successful completion.
- **Generation Limit Indicator:** When a response ends because the model reached its allocated output token limit (`finish_reason == "length"`), the UI displays a clear, non-intrusive status banner below the message bubble: *"Response reached generation limit"*.
- **Continuation Turn Action:** A `"Continue response"` button is rendered alongside the limit indicator. Activating it submits an explicit follow-up prompt (`"Continue"`) as a new conversation turn, seamlessly continuing the generated content without modifying past turn history.

### 5.6 Settings Model Management & Truthful Unload (`PC-CLIENT-010`)
- **Explicit Model Unload Control:** The Settings screen provides an *"Unload Model / Free VRAM"* button under the Active Model card whenever a model is resident in memory.
- **Generation Protection:** The unload action is disabled and blocked while active generation is in progress, preventing race conditions.
- **Truthful Unload Verification:** Activating unload calls authenticated `POST /api/v1/models/unload`. The backend returns `409 Conflict` if the provider is busy and `500 Internal Server Error` if unload fails or the model remains loaded. Flutter verifies that `status.model_loaded == false` before announcing success (`"Model unloaded successfully."`).
- **No Unevidenced VRAM Claims:** UI feedback truthfully reports model unload without claiming exact byte-for-byte VRAM reclamation without diagnostic hardware hooks.
- **Configuration Preservation:** Unloading a model evicts resident weights from memory while preserving saved model selection in `host_config.json`, allowing instant reload on demand.
- **Deferred Target Capabilities:** Hardware-aware dynamic memory budgeting formulas (e.g. 50% dedicated VRAM ceiling) and automated model recommendation algorithms remain target capabilities tracked under `PC-CLIENT-010` and are not currently enforced in code.

### 5.7 Nonblocking Future Chat UX Items (`PC-CLIENT-006` Backlog)
The following quality improvements are cataloged as nonblocking future UX enhancements:
1. **Visible Horizontal Scrollbar for Fenced Code Blocks:** Add a dedicated visible horizontal scrollbar (matching wide tables) and enhanced horizontal scrolling gestures for wide code snippets rendered by `_CodeBlockWidget`.
2. **Improved Model-Generated Mathematical Presentation:** Refine system prompt guidance and rendering for complex multi-step LaTeX equations, while strictly maintaining the rule that fenced literal code blocks (` ```latex `) are never converted into math widgets.
