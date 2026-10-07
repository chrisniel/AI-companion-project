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

#### Approved Mobile V1 Targets
- **Flutter Mobile Foundation:** Production Flutter mobile application target in shared monorepo workspace.
- **Production Package Identity:** Locked `com.cnl.aicompanion` (Kotlin prototype `android/` is reference evidence only).
- **PC V1 Independence:** Mobile Companion development does not block PC V1 delivery.
- **Single-Profile Satellite Binding:** Mobile satellite binds to exactly one Profile; PC Host is sole Account/Profile Admin.
- **Platform-Protected Secure Storage:** Device Token and third-party API credentials stored in Android Keystore; plaintext storage strictly prohibited.
- **Relational Persistence & Durable Outbox:** Relational SQLite-backed local persistence (Drift preferred candidate) with transactional mutation journal (outbox) surviving process death and reboot.
- **Mobile ↔ Host Synchronization:** Asymmetric per-domain synchronization, client-generated stable entity IDs (UUIDv4), monotonic revision checks, and typed `CONFLICT_DETECTED` / `STALE_CURSOR` outcomes.
- **Offline Task Management:** Full offline Task create, update, `SET_COMPLETION`, and delete with causal dependency ordering.
- **Native Scheduling & Alarm Delivery:** Precomputed Reminder/Alarm occurrence replication from PC `SchedulerService`; `AlarmManager` exact alarms with `canScheduleExactAlarms()` degradation handling and reboot recovery.
- **Capability-Dependent Local Inference:** Evidence-driven Tiers 0–3 runtime qualification as optional auxiliary capability; single resident model cap (`--models-max 1`); LAN Host-to-Device model transfer.
- **Disconnected Conversation Working State & Provenance:** Qualified Tier 2/3 devices support offline local text turns; devices with authorized Cloud LLM support disconnected cloud turns; synchronized as atomic whole-turn units with execution-origin provenance (`MOBILE_LOCAL_INFERENCE` / `MOBILE_CLOUD_INFERENCE`) and `client_message_id` deduplication without Host LLM replay or tool invocation.
- **Decoupled Local TTS & STT:** Capability-dependent device-local TTS where approved provider installed; independently capability-gated local STT with truthful fallback to text.
- **Connected Voice Streaming:** Full-duplex WebSocket audio streaming to PC Runtime canonical STT/TTS/VAD providers with mandatory immediate barge-in.
- **Optional Cloud Providers:** Cloud LLM, Cloud STT, and Cloud TTS independently permissioned; explicit opt-in; provider credentials stored device-locally in Android Keystore; zero silent cloud fallback.
- **Platform Security & Governance:** Backup exclusions (`dataExtractionRules`, `backup_rules.xml`), private sandbox baseline, clipboard/screen privacy (`FLAG_SECURE`), and thermal/battery governance.
- **Multi-Layer Verification & Golden Gate:** 5-layer test matrix (L1–L5) and 12-group Mobile Golden Acceptance Gate (MG1–MG12) collecting verified evidence across L1–L5 with mandatory physical hardware runs for hardware/audio/thermal behaviors.

#### Mobile Later (Deferred Post-V1)
- **Health Connect & Wearables:** Real Health Connect integration (`androidx.health.connect`) and biometric synchronization (prototype mock UI sequestered).
- **Autonomous Local Routines:** Autonomous local routine execution deferred post-V1; cached read-only view offline only.
- **Always-On Wake Word Detection:** Continuous background wake-word listening on mobile.

#### Post-V1 / Implementation-Open Candidates
- **Local Mobile VLM / Vision Inference:** Local on-device vision model execution (media capture and upload to PC Host supported in V1; local vision inference is an unscheduled candidate).
- **Curated In-App Model Hub Downloads:** Managed external model catalog discovery and direct online downloading (LAN PC transfer used in V1).

### 2.5 Rejected Proposals (Prohibited Capabilities)
- **Generic Command Shell Execution:** Arbitrary `cmd.exe`, PowerShell, Bash, raw OS process spawning, or unrestricted filesystem administrative authority (Permanently REJECTED under Decision D9 Risk 3).
- **Direct Router Port Forwarding / Public Internet Exposure:** Exposing the Local AI Runtime directly to public IP without private mesh or authenticated reverse proxy (Permanently REJECTED under Decision D5).
- **Unbounded Autonomous Looping:** Unconstrained recursive self-directed agent loops without human-in-the-loop gates or explicit timeouts.
- **Shared Master Secrets on Client Devices:** Distributing master database encryption keys or master API secrets to satellite/mobile endpoints.
- **Voice as Biometric Authentication:** Using conversational voiceprint matching as an authorization or authentication factor.
- **Silent Emotion-Driven Policy Changes:** Modulating security permissions, factuality standards, alarm execution, or queue priority based on companion mood.
