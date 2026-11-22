# Runtime and Models Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical (Aligned with Decisions D1-D11, ADR-0007)
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1-D11. Master release planning is owned by [`docs/02_Planning/00_Master/`](../../02_Planning/00_Master/). This focused specification owns normative architecture for the local inference runtime, models, and execution providers.

---

## 1. Purpose & Scope

This specification defines the local inference runtime, hardware execution model, model registry lifecycle, and cloud fallback boundaries for the AI Companion:
- Provider-independent LLM orchestration layer.
- Primary local-first inference architecture supporting offline core/local companion operation without cloud LLM dependency.
- Single resident model default policy (`--models-max 1`).
- Decision D6 controlled local model import pipeline (`inbox` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `atomic install` $\rightarrow$ `library` $\rightarrow$ `registry`).
- User-initiated manual scan and atomic installation of multi-file bundles (`.gguf` + `mmproj`).
- Relocatable model library (`LIBRARY_ROOT`).
- Model registry, artifact identity, capability metadata, and validation lifecycles.
- Phased model acquisition separating PC V1 local import from post-V1 online model hub downloads.
- Opt-in, transparent Cloud LLM Fallback boundaries.
- Mobile device-local model architecture, lifecycle states, and component separation (Mobile V1).

---

## 2. Durable Architecture & Invariants

### 2.1 Local-First & Single Resident Model Policy

- **Local Inference is Primary & Default:** The AI Companion is architected fundamentally as a private, locally hosted AI system. Core/local companion operation remains supported without cloud LLM dependency. Naturally network-dependent integrations (Web Search, Fetch, Weather) require internet connectivity.
- **Provider & Hardware Independence:** The conversational orchestrator interacts with language models through an abstract provider interface. The architecture does not permanently lock a single runtime binary, backend driver, or hardware vendor. While the current implementation utilizes `llama.cpp` over Vulkan on RX 580 baseline, the durable architecture accommodates alternative execution engines where separately approved.
- **Single Resident Model Default (`--models-max 1`):** To safeguard system stability and preserve memory for foreground gaming or creative workloads, the runtime enforces a default cap of **1 resident model in memory**. Loading a new model unloads the previously active model. Multi-model concurrency is an Advanced Setting requiring explicit user opt-in and presenting VRAM capacity warnings.

### 2.2 Controlled Model Import Pipeline (Decision D6)

The frozen D6 pipeline for controlled local model import is as follows:
`controlled inbox` -> `user Refresh / Scan` -> `discover candidate bundle` -> `detect identity / metadata / capabilities` -> `provenance classification` -> `user review/correction of configurable or inferred metadata` -> `preflight` -> `explicit confirmation` -> `staging` -> `atomic installation` -> `Library` -> `Registry`.

- **No Automatic Filesystem Watcher:** The runtime does not automatically watch or ingest files. Import is user-initiated.
- **No Arbitrary Host-Path Authority:** The runtime only operates within the defined import inbox and staging boundaries.
- **Provenance Classification:** Conceptual provenance states are DECLARED, DETECTED, INFERRED, USER_CONFIGURED, VERIFIED, UNKNOWN.
- **Metadata Integrity:** The user may correct inferred or configurable metadata but cannot falsify intrinsic artifact facts.
- **Preflight Checks:** Preflight must distinguish between:
  1. Artifact validity.
  2. Provider compatibility.
  3. Hardware suitability (a model may be valid/supported but "not recommended" on current hardware).
- **Multi-File Bundles:** Multi-file bundles (such as a main GGUF + mmproj) are first-class atomic import units.
- **Capabilities:** Detected capability != verified runtime compatibility.
- **Future Managed Downloads:** Any future managed model downloads must converge through this exact same D6 pipeline.

### 2.3 Managed Online Model Downloading (PC Later)

In accordance with the Master Decision Register:
- **Classification:** `APPROVED / NOT STARTED / PC LATER`.
- **Policy Invariant:** In-app discovery and downloading of models from public hubs (e.g., Hugging Face) is an approved architectural track scheduled for post-PC-V1 delivery. It is **not** prohibited, but it is deliberately sequenced after PC V1 to ensure the local file import foundation (Decision D6) is solid and verified first.

