# Local AI Control Center — Web Frontend Static Review

> **Scope:** Static source-code review of the exported React/TypeScript frontend from Google AI Studio Build.
>
> **Important:** Runtime testing, `npm install`, `npm run dev`, browser testing, and npm/build validation were intentionally left to the local developer workflow.
>
> **Conclusion:** Keep the frontend. It is a solid prototype foundation and does **not** need to be rewritten.

---

# 1. Overall Assessment

| Area | Assessment |
|---|---|
| UI architecture | Good prototype foundation |
| Component reuse | Good |
| Theme system | Very good |
| Mock-data separation | Mostly good |
| FastAPI readiness | Needs one architecture layer |
| Accessibility | Good intentions, several real gaps |
| Dependency hygiene | Needs cleanup |
| Production configuration | Contains AI Studio/mock leftovers |
| Backend coupling | None yet, which is good |
| GitHub readiness | Good after small cleanup |

The frontend is worth preserving and improving incrementally.

---

# 2. Must Fix

## 2.1 Undefined CSS Design Tokens

Two CSS variables are referenced but not defined:

```css
--color-border-strong
--color-surface
```

They appear in components such as:

- `src/components/workspace/devices/DeviceCard.tsx`
- `src/components/workspace/memory/MemoryItemCard.tsx`
- `src/components/workspace/characters/CharacterCard.tsx`
- `src/components/workspace/characters/CharacterEditor.tsx`

This can cause some hover/background declarations to become invalid silently.

### Recommended fix

Either define them semantically:

```css
:root {
  --color-border-strong: rgba(...);
  --color-surface: var(--color-surface-primary);
}
```

and provide dark-theme equivalents, or replace `--color-surface` with the intended existing semantic surface token.

---

## 2.2 Application-Wide `select-none`

The application root in `App.tsx` uses:

```tsx
<div className="... select-none">
```

There are many `select-none` usages and very few `select-text` overrides.

This can prevent normal text selection/copying across:

- assistant responses
- logs
- memory entries
- model/runtime data
- errors
- technical information

### Recommended fix

Remove `select-none` from the application root.

Use it only for surfaces where selection is undesirable:

- sidebar items
- icons
- buttons
- tabs
- drag handles
- tactile controls

Normal content should remain selectable.

---

## 2.3 Custom Wallpaper Persistence Uses Base64 in `localStorage`

The custom wallpaper implementation reads files using:

```tsx
reader.readAsDataURL(file)
```

and persists the Base64 result through theme settings.

This is acceptable for tiny prototypes but can easily hit browser `localStorage` limits with normal wallpapers.

### Risks

- `QuotaExceededError`
- theme persistence failure
- large JSON payloads
- slow storage writes

### Recommended short-term fix

Either:

- enforce a reasonable file-size limit and catch storage failures, or
- store image blobs in IndexedDB.

### Long-term fix

When the Local AI Core exists, custom assets can be managed outside browser `localStorage`.

---

## 2.4 Generate and Commit a Lockfile

The export contains:

```text
package.json
```

but no package-manager lockfile.

After running:

```bash
npm install
```

commit the generated:

```text
package-lock.json
```

Then clean installs can use:

```bash
npm ci
```

This improves reproducibility.

---

# 3. Dependency and AI Studio Cleanup

The current `package.json` includes packages such as:

```text
@google/genai
express
dotenv
@types/express
```

but the inspected React source does not currently use them.

`vite` also appears in both dependencies and devDependencies.

The README and environment example still contain Gemini-related frontend instructions.

Examples include:

```text
GEMINI_API_KEY
```

and AI Studio metadata that suggests a server-side Gemini capability.

That no longer matches the intended architecture:

```text
React
   ↓
FastAPI
   ↓
Gemini only if configured
```

The Gemini API key should **not** live in the React frontend.

### Recommended cleanup

Before backend integration, review and remove unused packages unless a real frontend use appears:

```text
@google/genai
express
dotenv
@types/express
```

Also clean:

- `README.md`
- `.env.example`
- AI Studio metadata
- duplicate Vite dependency declarations

---

# 4. Mock Data Architecture

The project already has useful mock-data separation such as:

```text
src/mock/localAiData.ts
src/mock/healthData.ts
src/mock/characterData.ts
src/mock/deviceAndMemoryData.ts
src/mock/logsData.ts
```

This is a good foundation.

However, several UI components import mocks directly.

Example pattern:

