# Walkthrough: M4 Batch C — Windows Native Audio, Hotkeys & Option A Voice UI

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Deliver Milestone M4 Batch C (zero-plugin native Windows C++ WASAPI audio capture/playback & Win32 global hotkeys, `DesktopAudioAdapter` & hardware/shortcut persistence, `DesktopVoiceController`, System Tray Mute toggle, Option A Voice UI across `ChatScreen`, `Settings -> Voice & Audio`, `Character Studio`, and `DesktopShell` amber mic privacy indicator, plus removal of the standalone `Voice` nav rail tab) on branch `feature/m4-voice-desktop-c`.
- Audience: Maintainers, independent reviewers, security reviewers, and QA engineers.
- Status: Implemented & Automated-Verified on `feature/m4-voice-desktop-c` (Pending Phase 4 Review & Manual Windows Hardware Audio QA)
- Last Updated: 2026-11-17

---

## 1. What Was Delivered

- **Zero-Plugin Native Windows C++ Audio & Hotkey Channel (`windows/runner/`):** Built `WindowsAudioChannel` (`ai_companion/windows_audio`) using Win32 COM (`IMMDeviceEnumerator`, `IAudioClient` capture/render) and `RegisterHotKey`/`WM_HOTKEY` without adding third-party pub plugins (`pubspec.yaml` unchanged). Enforced STA-safe UI COM initialization (`ScopedUiComGuard`) paired with dedicated MTA capture/render `std::thread`s (`ScopedMtaComGuard`), UI-thread message marshaling (`kWmAudioEvent = WM_APP + 0x43`), dynamic RIFF `"fmt "`/`"data"` subchunk scanning + linear resampler, `<50ms` generation-fenced `FlushPlayback`, in-memory two-note sine `playTestTone`, and global hotkey conflict reporting.
- **Dart Audio Adapter & Client Persistence (`platform/desktop_audio_adapter.dart`, `desktop_client_settings.dart`):** Added `DesktopAudioAdapter`, `WindowsWasapiAudioAdapter`, `NoOpDesktopAudioAdapter`, `VoiceHardwarePrefs`, `VoiceShortcutConfig` (defaults `Ctrl+Shift+V` in-app toggle, `Ctrl+Alt+V` global hotkey, `Ctrl+Shift+M` hard mute, `Right Alt` PTT, `Alt+Space` & duplicate validation), and shared JSON persistence helpers preserving existing client settings.
- **Voice Session Controller & Tray Mute (`features/voice/desktop_voice_controller.dart`, `lifecycle/desktop_lifecycle_coordinator.dart`):** Implemented `DesktopVoiceController` covering single-shot `pcm16` Dictation (capped at `kMaxTranscribePcmBytes = 1,468,006`), duplex `/api/v1/voice/ws` sessions with active conversation ensure/reload hooks, generation-tagged barge-in cut, hard OS mute synced with Windows tray `Mute Audio (Ctrl+Shift+M)`, clean-turn Auto-Read (`status == 'completed' || status == 'length'`), Character Studio voice preview, and full session teardown on `handleProfileEpochChanged`.
- **Option A Desktop Voice UI (`screens/chat_screen.dart`, `live_voice_stage_panel.dart`, `voice_shortcut_recorder.dart`, `settings_voice_section.dart`, `desktop_studio_controller.dart`, `studio_inspector_panel.dart`, `desktop_shell.dart`):** Removed `DesktopNavDestination.voice` and `screens/voice_screen.dart` (`5` nav tabs), added Header `Live Voice` & `Auto-Read` toggles, inline `LiveVoiceStagePanel` (reactive orb, RMS bar, live captions, active tool hint, Mute, composer-unfocused `Spacebar` / button Interrupt, `Right Alt` PTT hint, End Voice), active Composer Dictate button, and per-message `Read Aloud / Stop` to `ChatScreen`; promoted `SettingsSectionId.voice` to `available` (`SettingsVoiceSection`); added nullable `voiceId` + `clearVoiceId: true` and preview to `Character Studio`; wired `shell_mic_privacy_indicator` glowing amber privacy pill into `DesktopShell`.

## 2. Files Changed

