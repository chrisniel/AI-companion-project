# Mobile Companion Shell & UX Design

> **Document Role:** Canonical Mobile UI/UX presentation, layout shell, design tokens, and interaction flows specification.
> **Status:** Active Baseline (Mobile V1 Target Specification).
> **Normative Architectural Authority:** [`docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`](../04_Architecture/MOBILE_SYSTEM_BASELINE.md), [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md), [`docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md), [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md), [`docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md), [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md), [`docs/04_Architecture/01_Domains/multimodal-and-media.md`](../04_Architecture/01_Domains/multimodal-and-media.md), [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../04_Architecture/03_Integrations/health-and-wearables.md), [`docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md).

---

## 1. Executive Summary & Design Philosophy

The Mobile Companion experience extends the AI Companion system into an intimate, pocket-sized daily companion built with Flutter for Android. Unlike the PC desktop client ([`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](01_PC_Desktop_Shell_and_Tray.md)), which emphasizes deep workspace productivity, knowledge exploration, and persistent tray monitoring, the mobile experience is centered on:

1. **Immediate Contextual Presence:** Glanceable companion mood, upcoming schedule commitments, and instant conversational entry without friction (`D-PHONE-UX-01`, `D-PHONE-UX-02`).
2. **Graceful Standalone Independence:** Standalone mobile operation is treated as an ordinary, first-class capability transition—never as an application error or disabled state (`D-PHONE-UX-07`).
3. **Truthful Capability Visibility:** Transparent indication of active inference routes, host connectivity, speech engines, and sync status without exposing raw debug logs (`D-PHONE-UX-06`).
4. **Tactile & Expressive Mobile Aesthetic:** A hybrid visual language pairing clean minimalist geometry with selective tactile neumorphic depth and contextual frosted glass surfaces (`D-PHONE-UX-08`).

> **Implementation Reality Statement:**
> Flutter Mobile UI, screens, widgets, and themes are **NOT IMPLEMENTED** in the current repository code. The source repository contains PC desktop and backend runtime code. This specification governs the target mobile presentation architecture for upcoming implementation.

---

## 2. Core Shell Architecture: 5-Tab Navigation

The mobile shell implements a bottom navigation structure featuring five primary destinations, anchored by an elevated, visually prominent center action (`D-PHONE-UX-01`):

