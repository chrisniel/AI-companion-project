# Mobile Capabilities, Inference, Voice, and Verification Architecture

> **Document Role:** Canonical infrastructure and behavior specification for Mobile Companion hardware capabilities, local inference policy, voice architecture, security boundaries, and release verification.  
> **Status:** Proposed Canonical — Mobile Architecture Batch C / Review Pending  
> **Authority Precedence:** This specification governs Mobile hardware tiering, local/remote inference delegation, voice streaming and audio focus, platform security controls, resource governance, and testing architecture. It operates under the cross-cutting boundaries defined in [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md) and [`mobile-offline-and-sync.md`](./mobile-offline-and-sync.md). PC Local AI Runtime domain truth remains owned by shared specifications (such as [`runtime-and-models.md`](./runtime-and-models.md), [`voice-and-audio.md`](../01_Domains/voice-and-audio.md), and [`health-and-wearables.md`](../03_Integrations/health-and-wearables.md)).

---

## 1. Justification & Boundary

This specification defines the execution architecture for mobile hardware capabilities, on-device vs. host inference boundaries, mobile voice streaming, threat modeling, thermal/battery governance, and verification frameworks.

A dedicated specification is architecturally justified because:
1. **Mobile Execution Realities:** Unlike desktop workstations with continuous AC power and dedicated GPUs, mobile devices operate under severe thermal constraints, variable battery capacities, aggressive OS process lifecycle termination, and strict background execution limits.
2. **Cross-Cutting Capability Partitioning:** Local inference feasibility, voice processing, and hardware resource boundaries span multiple domains (Assistant, Models, Audio, Security, Performance). Unifying these mobile policies prevents fragmentation across desktop-centric domain specifications.
3. **Reference Integrity:** This document establishes the normative authority for all Batch C deliverables while preserving desktop-first PC V1 invariants.

---

## 2. C1: Local Mobile Inference & Hardware Capability Policy

### 2.1 Release Disposition: Capability-Dependent / Optional-Auxiliary
The foundational architecture question for Mobile V1 is resolved:
**Local Mobile inference is CAPABILITY-DEPENDENT and OPTIONAL-AUXILIARY for Mobile V1. It is NOT mandatory to run or use the Mobile Companion.**

#### 2.1.1 Architectural Rationale
1. **Core Product Usability Without Local LLM:** The essential productivity core of the Mobile Companion—viewing, creating, and modifying Tasks; receiving scheduled Reminders; triggering punctual, exact Alarms; viewing cached conversation history; and managing local device settings—functions 100% offline without any resident generative language model.
2. **Primary Delegation Model:** When network connectivity is present, the Mobile Companion delegates conversational turn execution to the PC Local AI Runtime (`CONNECTED_TO_PC`) over the authenticated local network or Tailscale mesh (`ADR-0019`).
3. **Optional Cloud Fallback:** When disconnected from the PC Host but internet access is available, the mobile client can optionally route conversational turns to external Cloud LLMs (`OPTIONAL_CLOUD`), provided the user has explicitly opted in and supplied their own provider API keys stored securely in the device Keystore.
4. **Offline Assistant Utility:** When disconnected from both PC and cloud, the conversational assistant is available **only if** the device meets the hardware capability tier, an approved mobile model artifact is installed, and device thermals/battery permit execution.
5. **Truthful Degradation Invariant:** If local inference is not supported by the hardware, not installed, or throttled due to resource pressure, the application MUST truthfully inform the user via the UI (e.g., *"Offline — Local Assistant model not installed. Connect to PC or configure Cloud API to chat; Tasks and Alarms remain fully active"*). The application must NEVER pretend to possess generative capability it cannot deliver, nor silently freeze the interface.

---

### 2.2 Semantic Hardware Capability Tiers

To avoid locking arbitrary retail price points or ephemeral chipset model numbers into canonical architecture, mobile hardware support is categorized into four **semantic capability tiers**:

