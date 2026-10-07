# Mobile Capabilities, Inference, Voice, and Verification Architecture

> **Document Role:** Canonical infrastructure and behavior specification for Mobile Companion hardware capabilities, local inference policy, voice architecture, security boundaries, and release verification.
> **Status:** Active Canonical
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

### 2.1 Release Disposition: Production Local LLM Path on Qualified Hardware
In accordance with Decision `D-PHONE-01`:
**Mobile V1 product implementation includes a real production-capable device-local LLM execution path for qualified devices.**

#### 2.1.1 Architectural Principles & Boundaries
1. **Production Path on Qualified Hardware (`D-PHONE-01`):** Local generative LLM inference is an approved Mobile V1 product capability, not a speculative research experiment or auxiliary afterthought.
2. **Individual Device Qualification (`D-PHONE-01`, `D-PHONE-03`):** Not every supported mobile phone must qualify. Local LLM capability is enabled dynamically based on measured runtime preflight qualification.
3. **Core Companion Survival Without Generative AI (`D-PHONE-02`):** The essential productivity core of the Mobile Companion—viewing, creating, and modifying Tasks; receiving scheduled Reminders; triggering punctual, exact Alarms; bounded Routine occurrence presentation; viewing cached conversations; managing local settings; and interacting with the companion presence shell—survives 100% offline without any resident generative language model.
4. **Orthogonal Availability Dimensions (`D-PHONE-01A`):** PC Host reachability, internet connectivity, and inference routing are strictly orthogonal state dimensions. Standalone Mobile (`STANDALONE_MOBILE`) is an ordinary operational state, never an application error.
5. **Inference Delegation Routes:**
   - *Connected to PC (`CONNECTED_TO_PC`):* When the PC Host is reachable over LAN or Tailscale, the client delegates heavy turn execution to the PC Local AI Runtime.
   - *Standalone Mobile with Qualified Local LLM:* When disconnected from the PC Host, qualified devices execute turns locally using their resident on-device model.
   - *Optional Cloud Fallback (`OPTIONAL_CLOUD`):* Disconnected mobile clients with internet access may optionally route turns to external Cloud LLMs only when the user has explicitly opted in and supplied their own credentials. Internet access does not imply Cloud LLM authorization (`D-PHONE-13C`).
   - *Limited Non-Generative Offline:* When disconnected and lacking a qualified or resident local model, the assistant interface truthfully informs the user while preserving all core non-generative features.
6. **Truthful Degradation Invariant:** The application MUST truthfully report active capabilities, requested vs. actual execution backend, model residency, and resource state. It must NEVER pretend to possess generative capability it cannot deliver, nor silently freeze the interface.

---

### 2.2 Evidence-Driven Hardware Capability Qualification

To avoid locking arbitrary retail price points, ephemeral chipset model numbers, or rigid unproven RAM thresholds into canonical architecture, mobile hardware qualification is governed primarily through **measured runtime preflight evidence**:

