# Archived Task: M4 Batch C — Windows Native Audio, Hotkeys, Option A Voice UI & Post-QA Stabilization

- **Branch:** `feature/m4-voice-desktop-c`
- **Plan:** [`plan-m4-voice-desktop-c.md`](../../02_Planning/01_Plans/plan-m4-voice-desktop-c.md)
- **Delivery Level:** Level C — Sensitive Design
- **Current Phase:** Phase 3 Complete — Automated-Verified on `feature/m4-voice-desktop-c` (Pending Manual Hardware QA & Phase 4 Combined Review)

## Checklist

- [x] Verify clean `develop` baseline (`de25ada`) and create branch `feature/m4-voice-desktop-c`
- [x] Author Level C implementation plan (`plan-m4-voice-desktop-c.md`) and pass Phase 1 Independent Plan Review (`a6e7645e` APPROVED)
- [x] Publish Phase 1 plan commit to `origin/feature/m4-voice-desktop-c` and obtain Human Owner approval
- [x] Phase 2 Slice 1: Native Windows C++ WASAPI & Win32 Hotkey MethodChannel (`windows_audio_channel.h/.cpp`) + Dart `DesktopAudioAdapter` & `DesktopClientSettings` (`flutter build windows` verified)
- [x] Phase 2 Slice 2: `DesktopVoiceController` (Dictation, Live Duplex WS, Read Aloud, Auto-Read, generation-tagged barge-in cut, Tray Mute, Profile switch isolation) (`desktop_voice_test.dart`, `desktop_lifecycle_test.dart`)
- [x] Phase 2 Slice 3: Option A UI (`ChatScreen` Live Voice Stage / Dictation / Read Aloud / Auto-Read, `Settings -> Voice & Audio`, `Character Studio` voice picker, Shell mic privacy pill, remove `Voice` rail tab & update tests) (`dart analyze .` `0` issues, `423/423` Desktop tests passing, Windows debug build passing)
- [x] Manual Windows QA & full post-QA audit: identified 7 reported issues + 5 hidden bugs and updated `plan-m4-voice-desktop-c.md` with Slice 4
- [x] Phase 1 Gate (Slice 4): Human Owner approval of expanded Slice 4 scope (backend context/compaction, `espeak-ng`/Taglish G2P + latency/VAD endpointing, tray/shortcut/mute/UI fixes, & `requirements.lock` sync)
- [x] Phase 2 Slice 4A: Fix backend context token budgeting, tool schema overhead (`[0-9]`, `_compact_json_schema`), UTF-8 estimation (`_text_char_units`), empty failed history filtering & step-down auto-compaction (`orchestrator.py`, `compactor.py`, `tools/registry.py`, `test_assistant_orchestrator.py`, `test_character_personality_modulator.py`)
- [x] Phase 2 Slice 4B: Fix Kokoro G2P (`espeakng-loader` + Taglish + normalization), CPU thread tuning, multi-chunk `synthesize()`, hands-free VAD turn endpointing w/ 10-frame pre-roll, async TTS queue, `BargeInGate` bleed guard & lock Python deps (`tts.py`, `session_orchestrator.py`, `pyproject.toml`, `requirements.*`, `test_voice_engines_and_barge_in.py`, `test_voice_api_and_ws.py`)
- [x] Phase 2 Slice 4C: Fix Tray right-click `popUpContextMenu()` + `_audioMuted` menu retention, root `HardwareKeyboard` shortcuts w/ capture-modal & dual-zoom dedup guard, isolated `micRmsListenable`, clickable mute/unmute pills & Chat header button, cold-launch `refreshBackendState()`, `Read Aloud` completion timer, sentence-pipelined playback, voice error banner w/ 1-click Unmute, & Settings **Test Mic** / mic hot-swap
- [x] Verification Gate: full backend `pytest` (`887 passed`, `0` failed), `dart analyze .` (`0` issues), `flutter test --no-pub --concurrency=1 apps/desktop/test` (`427/427` passed), `flutter build windows --debug --no-pub` (`ai_companion_desktop.exe`, `14.8s`), `companion_api` (`0` issues, `112/112` passed), `check_dart_openapi_parity.py --check` (`87/87` schemas & routes), & `test_import_isolation.py` + `scripts/tests/test_python_dependency_lock.py`
- [x] Phase 3: Re-sync canonical docs, walkthrough, `CHANGELOG.md`, archive tracker on same branch, commit & push to Draft PR #46
- [ ] Phase 4: Combined independent review, green PR CI, Human Owner squash merge, & manual Windows hardware QA re-test
