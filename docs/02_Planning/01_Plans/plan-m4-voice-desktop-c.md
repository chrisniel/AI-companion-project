# Implementation Plan: M4 Batch C — Windows Native Audio, Hotkeys & Option A Voice UI

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- **Status:** Implemented & Automated-Verified on `feature/m4-voice-desktop-c` (Pending Phase 4 Review & Manual Windows Hardware Audio QA)
- **Delivery Level:** Level C — Sensitive Design
- **Scope Mode:** New Feature — M4 Batch C native Windows C++ WASAPI audio capture/playback, Win32 global hotkeys (`WindowsAudioChannel`), Option A Desktop Voice UI (removing standalone `Voice` rail tab and integrating Dictation, Live Duplex Voice Stage, Auto-Read, and Read Aloud into `ChatScreen`), `Settings -> Voice & Audio` promotion (`SettingsVoiceSection` with customizable shortcuts, hardware device pickers, barge-in & engine controls), `Character Studio` voice picker, `DesktopShell` amber mic privacy indicator, and System Tray Mute toggle.
- **Target Files:**
  - `frontend/flutter/apps/desktop/windows/runner/` (`CMakeLists.txt`, `flutter_window.h`, `flutter_window.cpp`, `windows_audio_channel.h`, `windows_audio_channel.cpp`)
  - `frontend/flutter/apps/desktop/lib/platform/` (`desktop_audio_adapter.dart`, `desktop_client_settings.dart`)
  - `frontend/flutter/apps/desktop/lib/features/voice/` (`desktop_voice_controller.dart`, `live_voice_stage_panel.dart`, `voice_shortcut_recorder.dart`)
  - `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`
  - `frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart`
  - `frontend/flutter/apps/desktop/lib/shell/` (`desktop_navigation_rail.dart`, `desktop_shell.dart`)
  - `frontend/flutter/apps/desktop/lib/screens/` (`chat_screen.dart`, `settings_screen.dart`, `studio_screen.dart`, DELETE `voice_screen.dart`)
  - `frontend/flutter/apps/desktop/lib/features/settings/` (`settings_section.dart`, `sections/settings_voice_section.dart`)
  - `frontend/flutter/apps/desktop/lib/features/studio/` (`desktop_studio_controller.dart`, `studio_inspector_panel.dart`)
  - `frontend/flutter/apps/desktop/test/` (`desktop_voice_test.dart`, updates to `desktop_shell_test.dart`, `desktop_settings_revamp_test.dart`, `desktop_studio_controller_test.dart`, `studio_screen_test.dart`, `desktop_lifecycle_test.dart`, `desktop_shortcuts_test.dart`, `widget_test.dart`)
  - Phase 3 docs: [`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md), [`docs/05_Design/05_Voice_Mode_and_Audio_Controls.md`](../../05_Design/05_Voice_Mode_and_Audio_Controls.md), [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md), [`docs/02_Planning/00_Master/WBS.md`](../00_Master/WBS.md), [`MASTER_CHECKLIST.md`](../00_Master/MASTER_CHECKLIST.md), [`DELIVERY_INDEX.md`](../00_Master/DELIVERY_INDEX.md), [`CHANGELOG.md`](../../../CHANGELOG.md), walkthrough, and archived branch tracker.
- **Branch:** `feature/m4-voice-desktop-c`
- **Active Branch Tracker:** `docs/01_Tracking/active/task-feature-m4-voice-desktop-c.md`

> Notice: Update this plan in place during planning. After Phase 1 approval, track execution in `docs/01_Tracking/active/task-feature-m4-voice-desktop-c.md` and reopen this plan only when revising scope or architecture.

---

## 1. Request Understanding & Goals

- **Primary Objective:** Complete Milestone M4's Desktop Voice delivery (**`PC-VOICE-001`** and the remaining Desktop UI half of `PC-VOICE-002..005`, `PC-CLIENT-004`, `PC-CLIENT-011`) on Windows without adding third-party Flutter audio packages, implementing the agreed **Option A** UX architecture where all voice conversation lives directly inside `ChatScreen` while `Settings -> Voice & Audio` and `Character Studio` own hardware, shortcut, and voice selection.
- **Relevant Canonical Requirements:**
  - [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../04_Architecture/SYSTEM_BASELINE.md) — §3 Invariants #3 (`Multi-Profile`), #5 (`D9`), #8 (`D5`), #9 (`ADR-0019`), #10 (`Native Voice Architecture`), and §5 Golden Group G9.
  - [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md) — Hardware capture/playback ownership, mandatory `<50ms` local barge-in playback cut with monotonic generation/turn identity, hard OS mic mute & visible privacy indicator, Profile isolation on switch/revoke, and RAM-only transient audio handling.
  - [`docs/05_Design/01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md) — Top utility strip controls, Tray `Mute Audio` menu item, and 5-tab navigation alignment under Option A.
  - [`docs/05_Design/05_Voice_Mode_and_Audio_Controls.md`](../../05_Design/05_Voice_Mode_and_Audio_Controls.md) — Mic/speaker device selectors with live RMS meter and Test Sound, Barge-In / VAD / PTT / Mute controls, amber mic indicator.
  - Approved interactive visual preview: `m4_voice_tools_preview.html` (Option A Chat Voice Mode + Customizable Shortcuts + Settings Voice & Audio).
