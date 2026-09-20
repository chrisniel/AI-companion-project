# Implementation Plan: Android V1.2 Fluid Transitions, Swipe Navigation & Soft Glass Parity

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Approved & Implemented
- Sprint: Android V1.2 Fluid Transitions, Swipe Gestures & Soft Glass Depth
- Scope Guard: Soft Glass design system (Neumorphism + Glassmorphism fusion) matching web client sidebar tokens (`--neu-nav-embossed`, `--neu-nav-inset`), eliminate the harsh glowing border around selected nav items, horizontal swipe pager for 5 primary tabs, directional left/right menu sliding, liquid glass transition depth, and regression test suite.

---

## 1. Problem Statement & User Visual Clarification

### A. Neumorphism + Glassmorphism Fusion (Web Client Parity)
- **User Clarification**: *"wait, I dont mean to pure neumorphism. Sorry for not clarifying we still stick with Neumorphism + glassmorphism. wait let me send a sample of the web image. that? it still glass but the neumorphism is there. can you revise the plan? Thanksssss"*
- **Web Reference Analysis (`frontend/web/src/index.css`)**:
  - The design is **Soft Glass**: a refined fusion of **Glassmorphism** (translucent atmospheric panels, background aura glow presets) and **Neumorphism** (directional embossed dual-shadows and inset wells).
  - **Light Mode (`.nav-menu-item-active`)**:
    - Background: `var(--color-surface-elevated)` (`#FFFFFF`)
    - Dual Shadow (`--neu-nav-embossed`): `2px 3px 8px rgba(150, 172, 202, 0.35), -2px -2px 6px rgba(255, 255, 255, 0.95)`
    - Border: Delicate hairline `rgba(255, 255, 255, 0.70)` or subtle slate hairline (`0.75.dp`), NOT a harsh white stroke.
    - Icon & Text: Vibrant accent royal blue.
  - **Dark Mode (`.nav-menu-item-active`)**:
    - Background: `var(--color-surface-elevated)` (`#192130`)
    - Dual Shadow (`--neu-nav-embossed`): `2px 3px 8px rgba(0, 0, 0, 0.60), -1.5px -1.5px 5px rgba(255, 255, 255, 0.04)`
    - Border: Restrained hairline border `rgba(255, 255, 255, 0.12)` (`var(--color-border-highlight)`), NOT a glowing neon ring!
    - Icon & Text: Vibrant sky blue.
  - **Why Android Had a "Weird Border Glow"**:
    - In `AppBottomBar.kt`:
      - Line 170: `CenterAssistantNavItemView` applied `.border(1.5.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.8f), ...)))`.
      - Line 270: `BottomNavItemView` applied `.border(1.0.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.35f), accentPrimaryColor.copy(alpha = 0.55f))))`.
    - That 80% white stroke and 55% cyan gradient produced an artificial neon glow ring. In the web client, it is a soft, delicate 1px hairline `rgba(255, 255, 255, 0.12)` border with embossed dual shadows!

### B. "Transition Between Changing Menus Still Too Laggy" & Directional Sliding
- **User Feedback**: *"the transition between changing menus still too laggy, maybe instead we do is slide from left or right based on the menu placement."*
- **Root Cause**: In `AppShell.kt`, primary destinations were mounted/unmounted via `NavHost`. Every tab switch destroyed the previous screen and forced complete instantiation, layout measurement, and composition of the next screen on frame 0. This caused frame drops and perceptible lag on Android hardware.
- **Solution**: Directional navigation where switching to a menu to the right slides from right-to-left, and switching to a menu to the left slides from left-to-right.

### C. Swipe Across Menus & Eliminate "Contents Popping Up"
- **User Feedback**: *"Also, can you add where users can swipe in the screen to swipe to other menu not just clickable below then add a transition to the menu too. not just it pops out. and the other things contents to slowly transition too. It feels laggy because a lot of contents inside each menu is just popping up."*
- **Solution**: Implement `HorizontalPager` with `beyondViewportPageCount = 1` for the 5 primary tabs (`Home | Tasks | Assistant | Health | More`). This enables 1:1 physical finger tracking, inertial fling, and ensures neighbor screens are already pre-rendered, completely eliminating content pop-in and transition latency.