1. **Supported ABI & Execution Backend:** Device provides a supported 64-bit ABI (e.g., ARM64-v8a / v9a) and supported execution runtime runtime/acceleration libraries.
2. **Compatible Model Artifact:** A verified, compatible mobile model artifact matching runtime capabilities is installed.
3. **Available Memory & Safety Reserve:** Currently available system memory (`ActivityManager.MemoryInfo.availMem`) meets the model's declared resident working set plus a measured, configurable safety reserve ensuring adequate headroom for the host OS and companion UI.
4. **Successful Preflight & Load:** Model initialization and warmup complete cleanly without memory allocation failures (`OutOfMemoryError`) or system memory warnings (`MemoryInfo.lowMemory`).
5. **Acceptable Sustained Responsiveness:** Generation maintains interactive responsiveness without causing UI thread jank or frame drops.
6. **Acceptable Sustained Thermal Stability:** The device must demonstrate acceptable sustained thermal stability without unacceptable throttling under the qualified runtime workload. Exact Android thermal-status thresholds and qualification cutoffs remain implementation/benchmark open.
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
Empirical tests conducted on a reference hardware baseline (**Reference Android Device A: Android 13, ARM64, 8 GB physical RAM, mid-range mobile SoC class**) utilizing standalone mobile inference engines demonstrated provisional feasibility for sub-1B and 1B class models:
- *Gemma 3 270M Q8:* Prompt processing $\approx$ 172.8 t/s, Generation $\approx$ 25.6 t/s, Resident RAM $\approx$ 754 MB.
- *Qwen 3.5 0.8B:* Prompt processing $\approx$ 62.5 t/s, Generation $\approx$ 14.8 t/s.
- *Llama 3.2 1B:* Prompt processing $\approx$ 42.9 t/s, Generation $\approx$ 12.4 t/s.
*Archival Caveat:* These empirical figures represent point-in-time exploratory research recorded in [`docs/00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md`](../../00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md). They serve as non-canonical empirical feasibility evidence that sub-1B and 1B models can achieve interactive speeds on mid-range hardware. Parameter counts, quantization formats, and candidate model names are non-canonical research examples. They do NOT constitute contractual throughput guarantees or permanent architectural dependencies.

---

### 2.3 Mobile-Local Model Lifecycle & D6 Mobile Adaptation

While PC workstations follow the Decision D6 import pipeline (`inbox` $\rightarrow$ `scan` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `library`), mobile platforms operate under Android Scoped Storage and sandboxing constraints. The mobile adaptation of D6 enforces the following rules in accordance with `D-PHONE-05`:

1. **Model Acquisition & Distribution:**
   - *Host-to-Device Direct Transfer (Preferred LAN Path):* When connected over LAN or Tailscale, the PC Host can package an approved, verified small-format model artifact and stream it directly to the Mobile Companion over the authenticated local connection.
   - *Curated In-App Download (Optional Post-V1):* User-initiated download of an approved, signed mobile model bundle from an official repository over HTTPS. Arbitrary URL downloads or unverified third-party sources are rejected.
   - *No Broad Storage Access:* Mobile Companion MUST NOT request `MANAGE_EXTERNAL_STORAGE` or scan arbitrary filesystem folders. Models reside strictly within app-specific internal or external files directories (`context.getExternalFilesDir("models")`).
2. **Cryptographic Integrity & Preflight:**
   - Before a downloaded or transferred model artifact is registered, its cryptographic hash (SHA-256) is verified against the signed manifest.
   - *Preflight Capacity Check:* Before loading, the mobile engine inspects current device available RAM (`ActivityManager.MemoryInfo.availMem`) and thermal status. Available memory must meet the model's declared resident working set plus a measured, configurable safety reserve ensuring adequate headroom for the host OS and companion UI. If insufficient, the load operation aborts with an informative diagnostic message.
3. **Canonical Model Lifecycle States (`D-PHONE-05`):**
   - The lifecycle of a local generative model transitions through explicit states: `installed`, `loaded / resident`, `active`, `unloaded`, `removed`.
   - *Single Resident Model Policy (`--models-max 1` Mobile Equivalent):* At most **ONE** generative LLM may reside in mobile RAM at any given time. Loading a local model automatically unloads any prior active model. Concurrent execution of multiple generative models on mobile is strictly prohibited. Speech and vision models are budgeted separately.
   - *Unload vs. Removal:* Unloading evicts weights from memory to release RAM/VRAM. *Unload never removes or deletes the model artifact from disk.* Explicit removal/purge is a separate user-initiated action.
4. **Model Resource & Process Lifecycle:**
   - *Background Release/Suspension:* Backgrounding the application with no active approved user-visible operation may release or suspend expensive model resources to prevent premature process termination by the Android low-memory killer (LMK).
   - *Active Operations:* Explicitly user-initiated active operations (such as an approved active Voice foreground session) follow their approved execution lifecycle.
   - *Resource Pressure Triggers:* High memory pressure, elevated thermal state, OS process lifecycle constraints, or user battery policies may force model unloading via the Progressive Resource Governor (`D-PHONE-05A`).
   - *Process Death Resilience:* OS process termination by the Android platform must always be tolerated safely; transient model state is reconstructed cleanly on subsequent launch.