| Capability Tier | Hardware Criteria (Indicative) | Local LLM Support | Offline Experience | Primary Inference Path |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 0: Unsupported / Low-Memory** | <4 GB total RAM, 32-bit architecture, or legacy SoC | **DISABLED / PROHIBITED** | Full offline Tasks, Alarms, Reminders, and cached data. Zero local generative inference. | `CONNECTED_TO_PC` (Host delegation) or `OPTIONAL_CLOUD`. |
| **Tier 1: Connected-Only / Constrained** | 4 GB RAM, low-end 64-bit SoC, or heavily thermal-constrained devices | **DISABLED BY DEFAULT** (Local LLM install locked to prevent OOM) | Full offline productivity. Viewing cached conversations. | `CONNECTED_TO_PC` or `OPTIONAL_CLOUD`. |
| **Tier 2: Local-Lite Capable** | 4 GB–8 GB total RAM, modern mid-tier 64-bit SoC (e.g. Dimensity 700/900 series, Snapdragon 6/7 series) | **SUPPORTED (Sub-1B Class)**: Ultra-compact models (e.g. 270M–800M parameter class, quantized Q4–Q8) | Full offline productivity + basic offline conversational assistance and local entity query. | `CONNECTED_TO_PC` primary; Local-Lite fallback when disconnected; `OPTIONAL_CLOUD` opt-in. |
| **Tier 3: Full-Local Capable** | $\ge$8 GB total RAM, high-end flagship SoC (e.g. Snapdragon 8 Gen series, Dimensity 9000 series, modern Apple A/M series) | **SUPPORTED (1B–3B Class)**: Compact models (e.g. 1B–3B parameter class, quantized Q4_K_M) | Full offline productivity + rich offline conversational assistance, summarization, and task extraction. | `CONNECTED_TO_PC` primary; Local model fallback when disconnected; `OPTIONAL_CLOUD` opt-in. |

#### 2.2.1 Empirical Research Context (Non-Canonical Evidence)
Preliminary exploratory tests conducted on an Infinix ZERO ULTRA (MediaTek Dimensity 920, 8 GB RAM, Android 13) utilizing PocketPal demonstrated empirical feasibility for sub-1B and 1B models:
- *Gemma 3 270M Q8:* Prompt processing $\approx$ 172.8 t/s, Generation $\approx$ 25.6 t/s, Resident RAM $\approx$ 754 MB.
- *Qwen 3.5 0.8B:* Prompt processing $\approx$ 62.5 t/s, Generation $\approx$ 14.8 t/s.
- *Llama 3.2 1B:* Prompt processing $\approx$ 42.9 t/s, Generation $\approx$ 12.4 t/s.
*Archival Caveat:* These empirical figures represent point-in-time exploratory research on a single device configuration. They serve as feasibility evidence that sub-1B and 1B models can achieve interactive speeds on mid-range hardware, but they do NOT constitute contractual throughput guarantees across all Android hardware.

---

### 2.3 Mobile-Local Model Lifecycle & D6 Mobile Adaptation

While PC workstations follow the Decision D6 import pipeline (`inbox` $\rightarrow$ `scan` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `library`), mobile platforms operate under Android Scoped Storage and sandboxing constraints. The mobile adaptation of D6 enforces the following rules:

1. **Model Acquisition & Distribution:**
   - *Host-to-Device Direct Transfer (Preferred):* When connected over LAN or Tailscale, the PC Host can package an approved, verified small-format model artifact and stream it directly to the Mobile Companion over the authenticated local connection.
   - *Curated In-App Download (Optional Post-V1):* User-initiated download of an approved, signed mobile model bundle from an official repository over HTTPS. Arbitrary URL downloads or unverified third-party sources are rejected.
   - *No Broad Storage Access:* Mobile Companion MUST NOT request `MANAGE_EXTERNAL_STORAGE` or scan arbitrary filesystem folders. Models reside strictly within app-specific internal or external files directories (`context.getExternalFilesDir("models")`).
2. **Cryptographic Integrity & Preflight:**
   - Before a downloaded or transferred model artifact is registered, its cryptographic hash (SHA-256) is verified against the signed manifest.
   - *Preflight Capacity Check:* Before loading, the mobile engine inspects current device available RAM (`ActivityManager.MemoryInfo.availMem`) and thermal status. If available memory is less than the model's declared resident budget plus a safety margin (minimum 500 MB headroom for OS/UI), the load operation is aborted with an informative diagnostic message.
3. **Single Resident Model Policy (`--models-max 1` Mobile Equivalent):**
   - At most **ONE** generative model may reside in mobile RAM at any given time.
   - Loading a local model automatically unloads any prior active model. Concurrent execution of multiple generative models on mobile is strictly prohibited.