### 2.4 Optional Cloud LLM Fallback (PC V1)

In accordance with the Master Decision Register:
- **Classification:** `APPROVED / NOT STARTED / PC V1`.
- **Architectural Rules:**
  - **Local Remains Primary:** Local inference is always default; cloud fallback is strictly an opt-in auxiliary.
  - **Explicit User Credentials:** The user must explicitly supply their own API keys; the companion distributes no default hosted keys.
  - **Egress Transparency:** Any conversational turn or tool execution routed to an external cloud model must clearly indicate external egress to the user.
  - **Local-Only Preserved:** Disabling cloud fallback preserves supported core/local companion operation in local-only mode. Naturally network-dependent integrations such as Web Search, Fetch, Weather, and current-information retrieval still require network connectivity.
   There is no automatic cloud egress merely because local inference is constrained.

### 2.5 Model Registry, Artifact & Capability Semantics

To ensure robust model management and avoid semantic conflation across model identity, file artifacts, and runtime execution, the architecture enforces the following durable invariants:

- **Logical Model vs. Artifact Identity:** A logical model identity (e.g., a base model architecture and training family) must remain distinguishable from individual runtime artifacts and quantizations (e.g., `Q4_K_M`, `Q5_K_M`, `Q8_0`). While current implementation registers individual model files directly, the durable architecture preserves conceptual separation and must not prevent future grouping of multiple quantization artifacts under a common logical model entry. Exact schema grouping remains open design.
- **Model Metadata vs. Runtime Configuration:** The architecture maintains a strict semantic separation between:
  1. *Model Metadata:* What an artifact or model intrinsically *is* (e.g., base architecture, parameter count, quantization type, native context limit, declared modalities).
  2. *Runtime Configuration & State:* How the current host environment *runs* it (e.g., active context window size, GPU offload layers, CPU thread allocation, active performance profile).
  System components must never collapse or conflate intrinsic model metadata with transient runtime execution configuration (such as conflating `model_context_limit` with `runtime_context_size`, or intrinsic capabilities with active hardware offload profiles).
- **Explicit Capabilities & Modalities:** Model capabilities and supported modalities must be declared or detected explicitly where relevant rather than inferred solely from heuristic file naming conventions or display labels. Conceptual capability domains may include `chat`, `vision`, `reasoning`, `tool calling`, `structured output`, `multilingual`, and `code`. The registry must not promote unsupported future capabilities merely because the registry schema is capable of representing them.
- **Companion Artifacts & Partial Capability:** The model architecture supports multi-file companion artifacts where a model requires auxiliary weights (such as an `mmproj` vision projector for multimodal models). The absence of a capability-specific companion artifact must not automatically mark the entire model unusable; for example, a vision-capable primary model whose projector artifact is missing may remain usable for pure text inference while vision capabilities remain disabled until the companion artifact is provided. Exact registry representation remains open design.
- **Model Identity vs. Runtime Compatibility:** An artifact's identity and format metadata must remain strictly separated from runtime compatibility test results. A model artifact possesses intrinsic metadata (architecture, quantization, file size), and independently possesses empirical compatibility evaluations (tested engine, tested build, tested platform, verified acceleration backend, compatibility status). For example, successfully verifying execution on Vulkan does not make the artifact intrinsically a "Vulkan model."
- **Validation & Registration Lifecycle:** The registry lifecycle distinguishes conceptually between distinct stages: `discovered`, `registered`, `verified`, and `incompatible`. The durable principle is that *file presence on disk does not imply verified usability*. Exact enum names and schema representations remain open design.
- **Capability Confidence & Provenance:** The architecture distinguishes between different confidence levels and provenance of model capabilities (e.g., `declared` by manifest, `detected` from tensor metadata, `verified` by runtime preflight test, or `unknown`). Inferred or self-declared capabilities must not silently be treated as equivalent to verified runtime capability. Exact schema fields remain open design.
- **Chat Template & Tokenizer Integrity:** Where reliable model-provided chat-template or tokenizer metadata is present in artifact headers, runtime template selection must respect and preserve that metadata rather than applying arbitrary prompt templates based solely on generic filename matching. Exact template override mechanisms remain open design.
- **Generation Recommendations vs. Identity:** Default generation parameters (such as recommended temperature, top-p, or repetition penalty) represent non-binding baseline recommendations. They do not constitute immutable model identity metadata and may be tuned or overridden by runtime configuration, user preferences, or character prompt definitions.
- **Format & Provider Independence (No Eternal GGUF Lock):** While the current `llama.cpp` implementation exclusively uses the GGUF container format, the durable model registry and acquisition architecture is provider- and format-agnostic. Registry abstractions must accommodate future safe, approved runtime formats (such as ONNX) without requiring all models to permanently conform to GGUF.
- **Controlled Web / Filesystem Import Boundary:** A browser or web client model-import workflow must never grant unrestricted host filesystem path authority. Any Web-based local model import must enter through the controlled Decision D6 import pipeline (`inbox` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `atomic install` $\rightarrow$ `library` $\rightarrow$ `registry`) rather than accepting arbitrary filesystem paths from client input.
- **Factory Registry as Bootstrap Catalog (Not a Model Whitelist):** The repository/factory registry template (`models/registry.template.json`) is a bootstrap and example catalog of verified reference models, and must **not** act as a permanent whitelist of every model architecture the system may support. Real-world model compatibility is determined through approved runtime/provider preflight validation, format integrity checks, and hardware capability constraints rather than mere presence in the factory template. This principle does not imply that every arbitrary model file must be accepted; strict safety validation, format checks, and resource preflight remain required.