---

## 2. Architecture & Technical Design

```
+-----------------------------------------------------------------------------------+
| AppShell (Root Compose Container)                                                 |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | AppTopBar (Contextual title & status, synced with pagerState.currentPage)   |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | NavHost (Handles Secondary Screens: Settings, Schedule, Alarms, etc.)       |  |
|  |                                                                             |  |
|  |   Route: Routes.HOME / Primary Pager Container                              |  |
|  |   +---------------------------------------------------------------------+   |  |
|  |   | HorizontalPager (state = pagerState, beyondViewportPageCount = 1)   |   |  |
|  |   |                                                                     |   |  |
|  |   | [ Page 0: Home ] <---> [ Page 1: Tasks ] <---> [ Page 2: Assistant ]|   |  |
|  |   |                                          <---> [ Page 3: Health ]   |   |  |
|  |   |                                          <---> [ Page 4: More ]     |   |  |
|  |   +---------------------------------------------------------------------+   |  |
|  |                                                                             |  |
|  |   Route: Secondary Screens (Slide-in from right, slide-out to right)        |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | AppBottomBar (Soft Glass Embossed Neumorphic Depth - NO HARSH BORDER GLOW)  |  |
|  | - Tab 0: Home      (Tapping animates pagerState to page 0)                  |  |
|  | - Tab 1: Tasks     (Tapping animates pagerState to page 1)                  |  |
|  | - Tab 2: Assistant (Tapping animates pagerState to page 2 - Elevated center)|  |
|  | - Tab 3: Health    (Tapping animates pagerState to page 3)                  |  |
|  | - Tab 4: More      (Tapping animates pagerState to page 4)                  |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 3. Phased Implementation Steps

### Phase 1: Soft Glass Neumorphic Calibration (Eliminate Harsh Border Glow)
1. **Calibrate `AppBottomBar.kt` Selected Pill**:
   - Align selected indicator pill with web tokens (`--neu-nav-embossed`):
     - **Light Mode**: Background `surfaceElevated` (`#FFFFFF`), dual shadow (drop shadow `Color(0x3D7F95AF)` + top highlight `Color(0xF5FFFFFF)`), delicate hairline border `SoftTheme.tokens.borders.hairline` with subtle border gradient (`alpha ~ 0.30f`).
     - **Dark Mode**: Background `surfaceElevated` (`#192130`), dual shadow (drop shadow `Color(0xB8000000)` + specular rim `Color(0x14FFFFFF)`), delicate hairline border `Color.White.copy(alpha = 0.12f)`.
     - **Remove** the harsh `0.35f` white + `0.55f` cyan gradient border stroke that was creating the artificial neon glow.
2. **Calibrate Floating Center Assistant Button**:
   - In `CenterAssistantNavItemView`:
     - Keep elevated floating circular shape (52dp).
     - Replace the `1.5dp` `Color.White.copy(alpha = 0.8f)` border with a delicate `0.75dp` hairline edge matching the web's subtle glass highlight (`Color.White.copy(alpha = 0.15f)` in dark mode, `Color.White.copy(alpha = 0.70f)` in light mode).
     - Keep the soft elevated drop shadow and top-left dual specular reflection.
3. **Calibrate `SoftNeumorphic.kt` Engine**:
   - Ensure `softNeumorphicRaised` directional gradient smoothly blends from top-left to bottom-right without hard perimeter double-strokes.
   - Maintain `softInsetWell` for text fields, search bars, and pressed states.

### Phase 2: Horizontal Swipe Pager & Directional Slide Navigation
1. **Primary Screen Pager Integration in `AppShell.kt`**:
   - Introduce `rememberPagerState(initialPage = 0) { 5 }` within the primary destination container.
   - Map page indices:
     - `0`: `HomeScreen`
     - `1`: `TasksScreen`
     - `2`: `AssistantScreen`
     - `3`: `HealthScreen`
     - `4`: `MoreScreen`
   - Set `beyondViewportPageCount = 1` so neighboring pages remain composed in memory, eliminating frame drops during transitions.
