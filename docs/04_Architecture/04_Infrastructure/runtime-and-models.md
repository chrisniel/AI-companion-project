# Runtime and Models Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.3).  
> **Status:** Active Working Specification — **AUTHORITY TRANSFER PENDING R11.4**.  
> **Authority Precedence:** Focused staged specification authored during R11.3. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../LLAMA_CPP_RUNTIME_ARCHITECTURE.md) and [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Decision D6, Optional Cloud LLM Fallback) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

---

## 1. Purpose & Scope

This specification defines the local inference runtime, hardware execution model, model registry lifecycle, and cloud fallback boundaries for the AI Companion:
- Provider-independent LLM orchestration layer.
- Primary local-first inference architecture ensuring fully offline companion capability.
- Decision D6 local model import pipeline (`inbox` $\rightarrow$ `preflight` $\rightarrow$ `staging` $\rightarrow$ `atomic install` $\rightarrow$ `library` $\rightarrow$ `registry`).
- Phased model acquisition separating PC V1 local import from post-V1 online model hub downloads.
- Opt-in, transparent Cloud LLM Fallback boundaries.

---

## 2. Durable Architecture & Invariants

### 2.1 Local-First & Hardware Independence

- **Local Inference is Primary & Default:** The AI Companion is architected fundamentally as a private, locally hosted AI system. The companion must remain fully functional with zero internet connectivity and zero external cloud dependencies.
- **Provider & Hardware Independence:** The conversational orchestrator interacts with language models through an abstract provider interface. The architecture does not permanently lock a single runtime binary, backend driver, or hardware vendor. While current implementations utilize `llama.cpp` over Vulkan, the durable architecture accommodates ONNX Runtime, DirectML, ROCm, CUDA, or alternative execution engines.
- **Controlled Concurrency & Single-Residency Invariant:** On consumer workstations, LLM memory residency is carefully managed to prevent VRAM exhaustion and host freeze. Active model residency defaults to one primary conversational model at a time, governed by an idle timeout and explicit unloading.

### 2.2 Model Import Pipeline (Decision D6)

In accordance with Decision D6, local model acquisition enforces a six-stage controlled pipeline:
$$\text{Inbox} \longrightarrow \text{Preflight} \longrightarrow \text{Staging} \longrightarrow \text{Atomic Install} \longrightarrow \text{Library} \longrightarrow \text{Registry}$$
1. **Inbox:** User deposits a `.gguf` file into `IMPORT_INBOX_DIR`.
2. **Preflight:** Inspects file headers, verifies GGUF magic bytes, reads architecture metadata, and estimates VRAM requirements against host capacity.
3. **Staging:** Moves valid models to `IMPORT_STAGING_DIR` while calculating SHA256 checksums and verifying tensor integrity.
4. **Atomic Install:** Atomically moves the verified file into the canonical `MODEL_LIBRARY_DIR`.
5. **Library:** The file resides in canonical permanent storage under managed paths.
6. **Registry:** Updates the active `installed_registry.json`, exposing the model with declared capabilities (context length, vision support, recommended prompt template) to the runtime.

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
  - **Local-Only Preserved:** Disabling cloud fallback leaves the companion fully operational in local-only mode.

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

### 3.1 Provider Abstraction & llama.cpp Driver

Verified in `backend/app/services/llm/`:
- **Provider Interface (`base.py`):** Defines `LLMProvider` protocol with async methods `generate()`, `generate_stream()`, `get_state()`, and health probes.
- **Concrete Providers:**
  - `LlamaCppProvider` (`llama_cpp.py`): Connects to a local `llama-server.exe` instance via OpenAI-compatible endpoints (`/v1/chat/completions`). Supports Server-Sent Events (SSE) token streaming.
  - `MockLLMProvider` (`mock.py`): Supplies deterministic synthetic token streams for testing.
  - **Cloud Providers:** **NOT IMPLEMENTED**. No OpenAI, Anthropic, or external cloud API client adapter exists in `app/services/llm/`.