---

### 2.6 Cloud LLM Routing Policy

The high-level fallback routing policy for cloud models is frozen:

- **Fresh Install Default:** LOCAL_ONLY.
- **Cloud Explicitly Enabled:** LOCAL_FIRST.
- **Advanced/Developer Options:** May expose CLOUD_PREFERRED, CLOUD_ONLY, manual provider/model selection, advanced fallback triggers, and background-cloud controls.
- **Per-Turn Explicit Overrides:** "Use Local for This Turn", "Use Cloud for This Turn".
- **LOCAL_FIRST Approved Fallback Triggers:**
  - Local provider unavailable after bounded recovery.
  - Required capability unavailable locally (e.g., vision/multimodal if local model lacks it).
  - Local generation failure.
  - Explicit user choice.
  - Approved Profile policy.
- **Resource Pressure constraint:** Hardware pressure / Gaming / Low-Impact alone NEVER authorizes cloud.
- **Background Inference:** Background cloud inference = OFF by default. Routine/background paid cloud inference requires separate explicit permission.
- **D9 Authority:** Cloud providers have zero inherent D9 tool authority.
- **Data Minimization:** Cloud context builder minimizes egress and does not send the entire Profile, Memory, or history.
- **Provenance:** Provider/model provenance MUST be persisted with assistant messages.
- **Credentials:** Device-local credential rules belong with [`authentication-and-secrets.md`](../02_Data_and_Security/authentication-and-secrets.md).
- **Open Design:** The exact provider adapter implementation remains open design.

### 2.7 Mobile Device-Local Model Architecture & Lifecycle (Mobile V1)

In accordance with Decisions `D-PHONE-01`, `D-PHONE-01C`, `D-PHONE-03`, and `D-PHONE-05`:

- **Four-Way Component Separation (`D-PHONE-03`):** In accordance with vendor-neutral mobile execution (`D-PHONE-03`), mobile model management strictly distinguishes four separate layers to prevent architectural ambiguity:
  1. *Model Artifact / Model Identity:* The packaged weights, format, configuration, and declared model identity (e.g., `.gguf` artifact).
  2. *Runtime / Provider:* The software inference engine executing inference (e.g., `llama.cpp` mobile bindings, ExecuTorch).
  3. *Execution / Acceleration Backend:* The hardware compute driver / accelerator interface (CPU, OpenCL, Vulkan, NPU).
  4. *Physical Hardware:* The host mobile SoC, compute cores, RAM, and thermal chassis.