2. **Bidirectional Full-Screen Swipe Gestures**:
   - Enable full-screen horizontal swiping across Home, Tasks, Assistant, Health, and More with native 1:1 finger tracking, physics fling, and overscroll bounce.
3. **Directional Programmatic Sliding on Bottom Tab Tap**:
   - When user taps a bottom navigation tab, call `coroutineScope.launch { pagerState.animateScrollToPage(item.pageIndex, animationSpec = tween(durationMillis = 280, easing = FastOutSlowInEasing)) }`.
   - Naturally slides left-to-right or right-to-left based on relative tab index ($0 \dots 4$).
4. **Bottom Bar & Top Bar Synchronization**:
   - Current selected tab in `AppBottomBar` is driven directly by `pagerState.currentPage`.
   - Top bar title and actions update reactively as pages swipe or scroll.
5. **Secondary Screen Transitions in `NavHost`**:
   - Screens like `Settings`, `Schedule`, `Alarms`, `Characters`, `Permissions`, etc. push on top of the pager with directional slide animations:
     - `enterTransition = slideInHorizontally { it } + fadeIn(tween(200))`
     - `exitTransition = slideOutHorizontally { -it / 4 } + fadeOut(tween(200))`
     - `popEnterTransition = slideInHorizontally { -it / 4 } + fadeIn(tween(200))`
     - `popExitTransition = slideOutHorizontally { it } + fadeOut(tween(200))`

### Phase 3: Liquid Glass Transition Depth (Eliminate Content Pop-in)
1. **Liquid Pager Transformation**:
   - Apply subtle scale and alpha damping to pages as they slide:
     ```kotlin
     val pageOffset = (pagerState.currentPage - page) + pagerState.currentPageOffsetFraction
     val absOffset = pageOffset.absoluteValue.coerceIn(0f, 1f)
     alpha = 1f - (absOffset * 0.18f)
     scaleX = 1f - (absOffset * 0.02f)
     scaleY = 1f - (absOffset * 0.02f)
     ```
   - Creates a physical, cohesive "liquid glass" glide where screen contents transition smoothly instead of popping abruptly.
2. **Eliminate Layout Rebuild Latency**:
   - Because neighbor pages are pre-composed (`beyondViewportPageCount = 1`), swiping or tapping reveals already-rendered layouts, eliminating the abrupt "popping up" sensation.

### Phase 4: Automated Testing & Verification
1. **Robolectric & Unit Tests**:
   - Update `NavigationRobolectricTest.kt` to verify:
     - All 5 bottom navigation clicks smoothly transition pages in `HorizontalPager`.
     - Horizontal swipe gestures (`performTouchInput { swipeLeft() }` / `swipeRight()}`) switch pages between Home, Tasks, Assistant, Health, More.
     - Secondary screen push/pop navigation remains 100% intact.
   - Run `./gradlew.bat testDebugUnitTest` and ensure 108+ tests pass.
2. **Physical Device Verification (Infinix X6820)**:
   - Build and install debug APK (`./gradlew.bat installDebug`).
   - Visually audit:
     - Zero harsh glowing border ring on selected bottom bar item in both light and dark modes (matching web client sidebar).
     - Natural, buttery smooth horizontal swiping across screens.
     - Directional sliding when tapping tabs.
     - Content feels fluid and no longer pops up abruptly.

---

## 4. Verification Plan

### Automated Tests
- Command: `./gradlew.bat testDebugUnitTest`
- Expected: All unit and Robolectric tests pass (108/108+).

### Physical Device Manual Verification
- Device: Infinix X6820 (Android 13) via wireless ADB.
- Manual Checks:
  1. Swipe left/right on screen across Home, Tasks, Assistant, Health, More.
  2. Tap bottom navigation items and verify directional sliding (left vs right based on placement).
  3. Verify no harsh glowing border rings on selected menu items in both light and dark modes (matching web client sidebar).
  4. Verify smooth content transitions with zero abrupt pop-in.
