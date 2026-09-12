# Implementation Plan: Android V1.3 Assistant Input, Matte Black Palette, Header Consolidation & Bouncy Transitions

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Proposed / Awaiting User Approval
- Sprint: Android V1.3 UI Polish, Matte Black Palette, Header Simplification & Language Dropdown
- Proposed Feature Branch: `feature/android-v1.3-matte-black-and-fluid-transitions` (branched off `develop` per `DEVELOPMENT.md`, awaiting user branch authorization)
- Scope Guard: Refine Assistant composer (eliminate mic/send button overlap, apply tactile embossed neumorphic styling to action buttons, inset well for message field morphing to embossed when typing), transition dark mode canvas & containers from bluish/navy to stealth matte black / charcoal graphite matching the user's reference image while preserving glass translucency, remove duplicate top bar on Home screen, place connection details inside interactive User avatar dropdown, update greeting subtitle to `● [Model] is online`, replace cramped 5-pill language row with a sleek `[🌐 Auto ▾]` dropdown, rename app to **"AI Companion"**, add subtle spring bounce to horizontal pager swiping and tab transitions, and smooth out Settings category transitions.

---

## 1. Problem Statement & User Guidance

### A. App Name & Identity Alignment: "AI Companion"
- **User Request**: *"and for the android app name we will change it to AI Companion too. since as you can see in the master plan it was not just local so yeah. I mean the user can use API instead too."*
- **Solution**:
  - Update `app_name` in `strings.xml` from `"Local AI Core"` to `"AI Companion"`.
  - Aligns with the Master Plan architecture, which supports both local inference (Windows PC llama.cpp) and cloud/remote APIs (Gemini, OpenRouter).

### B. Header Clutter & Redundancy on Home Screen
- **User Request**: *"Also this top part. can you hide the upper top part and put that inside that U icon when you pressed it. that top part is too much a lot of icon was happening. and that what does this mean? is it the user or? so yeah please and also instead of popping out above make it appear below the left icon with transition. thanks. also maybe change the Local AI Core? idk maybe made this app feels not too technical and let the user know that its the home?"*
- **Root Cause**:
  - `AppTopBar` at the very top displayed `(C) Local AI Core` and `● Core Active 22ms`.
  - Directly underneath, `HomeHeaderGreeting` repeated `"Good afternoon"`, `● Local AI Core reachable & ready`, and `(U)` user avatar.
  - This stacked two avatars and two status pills on the same screen. The bottom navigation bar already highlights "Home" with an embossed pill and icon, making the top bar completely redundant.
- **Target Design**:
  - Remove `AppTopBar` from the Home screen. Home opens directly into the greeting header, saving ~60dp of vertical space.
  - Update greeting subtitle from technical *"Local AI Core reachable & ready"* to personal: `● Aura is online` (dynamically using active persona/model name).
  - Tapping the `(U)` User avatar smoothly animates a soft glass dropdown card directly below it, displaying User Profile, shortcut to Settings, and Core Connection details (`● Core Active • 22ms`, IP, latency).

### C. Language Selector in Hero Card: Eliminating Cramped Vertical Text
- **User Request**: *"as you can see the selection for language is too cramped. can we do about it? like a dropdown of selection? or a 2x2 row and columns? can you recommend me?"*
- **Root Cause**:
  - In `HomeScreen.kt`, the top row of `HomeAssistantHero` places the status badge (`Core Online • Direct LAN`) and 5 text chips (`Auto`, `US EN`, `PH FIL`, `JP JA`, `Mixed`) on a single row.
  - On mobile widths, horizontal space runs out, squeezing `JP JA` into a vertical column (`J \n P \n J \n A`).
- **Target Design (Compact Dropdown Pill)**:
  - Replace the 5 static chips with an elegant soft glass pill: `[ 🌐 Auto ▾ ]` or `[ 🌐 EN ▾ ]`.
  - Tapping it smoothly opens a soft glass dropdown menu listing all languages with clean labels (`🌐 Auto (Detect)`, `🇺🇸 English (US)`, `🇵🇭 Filipino (Tagalog)`, `🇯🇵 Japanese (日本語)`, `✨ Mixed Mode`).
  - Takes only ~70dp of width, gives the connection badge plenty of room, and prevents any vertical text wrapping.

