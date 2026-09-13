# llama.cpp Runtime Architecture Specification

**Project:** AI Companion Project  
**Architecture Area:** Local LLM Runtime, Persistent Router & Hardware Offload  
**Document Role:** Canonical runtime architecture and execution specification  
**Document Status:** Approved Architecture / Active Baseline  
**Pinned Baseline:** `llama.cpp` b10936 (Windows x86_64, Vulkan build in `runtime/llama.cpp/`)
**Primary Host:** Windows 11 Local AI Runtime

> **Scope note:** This document owns llama.cpp-specific lifecycle, router architecture, port/profile/sleep/PID behavior, and hardware offload details. General configuration domains, persistent storage layout, `COMPANION_DATA_ROOT`, model-manifest contract, and asset-library rules are defined canonically in `docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`.
**Primary GPU Target:** AMD Aisurix RX 580 2048SP (8 GB VRAM)  
**Primary RAM Target:** 16 GB System DDR4 RAM  

---

## 1. Executive Summary & Principles

The AI Companion project uses a local build of `llama.cpp` as its primary inference engine. To ensure stable coexistence with desktop workloads, development, and gaming on an 8 GB VRAM GPU, the runtime architecture follows six core invariants:

1. **Persistent Router Mode (`--models-max 1`):** A single persistent `llama-server.exe` router process runs in the background. It manages model weights dynamically via HTTP lifecycle endpoints (`/models/load`, `/models/unload`) without needing complete process restarts for every model switch.
2. **FastAPI Is the Sole Authenticated Boundary:** `llama-server.exe` binds strictly to `127.0.0.1:8080`. External clients (React Web, Android Companion) never communicate directly with `llama-server`. All requests pass through FastAPI on `127.0.0.1:8000` with strict Bearer/X-API-Key token validation and input sanitization.
3. **One Primary Model Resident:** While multiple GGUF models reside on disk, exactly one generative model (plus its optional `mmproj` multimodal projector) is loaded into VRAM at any given time.
4. **Distinct Lifecycle Semantics (Sleep vs. Unload vs. Terminate):**
   - **Automatic Sleep:** Native idle timeout (`--sleep-idle-seconds 900`) releases GPU memory when inactive. The router remains running, and subsequent inference requests automatically wake the model.
   - **Explicit Unload:** User clicks **[ Unload VRAM ]** in Web or Android. The model is cleanly evicted, releasing ~5 GB VRAM. The router stays alive.
   - **Scoped PID Termination:** Used solely as an emergency fallback if the router crashes or hangs. Process termination targets only the specific PID spawned by Local AI Runtime; blind `taskkill /IM llama-server.exe /F` is strictly forbidden.
5. **Decoupled Model Choice and Runtime Profile:** Model selection (e.g. `Qwen3-VL-4B-Instruct`), Runtime Profile (`Eco`, `Balanced`, `Maximum`), and Convenience Presets are independent dimensions.
6. **No Fabricated Telemetry:** All VRAM readings, token generation speeds, and memory metrics must derive from verified OS/driver probes (`psutil`, AMD ADL / GPU-Z) or upstream engine metrics, never synthetic approximations.

---

## 2. Target Runtime Topology

```text
               ┌──────────────────────────────────────────────┐
               │         Client Layer (Web & Android)         │
               └──────────────────────┬───────────────────────┘
                                      │ Authenticated HTTP / SSE (Bearer Token)
                                      ▼
               ┌──────────────────────────────────────────────┐
               │            FastAPI Local AI Runtime             │
               │               127.0.0.1:8000                 │
               │                                              │
               │  ┌────────────────────────────────────────┐  │
               │  │ AssistantOrchestrator                  │  │
               │  │  - Context budget & trust framing      │  │
               │  │  - SQLite FTS5 memory injection        │  │
               │  └───────────────────┬────────────────────┘  │
               │                      ▼                       │
               │  ┌────────────────────────────────────────┐  │
               │  │ LLMManager / llama_cpp Service         │  │
               │  │  - ModelRegistry & GGUF path resolver  │  │
               │  │  - RuntimeStateManager & lifecycle    │  │
               │  │  - Process ownership tracking (PID)    │  │
               │  └───────────────────┬────────────────────┘  │
               └──────────────────────┼───────────────────────┘
                                      │ Localhost only (127.0.0.1:8080)
                                      ▼
               ┌──────────────────────────────────────────────┐
               │           llama-server Router                │
               │               b10936 Vulkan                  │
               │                                              │
               │  • POST /models/load                         │
               │  • POST /models/unload                       │
               │  • POST /v1/chat/completions (SSE stream)    │
               │  • GET  /health & /metrics                   │
               │  • Idle sleep timer (900s)                   │
               └──────────────────────┬───────────────────────┘
                                      │ Vulkan GPU Offload
                                      ▼
               ┌──────────────────────────────────────────────┐
               │        Aisurix AMD RX 580 8 GB VRAM          │
               │   (Max 1 resident model: 2B / 4B / 8B GGUF)  │
               └──────────────────────────────────────────────┘
```

