# AI Companion — Decision Debt & Open Implementation Details (PC V1 & Mobile V1)

> **Document Role:** Authoritative catalog of approved implementation-open details, benchmark-dependent parameters, and deferred improvement candidates.
> **Status:** Active Canonical Planning Baseline
> **Governance Invariant:** PC V1 architecture remains FROZEN. Approved Mobile V1 architecture is also indexed here, with Mobile implementation-open details tracked separately under Section 2 (`MOBILE V1 OPEN IMPLEMENTATION DETAIL`). This register captures technical mechanism choices, empirical evidence needs, and implementation parameters that were deliberately left open without reopening agreed architecture.

---

## 1. Classification Categories

| Category | Definition | Action Required |
| :--- | :--- | :--- |
| **`V1 BLOCKER`** | Implementation detail that must be resolved before a specific PC V1 milestone can finish. | Resolve during respective milestone planning. |
| **`V1 OPEN DETAIL`** | Approved functional requirement where the exact code mechanism is intentionally flexible. | Design during feature implementation. |
| **`MOBILE V1 OPEN DETAIL`** | Approved Mobile V1 functional requirement where the code mechanism or parameter is open design. | Design during respective Mobile feature implementation. |
| **`PC-LATER / V2`** | Valid architectural enhancement explicitly deferred to post-PC-V1 releases. | Revisit during V2 planning. |
| **`EXPERIMENT NEEDED`**| Parameter or threshold that requires empirical workstation benchmarking. | Execute benchmark spike to tune values. |

---

## 2. Decision Debt Item Inventory

### Category: `V1 BLOCKER`
- **`DEBT-V1-01`: Windows Task Scheduler vs. Startup Folder Implementation**
  - *Context:* Decision D2 mandates autostart at login. The exact registration mechanism (Task Scheduler XML vs. Windows Startup shortcut `shell:startup`) must be selected.
  - *Current Direction:* Task Scheduler configured for `At log on` is preferred because it runs decoupled from console windows and supports auto-restart on unexpected exit.
  - *Resolution Point:* Milestone M2 planning.

- **`DEBT-V1-02`: Flutter Windows Native Toast Adapter Selection**
  - *Context:* The Local AI Runtime owns durable scheduling, due-event truth, and backlog. Flutter Desktop owns native Windows Toast presentation, including catch-up after client relaunch ([canonical boundary](../../04_Architecture/04_Infrastructure/windows-host-and-notifications.md)).
  - *Decision Needed:* Select the Flutter Windows notification plugin or platform-channel/native adapter and verify activation callbacks and presentation behavior. The implementation choice remains OPEN; Python does not own native Toast presentation.
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
  - *Need:* Emotion decay/rebalancing function and time constants require empirical tuning.
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
- **`DEBT-LATER-005`: Mobile-to-PC Full Bidirectional State Synchronization [RESOLVED / SUPERSEDED]**
  - *Resolution:* Superseded and resolved by approved Mobile synchronization architecture in [`mobile-offline-and-sync.md`](../../04_Architecture/04_Infrastructure/mobile-offline-and-sync.md) (asymmetric per-domain sync, durable outbox, client-generated stable entity IDs, monotonic revision checks, typed `CONFLICT_DETECTED` and `STALE_CURSOR` outcomes).

### Category: `MOBILE V1 OPEN IMPLEMENTATION DETAIL`
- **`DEBT-MOB-01`: Mobile Device Credential Expiry & Rotation Timing/Handshake**
  - *Context:* Independent rotation of Device Token without profile alteration is approved (`MOBILE_SYSTEM_BASELINE.md` §4.3, `mobile-capabilities-and-runtime.md` §5.3).
  - *Open Detail:* Exact expiry periods, token format, overlap/grace windows, and automated refresh protocol.
  - *Resolution Point:* Stream `MOB-IDENTITY-003` implementation plan.

- **`DEBT-MOB-02`: Synchronization Change-History Retention Horizon**
  - *Context:* Host maintains bounded change-history retention for delta sync and tombstone propagation (`mobile-offline-and-sync.md` §3.2.5).
  - *Open Detail:* Exact retention horizon duration (decoupled from user-facing 30-day recycle bin).
  - *Resolution Point:* Stream `MOB-CONTRACT-004` / `MOB-SYNC-005` implementation plan.