- **Concrete Deliverables:**
  1. In-process Windows C++ WASAPI & Win32 `RegisterHotKey` MethodChannel (`WindowsAudioChannel` on `ai_companion/windows_audio`) compiled into the Desktop Windows runner with zero new `pubspec.yaml` dependencies and strict UI-thread `PostMessageW` marshaling + COM apartment discipline.
  2. Platform-abstracted `DesktopAudioAdapter` (`WindowsWasapiAudioAdapter` + `NoOpDesktopAudioAdapter`) and device-local persistence in `DesktopClientSettings` (`selectedMicDeviceId`, `selectedSpeakerDeviceId`, `audioMuted`, `voiceShortcuts`).
  3. Profile-scoped, epoch-fenced `DesktopVoiceController` integrating `CompanionClient` voice REST endpoints + `VoiceSessionClient` full-duplex WebSocket + native WASAPI capture/playback with synchronous generation-tagged `<50ms` barge-in flush.
  4. **Option A** UI completion: remove `DesktopNavDestination.voice` & `VoiceScreen`; upgrade `ChatScreen` (Live Voice Mode header toggle, inline `LiveVoiceStagePanel`, active composer Mic Dictation button, `Auto-Read` toggle, per-message Read Aloud/Stop); promote `SettingsSectionId.voice` (`SettingsVoiceSection` with shortcut recorder, hardware pickers + meter + Test Sound, barge-in/VAD/TTS/privacy settings, live backend telemetry); add `voiceId` selection + preview in `Character Studio`.
  5. Shell mic capture privacy indicator in `_buildTopUtilityStrip` and **Mute Audio (`Ctrl+Shift+M`)** item in the Windows System Tray menu.
  6. Updated Desktop widget/unit tests (`flutter analyze --no-pub`, full `apps/desktop/test`, `flutter build windows --debug --no-pub`) and synchronized canonical documentation.
- **Explicit Out-of-Scope:**
  - Backend schema/API changes (all `6` REST endpoints, `WS /api/v1/voice/ws`, and `CharacterInstance.voice_id` already landed in M4 Batch B).
  - Screen Share / Camera capture multimodal pipeline (prepared cleanly via Option A unified `ChatScreen`, deferred to dedicated Vision work).
  - Always-on wake word (`openWakeWord`, `PC Later`) and global low-level keyboard hook (`WH_KEYBOARD_LL` avoided to remain AV-clean).
  - React Web (`frontend/web/`) or Android (`android/`).

---

## 2. Architecture & Technical Approach

