# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Phase 8P.2 completed — awaiting review
- Current Sprint: Phase 8 — PC Frontend Architecture, Runtime Config, Multimodal & Polish
- Branches: `feature/phase8-ui-foundation` → `feature/phase8-runtime-config` → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock removal, view decomposition, COMPANION_DATA_ROOT, terminology reconciliation, model schema split, image attachments, 100+ pytest / 132+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video/PDF. No CUDA. No new state library. No LFS/gitattributes changes.
- Plan: `docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 backend pytest, 132 frontend vitest, 0 tsc errors, migration head 005_scope_message_constraints (last verified Phase 8A baseline)

## Open Decisions — Resolved

| Decision | Resolution |
|----------|-----------|
| OD1: Default Windows data-root | **A** — `%LOCALAPPDATA%\AI Companion\Data` |
| OD2: Bootstrap locator | **A** — `%LOCALAPPDATA%\AI Companion\bootstrap.json` |
| OD3: Dev models vs installed library | **A** — Dev/bootstrap models remain under existing Git/LFS policy; installed/user-imported models use `COMPANION_DATA_ROOT/library/models/` |

## [CURRENT EXECUTION STATE — PHASE 8P.2 COMPLETED — AWAITING CHATGPT/USER REVIEW]

- Status: Phase 8P.2 Runtime Engine Configuration & Performance Profiles implemented and verified; awaiting approval to begin Batch 8P.3.
- Completed: Batch 8P.2 runtime engine settings (LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION) and hardware performance profiles (PROFILE_*_CTX, PROFILE_*_GPU_LAYERS, PROFILE_*_THREADS, PROFILE_*_MMPROJ_OFFLOAD) implemented in config.py, wired into llama_cpp.py, and covered by 6 focused regression tests.
- Verified: 94 backend pytest passed, 132 frontend vitest passed, 0 tsc errors.
- Baseline: 94 backend pytest, 132 frontend vitest, 0 tsc errors, migration head 005_scope_message_constraints.
- Scope Guard: Batch 8P.2 scope strictly honored. Zero migrations. Zero database changes. Zero 8P.3 changes. No Whisper/voice changes.
- Active Plan: `docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`

---

## Active Checklist — Phase 8

### 8A — Frontend Architecture & UX Harmonization
Branch: `feature/phase8-ui-foundation`
- [x] 8A.1: Mock removal — HomeView (time-derived greeting), AssistantView (stale mockConversations), HealthView (truthful unavailable state & planned providers), MemoryView (truthful SQLite FTS5 store & contract)
- [x] 8A.2: AssistantView decomposition — AssistantComposer (stub attach), AssistantMessageList, AssistantStatusBar (provenance), AssistantErrorDisplay
- [x] 8A.3: ModelsView — variant badges, mmproj warning badge (degraded not incompatible), applied-vs-requested profile labels
- [x] 8A.3b: Production Truthfulness Sweep
  - [x] 8A.3b.1: Shell + Home
  - [x] 8A.3b.2: Tasks + Schedule
  - [x] 8A.3b.3: Characters + Devices + Logs + Settings
- [x] 8A.4: mock/*.ts — @deprecated annotations on all file headers (do not delete yet)

---

### 8P — Runtime Configuration & Persistent Asset Foundation
Branch: `feature/phase8-runtime-config` (based on merged 8A)

**8P.1 — Terminology & Test Alignment**
- [x] 8P.1a: Backend — grep/fix remaining "Local AI Core" in backend/app/__init__.py, retention.py, mock.py, auth.py, .env.example; add reconciliation comment in config.py; update backend/tests/test_llm.py string assertion
- [x] 8P.1b: Frontend — rename "Local AI Core" → "Local AI Runtime" across decomposed locations (AssistantErrorDisplay.tsx, Header.tsx, HomeView.tsx, AssistantPanel.tsx, ModelsView.tsx, ModelProvidersCard.tsx, ApplicationStatesShowcase.tsx, HealthPipelineCard.tsx, mock/healthData.ts)
- [x] 8P.1c: Frontend tests — update assistantViewReliability.test.tsx AND shellHomeTruthfulness.test.tsx error/status string assertions
- [x] 8P.1d: ModelsView — fix GGUF/Vulkan label conflation; separate GGUF (format), llama.cpp (engine), Vulkan (acceleration) fields

**8P.2 — Runtime Engine Configuration & Performance Profiles**
- [x] 8P.2a: config.py — LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION declarative fields; PROFILE_*_* env-overridable constants (RX 580 defaults preserved)
- [x] 8P.2b: llama_cpp.py — _engine_version reads settings.LLAMA_ENGINE_VERSION; _get_profile_params() reads settings.PROFILE_*_*; remove inline RX 580 constants

**8P.3 — Atomic Persistent Storage Foundation**
- [ ] 8P.3a: config.py — resolve_data_root() (env COMPANION_DATA_ROOT > bootstrap.json data_root > default %LOCALAPPDATA%\AI Companion\Data); derive all 11 canonical paths (DATABASE_DIR, DATABASE_PATH, LIBRARY_DIR, MODEL_LIBRARY_DIR, INSTALLED_REGISTRY_PATH, VOICE_LIBRARY_DIR, ATTACHMENT_DIR, IMPORT_INBOX_DIR, IMPORT_STAGING_DIR, CHARACTER_DIR, MEMORY_DIR); deprecate DATA_DIR, MODELS_DIR, LLAMA_MODELS_DIR; remove hardcoded DATABASE_URL
- [ ] 8P.3b: session.py / startup hook — atomic migration & engine ordering: ensure_data_root() evaluates legacy candidates before SQLAlchemy engine binds or creates a fresh database
- [ ] 8P.3c: Multi-candidate legacy safety — check backend/data/companion.db and <repo-root>/data/companion.db; exactly one -> safe copy, verify Alembic head (005_scope_message_constraints), create backup; multiple differing -> STOP with RuntimeError and report ambiguity; none -> fresh install
- [ ] 8P.3d: Test isolation & bootstrap tests — test_bootstrap.py (locator resolution, corruption fallback, unmounted path, env precedence) + test_migration_safety.py (fresh, single legacy, multi-candidate ambiguity stop, test isolation without %LOCALAPPDATA% pollution)

**8P.4 — Model Registry Schema v3 & Temporary Serialization Bridge**
- [ ] 8P.4a: schemas/model_registry.py — new enums (ModelAssetType, ModelVariant, InputModality, ModelDiscoveryState, ReasoningMode, CapabilityProvenance) + sub-schemas (CompanionArtifactStatus, CapabilityEntry, GenerationDefaults, CompanionFile extended)
- [ ] 8P.4b: schemas/model_registry.py — ModelManifest (stable identity + artifact metadata; runtime_compatibility: List[str] = []), ModelLibraryState (validation status, available capabilities, sizes), ModelRuntimeHints (recommendations only), ModelRegistryEntry (composes all three + runtime_model_id + registry_source: Literal["factory","installed"])
- [ ] 8P.4c: schemas/model_registry.py — temporary @computed_field compatibility bridge on ModelRegistryEntry for existing flat fields (context_limit, estimated_vram_gb, variant, capabilities, etc.)
- [ ] 8P.4d: models/registry.template.json — upgrade to schema v3; asset_type, architecture, input_modalities, model_max_context, reasoning_mode on all entries; clarifying _note

**8P.5 — Effective Registry, Validation, GGUF Metadata & Capability Availability**
- [ ] 8P.5a: model_registry.py — _build_effective_registry(): load factory (models/registry.template.json relative to FACTORY_MODEL_ROOT); load installed (INSTALLED_REGISTRY_PATH relative to MODEL_LIBRARY_DIR) if present; installed entry shadows factory on same id; empty installed never hides factory; registry_source tag per entry
- [ ] 8P.5b: model_registry.py — _validate_entry(): missing mmproj -> vision removed from available_capabilities; text usable; model NOT prohibited from loading; missing primary -> unavailable
- [ ] 8P.5c: model_registry.py — unregistered scanner: capabilities=[], input_modalities=[], model_max_context=None, runtime_compatibility=[], variant=unknown (NO fabricated defaults)
- [ ] 8P.5d: model_registry.py — bounded, zero-dependency, best-effort Python GGUF header reader (metadata only; read general.architecture, derive context key dynamically as <architecture>.context_length; general.quantization_version is NOT quantization scheme; use general.file_type only when recognized to populate quantization, else unknown; never infer quantization or capabilities from arbitrary filename text; bounded KV/string counts; never loads tensors; safe error fallback)

**8P.6 — Frontend Contract & OpenAPI Reconciliation**
- [ ] 8P.6a: registryApi.ts — ModelManifest, ModelLibraryState, ModelRuntimeHints TypeScript interfaces; RegistryEntry updated; migrate consumers to model_max_context
- [ ] 8P.6b: ModelsView.tsx — update model mapping to use structured layers and model_max_context
- [ ] 8P.6c: Frontend test fixtures — update mock registries in modelsStateReconciliation.test.tsx, assistantViewReliability.test.tsx, shellHomeTruthfulness.test.tsx
- [ ] 8P.6d: Flat field cleanup — search repository-wide for remaining flat consumers; retire temporary @computed_field aliases if no active consumers remain
- [ ] 8P.6e: contracts/openapi/openapi.json — regenerate contract from actual FastAPI app (app.openapi()); verify all existing model/LLM routes represented (GET /api/v1/models, GET /api/v1/models/registry, POST /api/v1/models/load, POST /api/v1/models/unload, PATCH /api/v1/models/profile, POST /api/v1/chat/completions); do not hand-author partial endpoints; review diff for unrelated drift

**8P.7 — Canonical Documentation Alignment (Historical Verification)**
- [x] 8P.7a: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — terminology, test baseline, Phase 8 sequence, arch doc cross-reference, model invariants
- [x] 8P.7b: LLAMA_CPP_RUNTIME_ARCHITECTURE.md — terminology, port corrected to 8085, Eco GPU layers corrected to 0, unverified rows removed, scope note added
- [x] 8P.7c: VOICE_AND_AUDIO_ARCHITECTURE.md — terminology, storage cross-reference note
- [x] 8P.7d: AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md — Section 33 rewritten from Open to Resolved Decisions (OD1/OD2/OD3)
- [x] 8P.7e: README.md — terminology, implemented baseline status, Phase 8 active delivery

---

### 8B — Multimodal Image Attachment Foundation
Branch: `feature/multimodal-image-attachments` (based on merged 8P; depends on settings.ATTACHMENT_DIR from 8P.3)
- [ ] 8B.1: migrations/versions/006_add_attachments.py (revision=006_add_attachments, down_revision=005_scope_message_constraints)
- [ ] 8B.2: models/attachment.py — Attachment ORM (UUIDPrimaryKeyMixin + TimestampMixin + OwnerMixin + SoftDeleteMixin); add relationships to Conversation + Message
- [ ] 8B.3: schemas/attachment.py — AttachmentOut (no storage_path), AttachmentRef, validation constants
- [ ] 8B.4: schemas/multimodal.py — TextContent, ImageAttachmentRef (attachment_id+mime_type), ResolvedImageContent (mime_type+bytes), ContentBlock
- [ ] 8B.5: schemas/llm.py — ChatMessage.content: Union[str, List[ContentBlock]]
- [ ] 8B.6: schemas/message.py — MessageSend.attachment_ids[], MessageOut.attachments[]
- [ ] 8B.7: services/attachment_validator.py — Pillow, byte-header MIME, dimensions, megapixel, decompression bomb; PNG + JPEG only (WebP deferred)
- [ ] 8B.8: endpoints/attachments.py — POST upload, GET preview (Bearer auth, Blob response), DELETE soft-delete; path traversal guard; storage_path never in API response
- [ ] 8B.8b: services/attachment_service.py — claim_attachments_for_message(): atomic conditional UPDATE (WHERE message_id IS NULL + owner + conversation + not deleted); exactly 1 row required; 0 rows = 422 with diagnostics; TOCTOU-safe; rollback on any failure
- [ ] 8B.9: services/assistant/media_resolver.py — resolve_image_content(ref: ImageAttachmentRef) -> ResolvedImageContent; resolves path from settings.ATTACHMENT_DIR; traversal guard; async file IO here (not in provider)
- [ ] 8B.10: orchestrator.py — vision gate via available_capabilities; calls media_resolver; wraps ResolvedImageContent in ContentBlock[]; cancellation after commit preserves user message + attachments
- [ ] 8B.11: llama_cpp.py — _translate_messages(): receives ContentBlock[] with ResolvedImageContent (bytes pre-loaded); NO filesystem IO; NO attachment IDs; NO run_in_executor for file reads; encodes bytes as data-URL
- [ ] 8B.12: attachmentApi.ts — upload, delete, fetchAttachmentBlobUrl (URL.createObjectURL lifecycle, revokeObjectURL on cleanup)
- [ ] 8B.13: conversationApi.ts — attachment_ids[] in streamSendMessage
- [ ] 8B.14: AssistantComposer.tsx — vision gate (available_capabilities), file input, authenticated Blob previews, remove→DELETE, count limit
- [ ] 8B.15: ConversationMessageItem.tsx — authenticated Blob previews for committed history; revokeObjectURL on unmount
- [ ] 8B.16: test_attachments.py — migration, ORM parity, upload, BOLA, MIME, dimensions, limits, lifecycle, history, cross-conversation bind, reuse-committed, multi-candidate DB error, bootstrap locator
- [ ] 8B.17: attachmentComposer.test.tsx — vision gate, mmproj-absent (degraded not prohibited), upload, preview, remove, limit

---

### 8C — Integration, Accessibility & Polish
Branch: `feature/phase8-ui-integration-polish` (based on merged 8B)
- [ ] 8C.1: Delete mock/*.ts files (verify zero production imports first; grep check mandatory)
- [ ] 8C.2: Bundle analysis — vite-bundle-visualizer; lazy-load ScheduleView if > 500KB chunk
- [ ] 8C.3: Accessibility — aria-labels on all icon-only buttons; role="article" on message bubbles; focus management; keyboard nav
- [ ] 8C.4: test: phase8Integration.test.tsx — reload + preview, cancellation semantics, vision gate, mmproj-absent, limits, WebP rejection, model switch
- [ ] 8C.5: pytest backend regression — target 100+ passed
- [ ] 8C.6: CREATE docs/03_Walkthroughs/walkthrough-phase8-multimodal-attachments.md (7-section template)
- [ ] 8C.7: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — update test counts (100+/50+); mark Phase 8 complete
- [ ] 8C.8: Archive sprint → docs/01_Tracking/archive/task-YYYY-MM-DD-phase8-ui-multimodal.md