5. **Container & Engine Independence:**
   - The architecture accommodates mobile runtime backends such as `llama.cpp` JNI bindings, ONNX Runtime Mobile, or ExecuTorch. The canonical specification does NOT permanently freeze a single container format (such as GGUF) or vendor engine for all mobile eternity.

### 2.4 Mobile Multimodal & Local Vision Capabilities (`D-PHONE-16` through `D-PHONE-16E`, `D-SHARED-VISION-01`)

- **Conditional Mobile V1 Disposition (`D-PHONE-16`):** Qualified mobile hardware and local models may perform local still-image understanding in Mobile V1, intentionally superseding the prior post-V1-only disposition. Mobile local vision is optional, non-universal, and capability-gated.
- **Camera as Input Adapter (`D-PHONE-16A`):** Device camera capture and photo gallery selection function strictly as input adapters feeding into the shared attachment and multimodal conversation pipeline. Captured frames become standard image attachments conforming to the canonical validation pipeline.
- **Multimodal Route Selection (`D-PHONE-16B`):** Image inference routes among the approved route set:
  - PC Host local vision
  - Qualified Mobile local VLM
  - Separately authorized Cloud multimodal model
  - Unavailable (graceful degradation with clear user feedback if no route qualifies)
  Route selection dynamically evaluates Host reachability, local model qualification and resource state, device thermal/battery conditions, user privacy preferences, and explicit cloud authorizations. The exact preference, fallback order, and retry timing remain implementation-open.
  *Permission Invariant:* Public internet access or general Cloud LLM permission does **not** imply permission for Cloud Vision. Cloud multimodal egress requires independent user authorization.
- **Evidence-Based Qualification (`D-PHONE-16C`):** Mobile vision models must pass empirical task-scoped qualification. Passing basic object recognition does not imply competence in fine OCR, spatial navigation, or high-risk medical/document parsing. Resource Governor limits vision residency to preserve device thermal and memory stability.
- **Offline Multimodal Persistence & Sync (`D-PHONE-16D`):** When operating disconnected, local image attachments, user turns, and generated local responses persist durably in local SQLite/storage. Upon reconnecting, the turn history and binary attachments synchronize to the PC Host without Host re-generation.
- **Explicit-Capture Boundary (`D-PHONE-16E`):** Mobile V1 strictly limits vision to explicit, user-initiated still-image capture or gallery file picking. Continuous ambient camera streams, background visual sensing, and automated environmental monitoring are strictly excluded.
- **Vision vs Memory Decoupling (`D-SHARED-VISION-01`):** Visual observations and image turn contents remain scoped to conversation context and media history. They must **never** automatically generate canonical D7 Memory records without explicit user intent and D7 evaluation.

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
             +-------------------------------+-------------------------------+
             |                               |                               |
     [CONNECTED_TO_PC]                [OFFLINE_LOCAL]                 [OPTIONAL_CLOUD]
             |                               |                               |
             v                               v                               v
