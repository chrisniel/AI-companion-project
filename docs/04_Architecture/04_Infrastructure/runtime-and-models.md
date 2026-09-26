# Runtime and Models Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the local inference runtime, hardware execution model, model registry lifecycle, and cloud fallback boundaries for the AI Companion:
- Provider-independent LLM orchestration layer.
- Primary local-first inference architecture supporting offline core/local companion operation without cloud LLM dependency.
- Decision D6 local model import pipeline (`inbox` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `atomic install` $\rightarrow$ `library` $\rightarrow$ `registry`).
- Model registry, artifact identity, capability metadata, and validation lifecycles.
- Phased model acquisition separating PC V1 local import from post-V1 online model hub downloads.
- Opt-in, transparent Cloud LLM Fallback boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Local-First & Hardware Independence

- **Local Inference is Primary & Default:** The AI Companion is architected fundamentally as a private, locally hosted AI system. Core/local companion operation remains supported without cloud LLM dependency, and local-only operation remains valid. Naturally network-dependent integrations such as Web Search, Fetch, Weather, or current information require network connectivity.
- **Provider & Hardware Independence:** The conversational orchestrator interacts with language models through an abstract provider interface. The architecture does not permanently lock a single runtime binary, backend driver, or hardware vendor. While the current implementation utilizes `llama.cpp` over Vulkan, the durable architecture accommodates ONNX Runtime, DirectML, ROCm, CUDA, or alternative execution engines where separately approved.
- **Bounded Resource Residency:** Resource residency must remain bounded and safe for host capacity. Current implementation uses `LLAMA_ROUTER_MODELS_MAX = 1` as reference resource policy. Future multi-model residency remains open design.

### 2.2 Model Import Pipeline (Decision D6)

In accordance with Decision D6, local model acquisition enforces a six-stage controlled pipeline:
$$\text{Inbox} \longrightarrow \text{Preflight} \longrightarrow \text{Staging} \longrightarrow \text{Atomic Install} \longrightarrow \text{Library} \longrightarrow \text{Registry}$$
1. **Inbox:** User deposits model files into `IMPORT_INBOX_DIR`.
2. **Preflight:** Inspects file headers, verifies format metadata, and estimates memory requirements against host capacity.
3. **Staging:** Moves validated models to `IMPORT_STAGING_DIR` for integrity validation.
4. **Atomic Install:** Atomically moves the verified file into the canonical `MODEL_LIBRARY_DIR` (`COMPANION_DATA_ROOT/library/models/llm`).
5. **Library:** The file resides in canonical permanent storage under managed paths.
6. **Registry:** Updates the active model registry at `COMPANION_DATA_ROOT/library/registry/models.json`, exposing the model with declared capabilities (context length, vision support, recommended prompt template) to the runtime.

### 2.3 Managed Online Model Downloading (PC Later)

In accordance with the Feature Promotion Map (**Managed Online Model Downloading**):
- **Classification:** `APPROVED / NOT STARTED / PC LATER`.
- **Policy Invariant:** In-app discovery and downloading of models from public hubs (e.g., Hugging Face) is an approved architectural track scheduled for post-PC-V1 delivery. It is **not** prohibited, but it is deliberately sequenced after PC V1 to ensure the local file import foundation (Decision D6) is solid and verified first.

### 2.4 Optional Cloud LLM Fallback (PC V1)

In accordance with the Feature Promotion Map (**Optional Cloud LLM Fallback**):
- **Classification:** `APPROVED / NOT STARTED / PC V1`.
- **Architectural Rules:**
  - **Local Remains Primary:** Local inference is always default; cloud fallback is strictly an opt-in auxiliary.
  - **Explicit User Credentials:** The user must explicitly supply their own API keys; the companion distributes no default hosted keys.
  - **Egress Transparency:** Any conversational turn or tool execution routed to an external cloud model must clearly indicate external egress to the user.
  - **Local-Only Preserved:** Disabling cloud fallback preserves supported core/local companion operation in local-only mode. Naturally network-dependent integrations such as Web Search, Fetch, Weather, and current-information retrieval still require network connectivity.
  - **Fallback Routing Open Design:** Fallback activation and routing policy remains open design. There is no automatic cloud egress merely because local inference is constrained.

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
  - `async shutdown() -> None`
- **Concrete Providers:**
  - `LlamaCppProvider` (`llama_cpp.py`): Connects to a local router or launches standalone `llama-server.exe`, tracks Core-managed process state, loads/unloads models via router API, applies profiles, and idle-unloads models. Supports Server-Sent Events (SSE) token streaming via OpenAI-compatible endpoints (`/v1/chat/completions`).
  - `MockLLMProvider` (`mock.py`): Supplies deterministic synthetic token streams for testing.
  - **Cloud Providers:** **NOT IMPLEMENTED**. No OpenAI, Anthropic, or external cloud API client adapter exists in `app/services/llm/`.
- **Process Management & Router Constants:** `scripts/start-model.ps1` exists as a diagnostic/helper script, not the primary runtime launcher. Current implementation constants include:
  - Local loopback host: `127.0.0.1` (never `0.0.0.0`).
  - Router port: `8085` (`LLAMA_ROUTER_PORT`).
  - Auto-unload timeout: `900s` (`LLAMA_ROUTER_IDLE_TIMEOUT`).
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

