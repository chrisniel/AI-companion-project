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
3. **Optional Cloud Fallback:** When disconnected from the PC Host but internet access is available, the mobile client can optionally route conversational turns to external Cloud LLMs (`OPTIONAL_CLOUD`), provided the user has explicitly opted in and supplied their own provider API keys stored securely in platform-protected device storage.
4. **Offline Assistant Utility:** When disconnected from both PC and cloud, the conversational assistant is available **only if** the device meets evidence-based runtime qualification, an approved mobile model artifact is installed, and device thermals/battery permit execution.
5. **Truthful Degradation Invariant:** If local inference is not supported by the hardware, not installed, or throttled due to resource pressure, the application MUST truthfully inform the user via the UI (e.g., *"Offline — Local Assistant model not installed. Connect to PC or configure Cloud API to chat; Tasks and Alarms remain fully active"*). The application must NEVER pretend to possess generative capability it cannot deliver, nor silently freeze the interface.

---

### 2.2 Evidence-Driven Hardware Capability Qualification

To avoid locking arbitrary retail price points, ephemeral chipset model numbers, or rigid unproven RAM thresholds into canonical architecture, mobile hardware qualification is governed primarily through **measured runtime preflight evidence**:

1. **Supported ABI & Execution Backend:** Device provides a supported 64-bit ABI (e.g., ARM64-v8a / v9a) and supported execution runtime runtime/acceleration libraries.
2. **Compatible Model Artifact:** A verified, compatible mobile model artifact matching runtime capabilities is installed.
3. **Available Memory & Safety Reserve:** Currently available system memory (`ActivityManager.MemoryInfo.availMem`) meets the model's declared resident working set plus a measured, configurable safety reserve ensuring adequate headroom for the host OS and companion UI.
4. **Successful Preflight & Load:** Model initialization and warmup complete cleanly without memory allocation failures (`OutOfMemoryError`) or system memory warnings (`MemoryInfo.lowMemory`).
5. **Acceptable Sustained Responsiveness:** Generation maintains interactive responsiveness without causing UI thread jank or frame drops.
6. **Acceptable Thermal State:** Device thermal status remains below throttling limits (`THERMAL_STATUS_NONE` or `LIGHT`).
7. **Sufficient Storage Reserve:** Local storage accommodates model weights plus a verified safety margin for database and outbox transactions.
8. **No Critical OS Resource Pressure:** System is not under severe background memory reclamation or power-saver suppression.

#### 2.2.1 Semantic Capability Tiers

The architecture defines four **non-overlapping semantic capability tiers** based on runtime qualification levels rather than rigid commercial hardware brackets:

| Capability Tier | Qualification Level | Local LLM Support | Offline Experience | Primary Inference Path |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 0: Unsupported / Non-Inference Endpoint** | Lacks supported 64-bit ABI, compatible runtime execution libraries, or minimum memory architecture to host local models. | **DISABLED / PROHIBITED** | Full offline Tasks, Alarms, Reminders, and cached data. Zero local generative inference. | `CONNECTED_TO_PC` (Host delegation) or `OPTIONAL_CLOUD`. |
| **Tier 1: Connected-Only / Resource-Constrained** | Meets base OS/ABI requirements but cannot sustain reliable local model execution alongside active system services without triggering memory/thermal eviction. | **DISABLED BY DEFAULT** (Local LLM install locked to prevent system instability) | Full offline productivity. Viewing cached conversations. | `CONNECTED_TO_PC` or `OPTIONAL_CLOUD`. |
| **Tier 2: Local-Lite Qualified** | Demonstrably satisfies runtime preflight for an ultra-compact model artifact while maintaining a validated memory safety reserve and acceptable responsiveness without thermal degradation. | **QUALIFIED (Ultra-Compact Class)** | Full offline productivity + basic offline conversational assistance and local entity queries. | `CONNECTED_TO_PC` primary; Local-Lite fallback when disconnected; `OPTIONAL_CLOUD` opt-in. |
| **Tier 3: Full-Local Qualified** | Demonstrably satisfies preflight for standard compact mobile models, possessing substantial measured memory headroom, sustained compute throughput, and thermal resilience. | **QUALIFIED (Compact Mobile Class)** | Full offline productivity + advanced offline conversational assistance, summarization, and task extraction. | `CONNECTED_TO_PC` primary; Local model fallback when disconnected; `OPTIONAL_CLOUD` opt-in. |