+-------------------------+     +-------------------------+     +-------------------------+
|   PC Local AI Runtime   |     | Device-Local TTS / STT  |     | Provider Cloud Gateway  |
| (Canonical STT/TTS/VAD) |     |  (Capability-Dependent) |     | (User Keys in Keystore) |
+-------------------------+     +-------------------------+     +-------------------------+
```

1. **Composable Voice Architecture (`D-PHONE-04`, `D-PHONE-14`):**
   - Voice decomposes into three independent, decoupled pipeline stages: Speech-to-Text (STT), conversational reasoning (LLM), and Text-to-Speech (TTS).
   - Each stage may independently execute via **Local Mobile**, **PC Host**, or separately authorized **Cloud** provider.
   - Enabling or executing one stage does not mandate the presence of the others.
2. **Connected-to-PC Voice Mode (`D-PHONE-14A`):**
   - Uses a dedicated full-duplex **WebSocket connection** (`ADR-0019`) over the authenticated local transport.
   - Raw audio frames captured by the mobile microphone stream in real time to the PC Runtime.
   - The PC Runtime executes canonical speech-to-text (`whisper.cpp` reference candidate), feeds tokens to the language model, synthesizes audio via its canonical TTS provider (`Kokoro-82M` reference candidate), and streams audio buffers back to the phone for native playback.
   - Mobile phone owns capture, playback, audio focus, dynamic route switching, immediate local muting, and UI.
3. **Offline Mobile Audio & Voice Capabilities (`D-PHONE-14B`, `D-PHONE-14C`, `D-PHONE-14D`):**
   - *Device-Local TTS (`D-PHONE-14B`):* Classified as **Conditional Mobile V1**. A qualified local TTS engine vocalizes companion text turns, alarms, and routine check-ins independently of local STT or local LLM.
   - *Device-Local STT (`D-PHONE-14C`):* Classified as **Conditional Mobile V1**. Evaluated under evidence-driven qualification. Focuses strictly on explicit user action (push-to-talk, tap-to-speak, or active session); continuous ambient listening is excluded.
   - *Full Offline Voice (`D-PHONE-14D`):* Classified as **Conditional Mobile V1**. Activates when local STT, local LLM, and local TTS all qualify and resource governor permits. Degrades compositionally if any component is evicted or throttled.
   - *Truthful Degradation Invariant:* If disconnected from PC and without qualified local speech recognition (STT) or Cloud Voice credentials, interactive voice input truthfully degrades to typed text input. If local TTS is available, companion responses can still be vocalized locally; if local TTS is also unsupported or uninstalled, the interface truthfully falls back to visual text display with clear status indication (*"Speech input unavailable offline — connect to PC Host or configure Cloud Voice"*).
4. **Voice Route Selection (`D-PHONE-14E`):**
   - Default `Auto` route selection dynamically evaluates PC Host reachability, local component qualification, device thermal/battery headroom, network state, and cloud permissions.
   - The active operational route (e.g. `Host STT + Host LLM + Host TTS` vs `Local STT + Local LLM + Local TTS`) remains visible and inspectable in the UI.
5. **Shared STT Candidate Qualification (`D-PHONE-14G`):**
   - `whisper.cpp` is the first approved research candidate for mobile local STT qualification to align with the PC Voice architecture direction. It serves as an empirical research and qualification candidate, replaceable if benchmarks or qualification dictate, without altering overall composable voice architecture.
   - Mobile qualification is independent of PC; empirical benchmarks evaluate English, Tagalog, Taglish code-switching, date/time recognition, memory footprint, thermal load, and barge-in responsiveness.
6. **Optional Cloud Voice Routing & Permission Decoupling:**
   - Supported only when the user explicitly enables Cloud Voice and provides personal API credentials stored securely in Keystore.
   - *Permission Decoupling:* Cloud LLM, Cloud STT, and Cloud TTS are **three independently revocable permissions**:
     $$\text{Public Internet} \neq \text{Cloud LLM} \neq \text{Cloud STT} \neq \text{Cloud TTS}$$
     Enabling Cloud LLM does NOT authorize cloud audio streaming. Cloud audio transmission requires explicit separate consent.

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
- **Required Foreground Service & Audio Permissions:**
  - *Base Foreground Service Permission:* Manifest must declare base `android.permission.FOREGROUND_SERVICE` (required on Android 9+, API 28+).
  - *Type-Specific Foreground Service Permission:* Manifest must declare type-specific `android.permission.FOREGROUND_SERVICE_MICROPHONE` (mandatory on Android 14+, API 34+), and the service must declare `android:foregroundServiceType="microphone"`.
  - *Runtime Audio Permission:* Runtime `android.permission.RECORD_AUDIO` must be requested and granted by the user prior to capturing audio.
- **Modern Android While-in-Use Restrictions & Initiation Rules:**
  - Microphone capture on modern Android is strictly a **while-in-use** capability. The application cannot access the microphone when running in the background without an active foreground service.
  - On Android 14+ (API 34+), a microphone foreground service **CANNOT be initiated from the background**. It strictly requires a qualifying visible foreground user interaction (e.g. active visible activity). Attempting to start a microphone FGS from the background will fail with a platform exception (`ForegroundServiceStartNotAllowedException`).
  - Background code cannot arbitrarily start or resume microphone capture. Voice sessions originate strictly from visible, intentional user interaction in the foreground UI.
- **Active Session Screen-Lock & Foreground Execution Lifecycle:**
  - If the user explicitly starts a conversational voice session in the foreground and subsequently locks the screen or navigates to another app, the active session MAY continue running under the initiated microphone Foreground Service.
  - *User-Visible Indication:* The OS notification drawer displays an ongoing, prominent user notification indicating active microphone use and featuring an explicit **"End Session"** action control.
  - *Session Termination:* Tapping "End Session" or terminating the turn immediately stops the foreground service (`stopForeground(STOP_FOREGROUND_REMOVE)`), releases the native microphone hardware, and ends foreground execution.


---

### 3.5 Voice Privacy & Invariants
- **Voice is NOT Authentication:** Conversational voiceprints or acoustic characteristics must NEVER be used as an authentication or authorization factor (`ADR-0005`, `ADR-0018`).
- **Raw Audio is Transient:** Raw user audio buffers captured on the device or received over the network are transient memory buffers and are not retained by default. Application-level buffers and memory references are promptly released after their active processing lifecycle according to the approved Voice privacy policy. Debug audio recording requires separate, explicit developer opt-in if ever implemented.
- **Transcript Ownership:** Only the final transcribed text becomes a permanent conversation turn message, owned strictly by the active `profile_id`.

---

## 4. C3: Health and Wearables Release Disposition (`D-PHONE-15` through `D-PHONE-15E`, `D-SHARED-HEALTH-01` through `04`)

### 4.1 Formal Release Decision: Conditional Mobile V1 (`D-PHONE-15`)
In accordance with [`docs/04_Architecture/03_Integrations/health-and-wearables.md`](../03_Integrations/health-and-wearables.md), the formal release disposition for Mobile V1 is:
**Conditional Mobile V1 (`D-PHONE-15`), intentionally superseding the prior Batch C `Mobile Later (Deferred Post-V1)` deferral.**
Real Health Connect integration (`androidx.health.connect`) is an optional, read-only, consent-driven capability for qualified Android environments. A device, platform, or user configuration without usable Health Connect remains a fully valid Mobile V1 installation.

#### 4.1.1 Ingestion & Boundary Architecture
- **Granular Metric Authorization (`D-PHONE-15A`):** Biometric ingestion requires explicit user authorization partitioned by metric type (active calories, blood pressure, body temperature, distance, heart rate, oxygen saturation/SpO₂, sleep, steps). Only metrics actually supplied by the source are claimed.
- **Read-Only Ingestion (`D-PHONE-15B`):** The Companion reads approved Health Connect records into its local context but does not write or modify health records in Health Connect in Mobile V1.
- **Health Context vs. Memory Decoupling (`D-PHONE-15C`):** Health metrics, readings, and trends belong strictly to the Health Context domain and are **not** canonical D7 Memory. Explicit user health preferences may separately become Memory through D7.
- **Shared Normalized Health Context (`D-PHONE-15D`, `D-SHARED-HEALTH-01`):** Mobile serves as the Health Connect ingestion point and shares a unified normalized health schema with the PC Host, preserving timestamp, freshness, and source provenance.
- **Aggregation Boundary (`D-PHONE-15E`):** Android Health Connect serves as the canonical V1 mobile aggregation boundary. Direct proprietary wearable SDKs are not required in Mobile V1.
- **Non-Clinical Awareness & Check-Ins (`D-SHARED-HEALTH-02`, `D-SHARED-HEALTH-03`):** Health context provides empathetic conversational awareness, wellness suggestions, and check-in enrichment without making medical or diagnostic claims. Underlying facts remain deterministic; Character presentation modulates conversational framing only.
- **Health Egress Isolation (`D-SHARED-HEALTH-04`):** Permitting Cloud LLM or internet tools does **not** authorize transmitting health data off-device:
  $$\text{Public Internet} \neq \text{Cloud LLM} \neq \text{Health-to-Cloud}$$
  Health data inclusion in cloud prompts requires distinct, standalone user authorization.

#### 4.1.2 Prototype Sequestration & Implementation Reality
- **Current Prototype Status:** The existing Android codebase contains UI mock screens (`HealthScreen.kt`, `HealthViewModel.kt`) backed by synthetic profiles (`MockHealthDataProvider.kt`).
- **Production Implementation Reality:** The repository currently contains **zero** production Health Connect client code, zero `androidx.health.connect` dependencies, and zero health manifest permissions (`android.permission.health.*`). Production Flutter Mobile health integration is **NOT IMPLEMENTED**.
- **Sequestration Boundary:** Until real Health Connect integration is implemented and verified under an approved plan, existing Kotlin prototype screens remain sequestered as developer reference code and disabled in production builds.
- **Purge Rights Over Retained Copies:** Users retain absolute authority to inspect, export, or permanently erase all Companion-retained/synchronized health copies on demand. (The Companion does not claim automatic deletion authority over external source records residing in Android Health Connect unless created by the Companion and explicitly authorized by future architecture).

### 4.2 Future Location Context Boundary (`P-PHONE-LOC-01`)
- **Disposition:** `MOBILE LATER / APPROVED FUTURE DIRECTION`.
- **Architectural Boundary:** Location awareness is an optional future contextual signal, not an implemented Mobile V1 feature. Mobile V1 contains zero location permissions, zero background geolocation services, and zero location implementation tasks.
- **Privacy & Autonomy Invariants:**
  - *Opt-In Only:* Location ingestion requires explicit, separate user opt-in with clear disclosure of purpose.
  - *Geofencing Preference:* Event-oriented geofencing (e.g. entering or leaving a user-defined zone) is strongly preferred over continuous high-frequency GPS tracking.
  - *Context, Not Memory:* Location fixes and zone transitions belong strictly to ephemeral context, **not** canonical D7 Memory.
  - *Evidence, Not Security Authority:* Location data serves solely as contextual evidence; it never possesses scheduling, authorization, or security policy authority.
  - *No Hidden Tracking:* Silent or hidden background continuous location tracking is strictly prohibited.
  - *No Continuous History by Default:* The Companion does not maintain a continuous raw GPS track or breadcrumb location history by default.
  - *Explicit Background Purpose:* Any future background location evaluation requires an explicit, user-approved purpose and dedicated platform permissions.
  - *No Implicit Cloud Egress:* Location data is never transmitted to cloud services or cloud LLM providers by default; cloud transmission requires independent, explicit user consent.
  - *User Inspection & Purge Rights:* Users retain unconditional rights to inspect, disable, and permanently purge any retained location evidence.
  - *Character Guardrail:* Character persona, emotional state, or relationship framing cannot override or bypass user location privacy preferences.
  - *No V1 Implementation:* Mobile V1 introduces zero implementation tasks or code dependencies for location services. Exact geofence radii, retention windows, polling intervals, and provider APIs remain open for future specification.

### 4.3 Future Embodied Presence & AR Directions (`P-SHARED-PRESENCE-01`, `P-PHONE-AR-01`, `P-PHONE-AR-02`, `P-PRESENCE-02`)
- **Disposition:** `APPROVED FUTURE DIRECTION / EXPERIMENTAL LATER`.
- **Decoupled Architecture:** Physical and visual presence rendering is strictly decoupled from the core companion personality architecture:
  $$\text{Presence} \neq \text{Character Identity} \neq \text{Personality} \neq \text{Mood} \neq \text{Voice}$$
- **Presentation Modality Isolation:**
  - *Mobile V1 Focus:* Mobile V1 focuses entirely on the companion presence shell, 2D avatar/portrait representation, ambient visual state, and responsive text/voice conversational interfaces (`D-PHONE-06`, `D-PHONE-EMO-01`, `D-PHONE-12D`, `D-PHONE-12E`, `D-PHONE-UX-10`).
  - *Future Embodied Presence (`P-SHARED-PRESENCE-01`):* Shared embodied presence abstractions (e.g. unified 3D coordinate frames, spatial anchors, multi-device physical presence) are approved long-term architectural directions for subsequent milestones.
  - *Mobile AR Companion (`P-PHONE-AR-01`, `P-PHONE-AR-02`):* Augmented reality visual anchoring, spatial awareness, and mobile AR camera overlays are approved future research and design directions.
  - *Experimental Presence (`P-PRESENCE-02`):* Advanced embodied presence experiments (e.g. interactive spatial avatars, animated Live2D/3D skeletal runtimes, XR device integration) remain experimental post-V1 concepts.
- **Non-Requirement for V1:** 3D rendering engines, ARCore/scene graph dependencies, Live2D runtimes, and continuous spatial tracking are explicitly **NOT** requirements for Mobile V1 release.

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
  - Monitor supported modern Android architecture signals: `ComponentCallbacks2.onTrimMemory` background and visibility states (`TRIM_MEMORY_UI_HIDDEN`, applicable background trim states such as `TRIM_MEMORY_BACKGROUND`), `ActivityManager.MemoryInfo.lowMemory` / memory thresholds, and current process memory state. (Deprecated running-trim levels like `TRIM_MEMORY_RUNNING_CRITICAL` and legacy levels like `TRIM_MEMORY_COMPLETE` are no longer delivered on modern Android targets and are not relied upon).
  - Enforce model-load memory preflight validation against available device RAM prior to loading local model artifacts.
  - When memory pressure signals are received, clear ephemeral image/media caches and release or suspend expensive resident model allocations as appropriate.
  - Handle allocation failures (`OutOfMemoryError` and native runtime allocation errors) gracefully during model operations, resetting engine state cleanly and presenting a truthful UI fallback rather than crashing the process.
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
| **L3: Platform Lifecycle Tests** | Android Emulator Matrix | Activity recreation, process death restoration, `canScheduleExactAlarms()` revocation recovery, `ACTION_BOOT_COMPLETED` receiver alarm re-registration, notification permission prompt handling. Validates across an evidence-driven matrix spanning current Target SDK/API, supported lower API boundaries, and breaking transition versions (notifications, exact alarms, typed/while-in-use FGS, process lifecycle/timeouts). | FUTURE EMULATOR AUTOMATION (Scheduled emulator matrix) |
| **L4: Hardware & Audio Tests** | Physical Android Hardware | Real audio focus during incoming phone calls, Bluetooth headset disconnect, exact alarm firing out of deep overnight Doze, sustained thermal throttling behavior under local inference load. | PHYSICAL DEVICE / MANUAL GOLDEN (Physical hardware pass) |
| **L5: Host Integration Tests** | Multi-Process / Local Network | Mobile client communicating with running PC Local AI Runtime FastAPI harness: delta cursor sync, `STALE_CURSOR` re-baseline, `DEVICE_REVOKED` wipe, SSE streaming resilience across disconnects. | FUTURE INTEGRATION AUTOMATION (Integration harness) |

#### 7.1.1 Evidence-Driven L3 Emulator Matrix Specification
Rather than hardcoding arbitrary fixed emulator versions, the L3 platform lifecycle matrix is governed by observable platform behavioral boundaries:
1. **Target SDK/API Boundary:** Validates adherence to current target platform policies and runtime contracts (modern target API level).
2. **Supported Lower API Boundary:** Validates minimum supported SDK compatibility baseline, ensuring backward-compatible execution paths execute safely without runtime failures.
3. **Behavioral Transition Boundaries:** Specific OS releases introducing breaking platform lifecycle, permission, or background execution behavior:
   - *Notifications (API 33 / Android 13):* Runtime `POST_NOTIFICATIONS` permission prompt, grant/denial flows, and settings toggle recovery.
   - *Exact Alarms (API 34 / Android 14):* Restricted `SCHEDULE_EXACT_ALARM` access, dynamic `canScheduleExactAlarms()` gating, and absence of reliable revocation broadcast.
   - *Foreground Services (API 34 / Android 14):* Typed foreground service declaration (`FOREGROUND_SERVICE_MICROPHONE`), while-in-use restrictions, and prohibition of background FGS starts without visible UI initiation.
   - *Process Lifecycle & Timeouts (API 35+ / Android 15+):* Strict foreground service runtime limits, enhanced memory-pressure trimming, and 16 KB page-size compatibility.

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
- **MG8 — Voice Streaming & Audio Lifecycle:** Native mic capture, full-duplex WebSocket audio streaming to PC Host, immediate local barge-in playback muting, immediate muting on competing audio focus loss (`AUDIOFOCUS_LOSS`), pausing on unsafe route changes (`ACTION_AUDIO_BECOMING_NOISY`), device-local TTS vocalization when offline on qualifying devices, and graceful truthful degradation to text mode when unsupported.
- **MG9 — Mobile Inference & Hardware Tiers:** Capability detection across Tiers 0–3 based on runtime preflight evidence, clean UI degradation when unsupported, resident model memory budget enforcement, D6 mobile lifecycle integrity.
- **MG10 — Thermal, Battery & Power Governance:** WorkManager compliance with Doze maintenance windows, thermal throttling backoff under severe thermal state, graceful model unloading under modern `onTrimMemory` and memory pressure signals without process crash.
- **MG11 — Security, Revocation & Privacy:** Authoritative discovery of `DEVICE_REVOKED` triggering local revocation cleanup, preservation of third-party user keys, backup exclusion verification, quarantine on `PROFILE_INACTIVE`, permanent wipe on `PROFILE_PURGED`.
- **MG12 — Cross-Device Consistency:** Independent device alarm ringing without premature cancellation by passive PC notifications; cross-device alarm dismissal synchronization upon explicit user dismissal.

---

## 9. C8: Cross-Domain Consistency Review

A comprehensive coherence check across Batch A, Batch B, and Batch C confirms complete alignment:

1. **Authority Model:** PC Host remains sole Account/Profile Administrator (`ADR-0018`). Mobile operates strictly as an enrolled Satellite bound to 1 Profile.
2. **Domain Synchronization:** Tasks, Reminders, and Alarms follow the asymmetric replication and revision rules established in `mobile-offline-and-sync.md`.
3. **Inference & Voice Decoupling:** Desktop PC V1 voice and model architectures (`voice-and-audio.md`, `runtime-and-models.md`) remain unaffected. When connected, Mobile streams audio over full-duplex WebSocket to PC Runtime canonical STT/TTS/VAD providers. When offline, Mobile supports capability-dependent device-local TTS and independently capability-gated local STT/LLM inference without freezing a permanent single engine requirement or restricting Mobile solely to a passive audio edge node.
4. **Health Integration:** Formally aligned with [`health-and-wearables.md`](../03_Integrations/health-and-wearables.md) as **Conditional Mobile V1** (`D-PHONE-15`), intentionally superseding the prior Batch C `Mobile Later` deferral.
5. **No PC Code Regressions:** Zero changes to backend Python runtime, React web frontend, or Windows desktop code.
