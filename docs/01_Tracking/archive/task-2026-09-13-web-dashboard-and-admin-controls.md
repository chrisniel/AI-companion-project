# Archived Task: Track C2 — React Web Dashboard & Local AI Admin Controls

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Sprint: Track C2 — React Web Dashboard & Local AI Admin Controls
- Branch: `feature/web-dashboard-and-admin-controls`
- Completed Date: 2026-09-13
- Status: Completed & Verified by User

## Objectives Delivered

1. **Web Admin VRAM Lifecycle Controls**:
   - Added `POST /api/v1/models/load`, `POST /api/v1/models/unload`, and `PATCH /api/v1/models/profile` endpoints.
   - Connected tactile single-click **[ Load to VRAM ]** and **[ Unload VRAM ]** buttons in `ModelsView` and `CurrentModelHero`.
   - Switched process spawning to `subprocess.Popen` to resolve Windows `NotImplementedError` under Uvicorn.
   - Isolated runtime logs to root `data/llama_server.log` to prevent WatchFiles reload loops.
2. **Live SSE Streaming Chat**:
   - Connected `AssistantView.tsx` to `POST /api/v1/chat/completions` with progressive token streaming (`text/event-stream`).
   - Added auto-scrolling, unloaded model detection banner with quick load, and `AbortController` cancellation.
3. **Telemetry & Model Selection Parity**:
   - Decoupled model selection in `ModelsView.tsx` so selecting library models (e.g. Gemma) preserves real metadata.
   - Updated `CurrentModelHero.tsx` to display `0.0 GB VRAM`, `0 tokens in use (0%)`, and `Vulkan Offload (AMD RX 580)` when unloaded.
   - Cleaned up leftover Mac mock logs in `logsData.ts` to reflect real AMD Vulkan telemetry.

## Completed Checklist

- [x] Step 1: Relocate `llama_server.log` outside `backend/` to root `data/` to prevent WatchFiles restart loop
- [x] Step 2: Replace `create_subprocess_exec` with `subprocess.Popen` in `llama_cpp.py` to fix Windows `NotImplementedError`
- [x] Step 3: Update `_check_external_server` and `load_model` to cleanly manage process lifecycle
- [x] Step 4: Ensure `BackendContext.tsx` and `ModelsView.tsx` clear stale error state on successful model status fetch
- [x] Step 5: Fix `ModelsView.tsx` so selecting other models in the library preserves their real name, size, and metadata
- [x] Step 6: Fix `CurrentModelHero.tsx` metrics so unloaded state shows 0.0 GB VRAM, 0 tokens in use, and Vulkan (RX 580)
- [x] Step 7: Clean up Mac/Apple Metal mock logs in `logsData.ts` to reflect real AMD Vulkan telemetry
- [x] Step 8: Verify live load to VRAM on RX 580 and confirm UI updates accurately (Verified by user)

## Verification Status

- Automated Tests: 33/33 pytest unit tests passing.
- Frontend Verification: TypeScript typecheck (`tsc --noEmit`) and Vite production bundle passed with 0 errors.
- Live Hardware Verification: AMD Radeon RX 580 8GB VRAM allocation (~5.18 GB) confirmed via Task Manager and released to 0 MB on unload.