#### 2.2.2 Non-Canonical Research Context (Provisional Evidence Only)
Exploratory tests conducted on an Infinix ZERO ULTRA (MediaTek Dimensity 920, 8 GB RAM, Android 13) utilizing PocketPal demonstrated provisional feasibility for sub-1B and 1B models:
- *Gemma 3 270M Q8:* Prompt processing $\approx$ 172.8 t/s, Generation $\approx$ 25.6 t/s, Resident RAM $\approx$ 754 MB.
- *Qwen 3.5 0.8B:* Prompt processing $\approx$ 62.5 t/s, Generation $\approx$ 14.8 t/s.
- *Llama 3.2 1B:* Prompt processing $\approx$ 42.9 t/s, Generation $\approx$ 12.4 t/s.
*Archival Caveat:* These empirical figures represent point-in-time exploratory research on a single device configuration. They serve as feasibility evidence that sub-1B and 1B models can achieve interactive speeds on mid-range hardware, but parameter counts, quantization formats, and chipset names are non-canonical research examples. They do NOT constitute contractual throughput guarantees across Android hardware.

---

### 2.3 Mobile-Local Model Lifecycle & D6 Mobile Adaptation

While PC workstations follow the Decision D6 import pipeline (`inbox` $\rightarrow$ `scan` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `library`), mobile platforms operate under Android Scoped Storage and sandboxing constraints. The mobile adaptation of D6 enforces the following rules:

1. **Model Acquisition & Distribution:**
   - *Host-to-Device Direct Transfer (Preferred LAN Path):* When connected over LAN or Tailscale, the PC Host can package an approved, verified small-format model artifact and stream it directly to the Mobile Companion over the authenticated local connection.
   - *Curated In-App Download (Optional Post-V1):* User-initiated download of an approved, signed mobile model bundle from an official repository over HTTPS. Arbitrary URL downloads or unverified third-party sources are rejected.
   - *No Broad Storage Access:* Mobile Companion MUST NOT request `MANAGE_EXTERNAL_STORAGE` or scan arbitrary filesystem folders. Models reside strictly within app-specific internal or external files directories (`context.getExternalFilesDir("models")`).
2. **Cryptographic Integrity & Preflight:**
   - Before a downloaded or transferred model artifact is registered, its cryptographic hash (SHA-256) is verified against the signed manifest.
   - *Preflight Capacity Check:* Before loading, the mobile engine inspects current device available RAM (`ActivityManager.MemoryInfo.availMem`) and thermal status. Available memory must meet the model's declared resident working set plus a measured, configurable safety reserve ensuring adequate headroom for the host OS and companion UI. If insufficient, the load operation aborts with an informative diagnostic message.
3. **Single Resident Model Policy (`--models-max 1` Mobile Equivalent):**
   - At most **ONE** generative model may reside in mobile RAM at any given time.
   - Loading a local model automatically unloads any prior active model. Concurrent execution of multiple generative models on mobile is strictly prohibited.
4. **Model Resource & Process Lifecycle:**
   - *Background Release/Suspension:* Backgrounding the application with no active approved user-visible operation may release or suspend expensive model resources to prevent premature process termination by the Android low-memory killer (LMK).
   - *Active Operations:* Explicitly user-initiated active operations (such as an approved active Voice foreground session) follow their approved execution lifecycle.
   - *Resource Pressure Triggers:* High memory pressure, elevated thermal state, OS process lifecycle constraints, or user battery policies may force model unloading.
   - *Process Death Resilience:* OS process termination by the Android platform must always be tolerated safely; transient model state is reconstructed cleanly on subsequent launch.