- **Router Process Management:** Diagnostic startup is handled via `scripts/start-model.ps1`. The server runs with configuration:
  - Local loopback host: `127.0.0.1` (never `0.0.0.0`).
  - Diagnostic port: `8085` (`LLAMA_ROUTER_PORT`).
  - Auto-unload timeout: `900s` (`LLAMA_ROUTER_IDLE_TIMEOUT`).
  - Model residency cap: `1` (`LLAMA_ROUTER_MODELS_MAX`).

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
- **Registry Merging:** Merges factory template models (`models/registry.template.json`) with persistent user-installed models (`installed_registry.json`) to generate the effective runtime catalog.

### 3.4 Decision D6 Implementation Status vs. Gaps

- **Implemented Components:** Canonical path definitions for `IMPORT_INBOX_DIR`, `IMPORT_STAGING_DIR`, and `MODEL_LIBRARY_DIR` in `app/core/storage.py`; GGUF header validation and metadata parsing in `model_registry.py`.
- **Implementation Gaps:** Automated background file watching on the inbox folder, automated staging preflight validation workers, and user-facing import REST endpoints are **NOT YET IMPLEMENTED**.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1:

1. **Automated D6 Import Worker:** An asynchronous filesystem watcher and validation pipeline that moves dropped `.gguf` files through preflight checks, stages them, copies them to the library, and registers them automatically.
2. **Dynamic Provider Fallback Router:** An orchestration adapter that evaluates local model readiness and seamlessly routes conversational turns to an approved Cloud LLM provider when local resources are constrained or specialized capabilities are requested.
3. **Model Unload / Reload Management:** Robust host supervision that unloads the LLM process on host idle and safely re-launches it upon conversational demand.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future implementation plans:

- **Cloud Provider Integrations:** Evaluation and selection of supported external cloud APIs (e.g., Anthropic Claude, OpenAI, Google Gemini, OpenRouter) and credential management interfaces.
- **Routing & Fallback Thresholds:** Exact heuristic rules for triggering cloud fallback (e.g., local server unresponsive, VRAM exhausted, context exceeds local model limits, or user-toggled "High-Reasoning Mode").
- **Managed Downloader UI & Hub Integration:** Design for searching, queuing, and downloading GGUF quantization variants from Hugging Face Hub (PC Later).
- **Model Compatibility & Guardrails:** Automated validation preventing users from loading GGUFs incompatible with their system RAM or compute capabilities.
- **Future Multi-Model Residency:** Evaluation of multi-model concurrency for small specialist models (e.g., dedicated classifier, guardrail model, or embedding model concurrent with primary conversational LLM).

---

## 6. Security & Ownership Boundaries

- **Local Inference Isolation:** Local inference generates zero outbound network traffic. Prompt tokens, character lore, and conversational history remain entirely on host RAM/VRAM.
- **Cloud Egress Sanitization:** If cloud fallback is engaged, system prompts and context assembly must enforce privacy redaction policies, stripping sensitive profile identifiers.
- **Executable Binary Safety:** All model weights are loaded exclusively via tensor data formats (`.gguf`). Executing untrusted arbitrary code or loading unsafe Python pickle formats (`.bin`, `.pt`) is strictly prohibited.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Baseline inference model, Decision D6 (Model import pipeline), Optional Cloud LLM Fallback.
- [`docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`](../LLAMA_CPP_RUNTIME_ARCHITECTURE.md) — Detailed llama.cpp server flags, Vulkan setup, and performance tuning.

### Related Domain & Infrastructure Specifications
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) — Conversational orchestration and token streaming.
- [`docs/04_Architecture/04_Infrastructure/storage-and-assets.md`](storage-and-assets.md) — Canonical filesystem paths and model storage roots.
- [`docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`](performance-and-capacity.md) — Resource governance, gaming mode throttling, and VRAM management.
