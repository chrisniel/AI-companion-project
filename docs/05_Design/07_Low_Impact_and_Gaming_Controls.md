# Low-Impact & Gaming Controls Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](../04_Architecture/04_Infrastructure/performance-and-capacity.md), [`windows-host-and-notifications.md`](../04_Architecture/04_Infrastructure/windows-host-and-notifications.md), [`DECISION_REGISTER.md Row 44`](../02_Planning/00_Master/DECISION_REGISTER.md).

---

## 1. Overview & Resource Philosophy

Gaming / Low-Impact mode ensures that the AI Companion harmoniously coexists with heavy foreground PC workloads—such as AAA games, 3D rendering engines (Blender, Unreal Engine), and video editing suites—without causing stutter, frame drops, or VRAM starvation.

---

## 2. Three-State Mode Selector

Accessible via the main window footer, Settings $\rightarrow$ Performance, and the System Tray context menu:

```text
[ (•) Normal ]      [ ( ) Low-Impact ]      [ ( ) Auto (Recommended) ]
```

1. **Normal:** Standard configured hardware profile (`eco`, `balanced`, or `maximum`). Full context length, full GPU layer offloading.
2. **Low-Impact:** Manually forces the runtime into a low-resource footprint. Background tasks paused; GPU layers reduced or substituted.
3. **Auto (Default):** The runtime monitors active foreground processes against the configured **Game & Heavy Application List** (Option B). Automatically engages Low-Impact mode when a match is detected and restores Normal mode when the process terminates.

---

## 3. Game & Heavy Application List Management (Option B)

Located in Settings $\rightarrow$ Performance $\rightarrow$ "Auto Gaming Detection":
- **Default Application Roster:** Ships with common launcher and game process names pre-populated:
  - `steam.exe`, `epicgameslauncher.exe`, `battle.net.exe`
  - `blender.exe`, `unrealeditor.exe`, `premiere.exe`, `davinci.exe`
- **Add Executable Controls:**
  - `[ Browse .exe... ]`: Standard Windows file picker to select installed game executables.
  - `[ Add Running Process... ]`: Dropdown displaying currently running foreground applications for one-click addition.
- **Remove & Toggle:** Each entry features an active checkbox and a delete trashcan icon.

---

## 4. Visual Feedback & Transition UX

### 4.1 Main Window Status Banner
When Low-Impact mode is active (either manually or via Auto detection), a discreet, non-intrusive status strip appears at the bottom of the chat view:
> 🎮 **Gaming Mode Active** — Background tasks paused to prioritize GPU performance. [Switch to Normal]

### 4.2 Model Substitution Indicator
If the user has enabled **"Substitute Lightweight Model in Gaming Mode"**:
- When entering Low-Impact mode, the status banner indicates the model swap:
  > ⚡ **Low-Impact Model Active (Qwen-1.5B)** — VRAM freed for foreground graphics.
- Generational responses during gaming mode display a small badge: `[Low-Impact Mode]`.

### 4.3 Cooldown Delay Indicator
When exiting a game, a 30-second cooldown timer elapses before restoring the heavy model to prevent thrashing if the game is immediately restarted. The status banner displays: *"Restoring Normal Mode in 24s... [Restore Now]"*.

---

## 5. System Tray Quick Controls

Right-clicking the System Tray icon displays a quick-switch sub-menu:
```text
Performance Mode ▸  (•) Auto (Gaming List)
                    ( ) Normal
                    ( ) Force Low-Impact
```
This enables gamers to toggle mode without opening the main companion window.