- **`DEBT-MOB-03`: Flutter/Android Secure Storage Adapter Selection**
  - *Context:* Platform-protected Keystore-backed storage is mandatory; unencrypted SharedPreferences is prohibited (`mobile-offline-and-sync.md` §2.2, `mobile-capabilities-and-runtime.md` §5.1).
  - *Open Detail:* Exact Dart package abstraction (`flutter_secure_storage` with Keystore vs custom platform channel).
  - *Resolution Point:* Stream `MOB-IDENTITY-002` implementation plan.

- **`DEBT-MOB-04`: Mobile Local Inference Runtime & Container Selection**
  - *Context:* Pluggable mobile inference engine on qualified Tier 2/3 hardware (`mobile-capabilities-and-runtime.md` §2.2).
  - *Open Detail:* Specific library/container runtime (e.g. ExecuTorch vs llama.cpp Android) and compilation flags.
  - *Resolution Point:* Stream `MOB-INFER-004` implementation plan.

- **`DEBT-MOB-05`: Mobile Local TTS Provider Selection**
  - *Context:* Capability-dependent device-local TTS for alarm/text vocalization (`mobile-capabilities-and-runtime.md` §3.2).
  - *Open Detail:* Candidate reference Kokoro-82M vs Sherpa-ONNX vs Android system TTS provider.
  - *Resolution Point:* Stream `MOB-VOICE-005` implementation plan.

- **`DEBT-MOB-06`: Disconnected Conversation Branch Review/Merge UX and Batch Turn Import Schema**
  - *Context:* Atomic whole-turn sync and causal thread branching upon reconnection are approved (`mobile-offline-and-sync.md` §3.2.6).
  - *Open Detail:* Exact FastAPI endpoint DTO schema and user-facing branch merge/inspection UI design.
  - *Resolution Point:* Stream `MOB-CONTRACT-006` / `MOB-SYNC-007` implementation plan.

- **`DEBT-MOB-07`: Mobile Evidence-Driven L3 Emulator & Device Test Matrix Configuration**
  - *Context:* 5-layer test matrix L1–L5 and evidence-driven emulator matrix spanning target SDK/API (e.g. API 36 prototype target evidence), supported lower boundaries, and behavioral transition boundaries (notifications at API 33, exact alarms & while-in-use FGS at API 34, process lifecycle & timeouts at API 35+) per [`mobile-capabilities-and-runtime.md`](../../04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md) §7.1.1.
  - *Open Detail:* Exact CI headless emulator runner configuration, supported lower boundary pin, and hardware testbed setup.
  - *Resolution Point:* Stream `MOB-VERIFY-003` / `MOB-VERIFY-006` implementation plan.

- **`DEBT-MOB-08`: Flutter Relational Persistence Abstraction Library Selection**
  - *Context:* Relational SQLite-backed durable persistence is mandatory (`mobile-offline-and-sync.md` §2.2). Drift is the preferred/recommended Flutter candidate.
  - *Open Detail:* Final library confirmation between Drift vs alternative SQLite abstractions (e.g. sqflite) during Flutter scaffolding.
  - *Resolution Point:* Stream `MOB-DATA-001` implementation plan.

- **`DEBT-MOB-09`: Mobile WebSocket Audio Frame Codec Selection**
  - *Context:* Full-duplex WebSocket audio transport connecting to PC Runtime canonical STT/TTS/VAD providers is mandatory (`mobile-capabilities-and-runtime.md` §3.1).
  - *Open Detail:* Evaluation between Linear PCM 16-bit vs Opus 16 kHz compressed frames for bandwidth and latency optimization.
  - *Resolution Point:* Stream `MOB-VOICE-001` implementation plan.
- **`DEBT-MOB-10`: One Profile → Multiple Mobile Phones Topology & Concurrency**
  - *Context:* Ledger §19 and `D-SHARED-CONV-01` record that whether one Profile supports multiple concurrently enrolled Mobile phones remains an open product/topology question, while settled baseline architecture firmly locks that 1 Satellite Phone binds to at most 1 Profile, and the PC Host is the sole Account/Profile Admin.
  - *Settled Architecture:* 1 Satellite Phone = 1 Profile binding (`D-PHONE-01B`, [`profiles-and-devices.md`](../../04_Architecture/02_Data_and_Security/profiles-and-devices.md) §3); PC Host is sole Account/Profile Admin owning enrollment, credential rotation, and revocation.
  - *Open Product & Technical Detail:* Whether multiple concurrently enrolled Mobile phones per Profile are supported in V1 product topology, and if supported, multi-device outbox reconciliation, distributed cursor arbitration, and concurrent branch reconciliation rules.
  - *Resolution Point:* Mobile V1 product topology review / Post-V1 multi-device concurrency refinement.