- **Current Findings & Technical Baseline:**

  | Observation / Evidence | Verified Interpretation |
  | --- | --- |
  | `frontend/flutter/apps/desktop/windows/runner/` hosts `WindowsToastChannel` (`CMakeLists.txt`, `flutter_window.h/.cpp`) linking `ole32.lib`, `propsys.lib`, `winmm.lib`, `runtimeobject.lib` with zero extra Flutter pub plugins (`pubspec.yaml` untouched). `main.cpp:20` initializes STA COM (`::RoInitialize(RO_INIT_SINGLETHREADED)`) on the UI thread, and `WindowsToastChannel` uses `kWmToastActivated = WM_APP + 0x42` + `::PostMessageW` to marshal background callbacks back to `FlutterWindow::MessageHandler` safely. | Adding `WindowsAudioChannel` (`windows_audio_channel.h/.cpp`) mirrors `WindowsToastChannel`: UI-thread COM calls reuse the existing STA apartment safely; capture/render worker `std::thread`s initialize their own MTA COM apartment (`COINIT_MULTITHREADED`) with `ComPtr` teardown before `CoUninitialize()`; background audio frames marshal to the UI thread via a `std::mutex`-guarded queue + `kWmAudioEvent = WM_APP + 0x43` so `MethodChannel::InvokeMethod` runs exclusively on the UI thread. |
  | `tts.py` / `session_orchestrator.py` emit full RIFF WAV containers across heterogeneous sample rates (`24000 Hz` Kokoro, `22050 Hz` Windows SAPI, `16000 Hz` Mock), and SAPI encoders may include non-44-byte subchunks before `"data"`. | Playback walks RIFF subchunks (`"fmt "` + `"data"`) dynamically (never hardcoded 44-byte offsets) and resamples incoming mono/stereo PCM16 frames cleanly to the active open WASAPI render stream rate, eliminating pitch bugs or click-inducing stream re-opens. |
  | WASAPI shared-mode `IAudioClient::Initialize` supports `AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY` on Windows 10/11 (with software linear resampling fallback), converting 44.1/48 kHz hardware audio cleanly to/from `16 kHz` mono PCM16. | Capture thread emits `512`-sample (`32 ms`, `1024`-byte) PCM16 frames + RMS amplitude cleanly; `POST /api/v1/voice/transcribe` accepts `format: 'pcm16'` capped at `MAX_TRANSCRIBE_WAV_BYTES = 1,468,006`. |
  | `DesktopSettingsController` (`lib/controllers/desktop_settings_controller.dart:9-15`) defines `DesktopNavDestination.voice` and `DesktopShell` (`desktop_shell.dart:715`) mounts `VoiceScreen`. Existing tests (`desktop_shell_test.dart:43,53,70-73`, `widget_test.dart:26`, `desktop_settings_revamp_test.dart:47-49,292-296`) assert `'Voice'` nav destination and `SettingsSectionStatus.planned` for `voice`, while `desktop_shell_test.dart:737` uses `_RecordingCoordinator extends Fake implements DesktopLifecycleCoordinator`. | Option A cleanly removes `DesktopNavDestination.voice` and `voice_screen.dart` (leaving 5 rail items), updates `SettingsSectionId.voice` to `available`, wraps optional coordinator hooks (`onMuteToggleTriggered`, `updateAudioMutedStatus`) in `try {} on UnimplementedError {}` with optional `isAudioMuted = false` default parameter, gates `_buildTopUtilityStrip` on `_voiceController != null` too, and updates those test assertions in sync. |
  | `companion_api` (`PR #45` merged into `develop` at `de25ada`) already exposes `VoiceSessionClient`, `CompanionClient` (`6` REST methods), `VoiceStatusOut`, `VoiceCatalogOut`, `VoiceSettingsOut`, `VoiceSettingsUpdate`, `VoiceTranscribeRequest`, `VoiceSynthesizeRequest`, `VoiceWsEvent`, `CharacterInstanceCreate.voiceId`, and `CharacterInstanceUpdate.toJson({bool clearVoiceId = false})`. | Zero changes needed in `companion_api`; `VoiceSessionOrchestrator` requires an active `conversation_id` on `WS /api/v1/voice/ws` (`4404` otherwise), so `startLiveVoice()` creates a conversation automatically when `activeConversation == null` before connecting `VoiceSessionClient`. |
  | `DesktopStudioController` (`desktop_studio_controller.dart:18-225,557-576`) manages `CharacterStudioDraft`, `PendingUpdateSnapshot`, `_matchesUpdatePayload`, and `_matchesBaseline`, tested by `desktop_studio_controller_test.dart` & `studio_screen_test.dart`. | Extending `CharacterStudioDraft`, `PendingUpdateSnapshot`, and both reconciliation matchers with `voiceId`/`clearVoiceId` keeps timeout recovery accurate while keeping `isReadOnly` / `isNeutralSelected` safeguards intact. |
  | `DesktopClientSettings` (`%LOCALAPPDATA%\AI Companion\client_settings.json`) stores device-local non-secret Desktop config (`desktop_settings_revamp_test.dart:568` uses `_InMemoryDesktopClientSettings`). | Storing mic/speaker IDs, `audioMuted`, and `voiceShortcuts` in `DesktopClientSettings` cleanly separates PC hardware bindings from DB `profile_voice_settings` and honors injected test settings with zero `%LOCALAPPDATA%` disk writes when omitted. |