- **Canonical Mobile Model Lifecycle States (`D-PHONE-05`):** The lifecycle of a local generative model on mobile transitions through explicit states:
  - `installed`: The model artifact resides in app-scoped local storage and has passed cryptographic and format preflight validation.
  - `loaded / resident`: Model weights are mapped into device RAM / accelerator memory and runtime execution context is initialized.
  - `active`: The model is actively processing prompt context or generating tokens.
  - `unloaded`: Model weights are evicted from memory to release RAM/VRAM. *Architectural Invariant:* `unloaded` does **not** mean `removed`. An unloaded model remains installed on device storage ready for reloading.
  - `removed`: The model artifact is explicitly deleted from local device storage by user action.
- **Single Resident Generative LLM Cap (`D-PHONE-05`):** Mobile V1 enforces a hard limit of at most **one resident generative LLM** in device memory at any time. Loading a different generative model automatically unloads the previously active model. Concurrent execution of multiple generative LLMs on mobile is strictly prohibited. Speech (STT/TTS) and vision models are budgeted separately.
- **Replaceable Local Model Architecture (`D-PHONE-01C`):**
  - Users may install, select, change, load, unload, and remove approved local models.
  - No model family is permanently mandated or hard-coded into mobile architecture.
  - Model capabilities adhere to shared qualification semantics; switching models truthfully disables unsupported capabilities (e.g., switching to a pure text model disables vision assistance).
  - A generative model proposes typed tool intent; actual tool execution is mediated strictly by the Mobile Tool Gateway and deterministic Decision D9 policy.
- **Vendor-Neutral Execution & Candidate Models (`D-PHONE-03`):**
  - Mobile execution architecture is vendor-neutral, without permanent hardware lock to specific chipset vendors or architectures.
  - CPU execution serves as a broad fallback where supported, but is not an absolute universal guarantee across all low-end devices.
  - Requested execution backend (e.g., `AUTO`, `CPU`, `GPU`, `NPU`) and the actually applied backend must be truthfully and separately reported.
  - Evaluated models (such as Gemma 3 1B) represent empirical research candidates, not hard-coded architectural dependencies.

### 2.8 Dynamic Model Selection & Hardware-Aware Recommendation Architecture

In accordance with architectural decisions for replaceable local generative models:

- **Dynamic & Replaceable Model Invariant:** No model family or specific checkpoint is permanently mandated or hard-coded into the architecture. The runtime orchestrator supports dynamic selection, replacement, loading, and unloading of approved local models. The reference model (`qwen3-vl-2b-instruct`) serves as an empirical development and qualification baseline, not an immutable system dependency.
- **Strict Model Selection Precedence:** Runtime model resolution enforces deterministic precedence:
  1. *Explicit Operation Request:* The model explicitly specified in the client request payload.
  2. *Saved Host Configuration:* The model persisted in machine-level host configuration (`COMPANION_DATA_ROOT/config/host_config.json`).
  3. *Development Environment Override:* Explicit override via `COMPANION_DEV_MODEL` when present in development/test environments.
  4. *Fail-Closed Invariant (`MODEL_SELECTION_REQUIRED`):* If no model selection exists (no explicit operation request, no saved host configuration, and no development override), model loading fails closed with `MODEL_SELECTION_REQUIRED` (HTTP 422 in `backend/app/api/v1/endpoints/llm.py`). If a model was explicitly selected or requested but is missing from the registry or host storage, it fails closed with its actual distinct error (HTTP 404 Model Not Found in registry, or HTTP 400 Model File Missing on host, rather than conflating with `MODEL_SELECTION_REQUIRED`). The system **never** silently falls back to an unselected or arbitrary model.