```text
┌─────────────────────────────────────────────────────────────────┐
│ [● Host Connected]                  [Active Mood: 😊] [Profile] │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                       ACTIVE TAB CONTENT                        │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│   [Home]     [Schedule]     (( COMPANION ))     [Activity]  [More]  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.1 Tab Layout & Responsibilities

| Tab Item | Visual Position | Primary Responsibility | Architectural Reference |
| :--- | :--- | :--- | :--- |
| **Home** | Tab 1 (Left) | Contextual glanceable surface: companion greeting, active mood, quick status, immediate check-ins, next schedule card (`D-PHONE-UX-02`). | [`characters-personality-and-emotion.md`](../04_Architecture/01_Domains/characters-personality-and-emotion.md) |
| **Schedule** | Tab 2 | Unified temporal view combining Tasks, Reminders, Alarms, and daily Routines with category filter chips (`D-PHONE-UX-04`). | [`tasks-reminders-alarms-and-routines.md`](../04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md) |
| **Companion** | Center Action | Elevated, prominent floating action button launching the unified conversational surface (text, voice, vision, quick chips) (`D-PHONE-UX-03`). | [`assistant-and-conversations.md`](../04_Architecture/01_Domains/assistant-and-conversations.md) |
| **Activity** | Tab 4 | Activity & reconciliation inbox: sync status, background receipts, conflict notices, health check-ins, memory confirmation receipts (`D-PHONE-UX-05`). | [`mobile-offline-and-sync.md`](../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) |
| **More** | Tab 5 (Right) | Settings, capability drill-down, local model management, persona traits, language preferences, device pairing, backup/reset. | [`mobile-capabilities-and-runtime.md`](../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) |

### 2.2 Icon-First Navigation & Accessibility Semantics (`D-PHONE-UX-01A`)

- **Icon-First Hierarchy:** Bottom navigation tabs prioritize clean, recognizable iconography to maximize vertical screen real estate on mobile displays. Text labels are compact or hidden based on screen density.
- **Mandatory Accessibility Semantics:** Every tab item MUST provide explicit semantic labels (`Semantics(label: ..., button: true)`) in Flutter for Android TalkBack and accessibility screen readers:
  - Tab 1: *"Home, glanceable companion status and daily overview"*
  - Tab 2: *"Schedule, tasks, reminders, alarms, and routines"*
  - Center: *"Companion, open conversation and voice interaction"*
  - Tab 4: *"Activity, synchronization status, notifications, and reconciliation inbox"*
  - Tab 5: *"More, settings, capabilities, and device management"*
- **Touch Target Sizing:** All navigation items and interactive buttons enforce a minimum touch target bounding box of **48 × 48 dp**, compliant with mobile accessibility standards.

---

## 3. Screen Experiences & Interaction Patterns

### 3.1 Contextual Companion Home (`D-PHONE-UX-02`)

The Home tab is designed as an ambient daily check-in surface rather than a generic launcher or full chat history:

1. **Companion Presence Banner:**
   - Displays the active companion portrait or mood glyph with subtle breathing animation (`D-PHONE-UX-10`).
   - Contextual greeting adapting to time-of-day, current mood state, and companion personality tone (`D-PHONE-12D`, `D-PHONE-12E`).
2. **Capability Status Chip:** Compact pill indicator (`[● Host Connected]`, `[⚡ Standalone Local]`, `[☁ Standalone Cloud]`, `[○ Standalone Limited]`) that opens the granular capability drill-down on tap (`D-PHONE-UX-06`).
3. **Active Check-In Card:**
   - Appears when an interactive morning greeting, wellness check-in, or evening wrap-up is active (`D-PHONE-12D`).
   - Offers quick response chips (e.g., *"Doing well!"*, *"Tired today"*, *"Need to plan"*). Dismisses cleanly without penalty.
4. **Next Commitment Card:**
   - Glanceable preview of the immediate upcoming schedule item (Alarm, Reminder, or Task) with time remaining (`D-PHONE-UX-04`).
5. **Quick Action Bar:** One-tap entry chips for common mobile interactions:
   - *Quick Voice Note* (`D-PHONE-14`)
   - *Capture Photo / Document* (`D-PHONE-16`)
   - *Open Full Conversation* (`D-PHONE-UX-03`)

### 3.2 Unified Companion Interaction Surface (`D-PHONE-UX-03`)

Tapping the center Companion action opens the primary interaction surface, uniting text, speech, vision, and contextual action chips:

- **Message Stream:**
  - Displays conversational turns with clear speaker attribution, timestamp, and optional emotion indicator.
  - Supports causal conversation branching (`D-SHARED-CONV-01`), allowing users to swipe or tap turn markers to branch or view alternative responses.
  - Streaming turn control (`D-SHARED-CONV-02`): Live token streaming with an accessible Stop Generation button.
- **Unified Input Bar:**
  - **Text Field:** Auto-expanding multi-line text input with rich keyboard action.
  - **Camera & Attachment Button (`D-PHONE-16`):** One-tap access to camera still capture or photo library picker. Thumbnails render inline with a tap-to-remove button before sending.
  - **Voice / Mic Button (`D-PHONE-14`):** Accessible action control initiating voice interaction (e.g. push-to-talk or conversational voice mode; exact gesture/trigger mechanics remain implementation-open).
  - **Quick Action Chips:** Horizontally scrolling suggestions generated by context (e.g., *"Summarize meeting"*, *"Remind me at 3 PM"*, *"What's on my schedule?"*).

### 3.3 Unified Schedule Experience (`D-PHONE-UX-04`)

The Schedule screen consolidates all temporal entities into a unified chronological stream:

- **Filter Chips:** Horizontally scrollable category filters (`All`, `Alarms`, `Reminders`, `Tasks`, `Routines`).
- **Entity Type Presentation:**
  - **Tasks:** Stateful checkable items with completion checkbox, priority indicator, and due dates.
  - **Reminders:** Ephemeral alerts with contextual snooze options or dismiss actions (exact snooze durations remain design-open).
  - **Alarms:** Prominent alarm rows with toggle switch, repeat cadence, and clear wake-up presentation conforming to Android alarm and notification permissions, exact-alarm capability, and OS interruption/Do Not Disturb policies.
  - **Routines:** Stepwise habit blocks showing scheduled execution time and completion checkmarks.
- **Cross-Device Arbitration Indicator (`D-SHARED-SCHED-02`):** Items ringing across paired devices display a subtle sync badge (e.g., *"Active on PC & Phone"*).

### 3.4 Activity & Reconciliation Inbox (`D-PHONE-UX-05`)

The Activity tab acts as an audit log and reconciliation inbox for background companion events:

- **Synchronization Section:** Shows real-time sync state (e.g., *"All changes synced to PC"*, *"3 items pending upload"*), last sync timestamp, and a manual *Sync Now* action.
- **Reconciliation Notices:** Surfaces non-destructive merge outcomes, schedule synchronization notices, or detected conflicts (e.g. `CONFLICT_DETECTED` prompts requiring user decision) adhering to canonical sync policy.
- **Memory Confirmation Receipts:** Prompts where the companion presents newly proposed facts or explicit offline memory intents (`D-PHONE-08`) for user confirmation before committing to canonical D7 Memory.
- **Health & Wellness Summaries:** Periodic non-clinical summaries ingested from Health Connect (`D-PHONE-15D`).
- **Strict User-Facing Language Invariant:** The Activity Inbox presents high-level, human-readable notifications. It MUST NEVER display raw stack traces, JSON payloads, or developer debug logs.

---

## 4. Capability Status & Standalone UX

### 4.1 Compact Truthful Capability Status (`D-PHONE-UX-06`)

Mobile companions operate across dynamic network and resource environments. The UI communicates runtime state honestly:

*(ILLUSTRATIVE / NON-NORMATIVE)*
```text
┌────────────────────────────────────────────────────────┐
│  CAPABILITY DETAILS                         [Close ✕]  │
├────────────────────────────────────────────────────────┤
│  Host Connection:     Host Reachable (Connected)       │
│  Inference Route:     Host model / Local model         │
│  Speech-to-Text:      Local STT / Host STT             │
│  Text-to-Speech:      Local TTS / Host TTS             │
│  Sync Queue:          Up to date (0 pending)           │
│  Network Route:       LAN / Offline                    │
│  Thermal / Battery:   Normal state                     │
│  Permissions:         Notifications ✓, Mic ✓, Health ✓ │
└────────────────────────────────────────────────────────┘
```

#### Primary Status States

1. **Host Connected (`PC`):** Connected to reachable PC Host with full Host model reasoning, speech streaming, and real-time state synchronization.
2. **Standalone Local (`Local`):** Operating disconnected on mobile device using qualified local LLM (`D-PHONE-01`) and qualified local speech components.
3. **Standalone Cloud (`Cloud`):** Operating standalone using separately authorized cloud inference when explicitly configured by the user.
4. **Standalone Limited (`Limited`):** Operating offline or resource-constrained without an active generative LLM; deterministic core productivity (offline task management, alarms, reminders, routine presentation, local settings, and cached conversation viewing) remains fully operational.

#### Granular Drill-Down Sheet
Tapping the capability chip opens a bottom sheet detailing each subsystem independently:
- **Host reachability:** Status of local network discovery, reachability, and secure pairing.
- **Inference route & model:** Currently executing model name and backend engine.
- **Speech pipeline routes:** Separate rows for active STT and TTS engines.
- **Sync queue status:** Count of pending offline mutations and last sync time.
- **Thermal & battery governor state:** Normal, Warm, Throttled, or Battery Saver.
- **OS permissions:** Granular checklist (Microphone, Camera, Notifications, Health Connect, Battery Optimization).

### 4.2 Graceful Standalone Mobile UX (`D-PHONE-UX-07`)

- **Capability Transition, Not Error:** Disconnection from the PC Host is treated as a routine lifecycle transition. The UI MUST NOT display blocking error modals, alert dialogs, or disabled screen overlays.
- **Warm Companion Guidance:** A non-intrusive banner or card informs the user:
  *"Working independently on your phone right now. Eligible offline changes and pending intents synchronize after reconnect."*
- **Truthful Offline Capability Boundaries:**
  - *Offline Memory:* Cached canonical Memory is read-only; explicit user requests to remember information are recorded as pending memory intents (`D-PHONE-08`) reconciled upon Host reconnection.
  - *Offline Scheduling:* Tasks and mobile-origin reminder/alarm mutations follow approved offline persistence rules; host-origin reminder/alarm definitions remain read-only offline, and canonical routine recurrence remains Host-owned.
  - *Offline Conversation:* Generative turns require an available qualifying route (qualified mobile local LLM, reachable Host, or separately authorized cloud LLM). When no generative route is available, conversation history remains cached and readable, while new generative turn submission is read-only or unavailable with clear explanation.

---

## 5. Visual Design Language: Hybrid Aesthetic (`D-PHONE-UX-08`)

The mobile companion visual design combines three complementary paradigms to deliver a modern, tactile, and battery-efficient experience:

```text
┌─────────────────────────────────────────────────────────────────┐
│                     HYBRID VISUAL LANGUAGE                      │
├───────────────────────────────┬─────────────────────────────────┤
│ Foundational Minimalism       │ Clean layout geometry, generous │
│                               │ whitespace, strong typography   │
├───────────────────────────────┼─────────────────────────────────┤
│ Selective Neumorphism         │ Tactile dual-shadow embossing   │
│                               │ for buttons, sliders, cards     │
├───────────────────────────────┼─────────────────────────────────┤
│ Contextual Glassmorphism      │ Translucent frosted surfaces    │
│ (Liquid Glass)                │ for floating chrome and sheets  │
└───────────────────────────────┴─────────────────────────────────┘
```

### 5.1 Three Visual Layers

1. **Minimalist Foundation:** Structural simplicity, high-contrast text hierarchies, and predictable spatial layout eliminate cognitive clutter.
2. **Selective Neumorphic Depth:** Interactive physical controls (such as voice record buttons, trait sliders, and schedule toggle switches) employ soft dual-shadow embossing to create a tangible, inviting tactile response.
3. **Contextual Glass Surfaces (Liquid Glass):** Floating navigation bars, active voice overlays, and bottom sheets use translucent acrylic/glassmorphic blurring to provide depth while maintaining environmental awareness.

### 5.2 Appearance Modes

The mobile client supports four distinct appearance modes:

| Appearance Mode | Background Style | Card / Surface Style | Primary Focus |
| :--- | :--- | :--- | :--- |
| **OLED Black (Default)** | True deep black | High-contrast dark charcoal surfaces | Maximizes mobile battery life on AMOLED/OLED displays. |
| **Dark** | Soft dark foundation | Neutral muted dark surfaces | Reduced-contrast evening and low-light viewing. |
| **Light** | Clean bright background | Soft daylight neutral surfaces | High-ambient bright daylight environments. |
| **System** | Dynamic OS match | Dynamic OS match | Follows Android system night mode setting. |

- **Accents & Themes:** User-selectable companion accent colors (exact palette tokens and default swatches remain design-token implementation-open).
- **Background Customization:** Support for subtle ambient gradients or custom user-supplied wallpaper with configurable blur and dimming levels.

### 5.3 Reduced Motion & Adaptive Performance Governor

- **Accessibility Preference:** Automatically honors platform system settings for reduced motion, replacing fluid slide/fade animations with instantaneous cuts.
- **Thermal & Battery Governor Integration:** When the mobile device enters thermal throttling or battery saver mode, the UI governor dynamically downscales or disables glass blur effects and complex particle animations without resetting the user's selected appearance theme.

---

## 6. Companion Presence, Mood & Expression

### 6.1 Lightweight Mood Presence (`D-PHONE-UX-10`)

Companion mood provides immediate emotional continuity across devices without imposing heavy rendering overhead:

- **Tiered Presentation:**
  - **Tier 1 (Rich Asset):** 2D illustrated character portrait cross-fading expressions based on companion emotional state (`D-PHONE-06`).
  - **Tier 2 (Mood Glyph Fallback):** Guaranteed fallback to styled SVG glyphs or platform emoji (`😊`, `🤔`, `😴`, `✨`, `🧘`, `💪`) on devices lacking custom character assets or under constrained memory.
- **Ambient Accent Glow:** The navigation bar center action and Home banner emit a subtle ambient glow matching the active mood hue.

### 6.2 Check-ins & Companion Tone (`D-PHONE-12D`, `D-PHONE-12E`)

- **Delivery Surfaces:**
  - In-app contextual card on Home tab (`D-PHONE-UX-02`).
  - Interactive Android rich notification with quick action buttons.
  - Android home-screen glanceable widget (`D-PHONE-12D`: approved Mobile V1 target, currently NOT IMPLEMENTED; exact widget technology remains open).
- **Ethical Tone Guardrails:** Check-ins are non-nagging, gentle, and respectful. If a user dismisses or ignores a check-in, the companion remains quiet and does not escalate alerts or express guilt.

---

## 7. Multimodal, Voice & Health Presentation

### 7.1 Composable Voice Presentation (`D-PHONE-14`)

- **Duplex Voice Overlay:** Full-screen conversational view featuring an animated fluid audio waveform.
- **Voice Barge-In Control:** Visual speech detection ring indicating when the user is speaking, immediately pausing companion audio playback.
- **Audio Routing Indicator:** Displays active audio output (Phone Speaker, Earpiece, Bluetooth Headset).

### 7.2 Multimodal Vision UI (`D-PHONE-16`)

- **Camera Still Capture:** Viewfinder sheet for capturing photos of documents, notes, or surroundings.
- **Attachment Preview Strip:** Inline thumbnail carousel above the message input showing attached images with resolution badges and remove icons.
- **Privacy & Route Indicator (`D-PHONE-16B`):** Clear visual indicator identifying the active vision inference route among approved options (PC Host, Mobile Local VLM, Separately Authorized Cloud, or Unavailable). Visual observations never automatically generate canonical Memory (`D-SHARED-VISION-01`).

### 7.3 Health Connect Integration UI (`D-PHONE-15`)

- **Permission Management Sheet:** Granular toggles allowing users to authorize specific metrics (Steps, Sleep, Heart Rate, Active Energy) independently (`D-PHONE-15A`).
- **Wellness Cards:** Non-clinical trend cards on the Activity tab (e.g., *"Sleep: 7h 20m logged"*).
- **Privacy & Egress Notice:** Clear visual indicator confirming health data is strictly local context by default, is never transmitted to Cloud AI merely because Cloud LLM permission exists, and requires a separate explicit user authorization for health-to-cloud egress (`D-SHARED-HEALTH-04`).

---

## 8. Language & Localization Architecture

### 8.1 Companion Language vs. UI Decoupling (`D-PHONE-UX-09`)

The mobile client enforces complete decoupling between:
1. **Application UI Language:** The localized strings for menus, tab titles, settings labels, and error messages (managed via standard Flutter `flutter_localizations` / `intl`).
2. **Companion Conversational Language:** The natural language spoken and understood by the AI persona (e.g., user selects English UI but interacts with companion in Japanese).

### 8.2 Extensible Language Registry (`D-SHARED-LANG-01`, `D-SHARED-LANG-02`)

- **Language Registry (`D-SHARED-LANG-01`):** Extensible capability registry supporting configured languages with open storage representation.
- **Modality-Aware Support (`D-SHARED-LANG-02`):** Language capabilities are advertised truthfully based on qualification of the specific active components (text LLM, STT, TTS, or full voice pipeline), with support for conversational code-switching where qualified models support it.
- **Language Switcher:** Accessible language chip selector in More > Language Settings.

---

## 9. Future & Bounded Capability UX

### 9.1 Bounded Location Context Reference (`P-PHONE-LOC-01`)

- **Classification:** **MOBILE LATER / APPROVED FUTURE DIRECTION**.
- **UX Boundary:** Location context is not implemented in Mobile V1. Future design will feature an explicit opt-in permission card, coarse geofencing boundaries, zero continuous tracking, and full user inspection/purge controls in More > Privacy.

---

## 10. Design Verification & Traceability Matrix

| Decision ID | Spec Section | UX Requirement Summary | Target UX / Acceptance Direction |
| :--- | :--- | :--- | :--- |
| `D-PHONE-UX-01` | §2.1 | 5-Tab Shell (Home, Schedule, Companion, Activity, More) | Shell target specifies 5 tabs with prominent center action. |
| `D-PHONE-UX-01A` | §2.2 | Icon-first navigation with accessibility semantics | Target navigation specifies semantic labels on all tabs and min 48×48 dp touch targets. |
| `D-PHONE-UX-02` | §3.1 | Contextual Companion Home | Target Home screen specifies glanceable banner, status chip, check-in card, and quick actions. |
| `D-PHONE-UX-03` | §3.2 | Unified Companion interaction surface | Target conversational interface unifies text, voice, camera capture, and turn streaming. |
| `D-PHONE-UX-04` | §3.3 | Unified Schedule experience | Target Schedule specifies category filters, distinct entity types, and cross-device alert badges (`D-SHARED-SCHED-02`). |
| `D-PHONE-UX-05` | §3.4 | Activity & reconciliation inbox | Target Activity screen surfaces sync state, conflict receipts, and human-readable receipts without raw logs. |
| `D-PHONE-UX-06` | §4.1 | Compact capability status + drill-down | Target status chip presents PC/Local/Cloud/Limited summaries with independent subsystem drill-down. |
| `D-PHONE-UX-07` | §4.2 | Graceful standalone mobile UX | Host disconnection handled as capability transition with non-intrusive guidance and offline utility. |
| `D-PHONE-UX-08` | §5.1–5.3 | Hybrid visual language (Minimalism, Neumorphism, Glass) | Target styling defines OLED Black default, Dark, Light, System modes, and reduced-motion support. |
| `D-PHONE-UX-09` | §8.1 | Decoupled UI localization vs companion language | Target architecture decouples companion conversational language from app UI string resources. |
| `D-PHONE-UX-10` | §6.1 | Lightweight Mood presence with emoji fallback | Target presence specifies mood accent on banner with guaranteed emoji/glyph fallback. |
| `D-SHARED-LANG-01` | §8.2 | Extensible language registry | Target registry models language metadata extensibly with open storage representation. |
| `D-SHARED-LANG-02` | §8.2 | Modality-aware language support | Language support advertised truthfully according to qualification of relevant constituent models. |
| `D-PHONE-12D`, `12E` | §6.2 | Check-in surfaces & character-aware tone | Target check-in surfaces include Home card, rich notification, and approved V1 widget; non-nagging tone. |
| `P-PHONE-LOC-01` | §9.1 | Bounded opt-in location reference | Mobile Later direction; opt-in context only, no continuous tracking, no V1 implementation tasks. |
| `D-PHONE-14` | §7.1 | Composable voice presentation | Target voice UI specifies full-screen overlay, barge-in detection ring, and audio route indicator. |
| `D-PHONE-15` | §7.3 | Health Connect presentation | Target health UI specifies granular metric toggles, non-clinical cards, and egress guard notice. |
| `D-PHONE-16` | §7.2 | Multimodal camera & vision UI | Target vision UI specifies still capture sheet, thumbnail strip, and multi-route indicator (`D-PHONE-16B`). |