- **Architectural Approach:**
  1. **Native Windows Audio & Global Hotkey Layer (`WindowsAudioChannel` + `DesktopAudioAdapter`):**
     - **Thread & COM Safety Contract:**
       - `WindowsToastChannel`-style UI marshaling: define `constexpr UINT kWmAudioEvent = WM_APP + 0x43;` in `windows_audio_channel.h` and handle `kWmAudioEvent` (calling `audio_channel_->HandleAudioEventMessage()`) + `WM_HOTKEY` (`HandleHotkeyMessage(wparam)`) inside `FlutterWindow::MessageHandler`. If `audio_channel_` has been reset in `OnDestroy()`, incoming/pending frames in the queue are destroyed with the channel destructor after worker threads are joined.
       - UI thread NEVER calls `CoInitializeEx(..., COINIT_MULTITHREADED)`; it uses the existing STA initialized in `main.cpp` (or balanced `S_OK`/`S_FALSE` `COINIT_APARTMENTTHREADED`). Both the WASAPI capture thread and render thread call `::CoInitializeEx(nullptr, COINIT_MULTITHREADED)` on entry, drop all `ComPtr` references strictly inside an inner scope before exiting, and call `::CoUninitialize()` cleanly before returning so `~WindowsAudioChannel()` joins cleanly in `FlutterWindow::OnDestroy()`.
     - **WASAPI Device Enumeration (`enumerateDevices`):** Enumerates active Windows `eCapture` and `eRender` `IMMDevice` endpoints (`PKEY_Device_FriendlyName`), always preserving Windows Default (`""`).
     - **WASAPI Capture Loop (`startCapture(deviceId)`):** Dedicated capture thread opens shared-mode `IAudioClient` (`16000 Hz`, mono, `PCM16`, `AudioCategory_Communications`, `AUTOCONVERTPCM`, `32ms` / `512`-sample frames, software resample fallback if rejected), computes RMS `0.0..1.0`, enqueues capture frames under `std::mutex`, and posts `::PostMessageW(hwnd_, kWmAudioEvent, 0, 0)` so the UI thread calls `channel_->InvokeMethod("onCaptureFrame", ...)`. `stopCapture()` signals thread stop, joins safely, calls `IAudioClient::Stop()`, and releases capture COM handles immediately (hard OS driver capture cut).
     - **WASAPI Render Queue & `<50ms` Barge-In Cut (`playAudio(wavBytes, sampleRate, generation)` / `flushPlayback(minGeneration)`):** Parses RIFF containers dynamically by scanning `"fmt "` + `"data"` subchunks (supporting `24 kHz` Kokoro, `22.05 kHz` SAPI, `16 kHz` Mock, or raw PCM16 with fallback to `sampleRate`), resamples to the open render endpoint's sample rate in C++, and pushes generation-tagged PCM16 frames onto the render FIFO. `flushPlayback(newGen)` (and `setHardMuted(true)`) atomically sets `active_min_generation_ = newGen`, calls `IAudioClient::Stop()` + `Reset()`, clears queued buffers in `<50ms`, and resumes cleanly.
     - **`playTestTone(deviceId)`:** Generates a brief in-memory two-note sine chime (`~250 ms`) via WASAPI render — zero temp WAV files.
     - **Win32 Global Hotkey (`registerGlobalHotkey(modifiers, virtualKey)`):** Calls Win32 `RegisterHotKey(hwnd_, kGlobalVoiceHotkeyId, modifiers | MOD_NOREPEAT, vk)`, returns exact success/conflict error code, and dispatches `WM_HOTKEY` via UI-thread `InvokeMethod("onGlobalHotkey")`. Unregisters cleanly in `~WindowsAudioChannel()`.
  2. **Device-Local Voice Preferences (`DesktopClientSettings`):**
     - Structured `VoiceShortcutBinding` & `VoiceShortcutConfig` (`inAppToggle`, `globalToggle`, `muteToggle`, `pushToTalk`) persisted inside `client_settings.json` with conflict detection and `resetDefaults()`.
     - Selected mic/speaker device IDs and local `audioMuted` boolean persisted cleanly alongside `chatZoomLevel`.
  3. **`DesktopVoiceController` State Machine:**
     - **States:** `VoiceSessionPhase { idle, recordingDictation, transcribing, connectingWs, listening, thinking, speaking, errored }`.
     - **Dictation Flow:** `startDictation()` checks `MAX_TRANSCRIBE_WAV_BYTES = 1_468,006` budget while buffering `PCM16` frames from `DesktopAudioAdapter`; `stopAndTranscribeDictation()` sends `VoiceTranscribeRequest(audioBase64: ..., format: 'pcm16', sampleRate: 16000)` to `POST /api/v1/voice/transcribe` (stopping capture immediately at the max byte cap cleanly if reached).
     - **Live Voice Flow:** Ensures an active `conversationId` exists (calling `chatController.createNewConversation()` if `activeConversation == null`!), opens `VoiceSessionClient` over `WS /api/v1/voice/ws`, streams `512`-sample `audio.chunk` frames, updates live captions/state, calls `flushPlayback(++_playbackGeneration)` in `<50ms` on manual `interruptBargeIn()`, `turn.cancelled`, `vad.state: barge_in_triggered`, hard Mute, or `profileEpoch` change, and triggers `chatController.loadMessages(convId)` (+ `loadConversations()` when newly populated) on `stt.final` / `tts.end`.
     - **Auto-Read & Read Aloud:** `ChatScreen` / `DesktopVoiceController` triggers Auto-Read **only** on an `isGenerating: true -> false` transition when `voiceSettings.autoReadReplies && !isAudioMuted && !isLiveVoiceActive` and the newest assistant message completed cleanly (`status == 'completed' || status == 'length'`), never on conversation switches or history reloads. Manual `speakMessage(messageId, text)` stops prior generation first and plays synthesized WAV bytes.
     - **Mute & Profile Isolation:** `setMuted(true)` immediately calls `stopCapture()`, `flushPlayback()`, updates tray menu status (`onAudioMutedChanged`), and persists `audioMuted`. On `profileEpoch` change, sign-out, or controller disposal, tears down mic capture, playback, `VoiceSessionClient`, and transient captions, then loads the newly active Profile's `/api/v1/voice/settings`.
  4. **Option A UI Integration:**
     - **Navigation & Shell (`desktop_settings_controller.dart`, `desktop_navigation_rail.dart`, `desktop_shell.dart`):**
       - Remove `DesktopNavDestination.voice` & `voice_screen.dart` (5 tabs: `Chat`, `Schedule`, `Memory`, `Studio`, `Settings`).
       - Wire optional `DesktopVoiceController?` & `DesktopAudioAdapter?` into `DesktopShell`. Update `_buildTopUtilityStrip` gate (`if (_scheduleController != null || _toolPolicyController != null || _voiceController != null)`) & `ListenableBuilder` to include `_voiceController` so the glowing amber `Key('shell_mic_privacy_indicator')` pill always renders while mic capture is open (with 1-click mute/stop).
       - Register customizable in-app shortcuts (`inAppToggle`, `muteToggle`) via `CallbackShortcuts`, bind Win32 global hotkey to restore window (when hidden) + navigate/toggle Live Voice in Chat, and wrap optional tray coordinator callbacks in `try {} on UnimplementedError {}` (`desktop_shell_test.dart` fake compatibility).
       - Extend `DesktopLifecycleCoordinator` with optional `bool isAudioMuted = false` in `buildTrayMenuItemsWithSafety` (`Mute Audio` / `Unmute Audio` menu item) and `onMuteToggleTriggered`.
     - **`ChatScreen` (`chat_screen.dart`, `live_voice_stage_panel.dart`):**
       - Header: **Live Voice** toggle + **Auto-Read** chip.
       - Active Live Voice Mode: inline `LiveVoiceStagePanel` (Companion state orb + RMS bar + captions + Mute / Interrupt / Push-to-Talk `Right Alt` / End Voice Session). `Spacebar` shortcut triggers `interruptBargeIn()` **only** when Live Voice Mode is active and the text composer `TextField` (`_focusNode`) does not hold typing focus!
       - Composer: active **Mic Dictate** button (`Key('chat_dictate_button')`) toggling recording or Push-to-Talk into `_textController` while preserving existing draft safety.
       - Assistant bubbles: **Read Aloud / Stop** button (`Key('message_speak_${msg.id}')`).
     - **`Settings -> Voice & Audio` (`settings_section.dart`, `settings_screen.dart`, `settings_voice_section.dart`):**
       - Promote `SettingsSectionId.voice` to `SettingsSectionStatus.available` (`milestoneHint: null`). Pass optional `DesktopVoiceController?` into `SettingsScreen` (avoiding disk `%LOCALAPPDATA%` writes during tests when injected/null fallback uses in-memory settings).
       - Implement `SettingsVoiceSection`: Backend Engine Readiness banner (`GET /api/v1/voice/status`), Customizable Voice Shortcuts recorder (`VoiceShortcutRecorder`) + live Win32 conflict indicator + Reset Defaults, WASAPI Mic + RMS meter + Speaker + Test Sound + Refresh, Barge-In Policy + Silero VAD Sensitivity + STT Language + Default Voice + TTS Speed (`0.5x..2.0x`) + Auto-Read + Proactive Speech (`OFF` by default) + privacy disclosure.
     - **`Character Studio` (`desktop_studio_controller.dart`, `studio_inspector_panel.dart`):**
       - Add optional `voiceId` to `CharacterStudioDraft`, `PendingUpdateSnapshot`, `_matchesUpdatePayload`, and `_matchesBaseline` (forwarding explicit `clearVoiceId: draft.voiceId == null && baselineVoiceId != null` on PATCH).
       - Render **Character Voice** dropdown (`"Profile Default"` + catalog voices) + **Preview** button in `StudioInspectorPanel` Identity tab, disabled when `draft.isReadOnly` (`isLegacyPlaceholder`) and immutable on `isNeutralSelected`.