5. **Container & Engine Independence:**
   - The architecture accommodates mobile runtime backends such as `llama.cpp` JNI bindings, ONNX Runtime Mobile, or ExecuTorch. The canonical specification does NOT permanently freeze a single container format (such as GGUF) or vendor engine for all mobile eternity.

---

## 3. C2: Mobile Voice and Audio Architecture

Voice on Mobile requires distinct architectural partitioning from PC Desktop due to mobile audio hardware routing, phone call interruptions, audio focus protocols, and Android battery governance.

### 3.1 Hardware Ownership & Audio Focus Boundaries
- **Native Hardware Ownership:** The Flutter Mobile application (via native platform channels) owns local audio hardware enumeration, physical microphone capture, speaker/earpiece/Bluetooth playback routing, and Android Audio Focus management.
- **Canonical Speech & Turn Authority:** When connected to the PC Host, the **PC Local AI Runtime remains the canonical authority** for Voice session orchestration, Speech-to-Text (STT), Text-to-Speech (TTS), and Voice Activity Detection (VAD). Flutter Mobile does NOT replace canonical Runtime VAD authority. (A lightweight client-side speech-activity hint MAY be used on the client for immediate local muting responsiveness during barge-in, but canonical turn-taking remains host-managed).
- **Audio Focus & Route Interruption Protocols (`AudioManager`):**
  - *Short Voice Responses:* Request `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`.
  - *Interactive Conversational Voice Mode:* Request `AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE`.
  - *Audio-Focus Loss (Competing Audio / Incoming Phone Call):* When the OS reports `AUDIOFOCUS_LOSS` (e.g. incoming cellular call, active phone conversation, competing media app):
    1. Audio playback is muted and capture halted immediately on the client before awaiting network cancellation.
    2. An interruption frame is emitted to the server.
    3. The active conversational turn transitions cleanly to `INTERRUPTED`.
  - *Output Route Becoming Unsafe (`ACTION_AUDIO_BECOMING_NOISY`):* Delivered when a wired headset or Bluetooth A2DP audio output disconnects. The client immediately pauses audio playback locally to prevent unintended audio blaring over external device loudspeakers.
- **Bluetooth Dynamic Routing:** Audio route changes (Bluetooth SCO / BLE headset connect or disconnect) are monitored dynamically; unexpected headset disconnect immediately pauses playback.

---

### 3.2 Voice Processing & Routing Modalities