4. **Resource-Pressure Lifecycle & Unloading:**
   - *Background Eviction:* When the companion app is moved to the background, resident model weights in memory MUST be suspended or completely unloaded to avoid trigger-happy OS process termination by the Android low-memory killer (LMK).
   - *Memory Trim Response:* Upon receiving `ComponentCallbacks2.onTrimMemory(TRIM_MEMORY_RUNNING_CRITICAL)` or `TRIM_MEMORY_RUNNING_LOW`, the runtime MUST immediately release the active model context and unload weights.
5. **Container & Engine Independence:**
   - The architecture accommodates mobile runtime backends such as `llama.cpp` JNI bindings, ONNX Runtime Mobile, or ExecuTorch. The canonical specification does NOT permanently freeze a single container format (such as GGUF) or vendor engine for all mobile eternity.

---

## 3. C2: Mobile Voice and Audio Architecture

Voice on Mobile requires distinct architectural partitioning from PC Desktop due to mobile audio hardware routing, phone call interruptions, audio focus protocols, and Android battery governance.

### 3.1 Hardware Ownership & Audio Focus Boundaries
- **Native Hardware Ownership:** The Flutter Mobile application (via native platform channels) owns local audio hardware enumeration, physical microphone capture, speaker/earpiece/Bluetooth playback routing, and Android Audio Focus management.
- **Audio Focus Protocols (`AudioManager`):**
  - *Short Voice Responses:* Request `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`.
  - *Interactive Conversational Voice Mode:* Request `AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE`.
  - *Incoming Call Interruption:* When the OS reports `AUDIOFOCUS_LOSS` or `AudioManager.ACTION_AUDIO_BECOMING_NOISY` (e.g., headset unplugged, incoming cellular call, active phone conversation):
    1. Audio playback is muted immediately ($\le 50\text{ ms}$).
    2. Microphone capture halts instantly.
    3. An interruption/pause frame is emitted to the server.
    4. The active conversational turn transitions cleanly to `INTERRUPTED`.
- **Bluetooth & Audio Routing:** Audio route changes (Bluetooth SCO / A2DP connect or disconnect) must be monitored dynamically. Disconnection of wireless earbuds during audio synthesis immediately pauses playback rather than blaring output over the external loudspeaker.

---

### 3.2 Voice Processing & Routing Modalities

```
                        +------------------------------------------+
                        |          Flutter Mobile Client           |
                        |   Audio Capture / Playback / VAD / Focus |
                        +--------------------+---------------------+
                                             |
                   +-------------------------+-------------------------+
                   |                                                   |
         [CONNECTED_TO_PC]                                     [OPTIONAL_CLOUD]
                   |                                                   |
                   v                                                   v
   +-------------------------------+                   +-------------------------------+
   |      PC Local AI Runtime      |                   |    Provider Cloud Gateway     |
   | (whisper.cpp STT / Kokoro TTS)|                   |   (User API Keys in Keystore) |
   +-------------------------------+                   +-------------------------------+
```

1. **Connected-to-PC Voice Mode (Primary):**
   - Uses a dedicated full-duplex **WebSocket connection** (`ADR-0019`) over the authenticated local transport.
   - Raw audio frames captured by the mobile microphone stream in real time to the PC Runtime.
   - The PC Runtime executes speech-to-text (`whisper.cpp` or equivalent CPU/RAM-first engine), feeds tokens to the language model, synthesizes audio via TTS (`Kokoro-82M` candidate), and streams audio buffers back to the phone for native playback.
2. **Optional Cloud Voice Routing:**
   - Supported only when the user explicitly enables Cloud Voice and provides personal API credentials.
   - *Permission Decoupling:* Cloud LLM, Cloud STT, and Cloud TTS are **three independently revocable permissions**. Enabling Cloud LLM does NOT authorize cloud audio streaming. Cloud audio transmission requires explicit separate consent.
3. **Offline Voice Capability:**
   - In Mobile V1, continuous heavy offline speech recognition (STT) and neural voice synthesis (TTS) are **DEFERRED / CAPABILITY-DEPENDENT**.
   - If disconnected from PC and without cloud credentials, Voice Mode truthfully degrades to typed text input with visual companion responses, displaying an explicit indicator: *"Voice streaming requires connection to PC Host or Cloud Voice setup"*. Mobile devices are not burdened with mandatory heavy local TTS/STT runtimes in V1.

---