---

## 3. Proposed File Changes & In-Place Logic

### [ADD / MODIFY] `frontend/flutter/apps/desktop/windows/runner/`
- **`windows_audio_channel.h` / `windows_audio_channel.cpp` (ADD):** COM/WASAPI device enumeration, MTA capture/render worker threads with `kWmAudioEvent = WM_APP + 0x43` UI-thread queue marshaling, RIFF `"fmt "`/`"data"` scanner + sample-rate conversion, `<50ms` generation-tagged `flushPlayback`, in-memory test tone, and Win32 `RegisterHotKey` (`WM_HOTKEY`).
- **`flutter_window.h` / `flutter_window.cpp` / `CMakeLists.txt` (MODIFY):** Register `WindowsAudioChannel` alongside `WindowsToastChannel`, dispatch `kWmAudioEvent` and `WM_HOTKEY` in `MessageHandler`, and reset safely in `OnDestroy()`.

### [ADD / MODIFY] `frontend/flutter/apps/desktop/lib/platform/`
- **`desktop_audio_adapter.dart` (ADD):** Abstract `DesktopAudioAdapter`, `AudioDeviceInfo`, `VoiceShortcutConfig`, `HotkeyRegistrationResult`, `WindowsWasapiAudioAdapter`, and `NoOpDesktopAudioAdapter`.
- **`desktop_client_settings.dart` (MODIFY):** Add `readVoiceHardwarePrefs()` / `writeVoiceHardwarePrefs()` and `readVoiceShortcuts()` / `writeVoiceShortcuts()`.