### 3.3 Model Registry & GGUF Parser

Verified in `backend/app/services/model_registry.py`:
- **Metadata Reader (`read_gguf_metadata`):** Pure-Python binary reader parsing GGUF magic bytes (`0x46554747`), header fields, and key-value string metadata (architecture, context length, chat templates).
- **Registry Merging:** Merges factory template models (`models/registry.template.json`) with persistent user-installed models at `COMPANION_DATA_ROOT/library/registry/models.json` to generate the effective runtime catalog.
- **Canonical Model & Voice Libraries:** Model weights reside in `COMPANION_DATA_ROOT/library/models/llm`; voices reside in `COMPANION_DATA_ROOT/library/voices`.

### 3.4 Decision D6 Implementation Status vs. Gaps

- **Implemented Components:** Canonical path definitions for `IMPORT_INBOX_DIR`, `IMPORT_STAGING_DIR`, and `MODEL_LIBRARY_DIR` in `app/core/storage.py`; GGUF file discovery and header metadata parsing in `model_registry.py`.
- **Implementation Gaps:** An executable D6 controlled import workflow/service is **NOT YET IMPLEMENTED**.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1:

1. **Executable Controlled Import Workflow:** An executable workflow implementing the D6 stages (inbox $\rightarrow$ preflight $\rightarrow$ staging $\rightarrow$ atomic install $\rightarrow$ library $\rightarrow$ registry). Exact execution mechanisms (such as watcher vs. on-demand worker) remain implementation design.
2. **Optional Cloud LLM Fallback Router:** An opt-in provider adapter allowing users to configure cloud LLM access with transparent egress indications and strict local-first defaults. Fallback activation and routing policy remains open design.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Fallback Activation & Routing Policy:** Exact heuristic rules and user toggles for engaging optional cloud fallback (no automatic cloud egress merely because local resources are constrained).
- **D6 Import Execution Mechanism:** Concrete worker architecture (e.g., asynchronous filesystem watcher vs. scheduled background worker vs. REST-triggered import endpoint).
- **Integrity & Checksum Algorithms:** Exact hash and tensor verification algorithms for preflight/staging inspection.
- **Future Multi-Model Residency:** Evaluation of multi-model concurrency for small specialist models (e.g., dedicated classifier, guardrail model, or embedding model concurrent with primary conversational LLM) subject to host capacity.
- **Cloud Provider Integrations:** Evaluation and selection of supported external cloud APIs (e.g., Anthropic Claude, OpenAI, Google Gemini, OpenRouter) and credential management interfaces.
- **Managed Downloader UI & Hub Integration:** Design for searching, queuing, and downloading GGUF quantization variants from Hugging Face Hub (PC Later).
- **Model Compatibility & Guardrails:** Automated validation preventing users from loading GGUFs incompatible with their system RAM or compute capabilities.
- **Logical Model & Artifact Grouping Schema:** Data structures and migration paths for grouping multiple quantization artifacts under a logical model identity.
- **Companion Artifact Binding & Discovery:** Schema and discovery mechanics for associating auxiliary artifacts (e.g., `mmproj` vision projectors) with primary model entries.
- **Status Lifecycle Enums & Capability Provenance:** Concrete schema fields for tracking model lifecycle status (`discovered`, `registered`, `verified`, `incompatible`) and capability confidence provenance (`declared`, `detected`, `verified`).
- **Web-Based Import UX & D6 Boundary:** Client user experience for guided file import into the controlled D6 inbox directory without exposing unrestricted host filesystem picking.

---

## 6. Security & Ownership Boundaries

- **Local Inference Isolation:** During local inference, prompt/context data remains on the local host and does not require external/cloud egress by default. Current llama.cpp integration may exchange inference payloads over localhost/loopback HTTP between local processes.
- **Cloud Egress Sanitization:** If cloud fallback is engaged, system prompts and context assembly must enforce privacy redaction policies, stripping sensitive profile identifiers, and health data must never be egressed without explicit authorization.
- **Safe Model Format Boundary:** Durable safety rule: Never execute arbitrary untrusted code merely because it is packaged as a model asset. Unsafe executable or deserialization formats (e.g., raw Python pickles) require explicit safe handling or are rejected by the relevant importer. Current llama.cpp provider uses GGUF tensor format; safe runtime-specific formats (e.g., ONNX) may be supported where separately approved without permanently locking GGUF as the sole architectural format.
- **Controlled Import Filesystem Boundary:** A browser or web client model-import workflow must never grant unrestricted host filesystem path authority. Local file imports must enter strictly through the controlled Decision D6 import boundary rather than passing arbitrary host filesystem paths.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline inference model, Decision D6 (Model import pipeline), Optional Cloud LLM Fallback.
- [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../LLAMA_CPP_RUNTIME_ARCHITECTURE.md) — Detailed llama.cpp server flags, Vulkan setup, and performance tuning.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) — Conversational orchestration and token streaming.
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Canonical filesystem paths and model storage roots.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Resource governance, gaming mode throttling, and VRAM management.
