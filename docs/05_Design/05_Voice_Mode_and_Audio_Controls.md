# Voice Mode & Audio Controls Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md), [`ADR-0019`](../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md).

---

## 1. Overview & Voice Philosophy

Voice Mode provides a natural, low-latency, hands-free conversational interface for the AI Companion. The interaction design prioritizes fluid turn-taking, immediate conversational interruption (**Voice Barge-In**), and transparent audio hardware control.

---

## 2. Voice Mode Interface Layout (Option A — Integrated Chat Stage)

Voice Mode is integrated directly into the primary `ChatScreen` workspace (`LiveVoiceStagePanel`) rather than using a separate top-level navigation rail tab:
- **Chat Header Controls:** `Live Voice` button (`chat_voice_mode_toggle`) to enter/exit hands-free duplex voice mode and `Auto-Read` toggle (`chat_auto_read_toggle`) to speak completed text replies automatically.
- **Inline Stage (`LiveVoiceStagePanel`):** Appears above the message timeline during active voice sessions with a reactive Companion orb, live status pill (`Connecting...` / `Listening` / `Thinking...` / `Speaking`), WASAPI mic RMS level bar, active tool progress hint, and real-time user/assistant captions.
- **Composer Dictate & Message Read Aloud:** Active composer Mic button (`chat_dictate_button`) records WASAPI PCM16 audio into `POST /api/v1/voice/transcribe` and appends recognized text without overwriting existing unsent drafts; completed assistant messages expose per-message `Read Aloud / Stop` (`message_speak_<id>`) controls.
- **Stage Interaction Controls:**
  - **Mute Microphone Toggle (`Ctrl+Shift+M` default, customizable):** Cuts OS capture at the Windows driver level and flushes playback.
  - **Interrupt / Barge-In Button (`Spacebar` when composer is unfocused):** Immediately cuts companion speech and dispatches WS `barge_in`.
  - **End Voice Session (`Ctrl+Shift+V` in-app or `Ctrl+Alt+V` global default, customizable):** Closes the WebSocket channel, stops WASAPI capture, and hides `LiveVoiceStagePanel`.

---

## 3. Mandatory Voice Barge-In Interaction

In accordance with architectural invariants, conversational barge-in is **mandatory** in PC V1:
- **Generation-Fenced Hardware Flush & Server Cancel:** When either server-side Silero/energy VAD triggers `vad.state: barge_in_triggered`, the user clicks **Interrupt**, or presses `Spacebar` while the composer is unfocused:
  1. *Immediate Local Mute:* `DesktopVoiceController` increments `_playbackGeneration` and invokes `WindowsAudioChannel.flushPlayback`, clearing queued WASAPI render buffers in `<50ms`.
  2. *Barge-In Event Dispatch:* The client sends `{ "type": "barge_in" }` over `/api/v1/voice/ws` and marks the interrupted `turn_id` cancelled in `VoiceSessionClient`.
  3. *Runtime Cancellation:* The runtime cancels remaining LLM/TTS work within bounded timeout and starts listening for the user's new utterance.
- **Visual Feedback:** `LiveVoiceStagePanel` shifts immediately between "Speaking", "Thinking...", and "Listening", confirming interruption without stale audio leakage.

---

## 4. Audio Input, Output, Shortcuts & Character Voice Controls

Accessible via **Settings $\rightarrow$ Voice & Audio** (`SettingsVoiceSection`) and **Character Studio**:
- **Engine Readiness & Privacy Banner:** Displays live STT/VAD/TTS provider readiness (`GET /api/v1/voice/status`) and confirms audio buffers remain in transient RAM with zero disk persistence or biometric voiceprinting.
- **Microphone & Speaker Routing:** Native Windows WASAPI endpoint dropdowns (`IMMDeviceEnumerator`) with live mic RMS level meter, **Test Sound** playback verification, and **Refresh Devices**.
- **Customizable Keyboard Shortcuts:** Interactive key-combo recorder (`VoiceShortcutRecorderTile`) with conflict/reserved-key (`Alt+Space`) validation, Win32 global hotkey registration conflict warnings, and **Reset Defaults** (`Ctrl+Shift+V`, `Ctrl+Alt+V`, `Ctrl+Shift+M`, `Right Alt`).
- **Behavior & Character Voice:** Per-Profile Barge-In Policy (`smart_auto` / `strict_noisy` / `manual_only`), VAD Sensitivity (`low`/`medium`/`high`), Recognition Language (`en`/`auto`), Default TTS Voice + Preview, Speech Speed (`0.50x`–`2.00x`), Auto-Read Replies, opt-in Proactive Speech (`OFF` by default), plus per-character TTS voice override and preview inside `Character Studio` (`Identity & Lore`).

---

## 5. Mute & Privacy Controls

- **Hard Hardware Mute:** Toggling mute closes the microphone capture stream at the OS driver level.
- **Visual Privacy Warning:** When microphone capture is active, Windows displays its standard taskbar microphone indicator, and the desktop shell displays a persistent glowing amber badge.