---

## 3. Persistent Router Launch Specification

When the backend initializes the local LLM runtime, it executes `llama-server.exe` with absolute paths:

```powershell
runtime\llama.cpp\llama-server.exe `
  --host 127.0.0.1 `
  --port 8080 `
  --models-dir D:\OtherProjects\AI-companion-project\models `
  --models-max 1 `
  --sleep-idle-seconds 900 `
  --parallel 1 `
  --no-webui `
  --metrics `
  --log-file data\llama_server.log
```

### Launch Flags & Invariants:
- `--models-dir`: Absolute path to models root. No relative paths or client-supplied directory traversal.
- `--models-max 1`: Enforces single-model residency in VRAM.
- `--sleep-idle-seconds 900`: Configures 15-minute native inactivity sleep.
- `--no-webui`: Disables embedded upstream HTML interface to ensure FastAPI is the sole frontend gateway.
- `--log-file`: Logs routed strictly to root `data/llama_server.log` outside `backend/` to prevent WatchFiles hot-reload loops.

---

## 4. Semantic Runtime State Model

The runtime reports normalized semantic states reflecting the true status of both the router daemon and the resident model:

```text
    ┌────────────────┐
    │ SERVER_STOPPED │
    └───────┬────────┘
            │ spawn router subprocess
            ▼
    ┌────────────────┐
    │SERVER_STARTING │
    └───────┬────────┘
            │ port 8080 healthy
            ▼
    ┌────────────────┐
    │ MODEL_UNLOADED │◄───────────────────────────┐
    └───────┬────────┘                            │
            │ load request                        │ explicit unload
            ▼                                     │
    ┌────────────────┐                            │
    │ MODEL_LOADING  │                            │
    └───────┬────────┘                            │
            │ weights resident in VRAM            │
            ▼                                     │
    ┌────────────────┐     idle > 900s     ┌──────────────┐
    │  MODEL_READY   │────────────────────►│MODEL_SLEEPING│
    └───────┬────────┘                     └──────┬───────┘
            ▲                                     │
            │ prompt arrives / wake               │
            └─────────────────────────────────────┘
```

### State Definitions:
- `SERVER_STOPPED`: `llama-server.exe` process is not running.
- `SERVER_STARTING`: Process spawned, waiting for HTTP readiness on `http://127.0.0.1:8080/health`.
- `MODEL_UNLOADED`: Router process is active and listening, but 0 model weights are resident in VRAM.
- `MODEL_LOADING`: Engine is reading GGUF weights from NVMe and transferring layers to Vulkan VRAM.
- `MODEL_READY`: Model fully loaded and warm, ready for instant inference.
- `MODEL_SLEEPING`: Engine put weights to sleep after 900s inactivity. VRAM is released; next token request will wake the model.
- `MODEL_UNLOADING`: Transitioning from resident to unloaded.
- `MODEL_ERROR`: Model failed to load or crashed during generation.
- `SERVER_ERROR`: Router daemon died unexpectedly or port is unreachable.

---

## 5. Explicit Load / Unload Lifecycle Semantics