### D. Dark Mode Canvas & Containers: Matte Black / Charcoal Graphite
- **User Request**: *"can we change the background color or the containers to match this? instead of blueish its like a matt black but still with glass effect as we know now. just the accent. and btw this is the sample of pure neumorphism but we are not doing a pure so a refference only. Thanks"*
- **Target Design (Matching Reference Image)**:
  - Replace bluish/navy dark tones (`#162034`, `#0F1422`) with neutral matte dark charcoal / obsidian graphite:
    - Base Canvas (`BackgroundCharcoal`): `Color(0xFF0E1015)`
    - Raised Containers (`DarkSurfaceElevated`): `Color(0xF81F2229)` (Matches "Raised Element" in reference image)
    - Inset Wells (`DarkSurfaceWell`): `Color(0xFF121419)` (Matches "Sunken Element" / "Input Field")
    - Glass Translucency (`TranslucentPanelDark`): `Color(0xEB1A1D24)`
    - Specular Highlight: Subtle 8% white hairline bevel (`0x14FFFFFF`)
    - Shadow: Deep soft black (`0xCC000000`)

### E. Assistant Input Bar: Button Overlap & Tactile Morphing
- **User Request**: Size mic and send buttons to `36.dp` with `8.dp` spacing to eliminate overlap. Apply embossed neumorphic styling to action buttons (royal blue accent for Send). Message input box uses inset well when idle -> morphs to embossed surface when typing or focused.

### F. Bouncy Spring Transitions & Settings Smooth Switching
- **User Request**: Add subtle spring bounce to `HorizontalPager` swiping (`dampingRatio = 0.82f`) and bottom tab switching. Add smooth `AnimatedContent` transition to Settings categories.

---

## 2. Proposed Changes & Affected Files

### Component: Application Identity & Strings

#### [MODIFY] [strings.xml](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/res/values/strings.xml)
- Update `app_name` to `"AI Companion"`.

---

### Component: Home Screen & Header Simplification

#### [MODIFY] [AppShell.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
- Remove `AppTopBar` from Home screen (render topBar only when `currentRoute != Routes.HOME` and not a sub-destination with its own top bar).

#### [MODIFY] [HomeScreen.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/HomeScreen.kt)
- Update `HomeHeaderGreeting`:
  - Subtitle displays `● ${selectedPersona} is online` (e.g. `● Aura is online`) when reachable, or `Offline Mode` when disconnected.
  - Add interactive profile dropdown to `(U)` avatar: tapping animates a soft glass card below the avatar showing user profile details, settings button, and live connection status pill (`CompactConnectionIndicator`).
- Update `HomeAssistantHero`:
  - Replace cramped 5-pill row with a compact `[ 🌐 Auto ▾ ]` dropdown pill.
  - Clicking opens a soft glass dropdown menu listing all language options cleanly without crowding the status badge.

---

### Component: Color Palette & Foundations

#### [MODIFY] [Color.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/theme/Color.kt)
- Update dark mode color tokens from bluish/navy to neutral matte charcoal / obsidian graphite:
  - `BackgroundCharcoal = Color(0xFF0E1015)`
  - `BackgroundGraphite = Color(0xFF14161C)`
  - `DarkSurfaceBase = Color(0xF0181A22)`
  - `DarkSurfaceElevated = Color(0xF81F2229)`
  - `DarkSurfaceWell = Color(0xFF121419)`
  - `DarkSurfacePressed = Color(0xFF0F1115)`
  - `TranslucentPanelDark = Color(0xEB1A1D24)`
  - `NavSurfaceDark = Color(0xF2181B22)`
  - `ShadowDark = Color(0xCC000000)`

---

### Component: Assistant Screen Composer

#### [MODIFY] [AssistantComposer.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/assistant/AssistantComposer.kt)
- Set button sizes to `36.dp` with `8.dp` spacing and `minimumInteractiveComponentSize = Dp.Unspecified`.
- Send button: apply `Modifier.softNeumorphicRaised` with royal blue accent when `canSend == true`.
- Mic button: apply `Modifier.softNeumorphicRaised(shape = CircleShape, cornerRadius = 18.dp, elevation = 2.dp)`.
- Input container: morph from `Modifier.softInsetWell` when idle to `Modifier.softNeumorphicRaised` when focused or typing.

---

### Component: Brand Accent & Theme Defaults

