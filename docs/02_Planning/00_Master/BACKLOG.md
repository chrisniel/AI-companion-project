# AI Companion — PC V1 Master Backlog

> **Document Role:** Canonical backlog cataloging capabilities across release targets, experimental probes, and rejected proposals.  
> **Status:** Active Canonical Planning Baseline  
> **Release Axes:** Work items are strictly partitioned by release allocation and disposition. Items in `PC LATER`, `EXPERIMENTAL`, or `REJECTED` do not enter PC V1 implementation without formal architectural unfreezing.

---

## 1. Backlog Taxonomy

| Partition | Definition | Governance Rule |
| :--- | :--- | :--- |
| **`PC V1 Committed`** | Approved capabilities required for initial PC-hosted ecosystem release. | Tracked in WBS; enters active implementation plans. |
| **`PC Later`** | Approved capabilities postponed beyond PC V1 to preserve release integrity. | Frozen; design exploration permitted without blocking V1. |
| **`Experimental`** | Exploratory spikes, benchmark probes, or candidate research. | Throwaway code only; requires approval before promotion. |
| **`Mobile Follow-On`** | Android production companion capabilities (`com.cnl.aicompanion`). | Sequenced as a dedicated pass after PC V1 docs stabilize. |
| **`Rejected`** | Explicitly excluded from ordinary assistant capability or trust model. | Permanently barred; must not be reopened as PC Later. |

---

## 2. Partitioned Backlog Items

### 2.1 PC V1 Committed Backlog
- **Primary Desktop UI:** Flutter Windows Desktop application with system tray lifecycle and background supervision.
- **Multi-Profile Privacy:** Local Account administration with strictly isolated Profiles, PIN/Windows Hello protection, and single-Profile satellite device binding.
- **Runtime-Owned Work Queues:** Bounded FIFO per-conversation work queues surviving browser/client disconnects.
- **Host Startup & Notifications:** Windows Task Scheduler autostart at login; native Windows Action Center Toast delivery.
- **Controlled Local Model Import (D6):** User-initiated manual scan, metadata preflight, multi-file bundle staging (`.gguf` + `mmproj`), atomic installation to relocatable `LIBRARY_ROOT`.
- **Character Studio & Mood:** Profile-owned Character instances, eight continuous personality traits (0–100), persistent simulated mood that decays over time and never compromises functional correctness.
- **Selective Memory with Revalidation:** Profile/Character scoping, explicit remember commands, deterministic local extraction, temporary memory validity tracking, and bounded history recall.
- **D9 Deterministic Policy Engine:** 5-stage pipeline, DEFAULT DENY, configurable Risk 0/1/2, exact confirmation parameter binding, emergency kill switch, and auditable logging.
- **Scheduling & Notifications (D10):** Runtime `SchedulerService`, distinct Task/Reminder/Alarm/Routine, quiet hours defaults (Alarm bypasses; Reminder/Routine respects), native notification delivery.
- **Conversational Voice:** Local STT (e.g. `whisper.cpp` reference), local TTS (e.g. Kokoro-82M reference candidate), mandatory voice barge-in, WebSocket audio streaming.
- **Read-Only Web Information:** Public search, web fetch with strict SSRF containment, weather context, untrusted content sanitization, source provenance.
- **Optional Cloud Fallback:** `LOCAL_ONLY` default; opt-in `LOCAL_FIRST`; device-local API keys; background cloud inference defaults OFF; egress transparency.
- **Resilience & Maintenance:** Coordinated DB+Profile asset backup, pre-migration snapshots, staged restore verification, local admin Factory Reset.
- **Low-Impact / Gaming Mode:** Normal / Low Impact / Auto; Option B configured game/heavy app list; Low-Impact lightweight model substitution.
- **Two-Tier Verification:** Scoped CI matrix (always-running `ci-gate`) + 14-group Golden PC V1 Acceptance Gate.