### 3.3 Mandatory Mobile Barge-In Semantics
- **Zero-Latency Playback Interruption:** When the user begins speaking while companion voice output is actively playing:
  1. The local client immediately mutes speaker playback and discards all queued audio chunks locally.
  2. The client transmits an atomic `barge_in` cancellation frame over the WebSocket.
  3. The Host runtime immediately cancels downstream LLM token generation and TTS audio synthesis for that turn.
  4. The client initiates a fresh user speech capture buffer bound to a new turn ID.
- **Session Identity Isolation:** Audio buffers and playback frames carry `voice_session_id` and `turn_id`. Stale audio packets arriving after a barge-in event are dropped immediately by the client.

---

### 3.4 Background, Screen-Lock, and Foreground Service Boundaries
- **No Background Eavesdropping:** Continuous background microphone capture while the app is idle or closed is **STRICTLY PROHIBITED**.
- **No Always-On Wake Word in V1:** Wake-word detection on mobile is deferred to post-V1 (aligned with PC V1 Decision D1). Voice interactions require explicit user initiation (push-to-talk, tap-to-speak, or entering an explicit active Voice Session screen).
- **Active Session Screen-Lock Behavior:**
  - If the user explicitly initiates a hands-free conversational voice session and locks the screen (or switches to another app), the session MAY remain active **only** if backed by an explicit Android Foreground Service with type `FOREGROUND_SERVICE_TYPE_MICROPHONE` (`android.permission.FOREGROUND_SERVICE_MICROPHONE`).
  - *Notification Requirement:* The OS notification drawer MUST display an ongoing, prominent, non-dismissible notification stating: *"AI Companion Voice Session Active — Microphone in use"*, featuring a one-tap **"End Session"** action.
  - Terminating the session or pressing "End Session" immediately terminates the foreground service, releases the microphone, and revokes foreground execution.

---

### 3.5 Voice Privacy & Invariants
- **Voice is NOT Authentication:** Conversational voiceprints or acoustic characteristics must NEVER be used as an authentication or authorization factor (`ADR-0005`, `ADR-0018`).
- **Raw Audio is Ephemeral:** Raw user audio buffers captured on the device or received over the network are transient memory buffers. They MUST NOT be persisted to disk or flash storage by default. Once the turn transcription is finalized, the raw audio chunks are zeroed and discarded.
- **Transcript Ownership:** Only the final transcribed text becomes a permanent conversation turn message, owned strictly by the active `profile_id`.

---

## 4. C3: Health and Wearables Release Disposition

### 4.1 Formal Release Decision: `Mobile Later` (Deferred Post-V1)
In accordance with the PC V1 deferral in `docs/04_Architecture/03_Integrations/health-and-wearables.md`, the formal release disposition for Mobile V1 is:
**`Mobile Later` (Deferred Post-V1). Real Health Connect integration and wearable biometric sync are EXCLUDED from Mobile V1 release scope.**

#### 4.1.1 Prototype Sequestration & Non-Production Boundary
- **Current Prototype Status:** The existing Android codebase contains UI mock screens (`HealthScreen.kt`, `HealthViewModel.kt`) backed by synthetic profiles (`MockHealthDataProvider.kt`).
- **Production Boundary:**
  - The repository contains **zero** production Health Connect client code, zero `androidx.health.connect` dependencies, and zero health manifest permissions (`android.permission.health.*`).
  - For Mobile V1 production releases, all health UI routes, mock providers, and biometric screens MUST be sequestered as developer-only reference/demo code or disabled behind compile-time feature flags.
  - Production releases must not expose non-functional or mock health dashboards to end users.

#### 4.1.2 Permanent Non-Clinical & Privacy Invariants
Whenever health or biometric capabilities are designed in future phases, they MUST conform to the following non-negotiable principles:
1. **Absolute Non-Clinical Boundary:** The AI Companion is strictly an empathetic personal companion and productivity assistant. It makes **NO medical, clinical, or diagnostic claims**. It must never provide medical advice, diagnosis, triage, or clinical recommendations.
2. **Granular Per-Metric Consent:** Biometric ingestion requires explicit, informed user consent. Users must be able to grant or revoke access to individual metric categories (e.g. steps vs. heart rate vs. sleep) independently.
3. **No Automatic Cloud Egress:** Health and biometric context is strictly Profile-isolated local data. It MUST NEVER be transmitted to third-party Cloud LLMs or cloud endpoints without explicit, affirmative user authorization.
4. **Instant User Purge:** Users retain absolute authority to inspect, export, or permanently erase all collected biometric history on demand.