- **Host-Level Configuration Scope:** Model selection is a machine-wide host configuration owned by the host environment (`host_config.json`), not stored per-user profile and not owned primarily by environment files.
- **Hardware-Aware Model Recommendation & Advisory VRAM Preflight (Implemented — `PC-CLIENT-010`):**
  - *Real Host Hardware Probe & Dynamic Recommendations:* `backend/app/services/hardware_probe.py` (`probe_host_hardware()`) lazily detects Windows physical RAM (`GlobalMemoryStatusEx`) and GPU VRAM (`winreg` 64-bit `qwMemorySize`, falling back to `settings.HOST_DEDICATED_VRAM_GB` when unavailable). `assess_hardware_suitability()` and `compute_recommended_profiles_for_model()` evaluate primary `.gguf` size plus companion `mmproj` size (`companion_size_bytes`), KV-cache context overhead (`context_size`), and OS VRAM headroom across factory, installed, and inbox models to classify `recommended`, `supported_with_warning`, or `not_recommended` alongside PC-appropriate `recommended_profiles` (`maximum`, `balanced`, or `eco`).
  - *Advisory vs. Enforced Policy & Experimental `>8K` Context Window:* Dynamic recommendations and hardware telemetry (`host_gpu_name`, `host_vram_gb`, `host_ram_gb`) are surfaced in Flutter Desktop `SettingsRuntimeSection` (with 1-click **Apply Recommended Profile**). Explicit user model, profile, and experimental `context_mode` (`"profile"`, `"16k"`, `"model_max"`) selections always take precedence, subject to corrupt/truncated header fail-closed guards.
  - *Truthful Capabilities & Profile/Context Persistence:* Switching models reconfigures reported capabilities truthfully (disabling vision when `mmproj` is absent). Both `hardware_profile` and `context_mode` persist across restarts via `host_config.json` (`save_hardware_profile()`, `save_context_mode()`), and changing profile or context window resets active Core-managed router state cleanly (`SERVER_STOPPED`).

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Provider Abstraction & llama.cpp Driver

Verified in `backend/app/services/llm/`:
- **Provider Interface (`base.py`):** Defines abstract class `BaseLLMProvider` with exact contract:
  - `@property provider_name -> str`
  - `async load_model(model_name: Optional[str] = None, profile: Optional[str] = None) -> bool`
  - `async unload_model() -> bool`
  - `is_loaded() -> bool`
  - `async set_profile(profile: str) -> bool`
  - `async get_status() -> ModelStatusResponse`
  - `async generate(messages: List[ChatMessage], temperature: float = 0.7, max_tokens: int = 1024, **kwargs) -> str`
  - `async generate_stream(messages: List[ChatMessage], temperature: float = 0.7, max_tokens: int = 1024, **kwargs) -> AsyncGenerator[str, None]`
  - `def signal_shutdown_immediately() -> None`
  - `async shutdown(drain_timeout: Optional[float] = None, lock_timeout: float = 2.0) -> ProviderShutdownResult`
- **Concrete Providers:**
  - `LlamaCppProvider` (`llama_cpp.py`): Connects to a local router or launches standalone `llama-server.exe`, tracks Core-managed process state, loads/unloads models via router API, applies profiles, and manages idle sleep/unload lifecycles.
    - *Strict Lock Ownership & Cancellation-Aware Loading (`PC-HOST-005`):* `load_model()` checks `_shutdown_signaled` and uses `_sleep_or_abort()` to abort cooperatively during polling; `shutdown()` acquires `self._lock` with bounded timeout (`2.0s`), returning a structured `ProviderShutdownResult` and strictly avoiding unlocked mutations.
    - *Inference Draining & Crash Isolation:* `shutdown()` drains active streams up to `drain_timeout` (`4.0s` default). If generation remains active after timeout, Route B `self._llm` and router state are safely retained to prevent native crashes.
    - *Core-Managed vs. External Router Separation:* Core-managed `llama-server.exe` processes are terminated via `_stop_managed_router_locked()`; externally owned routers have model weights evicted via router API without terminating the foreign server process.
    - *Lock-Free Snapshot Status (`M5`):* `get_status()` returns a lock-free snapshot during `SERVER_STARTING`, `MODEL_LOADING`, and `MODEL_UNLOADING` without blocking on `self._lock` or overwriting active model state.
    - *Model ID Normalization (`M6`):* `loaded_model_id` is normalized through `find_model_registry_entry`, aligning primary file paths with canonical manifest IDs.
    - *4-State Truthful Status Reconciliation (`PC-CLIENT-010` / Track B):* `CompanionClient` enforces `90s` operation timeouts on model load; transitional states enter `STILL_LOADING` and reconcile via `GET /api/v1/models` without false failures, exposing a manual `Refresh Model Status` button; `DesktopChatController` executes immediate and background status polling until ready.
    - *Windowless Subprocess Execution:* Launches `llama-server.exe` with `creationflags=subprocess.CREATE_NO_WINDOW` on Windows, preserving direct process invocation, exact PID ownership, single-resident model policy, model load/unload lifecycle, and crash isolation without popping up an interactive console window.
    - *Request-Scoped Finish Reasons:* Preserves upstream chunk completion reasons (`"stop"`, `"length"`) via `GenerationStream` metadata, preventing concurrency races across interleaved turns.
    - *Truthful Model Unload (`POST /api/v1/models/unload`):* Returns `409 Conflict` if generation is active, `500 Internal Server Error` if unload fails or the model remains loaded in memory; verifies that `status.model_loaded == False` before returning success; preserves saved model selection in `host_config.json`.
    - *Client Settings Control (`PC-CLIENT-010`):* Flutter Settings exposes an authenticated "Unload Model / Free VRAM" action with active-generation protection and truthful status announcements.
  - `MockLLMProvider` (`mock.py`): Supplies deterministic synthetic token streams for testing.
  - **Cloud Providers:** **NOT IMPLEMENTED**. No OpenAI, Anthropic, or external cloud API client adapter exists in `app/services/llm/`.