### 2.2 PC Later (Post-V1 Approved Backlog)
- **Wake Word Detection:** Hands-free background listening (`WakeWordProvider`, openWakeWord / Snowboy).
- **Advanced Presence:** Animated Live2D, VRM/glTF 3D avatars, draggable floating desktop overlay, rich emotional animation states.
- **Interactive Browser Automation:** Playwright-driven form filling, authenticated navigation, and multi-step web interactions.
- **Managed Online Model Hub Downloads:** In-app discovery and background downloading from Hugging Face / Ollama library directly into D6 import pipeline.
- **Semantic / Vector Memory:** Dense vector embeddings and hybrid lexical+vector retrieval in SQLite (e.g., `sqlite-vec`).
- **Full Relationship Continuity:** Opt-in, hidden-by-default familiarity depth and relationship milestone mechanics (strictly decoupled from Personality/Emotion).
- **Richer Emotion Models:** Multi-dimensional affective simulation (e.g., PAD model) with complex emotional decay curves.
- **Generic Heuristic Game Detection:** Automatic detection of foreground fullscreen 3D graphics engines without manual app list configuration.
- **Cloud-Assisted Memory Processing:** Optional, user-authorized cloud-assisted summarization and memory extraction.
- **Diagnostics & Recovery Center:** Dedicated visual administrative interface for foreign-key validation, index rebuilding, and repair.

### 2.3 Experimental / Candidate Spikes
- **Stable Diffusion Presence Renderer:** Real-time generation of contextual character portraits/reactions via local SD-Turbo / Flux.
- **Alternative Audio Engines:** Evaluation of Piper TTS, KittenTTS, Sherpa-ONNX, and WebRTC VAD alternatives.
- **Alternative Inference Runtimes:** DirectML, ONNX Runtime Generative AI, or ROCm native drivers on AMD hardware.
- **Quick Cloudflare Tunnels:** Ephemeral quick tunnels for temporary mobile testing during development.

### 2.4 Mobile Follow-On Track (Android V1)
- **Flutter Mobile Foundation:** Flutter is the intended production foundation, preserving SoftGlass neumorphic design concepts.
- **Production Package Identity:** Locked com.cnl.aicompanion.
- **PC V1 Independence:** Android development does not block PC V1 delivery.
- **Single-Profile Mobile Binding:** Satellite phone binds to exactly one Profile.
- **Local Credentials:** Provider/API/device credentials remain device-local.
- **Current Evidence:** Current Kotlin repository code serves strictly as prototype/reference evidence.

**MOBILE ARCHITECTURE CANDIDATE INPUTS / RESEARCH:**
(To be evaluated during the separate mobile architecture pass; not currently frozen)
- Mobile-to-PC state synchronization topology.
- Local offline outbox queuing and state caching (e.g. Room).
- On-device compact offline roaming LLM.
- Wearable and biometric context synchronization (e.g. Android Health Connect API).

### 2.5 Rejected Proposals (Prohibited Capabilities)
- **Generic Command Shell Execution:** Arbitrary `cmd.exe`, PowerShell, Bash, raw OS process spawning, or unrestricted filesystem administrative authority (Permanently REJECTED under Decision D9 Risk 3).
- **Direct Router Port Forwarding / Public Internet Exposure:** Exposing the Local AI Runtime directly to public IP without private mesh or authenticated reverse proxy (Permanently REJECTED under Decision D5).
- **Unbounded Autonomous Looping:** Unconstrained recursive self-directed agent loops without human-in-the-loop gates or explicit timeouts.
- **Shared Master Secrets on Client Devices:** Distributing master database encryption keys or master API secrets to satellite/mobile endpoints.
- **Voice as Biometric Authentication:** Using conversational voiceprint matching as an authorization or authentication factor.
- **Silent Emotion-Driven Policy Changes:** Modulating security permissions, factuality standards, alarm execution, or queue priority based on companion mood.