### [ADD] `frontend/flutter/apps/desktop/lib/features/voice/`
- **`desktop_voice_controller.dart` (ADD):** State machine (`VoiceSessionPhase`), Dictation (`format: 'pcm16'`, bounded `1,468,006` B), Live Voice WS lifecycle, Read Aloud / Auto-Read transition hook, monotonic barge-in `playbackGeneration`, hard Mute, and `profileEpoch` cleanup.
- **`live_voice_stage_panel.dart` (ADD):** Reactive Companion Orb, state ring, live captions, RMS bar, Mute / Interrupt / End dock inside `ChatScreen`.
- **`voice_shortcut_recorder.dart` (ADD):** Key-combo capture tile/dialog + conflict indicator.

### [MODIFY / DELETE] Shell, Navigation, Chat, Settings & Studio
- **`desktop_settings_controller.dart` (MODIFY):** Remove `DesktopNavDestination.voice`.
- **`screens/voice_screen.dart` (DELETE):** Remove deprecated standalone `Voice` rail tab under Option A.
- **`desktop_lifecycle_coordinator.dart` (MODIFY):** Add `isAudioMuted`, `updateAudioMutedStatus(bool)`, `onMuteToggleTriggered`, and `Mute Audio` / `Unmute Audio` menu item with `isAudioMuted = false` optional default in `buildTrayMenuItemsWithSafety`.
- **`desktop_shell.dart` (MODIFY):** Wire `DesktopVoiceController` + `DesktopAudioAdapter`, remove `VoiceScreen` branch, gate `_buildTopUtilityStrip` on `_voiceController != null` as well and render glowing amber `shell_mic_privacy_indicator`, bind customizable global/in-app hotkeys cleanly (`try/on UnimplementedError` for test fakes).
- **`screens/chat_screen.dart` (MODIFY):** Header Live Voice & Auto-Read toggles, inline `LiveVoiceStagePanel`, active composer Mic Dictate button, composer-safe `Spacebar` barge-in shortcut, per-message Read Aloud / Stop controls.
- **`features/settings/settings_section.dart`, `screens/settings_screen.dart` & `sections/settings_voice_section.dart` (ADD/MODIFY):** Promote `SettingsSectionId.voice` to `available` and render `SettingsVoiceSection`.
- **`features/studio/desktop_studio_controller.dart` & `studio_inspector_panel.dart` (MODIFY):** Add `voiceId` across `CharacterStudioDraft`, `PendingUpdateSnapshot`, `_matchesUpdatePayload`, `_matchesBaseline`, `clearVoiceId`, and Studio Character Voice dropdown + Preview button (disabled when read-only).