- **Process Management & Router Constants:** `scripts/start-model.ps1` exists as a diagnostic/helper script, not the primary runtime launcher. Current implementation constants include:
  - Local loopback host: `127.0.0.1` (never `0.0.0.0`).
  - Router port: `8085` (`LLAMA_ROUTER_PORT`).
  - Native idle sleep timeout: `900s` (`LLAMA_ROUTER_IDLE_TIMEOUT` passing `--sleep-idle-seconds`). When the router is active with native idle sleep, `llama-server` handles memory sleep natively without Python auto-unloading the model. Native sleep is not equivalent to an explicit model unload (which terminates/evicts the model completely and resets loaded state via `POST /api/v1/models/unload`); the runtime does not claim auto-unload when configured for native idle sleep.
  - Model residency cap: `1` (`LLAMA_ROUTER_MODELS_MAX`).
  - Reference server build: `b10936`.
  *(These constants represent current implementation reality, not eternal architectural locks).*

### 3.2 Hardware Profiles & Reference Baseline

Verified in `backend/app/core/config.py`:
- **Current Reference Hardware:** An AMD Radeon RX 580 (8 GB VRAM) running `llama.cpp` build `b10936` with Vulkan acceleration serves as the active development reference baseline. *(This is current test hardware reality, not a locked release requirement).*
- **Hardware Performance Profiles:**
  - **`eco`:** Context `2048`, GPU layers `0` (pure CPU), threads `4`, multimodal offload disabled.
  - **`balanced`:** Context `4096`, GPU layers `28`, threads `6`, multimodal offload enabled.
  - **`maximum`:** Context `8192`, GPU layers `33`, threads `8`, multimodal offload enabled.

### 3.3 Model Registry, GGUF Parser & Hardware Profiles