---

## 5. C4: Mobile Security and Privacy Threat Review

Mobile satellite endpoints introduce unique threat vectors beyond stationary PC workstations. The security model defines deterministic platform defenses categorized into `MUST`, `SHOULD`, and `OPTIONAL`.

### 5.1 Comprehensive Threat Matrix

| Threat Vector | Risk Scenario | Security Boundary & Mitigation | Classification |
| :--- | :--- | :--- | :--- |
| **Lost / Stolen Phone** | Device falls into unauthorized hands while locked or unlocked. | Rely on Android OS lock screen (PIN/Pattern/Biometrics) and File-Based Encryption (FBE). PC Host Admin can execute remote `DEVICE_REVOKED` outcome upon network contact. | **MUST** |
| **OS Auto-Backup Leakage** | Android Cloud Backup transmits app database, tokens, or private caches to Google Drive unencrypted. | Configure `dataExtractionRules` and `backup_rules.xml` to explicitly exclude credentials, database files, caches, and models (`<exclude domain="sharedpref" path="."/>`, `<exclude domain="database" path="."/>`). | **MUST** |
| **Credential Extraction** | Malware or backup inspection attempts to read device pairing token or third-party API keys. | Store all cryptographic secrets and API keys in **Android Keystore-backed secure storage** (EncryptedSharedPreferences or hardware Keystore wrapper). Plaintext storage is strictly prohibited. | **MUST** |
| **Direct Network Exposure** | User exposes mobile port to internet or uses public unencrypted Wi-Fi. | Enforce TLS/HTTPS application transport; use Tailscale encrypted mesh for remote connections. Direct port forwarding is permanently rejected. | **MUST** |
| **Intent / Deep Link Injection** | Malicious third-party apps dispatch crafted intents to trigger internal companion actions. | All internal Activities, Services, and BroadcastReceivers MUST set `android:exported="false"`. External deep links must use explicit signature permissions or strict input validation. | **MUST** |
| **Clipboard Snooping** | Background clipboard monitors steal copied sensitive tokens or message turns. | Sensitive tokens and credentials must never be automatically placed onto the system clipboard. If copied by user intent, mark payload as sensitive (`ClipDescription.EXTRA_IS_SENSITIVE`). | **SHOULD** |
| **Recent Apps Screen Leak** | Task switcher captures sensitive conversation text or personal data in screenshot previews. | Apply `WindowManager.LayoutParams.FLAG_SECURE` to sensitive chat and settings screens where configured by user privacy settings. | **SHOULD** |
| **Rooted / Compromised OS** | Superuser malware bypasses Android application sandbox (`MODE_PRIVATE`). | Acknowledge that local sandbox protection cannot resist root compromise. Emit security warning when root access is detected; do not claim unbreakable client integrity on rooted hardware. | **SHOULD** |
| **Full Database Encryption (At-Rest)** | Physical flash memory extraction from seized device. | Replicated domain entities reside in private sandbox SQLite (`MODE_PRIVATE`). SQLCipher full-disk DB encryption adds significant CPU/battery overhead; categorized as an optional enhancement for high-threat profiles. | **OPTIONAL / THREAT-DEPENDENT** |
| **Biometric Screen Lock** | Shared phone unlocked by family member accesses private companion Profile. | App-level biometric/PIN prompt (Android BiometricPrompt) to unlock app UI without invalidating host credentials. | **OPTIONAL** |

#### 5.2 Cryptographic Rule: Zero Custom Cryptography
The application MUST NOT implement proprietary or custom encryption algorithms. All cryptographic operations must utilize standard platform-supported primitives provided by the Android Jetpack Security libraries and the Android Keystore system (AES-256-GCM, RSA-OAEP, HMAC-SHA256).

---

## 6. C5: Performance, Battery, and Thermal Governance

Mobile devices must manage resource consumption truthfully and conservatively to avoid battery exhaustion, thermal throttling, and OS termination.