### Explicit Load Flow
1. Client issues `POST /api/v1/models/load` with `{ "model_name": "Qwen3-VL-4B-Instruct-Q4_K_M.gguf" }`.
2. FastAPI validates:
   - File exists inside `MODELS_DIR`.
   - File has valid `.gguf` extension.
   - Name contains no path traversal sequences (`..`, `/`, `\`).
3. State transitions to `MODEL_LOADING`.
4. FastAPI issues `POST http://127.0.0.1:8080/models/load`.
5. When the engine responds 200 OK, telemetry probes measure resident VRAM and state transitions to `MODEL_READY`.

### Explicit Unload Flow
1. Client issues `POST /api/v1/models/unload`.
2. Check `generation_active`:
   - If active inference is streaming, reject with `409 Conflict (MODEL_BUSY)` or trigger client abort.
3. State transitions to `MODEL_UNLOADED`.
4. FastAPI issues `POST http://127.0.0.1:8080/models/unload`.
5. Engine releases GPU allocations. VRAM drops to ~0.0 GB (base display usage). Router remains alive on `127.0.0.1:8080`.

### Scoped Process Termination (Fallback Only)
If the router becomes totally unresponsive (e.g. driver hang during Vulkan kernel compilation):
1. Retrieve `self._process.pid` stored during startup.
2. Verify that the PID matches the Core-owned subprocess handle.
3. Terminate only that PID via `process.kill()` / Win32 `TerminateProcess`.
4. Reset state to `SERVER_STOPPED`. Never execute `taskkill /IM llama-server.exe /F`.

---

## 6. Model Selection vs. Runtime Profile Decoupling

The runtime separates model identity from execution parameters:

```text
               ┌──────────────────────────────────────────────┐
               │                Selected Model                │
               │   e.g. Qwen3-VL-4B-Instruct / 2B-Thinking    │
               └──────────────────────┬───────────────────────┘
                                      │ +
                                      ▼
               ┌──────────────────────────────────────────────┐
               │               Runtime Profile                │
               │          [Eco / Balanced / Maximum]          │
               └──────────────────────┬───────────────────────┘
                                      │ =
                                      ▼
               ┌──────────────────────────────────────────────┐
               │           Concrete Technical Flags           │
               │  - GPU Offload Layers: 20 vs 28 vs 33        │
               │  - Context Window: 2048 vs 4096 vs 8192      │
               │  - Flash Attention: Enabled / Disabled       │
               │  - KV Cache Quantization: FP16 vs Q8_0       │
               │  - CPU Threads: 4 vs 6                       │
               └──────────────────────────────────────────────┘
```

### Profile Parameter Mapping for RX 580 (8 GB):

| Parameter | Eco Profile | Balanced Profile (Default) | Maximum Profile |
|---|---|---|---|
| **Context Window (`-c`)** | 2048 tokens | 4096 tokens | 8192 tokens |
| **GPU Offload Layers (`-ngl`)** | 20 layers | 28 layers | 33 layers (Full offload) |
| **KV Cache Type (`--cache-type-k/v`)** | `q8_0` | `q8_0` | `f16` |
| **Batch / UBatch (`-b`, `-ub`)** | 256 / 128 | 512 / 256 | 512 / 512 |
| **Flash Attention (`-fa`)** | Enabled | Enabled | Enabled |
| **CPU Threads (`-t`)** | 4 threads | 4 threads | 6 threads |
| **Target VRAM Footprint** | ~2.5–3.2 GB | ~3.8–4.8 GB | ~6.0–7.2 GB |

---

## 7. Composite Multimodal Artifacts

Multimodal Vision-Language models (Qwen3-VL) consist of two binary files:
1. **Primary Weights:** `Qwen3-VL-4B-Instruct-Q4_K_M.gguf`
2. **Vision Projector:** `mmproj-Qwen3-VL-4B-Instruct-f16.gguf`

### Architectural Handling:
- The `ModelRegistry` treats these two files as **one logical model entry**.
- The UI exposes a single selection card: `"Qwen3-VL-4B-Instruct"`.
- When loaded, FastAPI passes both the main model path and `--mmproj <PATH_TO_MMPROJ>` to the engine.
- If the projector file is missing from disk, the registry marks `validation_status = "missing_companion"` and prohibits loading.

---

## 8. RX 580 Hardware Benchmark Protocol

Before any model candidate is approved for production presets, it must be benchmarked using the standard protocol:

| Benchmark Phase | Description | Expected VRAM | Expected RAM | Measurement Point |
|---|---|---|---|---|
| **Phase A** | Router daemon only (no model) | ~0.1 GB | ~40 MB | Baseline after router startup |
| **Phase B** | Model loading | Peak allocation | Peak allocation | Duration: `load_time_ms` |
| **Phase C** | Model warm & ready | Static allocation | Static allocation | Post-load steady state |
| **Phase D** | Active inference (streaming) | Active VRAM | Active RAM | Generation speed: `tokens/sec` |
| **Phase E** | Active vision inference | VRAM + mmproj | RAM + image | Time-to-First-Token on 1080p image |
| **Phase F** | Native idle sleep (after 900s) | Reclaimed (~0.1 GB) | Maintained / reduced | Idle release verified in GPU-Z |
| **Phase G** | Wake from sleep | Reloads to Phase C | Restored | Duration: `wake_time_ms` |
| **Phase H** | Explicit unload | 0.0 GB (released) | Baseline | VRAM instantly released |