Verified in `backend/app/services/model_registry.py` and `backend/app/services/host_config.py`:
- **Metadata Reader (`read_gguf_metadata`):** Pure-Python bounded binary reader parsing GGUF v2/v3 headers (`0x46554747`). Uses file-size-bounded buffered array skipping (`_skip_gguf_array`) for `tokenizer.ggml.*` arrays (`MAX_SKIP_ARRAY_LENGTH = 1_000_000`) and bounded length skipping for `tokenizer.chat_template` (`MAX_CHAT_TEMPLATE_LENGTH = 65_536`), with size/mtime caching (`_GGUF_METADATA_CACHE`) for real `.gguf` files >= 64 KB so trailing metadata keys (`general.file_type`, `general.quantization_version`, `general.name`, `general.size_label`, `general.license`, `clip.has_vision_encoder`) extract reliably without allocating large tokenizer arrays. Strict bounds (`MAX_STRING_LENGTH = 1024`, `MAX_ARRAY_LENGTH = 64`) remain enforced on keys and generic metadata.
- **Registry Merging:** Merges factory template models (`models/registry.template.json`) with persistent user-installed Schema v3 models at `INSTALLED_REGISTRY_PATH` (`<LIBRARY_ROOT>/registry/models.json`) while preserving `capability_provenance`.
- **Canonical Model & Voice Libraries:** Factory models reside under `MODELS_DIR`; user-installed D6 models reside under `MODEL_LIBRARY_DIR` (`<LIBRARY_ROOT>/models/llm/<model_id>/`); voices reside in `VOICE_LIBRARY_DIR` (`<LIBRARY_ROOT>/voices`).
- **Multi-Root `LlamaCppProvider`, Profile & Experimental Context Persistence:** `LlamaCppProvider` resolves assets across factory (`LLAMA_MODELS_DIR`) and installed (`MODEL_LIBRARY_DIR`) roots via strict `registry_source == "installed"` checks, switches/restarts managed router roots cleanly when changing between factory and installed models, initializes `hardware_profile` and `context_mode` from `host_config.json` (`get_saved_hardware_profile()` / `get_saved_context_mode()`), resets tracked active router state cleanly (`SERVER_STOPPED`) when `set_profile(..., context_mode=...)` stops a Core-managed router, exposes `requested_context_mode` plus detected hardware metadata on `ModelStatusResponse` (`PATCH /api/v1/models/profile`), and supports idle promotion via `LLMManager.refresh_auto_provider_if_idle()` after D6 installs.
- **Dynamic Model Selection API & Precedence:** Implemented in `backend/app/api/v1/endpoints/llm.py` (`POST /api/v1/models/select` and `POST /api/v1/models/load`). Model resolution strictly enforces precedence: explicit operation request $\rightarrow$ saved host config (`host_config.json`) $\rightarrow$ development override (`COMPANION_DEV_MODEL`). When no selection exists, load fails closed with `MODEL_SELECTION_REQUIRED` (HTTP 422). If an explicitly selected model is missing from the registry or host filesystem, select/load fails closed with distinct errors (HTTP 404 Not Found or HTTP 400 Bad Request) rather than generic selection failure.
- **Active Development Reference Model:** `qwen3-vl-2b-instruct` (Vision + Text) serves as the approved development reference model in `models/registry.template.json`.

### 3.4 Decision D6 Implementation Status (M2 Batch E)

- **Implemented Components (`PC-MODEL-001`..`006`, `PC-CLIENT-010`):**
  - Canonical path definitions (`IMPORT_INBOX_DIR`, `IMPORT_STAGING_DIR`, `MODEL_LIBRARY_DIR`, `INSTALLED_REGISTRY_PATH`) under `LIBRARY_ROOT` in `app/core/storage.py`.
  - Pure `model_import.py` D6 service: `scan_import_inbox()` (symlink-contained `.gguf` discovery, companion `mmproj` pairing, multi-format safety/engine warnings blocking unsafe `.pt`/`.pth`/`.pkl`/`.ckpt` pickle files and explaining skipped `.safetensors`/`.onnx`/`.bin` files, header/preflight inspection without background watchers), `install_inbox_candidate()` (unique staging directory, SHA-256 verification, atomic `os.replace` into `<MODEL_LIBRARY_DIR>/<model_id>/`, `transfer_mode` `"move"` or `"copy"` for inbox cleanup, Schema v3 `models.json` persistence, idle `auto` provider promotion), and `delete_installed_model()` (`400` on factory, `409` on active/loaded/generating, safe tree cleanup).
  - Host-Admin REST endpoints in `endpoints/llm.py`: `POST /api/v1/models/import/scan`, `POST /api/v1/models/import/install`, and `DELETE /api/v1/models/registry/{model_id}`.
  - Flutter Desktop `SettingsRuntimeSection` (`PC-CLIENT-010`): top **Refresh All** action bar, consumer-first **Add Local Models** panel synced with `DesktopSettingsController.storageRevision` (native Win32 **Add Model Files...** multi-file picker + Copy/Move switch + auto-creating **Open Inbox Folder** + **Scan Inbox** + **Install Bundle**), PC hardware VRAM/RAM summary badge with dynamic `recommendedProfiles` badges + 1-click **Apply Recommended Profile**, interactive Hardware Profile selector (`eco` / `balanced` / `maximum`) + collapsible warning-gated **>8K Experimental** (`16K`, `Model Max`) context selector, user-installed model uninstall action, and collapsed **Advanced Connection & Process** diagnostics. *(Physical Windows GUI verification with a real multi-GB `.gguf` + `mmproj` bundle awaits manual QA; SSE multi-GB copy progress streaming remains an open detail.)*