```tsx
import { mockTaskItems } from '../../mock/localAiData';
```

If FastAPI is wired directly from individual components later, the frontend will become harder to maintain.

## Recommended architecture before backend integration

```text
UI
 ↓
Repository / Service
 ↓
MockRepository
```

Later:

```text
UI
 ↓
Repository / Service
 ↓
ApiRepository
 ↓
FastAPI
```

Possible structure:

```text
src/data/
├── repositories/
│   ├── assistantRepository.ts
│   ├── taskRepository.ts
│   ├── scheduleRepository.ts
│   ├── modelRepository.ts
│   ├── healthRepository.ts
│   └── deviceRepository.ts
├── mock/
└── api/
```

or use a `src/services/` naming convention if preferred.

This is the most important architecture improvement before real API wiring.

---

# 5. Routing

Current navigation is controlled using local application state and a switch based on the active section.

That is acceptable for the prototype.

For production, consider React Router.

Suggested routes:

```text
/
/assistant
/tasks
/schedule
/health
/memory
/models
/characters
/devices
/logs
/settings
```

Benefits:

- browser Back/Forward support
- refresh preserves location
- deep links
- bookmarkable pages
- easier route testing
- easier future authorization/navigation guards

This is a **Should Improve**, not an urgent blocker.

---

# 6. Responsive State vs User Override

The current responsive logic automatically changes sidebar/assistant-panel state based on viewport width.

Conceptually:

```text
<= 1280
Assistant hidden
Sidebar collapsed

<= 1366
Assistant collapsed

> 1366
Everything expanded
```

This works, but automatic layout behavior and user-controlled layout state currently share the same state values.

That can lead to a user manually collapsing a panel only for a resize event to reopen it.

## Recommended future pattern

Separate:

```text
responsive recommendation
+
user override
```

Conceptually:

```tsx
const autoPanelMode = deriveFromWidth(width);
const effectiveMode = userOverride ?? autoPanelMode;
```

---

# 7. Accessibility Review

The project already contains several good accessibility patterns, including:

- `aria-selected`
- `aria-expanded`
- `aria-modal`
- progress roles
- switch roles
- focus-visible styling
- semantic buttons

However, the implementation should not yet be considered fully accessibility-complete.

## 7.1 Modal

The modal supports:

- Escape close
- backdrop close
- `aria-modal`

But should also support:

- moving focus into the modal when opened
- focus trapping while open
- restoring focus to the trigger when closed

## 7.2 Custom Select

The custom Select supports basic opening behavior but does not appear to fully implement keyboard-navigation behavior expected from an accessible listbox/select pattern.

Expected behavior may include:

- ArrowDown
- ArrowUp
- Home
- End
- Enter
- Escape
- active option management

For production, either implement the complete keyboard pattern or use an established accessible primitive underneath.

---

# 8. TypeScript and Tooling

Current TypeScript configuration does not enable strict mode.

The npm script named:

```json
"lint": "tsc --noEmit"
```

is actually performing type checking, not linting.