---

## 4. Step-by-Step Implementation Sequence (TDD)

1. **Slice 1 — Native Windows C++ WASAPI & Hotkey Channel (`windows/runner/`) + Dart `DesktopAudioAdapter` & `DesktopClientSettings`:**
   - Write failing unit tests for `DesktopClientSettings` voice hardware/shortcut persistence + conflict rules (`desktop_voice_test.dart`, RED).
   - Implement `windows_audio_channel.h/.cpp` (with `kWmAudioEvent` UI marshaling, STA/MTA COM isolation, RIFF subchunk walk), update `flutter_window.h/.cpp` & `CMakeLists.txt`, and implement `desktop_audio_adapter.dart` & `desktop_client_settings.dart` (GREEN).
   - Verify native Windows compilation (`flutter build windows --debug --no-pub`).
2. **Slice 2 — `DesktopVoiceController`, Generation-Tagged Barge-In, Tray Mute & Profile Isolation:**
   - Write failing tests covering: Dictation (`pcm16`, byte cap, transcript callback); Read Aloud + clean `isGenerating` transition `Auto-Read`; Live Voice auto-conversation creation + WS events + `<50ms` `flushPlayback` generation bump on `barge_in` / `vad.state: barge_in_triggered` / `turn.cancelled`; hard OS `setMuted` (`stopCapture` + `flushPlayback` + Tray sync); and immediate capture/WS tear-down on `profileEpoch` change (`desktop_voice_test.dart`, RED -> GREEN).
3. **Slice 3 — Option A UI (`Voice` Tab Removal, Shell Mic Badge, `ChatScreen`, `SettingsVoiceSection` & Studio Voice Picker):**
   - Write/update failing tests across `desktop_voice_test.dart`, `desktop_shell_test.dart`, `widget_test.dart`, `desktop_settings_revamp_test.dart`, `desktop_lifecycle_test.dart`, `desktop_shortcuts_test.dart`, `desktop_studio_controller_test.dart`, and `studio_screen_test.dart` (RED -> GREEN).
4. **Verification Gate (All Checks Must Pass Before Phase 3):**
   - `Push-Location frontend\flutter; dart analyze .; flutter test --no-pub --concurrency=1 apps/desktop/test; Pop-Location`
   - `Push-Location frontend\flutter\apps\desktop; flutter build windows --debug --no-pub; Pop-Location`
   - `Push-Location frontend\flutter\packages\companion_api; dart analyze; dart test; Pop-Location`
   - `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`
5. **Phase 3 Closure & Draft PR:**
   - Sync [`01_PC_Desktop_Shell_and_Tray.md`](../../05_Design/01_PC_Desktop_Shell_and_Tray.md), [`05_Voice_Mode_and_Audio_Controls.md`](../../05_Design/05_Voice_Mode_and_Audio_Controls.md), [`voice-and-audio.md`](../../04_Architecture/01_Domains/voice-and-audio.md), [`WBS.md`](../00_Master/WBS.md), [`MASTER_CHECKLIST.md`](../00_Master/MASTER_CHECKLIST.md), [`DELIVERY_INDEX.md`](../00_Master/DELIVERY_INDEX.md), `CHANGELOG.md`, `walkthrough-m4-voice-desktop-c.md`, archive `task-feature-m4-voice-desktop-c.md`, commit, push, and open Draft PR targeting `develop`.

