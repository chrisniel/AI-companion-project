# Voice Mode & Audio Controls Design

> **Document Role:** UX/UI presentation and interaction design specification.  
> **Status:** Active Baseline (PC V1).  
> **Normative Architectural Authority:** [`docs/04_Architecture/01_Domains/voice-and-audio.md`](../04_Architecture/01_Domains/voice-and-audio.md), [`ADR-0019`](../04_Architecture/decisions/ADR-0019-client-runtime-contract-and-work-boundaries.md).

---

## 1. Overview & Voice Philosophy

Voice Mode provides a natural, low-latency, hands-free conversational interface for the AI Companion. The interaction design prioritizes fluid turn-taking, immediate conversational interruption (**Voice Barge-In**), and transparent audio hardware control.

---

## 2. Voice Mode Interface Layout

Voice Mode can be experienced either as a full-screen dedicated view or as a compact floating widget:
- **Center:** Large companion avatar with animated reactive audio visualizer rings.
- **Top:** Active audio input/output device selector chips and connection status indicator (`WebSocket: Connected (18ms)`).
- **Bottom:** Primary interaction controls:
  - **Mute Microphone Toggle (`Ctrl+Shift+M`):** Instantly cuts audio stream transmission.
  - **Interrupt / Barge-In Button (`Spacebar`):** Immediately cuts companion speech.
  - **End Voice Session Button:** Closes the WebSocket channel and returns to standard chat.
- **Transcript Overlay:** Subtle, auto-scrolling live text captions displaying recognized speech and companion responses in real time.

---

## 3. Mandatory Voice Barge-In Interaction

In accordance with architectural invariants, conversational barge-in is **mandatory** in PC V1:
- **Voice Activity Detection (VAD) Trigger:** When the companion is speaking and the client-side VAD detects incoming user speech above the threshold:
  1. *Immediate Local Mute:* The Flutter audio player immediately pauses/mutes audio playback (<50ms).
  2. *Barge-In Event Dispatch:* The client sends a `{ "type": "barge_in" }` message over the duplex WebSocket to the runtime.
  3. *Runtime Cancellation:* The runtime cancels remaining TTS synthesis for the interrupted turn, cuts off token generation, and begins processing the user's new utterance.
- **Visual Feedback:** The companion avatar ring shifts instantly from "Speaking" (expanding waveforms) to "Listening" (attentive pulse), confirming the interruption without audible stutter.
- **Manual Interrupt Tap:** Clicking anywhere on the avatar or pressing the `Spacebar` triggers an instant manual interrupt.

---

## 4. Audio Input & Output Device Controls

Accessible via the Voice Mode header or Settings $\rightarrow$ Audio:
- **Microphone Selection:** Dropdown enumerating available Windows audio capture devices with a real-time input level meter.
- **Speaker Selection:** Dropdown enumerating available Windows audio playback devices with a "Test Sound" button.
- **Input Modes:**
  - *Continuous Listening with VAD (Default):* Automatically detects speech start and stop.
  - *Push-to-Talk (PTT):* Transmits audio only while a designated hotkey is held (default: `Right Alt` or mouse button).
- **VAD Sensitivity Slider:** Fine-tuning slider (Low / Medium / High) to adjust threshold against background keyboard clicks or fan noise.

---

## 5. Mute & Privacy Controls

- **Hard Hardware Mute:** Toggling mute closes the microphone capture stream at the OS driver level.
- **Visual Privacy Warning:** When microphone capture is active, Windows displays its standard taskbar microphone indicator, and the desktop shell displays a persistent glowing amber badge.