### 6.1 Android Background & Power Governance
- **Doze Mode & App Standby Compliance:**
  - The application MUST fully respect Android Doze mode and App Standby buckets.
  - Using continuous background WebSockets, permanent CPU wake locks, or background foreground services to bypass Doze is **STRICTLY PROHIBITED**.
  - All background data synchronization and outbox flushing MUST utilize `WorkManager` with network constraints (`NetworkType.CONNECTED`), allowing the OS to batch execution within battery-friendly maintenance windows.
- **Battery-Saver Mode (`PowerManager.isPowerSaveMode()`):**
  - When battery-saver mode is active on the device:
    1. Automatic background delta synchronization frequency is halved or deferred until charging.
    2. Local generative model pre-loading is disabled.
    3. Heavy UI animations and background particle effects are disabled.
    4. Voice interaction defaults to push-to-talk rather than continuous listening.

---

### 6.2 Thermal Monitoring & Adaptive Throttling
The mobile engine registers an active listener with `PowerManager.OnThermalStatusChangedListener` (Android 10+, API 29+):

```
+---------------------+---------------------------------------------------------------+
| THERMAL STATUS      | ARCHITECTURAL BEHAVIOR & THROTTLING ACTION                    |
+---------------------+---------------------------------------------------------------+
| THERMAL_STATUS_NONE | Normal operation. Standard inference context and UI fidelity. |
| THERMAL_STATUS_LIGHT| Normal operation. Log advisory telemetry.                     |
+---------------------+---------------------------------------------------------------+
| THERMAL_STATUS_MODERATE | Reduce local LLM context window by 50%. Defer background sync.|
|                     | Cap continuous generation tokens.                             |
+---------------------+---------------------------------------------------------------+
| THERMAL_STATUS_SEVERE   | HALT LOCAL INFERENCE IMMEDIATELY. Abort active generation.   |
|                     | Fallback to connected PC Host or Cloud LLM (if permitted).    |
|                     | Display truthful user notification: "Device hot — paused".    |
+---------------------+---------------------------------------------------------------+
| THERMAL_STATUS_CRITICAL | UNLOAD LOCAL MODEL FROM RAM. Terminate active Voice session.  |
| / EMERGENCY         | Release all non-essential hardware locks and foreground FGS.  |
+---------------------+---------------------------------------------------------------+
```

---

### 6.3 Memory Pressure & Low-Storage Safeguards
- **Memory Pressure (`ComponentCallbacks2.onTrimMemory`):**
  - `TRIM_MEMORY_RUNNING_LOW`: Clear image and media in-memory caches.
  - `TRIM_MEMORY_RUNNING_CRITICAL`: Instantly unload local LLM weights from memory.
  - If memory allocation fails during model initialization, the engine must catch `OutOfMemoryError` gracefully, reset engine state, and present a truthful UI fallback rather than crashing the app.
- **Storage Exhaustion:**
  - When device free storage falls below 500 MB:
    1. Model downloading or local import is blocked.
    2. Cached conversation attachments and temporary media files are automatically pruned.
    3. Outbox and essential SQLite database transactions are preserved.

---

## 7. C6: Testing and CI Architecture Boundary

### 7.1 Verification Matrix & Test Categories

Verification of the Mobile Companion is partitioned into four explicit testing layers:

| Test Layer | Execution Environment | Scope & Verification Targets | CI Automation Status |
| :--- | :--- | :--- | :--- |
| **L1: Unit & Domain Tests** | Host JVM / Dart VM (Headless) | Domain entity validation, outbox state machine, revision comparisons, conflict detection algorithms, JSON serialization, idempotency key generation. | Automated in standard headless CI. |
| **L2: Storage & Outbox Tests** | Headless / Robolectric / SQLite | SQLite migrations, transactional mutation journal rollback, outbox retry queuing, cursor pagination, mock Keystore adapter. | Automated in standard headless CI. |
| **L3: Platform Lifecycle Tests** | Android Emulator (API 34/35) | Activity recreation, process death restoration, `canScheduleExactAlarms()` revocation recovery, `ACTION_BOOT_COMPLETED` receiver alarm re-registration, notification permission prompt handling. | Automated in scheduled emulator matrix. |
| **L4: Hardware & Audio Tests** | Physical Android Hardware | Real audio focus during incoming phone calls, Bluetooth headset disconnect, exact alarm firing out of deep overnight Doze, sustained thermal throttling behavior under local inference load. | Manual / Hardware Golden verification pass. |
| **L5: Host Integration Tests** | Multi-Process / Local Network | Mobile client communicating with running PC Local AI Runtime FastAPI harness: delta cursor sync, `STALE_CURSOR` re-baseline, `DEVICE_REVOKED` wipe, SSE streaming resilience across disconnects. | Automated integration test suite. |