---

## 5. Acceptance Criteria & Verification Strategy

### Automated Repository Checks
- [ ] Flutter static analysis: `Push-Location frontend\flutter; dart analyze .; Pop-Location` (`0` issues)
- [ ] Full Flutter Desktop test suite: `Push-Location frontend\flutter; flutter test --no-pub --concurrency=1 apps/desktop/test; Pop-Location` (all existing `409` + new Batch C tests pass)
- [ ] Windows native C++ build: `Push-Location frontend\flutter\apps\desktop; flutter build windows --debug --no-pub; Pop-Location`
- [ ] `companion_api` sanity & contract parity: `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`
- [ ] Optional backend sanity check: `venv\Scripts\python.exe -m pytest backend\tests\test_voice_api_and_ws.py backend\tests\test_character_foundation.py -q`

### Manual & Host-Level Checks (Windows Hardware — Batch C UI + Audio!)
- [ ] Launch `ai_companion_desktop.exe` alongside local runtime (`ggml-base.bin` + `silero_vad.onnx` + `kokoro-82m-v1.0`):
  1. Open `Settings -> Voice & Audio`: verify Windows Mic dropdown + live input level meter react to voice; pick Speaker + click **Test Sound** to hear chime; test binding custom hotkey + **Reset Defaults**.
  2. Open `Character Studio`: assign `af_nicole` to a Character, click **Preview**, save, and verify Chat inherits it (`CharacterInstance.voice_id`); clear back to **Profile Default**.
  3. In `ChatScreen`: click Composer **Mic** icon, speak a phrase, verify transcription populates the input box without losing draft safety; toggle **Live Voice Mode**, speak a turn, verify animated Orb + real spoken TTS reply + persistent Chat history bubble + amber top-bar **Mic Live** pill; interrupt mid-sentence by speaking or pressing `Spacebar` and confirm playback stops cleanly in `<50ms`.
  4. Right-click System Tray icon -> toggle **Mute Audio** and verify mic capture stops and output silences.

---

## 6. Risks, Dependencies, Assumptions & Safeguards

- **Risks & Mitigations:**
  - *WASAPI sample-rate / channel format mismatch across Windows audio drivers (44.1 kHz / 48 kHz Float32 stereo hardware vs 16 kHz PCM16 mono):* Request `AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY` first and fall back to reading the hardware mix format with C++ channel downmix + linear resampling so every Windows headset/mic initializes cleanly.
  - *MethodChannel thread violation or COM apartment conflict (`RPC_E_CHANGED_MODE`):* UI thread retains `main.cpp`'s STA apartment cleanly and receives background capture/hotkey callbacks strictly via `::PostMessageW` + `kWmAudioEvent` / `WM_HOTKEY` inside `FlutterWindow::MessageHandler`; capture/render threads own independent MTA apartments.
  - *Barge-in race where in-flight MethodChannel PCM bytes play after `Spacebar` / VAD cut:* Monotonic `uint64_t` `playbackGeneration` checked on both Dart and C++ render FIFO queue guarantees stale audio is dropped instantaneously on `flushPlayback(generation)`.
  - *Unattended thread/COM lifetime on Windows app close (`FlutterWindow::OnDestroy`):* Worker capture/render threads join deterministically inside `~WindowsAudioChannel()` before `FlutterWindow::OnDestroy` completes teardown.
  - *Hot-swap / profile switch mic leak:* `DesktopVoiceController` listens to `profileEpoch` and immediately releases WASAPI capture & closes `VoiceSessionClient` before reloading new Profile voice settings.
- **Dependencies & Assumptions:** Windows 10/11 Desktop SDK (verified via `flutter build windows --debug --no-pub`), zero new `pubspec.yaml` dependencies, backend M4 Batch B merged into `develop` at `de25ada`.
- **Required Permissions:** Phase 1 planning branch/commit/push on `feature/m4-voice-desktop-c`; after Human Owner plan approval, full Phase 2–3 autonomous implementation, verification, doc sync, push, and Draft PR on `feature/m4-voice-desktop-c`.
- **Genuine Stop Conditions:** Material scope change (e.g., adding third-party pub audio plugins or altering backend API contracts), unapproved architecture changes, Windows C++ COM/WASAPI linker blocker, or unresolvable test failures.