## Recommended scripts later

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit",
    "lint": "...",
    "format": "..."
  }
}
```

Eventually work toward:

```json
"strict": true
```

Potentially also:

```text
noUnusedLocals
noUnusedParameters
```

Do not enable every strict rule at once if it creates a huge cleanup burden. Improve incrementally.

---

# 9. Large Components

Several view files are large enough that they may become difficult to maintain once API integration begins.

Examples include large files such as:

- `ScheduleView.tsx`
- `HomeView.tsx`
- `TasksView.tsx`
- `LogsView.tsx`
- `AssistantView.tsx`
- `SettingsView.tsx`
- `ThemeContext.tsx`
- `AssistantPanel.tsx`

These do not need an immediate rewrite.

## Recommended strategy

Extract meaningful page sections when backend integration starts.

Example:

```text
HomeView/
├── HomeView.tsx
├── NextCard.tsx
├── TodaySummary.tsx
├── AiStatusCard.tsx
├── WellnessCard.tsx
├── QuickActions.tsx
└── RecentActivity.tsx
```

Avoid excessive fragmentation into tiny components with no real reuse or conceptual boundary.

---

# 10. Fictional / Prototype Runtime Data

The prototype contains many fictional or placeholder values, including examples such as:

```text
Threadripper / RTX 4090
Pixel 8 Pro
Sony WH-1000XM5
PipeWire
Apple Metal
CoreAudio
CUDA
42.8 t/s
22ms latency
```

Most of these are correctly located in mock data.

Some values still appear directly in UI components.

Examples include hardcoded user/model/runtime labels such as:

```text
Chris
Llama-3.1-8B-Instruct
On-Device Neural Core v2.4
Zero External Cloud Telemetry
```

and fixed latency/port values.

## Recommended cleanup

Move remaining hardcoded runtime/user/device values into centralized mock fixtures.

Later replace those fixtures through repositories connected to FastAPI.

Also avoid claims such as:

```text
Zero External Cloud Telemetry
```

when the real product architecture intentionally supports optional Gemini/cloud fallback.

---

# 11. Performance Profile Enum Mismatch

The frontend currently contains a profile set that includes:

```text
eco
balanced
maximum
turbo
```

The currently agreed architecture uses:

```text
Eco
Balanced
Maximum
```

Unless a four-profile design is intentionally chosen, remove `turbo` before backend enums are defined.

Small enum mismatches become expensive once shared contracts exist.

---

# 12. Things Worth Preserving

## 12.1 Theme Architecture

The theme system is a strong part of the export.

It already handles concepts such as:

- Light
- Dark
- System
- background presets
- custom accents
- glass settings
- effect intensity
- interface density
- animation preferences
- persisted theme settings
- system color-scheme behavior

Keep this foundation.

## 12.2 Semantic Design Tokens

The centralized semantic token approach in CSS is substantially better than scattering arbitrary colors and shadows throughout JSX.

Keep it.

## 12.3 Reusable Component Library

Useful primitives are already separated, including components such as:

```text
Button
Card
GlassPanel
Modal
Tabs
Toggle
Select
Slider
Tooltip
MetricCard
CircularMetric
```

Keep the component system and improve it incrementally.

## 12.4 No Real Gemini / Backend Coupling Yet

Static review found no established production backend coupling such as:

- real API fetches
- WebSockets
- Gemini requests
- production device APIs

That is good at this phase.

## 12.5 No Obvious Dangerous Frontend Execution Patterns

No obvious use of patterns such as:

```text
dangerouslySetInnerHTML
eval()
new Function()
```

was observed during the static review.

---

# 13. Recommended Cleanup Phase Before FastAPI

After local manual/npm testing, perform a small frontend cleanup phase.

## FIX-01 — Undefined CSS Tokens
- define or replace missing `--color-border-strong`
- define or replace missing `--color-surface`

## FIX-02 — Text Selection
- remove root `select-none`
- keep selection disabled only for controls/navigation

## FIX-03 — Wallpaper Persistence Safety
- add file-size guard
- handle quota errors
- consider IndexedDB for local image blobs

## FIX-04 — Dependency Cleanup
- remove unused AI Studio/server dependencies
- remove duplicate Vite declaration
- generate lockfile

## FIX-05 — Frontend Secret Cleanup
- remove frontend Gemini key setup
- update `.env.example`
- update README
- clean AI Studio capability metadata

## FIX-06 — Centralize Remaining Mock Values
- move hardcoded runtime/user/device values into fixtures

## FIX-07 — Add Repository / Service Boundary
- introduce mock repository interfaces
- prepare later API repository implementations

## FIX-08 — Shared Enums / Types Cleanup
- normalize performance-profile values
- centralize domain enums used across pages

---

# 14. Recommended Local Testing Order

1. Run:

```bash
npm install
```

2. Confirm `package-lock.json` is generated.

3. Run:

```bash
npm run dev
```

4. Manually test all primary pages.

5. Test:

- Light theme
- Dark theme
- System theme
- custom wallpaper
- background presets
- glass effect controls

6. Test desktop widths:

- 1280
- 1366
- 1440
- 1920

7. Run the current TypeScript check:

```bash
npm run lint
```

8. Note:

- runtime errors
- browser warnings
- broken interactions
- layout issues
- console errors

9. Do not begin FastAPI integration until the frontend cleanup phase is complete.

---

# 15. Final Verdict

The exported Google AI Studio frontend is usable and worth keeping.

It does **not** require a rewrite.

The best path is:

```text
Current React Prototype
        ↓
Local Runtime Testing
        ↓
Frontend Cleanup Phase
        ↓
Repository / Service Boundary
        ↓
FastAPI Integration
```

The project is already a good enough UI foundation for the Local AI Control Center, provided the mock/runtime assumptions are cleaned up before production integration.