### 7.2 CI Boundary Rule
In accordance with project rules, **Batch C modifies ZERO existing CI workflow files** (`.github/workflows/`, `scripts/ci_policy.py`). The mobile testing architecture defines the verification contract for future mobile implementation tasks without destabilizing current PC V1 CI pipelines.

---

## 8. C7: Mobile Golden Acceptance Architecture

Analogous to the 14 Golden verification groups for PC V1, the Mobile Companion establishes **12 Mobile Golden Acceptance Groups (MG1 through MG12)** for release qualification:

- **MG1 — Enrollment & Identity:** Device pairing flow, revocable device token issuance, single-Profile binding enforcement, rejection of arbitrary profile assertions in request payloads.
- **MG2 — Platform Secure Storage & Transport:** Android Keystore storage of device token and provider API keys, zero plaintext storage in SharedPreferences, TLS/Tailscale transport security, rejection of direct port forwarding.
- **MG3 — Connected Host Operation:** Bidirectional communication with PC Local AI Runtime, REST turn submission, SSE token streaming, turn queue completion across transient client disconnects.
- **MG4 — Offline Durability & Outbox:** Fully functional offline Task creation, modification, and completion (`SET_COMPLETION`); durable outbox persistence surviving process death and OS reboot.
- **MG5 — Synchronization & Conflict Reconciliation:** Delta cursor synchronization, typed `CONFLICT_DETECTED` handling with user conflict presentation, typed `STALE_CURSOR` full re-baseline, retry idempotency deduplication (`mutation_id`).
- **MG6 — Punctual Offline Alarms & Reminders:** Alarm scheduling via `AlarmManager.setAlarmClock()`, precise ringing while device is in deep Doze, floating timezone recalculation, single-device duplicate firing suppression.
- **MG7 — System Lifecycle & Permission Resilience:** Alarm re-registration following `ACTION_BOOT_COMPLETED`, recovery when `SCHEDULE_EXACT_ALARM` or `POST_NOTIFICATIONS` is revoked, graceful degradation warnings.
- **MG8 — Voice Streaming & Audio Lifecycle:** Native mic capture, full-duplex WebSocket audio streaming to PC Host, real-time barge-in playback cancellation, immediate muting on incoming phone call (`AUDIOFOCUS_LOSS`).
- **MG9 — Mobile Inference & Hardware Tiers:** Truthful capability detection across hardware tiers (Tiers 0–3), clean UI degradation when unsupported, resident model memory budget enforcement, D6 mobile lifecycle integrity.
- **MG10 — Thermal, Battery & Power Governance:** WorkManager compliance with Doze maintenance windows, thermal throttling backoff under `THERMAL_STATUS_SEVERE`, graceful `onTrimMemory` model unloading without process crash.
- **MG11 — Security, Revocation & Privacy:** Authoritative `DEVICE_REVOKED` immediate local replica wipe, preservation of third-party user keys, backup exclusion verification, quarantine on `PROFILE_INACTIVE`, permanent wipe on `PROFILE_PURGED`.
- **MG12 — Cross-Device Consistency:** Independent device alarm ringing without premature cancellation by passive PC notifications; cross-device alarm dismissal synchronization upon explicit user dismissal.

---

## 9. C8: Cross-Domain Consistency Review

A comprehensive coherence check across Batch A, Batch B, and Batch C confirms complete alignment:

1. **Authority Model:** PC Host remains sole Account/Profile Administrator (`ADR-0018`). Mobile operates strictly as an enrolled Satellite bound to 1 Profile.
2. **Domain Synchronization:** Tasks, Reminders, and Alarms follow the asymmetric replication and revision rules established in `mobile-offline-and-sync.md`.
3. **Inference & Voice Decoupling:** Desktop PC V1 voice and model architectures (`voice-and-audio.md`, `runtime-and-models.md`) remain unaffected. Mobile client acts as an audio capture/playback edge node streaming over WebSocket.
4. **Health Integration:** Formally aligned with `health-and-wearables.md` as `Mobile Later` (Deferred Post-V1).
5. **No PC Code Regressions:** Zero changes to backend Python runtime, React web frontend, or Windows desktop code.