#### [MODIFY] [AppearanceModels.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/AppearanceModels.kt)
- Set default `accentPreset = AccentPreset.BLUE`.

#### [MODIFY] [SettingsModels.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/domain/model/SettingsModels.kt)
- Set default `accentPreset = AccentPreset.BLUE` with label `"Royal Blue"` and hex `0xFF1D4ED8`.

#### [MODIFY] [SettingsViewModel.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsViewModel.kt)
- Update reset fallback to `AccentPreset.BLUE`.

---

### Component: Fluid Bouncy Transitions & Settings Smooth Switching

#### [MODIFY] [AppShell.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/shell/AppShell.kt)
- Add `PagerDefaults.flingBehavior(state = pagerState, snapAnimationSpec = spring(dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow))`.
- Update tab click and back button animations to spring specs with gentle damping.

#### [MODIFY] [SettingsScreen.kt](file:///d:/OtherProjects/AI-companion-project/android/app/src/main/java/com/example/ui/screens/settings/SettingsScreen.kt)
- Wrap section content in `AnimatedContent` with smooth horizontal slide and crossfade.
- Style selected tab chip with soft neumorphic embossed pill.

---

## 3. Manual Edit Guide for Animation Timings

| Effect | File | Line | Key Parameter to Edit |
| :--- | :--- | :--- | :--- |
| **Pager Swipe Bounce & Fling** | `AppShell.kt` | ~L256 | `snapAnimationSpec = spring(dampingRatio = 0.82f, stiffness = 400f)` |
| **Tab Click Transition** | `AppShell.kt` | ~L135 | `animationSpec = spring(dampingRatio = 0.84f, stiffness = 400f)` |
| **Back Button to Home** | `AppShell.kt` | ~L104 | `animationSpec = spring(...)` |
| **Sub-Screen Slide (NavHost)** | `AppShell.kt` | ~L229-L248 | `tween(durationMillis = 240)` |
| **Settings Category Switch** | `SettingsScreen.kt` | ~L159 | `AnimatedContent` transition spec |

---

## 4. Master Plan Roadmap: What Comes After This?

According to [`docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`](file:///d:/OtherProjects/AI-companion-project/docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md), the upcoming project phases are:

1. **Next Track (Backend Foundation - Tracks B1 & B2)**:
   - Plan and build the **FastAPI host application** (`backend/`) on Windows.
   - Set up SQLite + SQLAlchemy 2 database with Alembic migrations for tasks, conversations, memories, and alarms.
   - Define OpenAPI contracts and typed realtime WebSocket/SSE event streams.
2. **Web Productionization (Tracks C1 & C2)**:
   - Connect the existing React Web App (`frontend/web/`) to the FastAPI backend.
3. **Local Inference Runtime & Audio Pipeline (Tracks B4, B5 & B7)**:
   - Proof of concept for `llama.cpp` local inference (GGUF models with AMD RX 580 benchmark) and cloud API fallback (Gemini/OpenRouter).
   - Local STT (Whisper/Sherpa-ONNX) & TTS (Kokoro/Piper) voice pipeline.
4. **Android Client Production Integration (Tracks A2 & A3)**:
   - Connect the Android app to the Windows host via LAN WebSocket/HTTP.
   - Real Health Connect integration for biometric data synchronization.

---

## 5. Verification Plan

### Automated Tests
- Command: `./gradlew.bat testDebugUnitTest`
- Expected: All 109 unit and Robolectric tests pass.

### Physical Device Verification (Infinix X6820 via Wireless ADB)
- Deploy updated APK via `./gradlew.bat installDebug`.
- Visual & Touch Checks:
  1. Verify app launches with title **"AI Companion"**.
  2. Home screen has no duplicate top bar; opens directly into **"Good afternoon"** with `● Aura is online`.
  3. Tapping `(U)` avatar opens the smooth profile & connection status dropdown below it.
  4. Hero card language pill `[ 🌐 Auto ▾ ]` opens clean dropdown menu with no vertical text wrapping.
  5. Dark mode containers display neutral matte black / charcoal graphite matching the reference image.
  6. Assistant mic and send buttons do not collide; send button is embossed royal blue; text box morphs between inset and emboss.
  7. Swipe gestures and tab clicks have a subtle, lively spring bounce.