```
                        +------------------------------------------+
                        |          Flutter Mobile Client           |
                        | Capture / Playback / Audio Focus / Hints |
                        +--------------------+---------------------+
                                             |
                   +-------------------------+-------------------------+
                   |                                                   |
         [CONNECTED_TO_PC]                                     [OPTIONAL_CLOUD]
                   |                                                   |
                   v                                                   v
   +-------------------------------+                   +-------------------------------+
   |      PC Local AI Runtime      |                   |    Provider Cloud Gateway     |
   | (Canonical STT / TTS / VAD)   |                   |  (User API Keys in Keystore)  |
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

### 3.3 Immediate Local Playback Interruption (Low-Latency Barge-In)
- **Immediate Local Muting:** When user speech is detected during companion voice playback:
  1. The mobile client immediately mutes local audio playback and discards queued audio chunks locally, without waiting for network roundtrip confirmation.
  2. The client transmits an atomic `barge_in` cancellation frame over the WebSocket.
  3. The Host runtime immediately cancels downstream LLM token generation and TTS audio synthesis for that turn.
  4. The client initiates a fresh user speech capture buffer bound to a new turn ID.
- **Latency Target:** Muting and playback cancellation occur locally prior to network acknowledgment; measurable low-latency acceptance targets are determined during implementation testing.
- **Session Identity Isolation:** Audio buffers and playback frames carry `voice_session_id` and `turn_id`. Stale audio packets arriving after a barge-in event are dropped immediately by the client.

---

### 3.4 Background, Screen-Lock, and Foreground Service Boundaries
- **No Background Eavesdropping:** Continuous background microphone capture while the app is idle or closed is **STRICTLY PROHIBITED**.
- **No Always-On Wake Word in V1:** Wake-word detection on mobile is deferred to post-V1 (aligned with PC V1 Decision D1). Voice interactions require explicit user initiation (push-to-talk, tap-to-speak, or entering an explicit active Voice Session screen).
- **Active Session Screen-Lock & Foreground Execution (FGS):**
  - Microphone access on modern Android is a while-in-use permission (`RECORD_AUDIO`). On Android 14+ (API 34+), microphone foreground services (`FOREGROUND_SERVICE_TYPE_MICROPHONE`) generally MUST be initiated while the application has an active, visible activity in the foreground.
  - Background code cannot arbitrarily initiate microphone capture. Voice sessions originate strictly from visible, intentional user interaction.
  - If the user explicitly starts a conversational voice session and subsequently locks the screen or switches tasks, the session MAY continue under an explicit Android Foreground Service (`android.permission.FOREGROUND_SERVICE_MICROPHONE`).
  - *User-Visible Indication:* The OS notification drawer displays an ongoing, prominent user notification indicating active microphone use and featuring an explicit **"End Session"** action control.
  - Ending the session immediately terminates the foreground service, releases the microphone hardware, and revokes foreground execution.

---

### 3.5 Voice Privacy & Invariants
- **Voice is NOT Authentication:** Conversational voiceprints or acoustic characteristics must NEVER be used as an authentication or authorization factor (`ADR-0005`, `ADR-0018`).
- **Raw Audio is Transient:** Raw user audio buffers captured on the device or received over the network are transient memory buffers. They are never intentionally persisted to disk by default. Application-level buffers and memory references are promptly released and eligible for memory reclamation after processing. Debug audio recording requires separate, explicit developer opt-in if ever implemented.
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
4. **Purge Rights Over Retained Copies:** Users retain absolute authority to inspect, export, or permanently erase all Companion-retained/synchronized health copies on demand. (The Companion does not claim automatic deletion authority over external source records residing in Android Health Connect unless created by the Companion and explicitly authorized by future architecture).

---

## 5. C4: Mobile Security and Privacy Threat Review

Mobile satellite endpoints introduce unique threat vectors beyond stationary PC workstations. The security model defines deterministic platform defenses categorized into `MUST`, `SHOULD`, and `OPTIONAL`.

### 5.1 Comprehensive Threat Matrix

| Threat Vector | Risk Scenario | Security Boundary & Mitigation | Classification |
| :--- | :--- | :--- | :--- |
| **Lost / Stolen Phone** | Device falls into unauthorized hands while locked or unlocked. | Rely on Android OS lock screen (PIN/Pattern/Biometrics) and File-Based Encryption (FBE). PC Host Admin can execute remote `DEVICE_REVOKED` outcome upon network contact. | **MUST** |
| **OS Backup Leakage** | Android Backup transmits device-bound credentials or private profile data off-device. | Configure `dataExtractionRules` and `backup_rules.xml` to explicitly exclude credentials, database files, caches, and models from cloud backups and device transfers as appropriate (`<exclude domain="sharedpref" path="."/>`, `<exclude domain="database" path="."/>`). | **MUST** |
| **Credential Extraction** | Malware or inspection attempts to extract device pairing tokens or user API keys. | Store cryptographic secrets and API keys in **supported Android platform-protected secure storage backed by Android Keystore**. Plaintext storage is strictly prohibited. | **MUST** |
| **Direct Network Exposure** | User exposes mobile port to internet or uses public untrusted network. | Require application authentication for all endpoints; require protected transport (TLS/HTTPS or approved encrypted overlay such as Tailscale) for non-loopback traffic. Direct port forwarding is permanently rejected. | **MUST** |
| **Intent / Deep Link Injection** | Malicious third-party apps dispatch crafted intents to trigger internal companion actions. | All internal Activities, Services, and BroadcastReceivers MUST set `android:exported="false"`. External deep links must use explicit signature permissions or strict input validation. | **MUST** |
| **Clipboard Snooping** | Background clipboard monitors steal copied sensitive tokens or message turns. | Sensitive tokens and credentials must never be automatically placed onto the system clipboard. If copied by user intent, mark payload as sensitive (`ClipDescription.EXTRA_IS_SENSITIVE`). | **SHOULD** |
| **Recent Apps Screen Leak** | Task switcher captures sensitive conversation text or personal data in screenshot previews. | Apply `WindowManager.LayoutParams.FLAG_SECURE` to sensitive chat and settings screens where configured by user privacy settings. | **SHOULD** |
| **Rooted / Compromised OS** | Superuser malware bypasses Android application sandbox (`MODE_PRIVATE`). | Acknowledge that local sandbox protection cannot resist root compromise. Emit security warning when root access is detected; do not claim unbreakable client integrity on rooted hardware. | **SHOULD** |
| **Full Database Encryption (At-Rest)** | Physical flash memory extraction from seized device. | Replicated domain entities reside in private sandbox SQLite (`MODE_PRIVATE`). SQLCipher full-disk DB encryption adds significant CPU/battery overhead; categorized as an optional enhancement for high-threat profiles. | **OPTIONAL / THREAT-DEPENDENT** |
| **Biometric Screen Lock** | Shared phone unlocked by family member accesses private companion Profile. | App-level biometric/PIN prompt (Android BiometricPrompt) to unlock app UI without invalidating host credentials. | **OPTIONAL** |

#### 5.2 Cryptographic Rule: Zero Custom Cryptography
The application MUST NOT implement proprietary or custom encryption algorithms. All cryptographic operations must utilize current supported Android platform cryptographic APIs, the Android Keystore system (AES-256-GCM, RSA-OAEP, HMAC-SHA256), and vetted maintained libraries where needed.

### 5.3 Device Credential Rotation Architecture Semantics
In alignment with [`MOBILE_SYSTEM_BASELINE.md`](../MOBILE_SYSTEM_BASELINE.md) (§4.3) and [`mobile-offline-and-sync.md`](./mobile-offline-and-sync.md) (§7):
1. **Independent Credential Rotation:** An independently enrolled Device credential may expire or be rotated/reissued without altering the Device's bound Profile identity.
2. **Non-Destructive Expiration:** When the Host reports a typed outcome of `CREDENTIAL_EXPIRED` or `ROTATION_REQUIRED`, the Mobile client MUST pause active synchronization and prompt the user to re-authenticate or refresh credentials. It MUST NOT execute destructive local data erasure or destroy replicated Profile domain data.
3. **Implementation Design Open:** Exact token formats, cryptographic rotation handshakes, refresh-token overlap/grace windows, and automated re-enrollment flows remain open design for future mobile implementation planning.

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
    1. Defer or reduce non-essential background synchronization work.
    2. Disable local generative model pre-loading.
    3. Disable non-essential UI animations and background particle effects.
    4. Voice interaction defaults to explicit push-to-talk rather than continuous listening.

---

### 6.2 Thermal Escalation Policy
The mobile engine registers an active listener with `PowerManager.OnThermalStatusChangedListener` (Android 10+, API 29+), enforcing an adaptive escalation policy:

1. **`THERMAL_STATUS_NONE` / `LIGHT` (Normal):** Normal operation. Standard configured inference context and UI fidelity.
2. **`THERMAL_STATUS_MODERATE` (Early Thermal Pressure):** Adaptive workload reduction based on measured device behavior (e.g. reduce inference context size, defer non-essential background sync).
3. **`THERMAL_STATUS_SEVERE` (Sustained Severe Thermal Pressure):** Pause or stop local generative inference as necessary; display truthful user notification (*"Device hot — local assistant paused"*); route to connected PC Host or Cloud LLM ONLY IF separately configured and authorized by user.
4. **`THERMAL_STATUS_CRITICAL` / `EMERGENCY` (Hardware Protection):** Unload expensive model resources from RAM; terminate active Voice sessions; release non-essential hardware locks and foreground execution; preserve core non-generative Mobile functions (Tasks, Alarms).

*Tuning Rule:* Exact numerical thresholds and adaptive context scaling belong to implementation benchmarking and device profiling, not hardcoded canonical constants.

---

### 6.3 Memory Pressure & Low-Storage Safeguards
- **Memory Pressure Governance:**
  - Monitor supported modern Android architecture signals: `ComponentCallbacks2.onTrimMemory` background and visibility states (`TRIM_MEMORY_UI_HIDDEN`, `TRIM_MEMORY_BACKGROUND`, `TRIM_MEMORY_COMPLETE`), `ActivityManager.MemoryInfo.lowMemory` / memory thresholds, and current process memory state. (Deprecated running-trim levels like `TRIM_MEMORY_RUNNING_CRITICAL` are not relied upon).
  - When memory pressure signals are received, clear ephemeral image/media caches and release or suspend expensive resident model allocations as appropriate.
  - Catch `OutOfMemoryError` gracefully during model operations, resetting engine state and presenting a truthful UI fallback rather than crashing the process.
- **Storage Safeguards:**
  - Storage preflight checks must verify available storage against required model artifact sizes plus a safety reserve for database and outbox transactions.
  - When storage becomes severely constrained, block new model downloads and prune cached conversation attachments while preserving essential SQLite database and outbox mutations.

---

## 7. C6: Testing and CI Architecture Boundary

### 7.1 Five-Layer Verification Matrix

Verification of the Mobile Companion is partitioned into **five explicit testing layers (L1 through L5)**:

| Test Layer | Execution Environment | Scope & Verification Targets | Target CI Automation Intent |
| :--- | :--- | :--- | :--- |
| **L1: Unit & Domain Tests** | Host JVM / Dart VM (Headless) | Domain entity validation, outbox state machine, revision comparisons, conflict detection algorithms, JSON serialization, idempotency key generation. | FUTURE AUTOMATED (Headless CI) |
| **L2: Storage & Outbox Tests** | Headless / Robolectric / SQLite | SQLite migrations, transactional mutation journal rollback, outbox retry queuing, cursor pagination, mock Keystore adapter. | FUTURE AUTOMATED (Headless CI / Robolectric) |
| **L3: Platform Lifecycle Tests** | Android Emulator (API 34/35) | Activity recreation, process death restoration, `canScheduleExactAlarms()` revocation recovery, `ACTION_BOOT_COMPLETED` receiver alarm re-registration, notification permission prompt handling. | FUTURE EMULATOR AUTOMATION (Scheduled emulator matrix) |
| **L4: Hardware & Audio Tests** | Physical Android Hardware | Real audio focus during incoming phone calls, Bluetooth headset disconnect, exact alarm firing out of deep overnight Doze, sustained thermal throttling behavior under local inference load. | PHYSICAL DEVICE / MANUAL GOLDEN (Physical hardware pass) |
| **L5: Host Integration Tests** | Multi-Process / Local Network | Mobile client communicating with running PC Local AI Runtime FastAPI harness: delta cursor sync, `STALE_CURSOR` re-baseline, `DEVICE_REVOKED` wipe, SSE streaming resilience across disconnects. | FUTURE INTEGRATION AUTOMATION (Integration harness) |

### 7.2 CI Boundary Rule
In accordance with project rules, **Batch C modifies ZERO existing CI workflow files** (`.github/workflows/`, `scripts/ci_policy.py`). The mobile testing architecture defines the verification contract for future mobile implementation tasks without destabilizing current PC V1 CI pipelines.

---

## 8. C7: Mobile Golden Acceptance Architecture

Analogous to the 14 Golden verification groups for PC V1, the Mobile Companion establishes **12 Mobile Golden Acceptance Groups (MG1 through MG12)** for release qualification:

- **MG1 — Enrollment & Identity:** Device pairing flow, revocable device token issuance, single-Profile binding enforcement, rejection of arbitrary profile assertions in request payloads.
- **MG2 — Platform Secure Storage & Transport:** Android Keystore protection for device token and provider API keys, zero plaintext storage, protected transport via TLS/HTTPS or approved encrypted overlay (Tailscale), rejection of direct port forwarding.
- **MG3 — Connected Host Operation:** Bidirectional communication with PC Local AI Runtime, REST turn submission, SSE token streaming, turn queue completion across transient client disconnects.
- **MG4 — Offline Durability & Outbox:** Fully functional offline Task creation, modification, and completion (`SET_COMPLETION`); durable outbox persistence surviving process death and OS reboot.
- **MG5 — Synchronization & Conflict Reconciliation:** Delta cursor synchronization, typed `CONFLICT_DETECTED` handling with user conflict presentation, typed `STALE_CURSOR` full re-baseline, retry idempotency deduplication (`mutation_id`).
- **MG6 — Punctual Offline Alarms & Reminders:** Alarm scheduling via `AlarmManager.setAlarmClock()`, precise ringing while device is in deep Doze conditional on exact-alarm capability/access, floating timezone recalculation, single-device duplicate firing suppression, and graceful degraded indication when exact alarm access is unavailable.
- **MG7 — System Lifecycle & Permission Resilience:** Alarm re-registration following `ACTION_BOOT_COMPLETED`, recovery when `SCHEDULE_EXACT_ALARM` or `POST_NOTIFICATIONS` is revoked, graceful degradation warnings.
- **MG8 — Voice Streaming & Audio Lifecycle:** Native mic capture, full-duplex WebSocket audio streaming to PC Host, immediate local barge-in playback muting, immediate muting on competing audio focus loss (`AUDIOFOCUS_LOSS`), pausing on unsafe route changes (`ACTION_AUDIO_BECOMING_NOISY`).
- **MG9 — Mobile Inference & Hardware Tiers:** Capability detection across Tiers 0–3 based on runtime preflight evidence, clean UI degradation when unsupported, resident model memory budget enforcement, D6 mobile lifecycle integrity.
- **MG10 — Thermal, Battery & Power Governance:** WorkManager compliance with Doze maintenance windows, thermal throttling backoff under severe thermal state, graceful model unloading under modern `onTrimMemory` and memory pressure signals without process crash.
- **MG11 — Security, Revocation & Privacy:** Authoritative discovery of `DEVICE_REVOKED` triggering local revocation cleanup, preservation of third-party user keys, backup exclusion verification, quarantine on `PROFILE_INACTIVE`, permanent wipe on `PROFILE_PURGED`.
- **MG12 — Cross-Device Consistency:** Independent device alarm ringing without premature cancellation by passive PC notifications; cross-device alarm dismissal synchronization upon explicit user dismissal.

---

## 9. C8: Cross-Domain Consistency Review

A comprehensive coherence check across Batch A, Batch B, and Batch C confirms complete alignment:

1. **Authority Model:** PC Host remains sole Account/Profile Administrator (`ADR-0018`). Mobile operates strictly as an enrolled Satellite bound to 1 Profile.
2. **Domain Synchronization:** Tasks, Reminders, and Alarms follow the asymmetric replication and revision rules established in `mobile-offline-and-sync.md`.
3. **Inference & Voice Decoupling:** Desktop PC V1 voice and model architectures (`voice-and-audio.md`, `runtime-and-models.md`) remain unaffected. Mobile client acts as an audio capture/playback edge node streaming over WebSocket to PC Runtime.
4. **Health Integration:** Formally aligned with `health-and-wearables.md` as `Mobile Later` (Deferred Post-V1).
5. **No PC Code Regressions:** Zero changes to backend Python runtime, React web frontend, or Windows desktop code.
