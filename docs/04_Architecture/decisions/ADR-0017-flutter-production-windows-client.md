# Flutter Production Windows Client

**Status:** Accepted<br>
**Decision ID:** ADR-0017<br>
**Codification Date:** 2026-10-03<br>
**Primary Canonical Owner:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md)<br>
**Related Specifications:** [`SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md), [`voice-and-audio.md`](../01_Domains/voice-and-audio.md), [`ADR-0002`](ADR-0002-d1-pc-v1-release-boundary.md), [`ADR-0003`](ADR-0003-d2-windows-host-model.md)

## Decision History
- Approved during PC V1 Architecture Decision Pass (2026-10-03).
- Recorded in Master Decision Register (`DECISION_REGISTER.md`, Row 22).
- Refined by human approval (Chris, 2026-10-11, PC V1 Option A): Window close (`×`) hides Flutter to system tray while runtime continues; unexpected UI termination leaves runtime alive; deliberate tray "Exit Companion" provides confirmed graceful full shutdown via `PC-HOST-005`.

## Context
The PC V1 product requires a high-performance, polished, native-feeling desktop experience on Windows. The client must integrate seamlessly with the Windows system tray, handle local microphone audio capture and speaker playback with low latency, display native notifications, and communicate cleanly with the decoupled local Python/FastAPI runtime.

Previously, React Web served as the primary interface accessed via a browser tab, with packaged shells (such as Tauri) considered for post-V1. However, browser tab lifecycle limitations, audio permissions, and tray integration constraints make a native desktop client necessary as the primary PC product surface.

## Decision
- **Flutter Desktop is approved as the primary production Windows client for PC V1.**
- **React Web** is retained as an active, fully supported developer harness and test oracle.
- **Kotlin Android** remains an independent prototype/reference client deferred to a dedicated post-PC-V1 pass.
- The Flutter client manages:
  - Native Windows desktop windowing, minimize-to-tray, and system tray context menus.
  - Lifecycle: Closing window (`×`) hides to tray; accidental UI crash leaves runtime alive; deliberate tray "Exit Companion" performs confirmed full shutdown of local runtime, owned model processes, and Flutter via `PC-HOST-005` (with remote host shutdown strictly prohibited).
  - Audio hardware interaction (capturing mic input and playing synthesized speech streams).
  - Native toast notifications and desktop UI presentation.
- The Local AI Runtime remains an independent Python/FastAPI process running as a background host process.

## Consequences
- Windows users receive a single coherent desktop application with background persistence and system tray integration.
- Desktop UI development standardizes on Flutter and Dart, while backend ML/runtime logic remains in Python and C++ .
- Web browser tab closures no longer disrupt background companion operations or audio sessions.
- React Web remains maintained for rapid frontend testing, API verification, and headless/remote browser access.

## Canonical Relationships
Normative authority for Windows client and host integration resides in [`docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md).

## Change Control
Modifying this decision requires demonstrating insurmountable technical or hardware barriers on Windows 10/11 or explicit human approval.