---

## 4. Remaining Target Architecture (PC V1 / Future)

1. **Streaming D6 Copy Progress (`DEBT-V1-05`):** Optional SSE progress stream during large multi-gigabyte file copies in `install_inbox_candidate()`.
2. **Optional Cloud LLM Fallback Router:** An opt-in provider adapter allowing users to configure cloud LLM access with transparent egress indications and strict local-first defaults (`LOCAL_FIRST`). Local-only execution is the default. Background cloud egress defaults to OFF.

---

## 5. Open Technical Details & Decision Debt

Detailed implementation choices for future planning are tracked in [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md):

- **Integrity & Checksum Algorithms:** Exact hash and tensor verification algorithms for preflight/staging inspection.
- **Automated RAM/VRAM Compatibility Guardrails:** Real-time formula or heuristic alerting users if a chosen model/context length exceeds available host memory.
- **Cloud Provider Integrations:** Evaluation and selection of supported external cloud APIs (Anthropic Claude, OpenAI, Google Gemini, OpenRouter) and credential management interfaces.
- **Managed Downloader UI & Hub Integration:** Design for searching, queuing, and downloading GGUF quantization variants from Hugging Face Hub (scheduled for PC Later).
- **Multi-Model Residency:** Multi-model concurrency is available as a Developer/Advanced configuration requiring explicit user opt-in, accompanied by host capacity checks and strong VRAM warnings.

---

## 6. Security & Ownership Boundaries

- **Local Inference Isolation:** During local inference, prompt/context data remains on the local host and does not require external/cloud egress by default. Current llama.cpp integration exchanges inference payloads over localhost/loopback HTTP between local processes.
- **Cloud Egress Sanitization:** If cloud fallback is engaged, system prompts and context assembly must enforce privacy redaction policies, stripping sensitive profile identifiers, and health data must never be egressed without explicit authorization.
- **Safe Model Format Boundary:** Durable safety rule: Never execute arbitrary untrusted code merely because it is packaged as a model asset. Unsafe executable or deserialization formats (e.g., raw Python pickles) require explicit safe handling or are rejected by the relevant importer. Current llama.cpp provider uses GGUF tensor format; safe runtime-specific formats (such as ONNX) may be supported where separately approved in provider-specific future work without permanently locking GGUF as the sole architectural format.
- **Controlled Import Filesystem Boundary:** A browser, desktop, or mobile client model-import workflow must never grant unrestricted host filesystem path authority. Local file imports must enter strictly through the controlled Decision D6 import boundary rather than passing arbitrary host filesystem paths.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Decision Spine
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline inference model, Decision D6 (Model import pipeline), Optional Cloud LLM Fallback.
- [`docs/02_Planning/00_Master/DECISION_REGISTER.md`](../../02_Planning/00_Master/DECISION_REGISTER.md) — Master Decision Register (D6 Model Acquisition, Residency).
- [`docs/02_Planning/00_Master/DECISION_DEBT.md`](../../02_Planning/00_Master/DECISION_DEBT.md) — Open technical debt and deferred model tooling items.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) — Conversational orchestration and token streaming.
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Canonical filesystem paths and model storage roots.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Resource governance, gaming mode throttling, and VRAM management.
- [`docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`](mobile-capabilities-and-runtime.md) — Mobile capability qualification, inference runtimes, and local execution policy.

