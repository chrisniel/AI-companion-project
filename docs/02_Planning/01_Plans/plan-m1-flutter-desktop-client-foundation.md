# Milestone M1: Flutter Desktop Client Foundation — Implementation Plan

> **Document Role:** Canonical implementation plan for Milestone M1 (Flutter Desktop Client Foundation).  
> **Status:** Approved Baseline with Binding Review Corrections.  
> **Authority Precedence:** Normative cross-cutting architecture is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md), [`MOBILE_SYSTEM_BASELINE.md` §3](../../04_Architecture/MOBILE_SYSTEM_BASELINE.md#L26), and [`ADR-0017`](../../04_Architecture/decisions/ADR-0017-flutter-production-windows-client.md). Active branch execution is tracked in [`docs/01_Tracking/active/task-m1-flutter-foundation.md`](../../01_Tracking/active/task-m1-flutter-foundation.md).

---

## 1. Executive Summary & Goals

Milestone M1 establishes the production Flutter desktop client foundation for Windows (`PC V1`), providing:
1. A clean, native Dart Pub Workspace under `frontend/flutter/` with separate application targets and shared platform-neutral packages (`companion_core`, `companion_api`, `companion_design`).
2. Native Windows desktop windowing, lifecycle management, and system tray integration anchored on the core invariant: **"Quit UI != Stop Runtime"**.
3. Desktop SoftGlass design tokens, typography, and dark/light themes maintaining visual parity with the approved design system.
4. Typed REST client, Server-Sent Events (SSE) token stream consumption, and connection state management communicating with the Local AI Runtime on `127.0.0.1:8000`.
5. Read-only storage root awareness (`APP_INSTALL_ROOT`, `DATA_ROOT`, `LIBRARY_ROOT`) without premature backend storage manager duplication.
6. Preserved functionality of the existing React Web client (`frontend/web/`) as a supported developer harness and test oracle.

---

## 2. Binding Architecture & Review Corrections

The implementation plan incorporates the following mandatory architectural corrections:

### Correction A: MessageSend Contract & Attachments
- In `contracts/openapi/openapi.json`, `attachment_ids` on `MessageSend` is an **optional array**, NOT a nullable array.
- For text-only turns in Batch 4, the Dart client MUST omit `attachment_ids` from JSON or send `[]`. It MUST NOT submit `null`.

### Correction B: Storage Diagnostics & Backend Authority
- The Local AI Runtime (`backend/app/core/storage.py`) is the sole authority for active persistent storage roots.
- Shared domain code (`companion_core`) defines platform-neutral diagnostic DTOs and interfaces, never duplicating backend resolver logic or guessing data-root identity from client environment variables.
- The desktop platform adapter (`apps/desktop/lib/platform/`) performs fail-closed, read-only inspection of `%LOCALAPPDATA%\AI Companion\bootstrap.json`.
- The diagnostic model distinguishes:
  1. `absent locator` (bootstrap.json does not exist);
  2. `corrupt locator` (bootstrap.json invalid JSON or missing fields);
  3. `valid locator with unavailable target` (syntactically valid path whose directory does not yet exist on disk);
  4. `local diagnostic candidate` (inspected path on client machine);
  5. `authoritative backend-reported location` (reported by runtime telemetry).

### Correction C: API Parity & SSE Contract Verification
- Manual Dart DTOs require automated contract verification via `scripts/check_dart_openapi_parity.py`.
- Tests validate field names, types, required/optional status, nullability, enums, formats, and serialization round-trips.
- SSE wire frames (`TokenChunk`, `DoneEvent`, `ErrorEvent`) receive separate runtime-wire tests because OpenAPI 3.1 does not completely type the SSE streaming protocol.
- Claims of parity must match actual verified test coverage, explicitly noting unmapped M2–M4 endpoints.

### Correction D: Native Shutdown & Decoupled Lifecycle
- The Flutter client must NOT use bare `exit(0)` as its normal shutdown design without performing safe native resource cleanup (destroying tray hooks, cancelling active SSE listeners, disposing window controllers).
- Controlled shutdown exits the Flutter UI shell while leaving the independent Python runtime process executing in the background.

### Correction E: Dependencies & Toolchain Pinning
- Pinned toolchain: Flutter `3.47.1` (stable), Dart `3.13.1`, Windows x64 with Visual Studio Community 2026 C++ toolchain.
- Workspace SDK constraint: `sdk: '>=3.6.0 <4.0.0'`.
- All member packages declare `resolution: workspace`.
- Tested dependency versions are pinned in the workspace `pubspec.lock`.

---

## 3. Workspace Structure & Package Boundaries

```text
frontend/flutter/
├── pubspec.yaml                      # Root workspace (declares workspace: member paths)
├── pubspec.lock                      # Single authoritative lockfile for all packages
├── analysis_options.yaml             # Strict static analysis rules
│
├── apps/
│   ├── desktop/                      # Primary Windows desktop app (ai_companion_desktop)
│   │   ├── lib/
│   │   │   ├── main.dart             # Desktop entrypoint
│   │   │   ├── app.dart              # Root widget & routing
│   │   │   ├── platform/             # Windows adapters (window_adapter, tray_adapter)
│   │   │   ├── navigation/           # Left navigation rail
│   │   │   ├── features/             # Chat view, settings/diagnostics view
│   │   │   └── state/                # Riverpod state providers
│   │   ├── windows/                  # Native C++ runner (CMakeLists.txt, runner.exe)
│   │   ├── test/                     # Widget & integration tests
│   │   └── pubspec.yaml              # resolution: workspace
│   │
│   └── mobile/                       # [FUTURE: Android V1 follow-on; NOT CREATED IN M1]
│
└── packages/
    ├── companion_core/               # Shared domain entities & diagnostic DTOs
    │   ├── lib/                      # Pure Dart; zero OS API imports
    │   ├── test/
    │   └── pubspec.yaml              # resolution: workspace
    │
    ├── companion_api/                # Shared typed client (REST, SSE, WebSocket stub)
    │   ├── lib/                      # HTTP/SSE parsing; zero OS API imports
    │   ├── test/
    │   └── pubspec.yaml              # resolution: workspace
    │
    └── companion_design/             # Shared design tokens & SoftGlass styling
        ├── lib/                      # Colors, typography, glass decorations
        ├── test/
        └── pubspec.yaml              # resolution: workspace
```

---

## 4. Delivery Batches

### Batch 1: Workspace Scaffolding & CI Integration (`PC-CLIENT-001`) — CURRENT
- Create Pub Workspace (`pubspec.yaml`, `analysis_options.yaml`).
- Create packages `companion_core`, `companion_api`, `companion_design`.
- Scaffold `apps/desktop` with Windows desktop runner (`flutter create --platforms=windows`).
- Implement smoke-test application launching on Windows.
- Update CI pipeline (`ci_policy.py`, `test_ci_policy.py`, `.github/workflows/ci.yml`) to add a dedicated Windows Flutter verification lane with strict gate accounting.
- **Exit Criteria:** `dart pub get`, `dart pub workspace list`, `dart analyze`, package tests, and `flutter build windows --debug` pass cleanly. CI regression tests pass.

### Batch 2: Window Management, System Tray & Lifecycle (`PC-CLIENT-002`)
- Window initialization: 1280×800 default, 1024×640 minimum, centered.
- Title bar close interception: `setPreventClose(true)` $\rightarrow$ `windowManager.hide()`.
- System tray integration: icon, tooltip, double-click restore, context menu.
- Tray context menu: *Open*, *Runtime Status*, *Stop Runtime (disabled, planned in M2)*, *Exit Companion*.
- Safe native cleanup before exiting UI process; Python runtime remains executing.
- **Exit Criteria:** Window hide/restore verified on Windows; tray exit terminates Flutter process without stopping backend.

### Batch 3: SoftGlass Design System, Shell Layout & Read-Only Roots (`PC-CLIENT-003`)
- SoftGlass tokens, blur formulas, and color schemes in `companion_design`.
- Dark and Light theme modes with 4 accent presets matching `frontend/web/src/index.css`.
- Desktop shell: custom header bar, left navigation rail (Chat, Voice [M4], Schedule [M3], Memory [M3], Studio [M3], Settings), health indicator.
- Read-only storage diagnostic adapter in `apps/desktop` inspecting `%LOCALAPPDATA%\AI Companion\bootstrap.json` in a fail-closed manner.
- **Exit Criteria:** Shell renders with authentic SoftGlass styling; theme toggles work; storage diagnostics report truthfully.

### Batch 4: Typed API Client, SSE Stream Consumer & Conversation UI (`PC-CLIENT-004`)
- Typed REST client with DPAPI credential injection and configurable base URL.
- Health polling updating shell health indicator (Green = Connected, Yellow = Reconnecting, Red = Stopped).
- Real-world SSE stream parser handling multi-byte UTF-8 chunks, split lines, token accumulation, `[DONE]`, `type: error`, and per-request stream cancellation.
- Reconnection triggers authoritative history reload via `GET /api/v1/conversations/{id}/messages`.
- Turn idempotency via `client_message_id`.
- Automated OpenAPI contract parity check via `scripts/check_dart_openapi_parity.py`.
- Minimal `CompanionWebSocketClient` interface stub.
- Initial Conversation UI: message list, user input composer, streaming response rendering.
- **Exit Criteria:** End-to-end conversation turn streams live text on Windows; parity verified against React Web test oracle; M1 Exit Criteria satisfied.

---

## 5. Excluded Future Work (Strict Scope Boundaries)

- ❌ **M2 Host Autostart:** No Task Scheduler registration or startup scripts.
- ❌ **M2 Native WinRT Toasts:** No Windows Action Center toast notifications.
- ❌ **M2 Multi-Profile Database Migration:** No schema changes or profile switcher UI.
- ❌ **M2 D6 Model Import:** No model scanning, inbox watching, or bundle staging.
- ❌ **Durable FIFO Backend Queue:** M1 consumes existing streaming endpoints.
- ❌ **M3 Character Studio & Mood Engine:** No 8-trait sliders or persistent emotion engine.
- ❌ **M4 Voice Pipeline:** No microphone audio capture, TTS playback, or duplex WebSocket voice.
- ❌ **Mobile V1 Application:** Zero Android production implementation.
- ❌ **Backend Business Logic:** Zero backend modifications.
