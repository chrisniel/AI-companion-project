# AI Companion — PC V1 Decision Debt & Open Implementation Details

> **Document Role:** Authoritative catalog of approved implementation-open details, benchmark-dependent parameters, and deferred improvement candidates.  
> **Status:** Active Canonical Planning Baseline  
> **Governance Invariant:** PC V1 architecture is FROZEN. Do not use Decision Debt to casually reopen agreed architecture. This register captures technical mechanism choices, empirical evidence needs, and implementation parameters that were deliberately left open.

---

## 1. Classification Categories

| Category | Definition | Action Required |
| :--- | :--- | :--- |
| **`V1 BLOCKER`** | Implementation detail that must be resolved before a specific PC V1 milestone can finish. | Resolve during respective milestone planning. |
| **`V1 OPEN DETAIL`** | Approved functional requirement where the exact code mechanism is intentionally flexible. | Design during feature implementation. |
| **`PC-LATER / V2`** | Valid architectural enhancement explicitly deferred to post-PC-V1 releases. | Revisit during V2 planning. |
| **`EXPERIMENT NEEDED`**| Parameter or threshold that requires empirical workstation benchmarking. | Execute benchmark spike to tune values. |

---

## 2. Decision Debt Item Inventory

### Category: `V1 BLOCKER`
- **`DEBT-V1-01`: Windows Task Scheduler vs. Startup Folder Implementation**
  - *Context:* Decision D2 mandates autostart at login. The exact registration mechanism (Task Scheduler XML vs. Windows Startup shortcut `shell:startup`) must be selected.
  - *Current Direction:* Task Scheduler configured for `At log on` is preferred because it runs decoupled from console windows and supports auto-restart on unexpected exit.
  - *Resolution Point:* Milestone M2 planning.

- **`DEBT-V1-02`: Windows Native Toast Library Selection in Python**
  - *Context:* Closed-browser native notification delivery is required for PC V1. Python backend needs a reliable Windows Toast dispatcher.
  - *Candidates:* `windows-toasts` (modern WinRT toast library with button callbacks) vs. direct WinRT bindings (`winsdk`) vs. decoupled notification worker.
  - *Resolution Point:* Milestone M2 planning.

- **`DEBT-V1-03`: Multi-Profile Database Migration Schema Design**
  - *Context:* Transitioning from single-user `owner_id` to multi-Profile `profile_id` (ADR-0018).
  - *Requirement:* Must provide an Alembic migration (007) that cleanly wraps existing data into a default primary Profile without data loss.
  - *Resolution Point:* Milestone M2 planning.

- **`DEBT-V1-04`: Local STT & TTS Process Architecture**
  - *Context:* Pre-staged binaries (`runtime/whisper.cpp/`) and Kokoro-82M ONNX weights exist locally.
  - *Decision Needed:* Subprocess daemons over localhost/HTTP (matching `llama-server.exe`) vs. in-process Python C-bindings (requiring `onnxruntime` + audio libraries in `backend/.venv`).
  - *Current Direction:* Subprocess daemon for `whisper.cpp` avoids heavy Python audio/C-extension dependencies in the backend.
  - *Resolution Point:* Milestone M4 planning.

### Category: `V1 OPEN IMPLEMENTATION DETAIL`
- **`DEBT-V1-05`: D6 Import UI Interaction & Progress Reporting**
  - *Context:* D6 requires manual user scan of inbox and preflight review.
  - *Open Detail:* Exact REST endpoint contract (`POST /api/v1/models/scan`, `POST /api/v1/models/import`) and SSE progress event stream during large multi-gigabyte file copies.
  - *Resolution Point:* Milestone M2 implementation plan.

- **`DEBT-V1-06`: Selective Automatic Memory Extraction Cadence & Prompts**
  - *Context:* Assistant evaluates conversation turns for clear, stable user facts.
  - *Open Detail:* Inline prompt evaluation in conversation turn vs. asynchronous background task; prompt heuristics for distinguishing permanent facts from transient statements.
  - *Resolution Point:* Milestone M3 implementation plan.

- **`DEBT-V1-07`: Low-Impact Option B Game List Storage Format**
  - *Context:* Low-Impact mode auto-activates when a configured game or heavy app is focused.
  - *Open Detail:* Configuration storage in `settings.json` vs. database; executable process name matching vs. window title matching; hysteresis cooldown timeout (e.g., 30–60s).
  - *Resolution Point:* Milestone M5 implementation plan.

- **`DEBT-V1-08`: Temporary Memory Expiration Sweep Frequency**
  - *Context:* Temporary memories have `valid_from` and `expires_at` metadata.
  - *Open Detail:* Immediate query-time filtering vs. background periodic expiration sweeper in `SchedulerService`.
  - *Resolution Point:* Milestone M3 implementation plan.

### Category: `EXPERIMENT / EVIDENCE NEEDED`
- **`DEBT-EXP-001`: Low-Impact Lightweight Model Benchmark on RX 580**
  - *Context:* Low-Impact mode swaps in a 1B–3B text model to conserve VRAM/compute during gaming.
  - *Need:* Empirical benchmark testing candidate GGUF models (e.g., Qwen-2.5-1.5B, Llama-3.2-1B/3B, Gemma-2-2B) on AMD RX 580 to verify VRAM footprint under 1.5 GB and sub-second prompt evaluation.
  - *Resolution Point:* Milestone M5 discovery spike.

- **`DEBT-EXP-002`: Kokoro-82M Neural Synthesis RTF on Reference CPU**
  - *Context:* Real-time factor (RTF) for Kokoro-82M on AMD Ryzen 5 3600 CPU cores.
  - *Need:* Benchmark ONNX quantized model execution on CPU to ensure RTF < 0.3x without starving foreground games.
  - *Resolution Point:* Milestone M4 discovery spike.

- **`DEBT-EXP-003`: Emotion Decay Rate Tuning**
  - *Context:* Simulated companion mood decays toward neutral over elapsed time.
  - *Need:* Tune decay half-life curves (e.g., 4-hour vs. 12-hour rebalancing) through experiential testing.
  - *Resolution Point:* Milestone M3 tuning.

### Category: `PC-LATER / V2 IMPROVEMENT CANDIDATE`
- **`DEBT-LATER-001`: Semantic / Vector Memory Retrieval (sqlite-vec)**
  - *Context:* Post-V1 addition of dense vector embeddings alongside SQLite FTS5 lexical search.
- **`DEBT-LATER-002`: Managed Public Model Hub Downloads**
  - *Context:* In-app browsing and downloading directly from Hugging Face / Ollama.
- **`DEBT-LATER-003`: Advanced Presence (Live2D / VRM / Floating Overlay)**
  - *Context:* Interactive animated 2D/3D avatars and floating desktop widgets.
- **`DEBT-LATER-004`: Interactive Browser Automation (Playwright)**
  - *Context:* Automated web form completion and multi-step web transactions.
- **`DEBT-LATER-005`: Mobile-to-PC Full Bidirectional State Synchronization**
  - *Context:* Room database outbox synchronization for the follow-on Android companion pass.
