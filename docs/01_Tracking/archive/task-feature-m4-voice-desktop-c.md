# Active Task: M4 Batch C — Windows Native Audio, Hotkeys & Option A Voice UI

- **Branch:** `feature/m4-voice-desktop-c`
- **Plan:** [`plan-m4-voice-desktop-c.md`](../../02_Planning/01_Plans/plan-m4-voice-desktop-c.md)
- **Delivery Level:** Level C — Sensitive Design
- **Current Phase:** Phase 3 — Documentation & Closure Prepared (Awaiting Phase 4 Independent Review & Human Merge)

## Checklist

- [x] Verify clean `develop` baseline (`de25ada`) and create branch `feature/m4-voice-desktop-c`
- [x] Author Level C implementation plan (`plan-m4-voice-desktop-c.md`) and pass Phase 1 Independent Plan Review (`a6e7645e` APPROVED)
- [x] Publish Phase 1 plan commit to `origin/feature/m4-voice-desktop-c` and obtain Human Owner approval
- [x] Phase 2 Slice 1: Native Windows C++ WASAPI & Win32 Hotkey MethodChannel (`windows_audio_channel.h/.cpp`) + Dart `DesktopAudioAdapter` & `DesktopClientSettings` (`flutter build windows` verified)
- [x] Phase 2 Slice 2: `DesktopVoiceController` (Dictation, Live Duplex WS, Read Aloud, Auto-Read, generation-tagged barge-in cut, Tray Mute, Profile switch isolation) (`desktop_voice_test.dart`, `desktop_lifecycle_test.dart`)
- [x] Phase 2 Slice 3: Option A UI (`ChatScreen` Live Voice Stage / Dictation / Read Aloud / Auto-Read, `Settings -> Voice & Audio`, `Character Studio` voice picker, Shell mic privacy pill, remove `Voice` rail tab & update tests) (`dart analyze .` `0` issues, `423/423` Desktop tests passing, Windows debug build passing)
- [x] Phase 3: Sync canonical UI/architecture docs (`01_PC_Desktop_Shell_and_Tray.md`, `05_Voice_Mode_and_Audio_Controls.md`, `voice-and-audio.md`), master spine, walkthrough (`walkthrough-m4-voice-desktop-c.md`), `CHANGELOG.md`, & archive tracker
- [ ] Phase 4: Combined independent review, green PR CI, Human Owner squash merge, & manual Windows hardware audio QA