- `frontend/flutter/apps/desktop/windows/runner/windows_audio_channel.h`, `windows_audio_channel.cpp`, `CMakeLists.txt`, `flutter_window.h`, `flutter_window.cpp` — Native Windows C++ WASAPI capture/playback & Win32 hotkey channel (`+0` pub dependencies).
- `frontend/flutter/apps/desktop/lib/platform/desktop_audio_adapter.dart`, `desktop_client_settings.dart` — Audio adapter interfaces, models, shortcut config, and safe JSON persistence.
- `frontend/flutter/apps/desktop/lib/features/voice/desktop_voice_controller.dart`, `live_voice_stage_panel.dart`, `voice_shortcut_recorder.dart` — Voice session controller, inline stage panel, and interactive shortcut recorder.
- `frontend/flutter/apps/desktop/lib/lifecycle/desktop_lifecycle_coordinator.dart` — Tray `Mute Audio (Ctrl+Shift+M)` action and status sync.
- `frontend/flutter/apps/desktop/lib/controllers/desktop_settings_controller.dart`, `lib/screens/voice_screen.dart` (deleted) — Option A 5-tab navigation rail.
- `frontend/flutter/apps/desktop/lib/features/settings/settings_section.dart`, `sections/settings_voice_section.dart`, `lib/screens/settings_screen.dart` — Promoted `Settings -> Voice & Audio` section.
- `frontend/flutter/apps/desktop/lib/features/studio/desktop_studio_controller.dart`, `studio_inspector_panel.dart`, `lib/screens/studio_screen.dart` — Character `voiceId` editing, `clearVoiceId: true`, `PendingUpdateSnapshot` reconciliation, and preview button.
- `frontend/flutter/apps/desktop/lib/shell/desktop_shell.dart`, `lib/screens/chat_screen.dart` — `DesktopShell` glowing amber mic privacy indicator + shortcut wiring; `ChatScreen` Option A voice controls & unfocused `Spacebar` interrupt.
- `frontend/flutter/apps/desktop/test/` — Added `desktop_voice_test.dart`, `desktop_voice_ui_test.dart`, Studio `voiceId` tests (`desktop_studio_controller_test.dart`, `studio_screen_test.dart`), and Option A assertions (`desktop_shell_test.dart`, `widget_test.dart`, `desktop_settings_revamp_test.dart`, `desktop_lifecycle_test.dart`).
- Canonical documentation (`docs/05_Design/`, `docs/04_Architecture/01_Domains/voice-and-audio.md`, `docs/02_Planning/00_Master/`, `CHANGELOG.md`, `plan-m4-voice-desktop-c.md`, archived branch tracker).

## 3. How the Logic Works

1. **Native WASAPI & Hotkey Bridge:** `FlutterWindow` owns `WindowsAudioChannel`, registering `ai_companion/windows_audio` and routing `kWmAudioEvent` + `WM_HOTKEY` window messages safely on the UI STA thread while dedicated MTA audio threads capture 16 kHz PCM16 frames and mix/resample WAV/PCM output with generation-tagged buffer flushing.
2. **Voice Control & Isolation:** `DesktopVoiceController` coordinates hardware endpoint selection, global/in-app shortcuts, hard mute (`setMuted` stops OS capture & tray state), single-shot Composer dictation, and live duplex `WS /api/v1/voice/ws` turns; Profile switches invoke `handleProfileEpochChanged` to tear down audio/WS state immediately.
3. **Option A Workspace Integration:** Users dictate or launch live voice inside `ChatScreen` (`LiveVoiceStagePanel`), inspect/configure hardware, shortcuts, barge-in, TTS speed, and privacy in `Settings -> Voice & Audio`, and bind optional per-character TTS voices in `Character Studio` (leaving Neutral Assistant immutable).

## 4. Verification Steps

### Automated Checks

- [x] `dart analyze .` (from `frontend/flutter`): `No issues found!`.
- [x] `flutter test --no-pub --concurrency=1 apps/desktop/test`: `423: All tests passed!` (`0` failed, `0` skipped — run after all final code edits).
- [x] `flutter build windows --debug --no-pub` (from `frontend/flutter/apps/desktop`): `Built build\windows\x64\runner\Debug\ai_companion_desktop.exe` (`19.6s`, exit `0`; re-verified clean MSVC `/W4 /WX` build cleanly prior to doc closure).
- [x] `companion_api` (`dart analyze` + `dart test`): `No issues found!`, `112: All tests passed!`.
- [x] `venv\Scripts\python.exe scripts\check_dart_openapi_parity.py --check`: `ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED` (`87/87` DTO schemas).
- [x] `venv\Scripts\python.exe -m pytest backend\tests\test_voice_api_and_ws.py backend\tests\test_character_foundation.py -q`: `14 passed`.

### Pending Manual Physical Windows Hardware & GUI QA

- [ ] Launch `ai_companion_desktop.exe` on Windows with a real microphone & speaker: open **Settings → Voice & Audio**, verify real WASAPI endpoints populate, click **Test Sound**, and observe the live RMS level meter react to speech.
- [ ] Verify **Chat** Composer **Dictate** records real speech into the text box and **Read Aloud** speaks a completed assistant reply.
- [ ] Verify **Live Voice** session in **Chat**: confirm the glowing amber **Mic Active** badge appears in the shell utility strip, interrupt mid-sentence via unfocused `Spacebar` / voice barge-in (`<50ms` audio cut), test **Mute Audio** via both `Ctrl+Shift+M` and the Windows System Tray menu, and test the `Ctrl+Alt+V` global hotkey while the Desktop window is minimized/hidden.
- [ ] Verify **Character Studio** per-character voice dropdown & preview playback.
