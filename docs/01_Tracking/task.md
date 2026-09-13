# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Draft — awaiting final architecture review (Pass 2)
- Current Sprint: Phase 8 — PC Frontend Architecture, Runtime Config, Multimodal & Polish
- Branches: `feature/phase8-ui-foundation` → `feature/phase8-runtime-config` → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock removal, view decomposition, terminology reconciliation, COMPANION_DATA_ROOT, image attachments, 100+ pytest / 50+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video (unverified). No CUDA implementation. No new state library.
- Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 pytest, 38 vitest, 0 tsc errors, migration head 005_scope_message_constraints

## [CURRENT EXECUTION STATE - PASS 2 CORRECTION APPLIED, AWAITING USER FINAL REVIEW]

- Next Action: User and ChatGPT review revised plan; issue APPROVED signal before Gemini starts 8A.
- Active Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`

## Active Checklist — Phase 8

### 8A — Frontend Architecture & UX Harmonization
- [ ] 8A.1: Mock removal — HomeView greeting, AssistantView mockConversations, HealthView, MemoryView live wiring
- [ ] 8A.2: AssistantView decomposition — Composer (stub attach), MessageList, StatusBar (provenance), ErrorDisplay
- [ ] 8A.3: Models progressive disclosure — variant badges, mmproj warning, applied-vs-requested profile labels
- [ ] 8A.4: @deprecated annotations on all mock/*.ts files

### ⚠️ Pre-Implementation Gate — Open Decisions (resolve before Gemini starts 8P)
- [ ] 8P-OD1: Default Windows data-root location (A: %LOCALAPPDATA%\AI Companion\Data  B: %USERPROFILE%\Documents\AI Companion  C: first-run prompt)
- [ ] 8P-OD2: Bootstrap locator implementation (A: %LOCALAPPDATA% bootstrap.json  B: Windows registry  C: installer-managed)
- [ ] 8P-OD3: Dev models vs installed-library migration policy (A: keep repo-managed / B: explicit migration plan)

### 8P — Runtime Configuration & Persistent Asset Foundation
- [ ] 8P.1a: Backend — grep/fix remaining "Local AI Core" in .py; reconciliation comment in config.py
- [ ] 8P.1b: Frontend — rename "Local AI Core" → "Local AI Runtime" in all 19 confirmed locations
- [ ] 8P.1c: Frontend tests — update assistantViewReliability.test.tsx error string assertions
- [ ] 8P.1d: ModelsView — fix GGUF/Vulkan label conflation; separate GGUF / Engine / Acceleration fields
- [ ] 8P.2: config.py — COMPANION_DATA_ROOT + derived path properties (DATA_DIR, MODEL_LIBRARY_DIR, ATTACHMENT_DIR, VOICE_LIBRARY_DIR, CHARACTER_DIR, MEMORY_DIR, IMPORT_STAGING_DIR)
- [ ] 8P.3: registry.template.json — _schema_version 2, clarifying _note; deprecate LLAMA_MODELS_DIR usages
- [ ] 8P.4: config.py — LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION declarative fields
- [ ] 8P.5: config.py + llama_cpp.py — PROFILE_*_* env-overridable constants; _get_profile_params() reads settings
- [ ] 8P.6: Canonical docs — AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md, LLAMA_CPP_RUNTIME_ARCHITECTURE.md, README.md
- [ ] 8P.7a: schemas/model_registry.py — ModelManifest, ModelAssetType, ModelVariant, InputModality, ModelDiscoveryState; ModelRegistryEntry split (manifest + computed state); backward-compat flat accessors
- [ ] 8P.7b: services/model_registry.py — _validate_entry() discovery state; scanner uses variant=unknown; GGUF metadata extraction (best-effort)
- [ ] 8P.7c: models/registry.template.json — schema version 3; add asset_type, architecture, input_modalities, model_max_context
- [ ] 8P.7d: registryApi.ts — ModelManifest, RegistryEntry split, new enums; context_limit → model_max_context in consumers
- [ ] 8P.7e: CREATE docs/04_Architecture/MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md
- [ ] 8P.7f: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — model library invariant rules summary
- [ ] 8P.2b: config.py — canonical directory layout per §6.2 (database/, library/models/llm/, library/registry/, imports/inbox/, characters/, memory/)
- [ ] 8P.2c: config.py — DATABASE_URL removed as hardcoded string; derived from settings.DATABASE_PATH (absolute, backward-safe)
- [ ] 8P.3b: model_registry.py — check INSTALLED_REGISTRY_PATH first; fall back to template; writes go to installed registry only
- [ ] 8P.7a-ext: ModelManifest — ReasoningMode enum, CapabilityEntry+Provenance, GenerationDefaults, CompanionArtifactStatus
- [ ] 8P.7b-ext: _validate_entry() — per-capability available_capabilities (partial companion handling; text chat available without mmproj)
- [ ] 8P.8: First-run migration — detect legacy DB → copy to COMPANION_DATA_ROOT/database/ → verify → backup original → restart-safe

### 8B — Multimodal Image Attachment Foundation
- [ ] 8B.1: Migration 006_add_attachments.py (depends on 8P ATTACHMENT_DIR)
- [ ] 8B.2: Attachment ORM — all 4 mixins, UUID storage path
- [ ] 8B.3: Conversation + Message models — back_populates="attachments" on both sides
- [ ] 8B.4: schemas/attachment.py — AttachmentOut (no storage_path), AttachmentRef
- [ ] 8B.5: schemas/multimodal.py — TextContent, ImageAttachmentContent (provider-independent)
- [ ] 8B.6: schemas/llm.py — ChatMessage.content Union[str, List[ContentBlock]]
- [ ] 8B.7: services/attachment_validator.py — Pillow, byte-header MIME, dims, megapixel, decompression bomb
- [ ] 8B.8: endpoints/attachments.py — upload, authenticated preview, soft-delete; ATTACHMENT_DIR security
- [ ] 8B.9: Orchestrator — provider-independent content_blocks + vision gate
- [ ] 8B.10: LlamaCppProvider — _translate_messages(), file IO via run_in_executor (async safe)
- [ ] 8B.11: conversationApi.ts — attachment_ids[] in streamSendMessage
- [ ] 8B.12: attachmentApi.ts — uploadAttachment, deleteAttachment, fetchAttachmentBlobUrl
- [ ] 8B.13: AssistantComposer — real file input, Blob previews (URL.createObjectURL), vision gate, remove→DELETE
- [ ] 8B.14: ConversationMessageItem — authenticated Blob previews for history
- [ ] 8B.15: GET messages — AttachmentRef[] returned; F5 reload restores previews

### 8C — Integration, Accessibility & Polish
- [ ] 8C.1: Delete deprecated mock files (grep verification first)
- [ ] 8C.2: Bundle analysis + lazy-load if warranted
- [ ] 8C.3: Accessibility — aria-labels, role=article, focus management, keyboard nav
- [ ] 8C.4: Final test suite — target 100+ pytest, 50+ vitest
- [ ] 8C.5: Walkthrough + MASTER_IMPLEMENTATION_PLAN update + archive

## Completed — Phase 0–7 PC Stabilization (merged to develop 2026-09-14)

- [x] Phases 0–7: Full PC runtime stabilization — 88 pytest, 38 vitest, clean build, migration head 005_scope_message_constraints
- [x] Runtime: singleton router ownership, profile correctness, VRAM telemetry, MODEL_SLEEPING
- [x] Frontend: AssistantView crash fix, WorkspaceErrorBoundary, SSE reliability
- [x] DB: migration 005 UNIQUE constraints on sequence_no and client_message_id
