# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Final planning baseline — awaiting user APPROVED signal before implementation begins
- Current Sprint: Phase 8 — PC Frontend Architecture, Runtime Config, Multimodal & Polish
- Branches: `feature/phase8-ui-foundation` → `feature/phase8-runtime-config` → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock removal, view decomposition, COMPANION_DATA_ROOT, terminology reconciliation, model schema split, image attachments, 100+ pytest / 50+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video/PDF. No CUDA. No new state library. No LFS/gitattributes changes.
- Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 pytest, 38 vitest, 0 tsc errors, migration head 005_scope_message_constraints

## Open Decisions — Resolved

| Decision | Resolution |
|----------|-----------|
| OD1: Default Windows data-root | **A** — `%LOCALAPPDATA%\AI Companion\Data` |
| OD2: Bootstrap locator | **A** — `%LOCALAPPDATA%\AI Companion\bootstrap.json` |
| OD3: Dev models vs installed library | **A** — Dev/bootstrap models remain under existing Git/LFS policy; installed/user-imported models use `COMPANION_DATA_ROOT/library/models/` |

## [CURRENT EXECUTION STATE — FINAL PLAN COMPLETE, AWAITING USER APPROVED SIGNAL]

- Next Action: User issues APPROVED signal → Gemini starts `feature/phase8-ui-foundation` (8A)
- Active Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md` (complete rewrite, self-contained)

---

## Active Checklist — Phase 8

### 8A — Frontend Architecture & UX Harmonization
Branch: `feature/phase8-ui-foundation`
- [ ] 8A.1: Mock removal — HomeView (time-derived greeting), AssistantView (stale mockConversations), HealthView (live BackendContext), MemoryView (live memoryApi)
- [ ] 8A.2: AssistantView decomposition — AssistantComposer (stub attach), AssistantMessageList, AssistantStatusBar (provenance), AssistantErrorDisplay
- [ ] 8A.3: ModelsView — variant badges, mmproj warning badge (degraded not incompatible), applied-vs-requested profile labels
- [ ] 8A.4: mock/*.ts — @deprecated annotations on all file headers (do not delete yet)

---

### 8P — Runtime Configuration & Persistent Asset Foundation
Branch: `feature/phase8-runtime-config` (based on merged 8A)

**8P.1 — Terminology Reconciliation**
- [ ] 8P.1a: Backend — grep/fix remaining "Local AI Core" in .py; reconciliation comment in config.py
- [ ] 8P.1b: Frontend — rename "Local AI Core" → "Local AI Runtime" in all 19 confirmed locations
- [ ] 8P.1c: Frontend tests — update assistantViewReliability.test.tsx error string assertions (mandatory — tests will fail without this)
- [ ] 8P.1d: ModelsView — fix GGUF/Vulkan label conflation; separate GGUF / Engine / Acceleration fields

**8P.2 — COMPANION_DATA_ROOT Configuration**
- [ ] 8P.2: config.py — COMPANION_DATA_ROOT (default: %LOCALAPPDATA%\AI Companion\Data) + all derived path properties (DATABASE_DIR, DATABASE_PATH, LIBRARY_DIR, MODEL_LIBRARY_DIR, INSTALLED_REGISTRY_PATH, VOICE_LIBRARY_DIR, ATTACHMENT_DIR, IMPORT_INBOX_DIR, IMPORT_STAGING_DIR, CHARACTER_DIR, MEMORY_DIR)
- [ ] 8P.2b: config.py — remove hardcoded DATABASE_URL string; derive from settings.DATABASE_PATH (absolute); deprecate DATA_DIR, MODELS_DIR, LLAMA_MODELS_DIR

**8P.3 — Runtime Engine Fields**
- [ ] 8P.3: config.py — LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION declarative fields
- [ ] 8P.3b: llama_cpp.py — _engine_version reads settings.LLAMA_ENGINE_VERSION

**8P.4 — Profile Portability**
- [ ] 8P.4: config.py — PROFILE_*_* env-overridable constants (RX 580 defaults preserved as current values)
- [ ] 8P.4b: llama_cpp.py — _get_profile_params() reads settings.PROFILE_*; remove inline RX 580 constants

**8P.5 — Model Registry Schema (Final)**
- [ ] 8P.5a: schemas/model_registry.py — new enums (ModelAssetType, ModelVariant, InputModality, ModelDiscoveryState, ReasoningMode, CapabilityProvenance) + sub-schemas (CompanionArtifactStatus, CapabilityEntry, GenerationDefaults, CompanionFile extended)
- [ ] 8P.5b: schemas/model_registry.py — ModelManifest (identity + artifact metadata, immutable), ModelLibraryState (computed validation state), ModelRuntimeHints (recommendations only), ModelRegistryEntry (composes all three + runtime_model_id)
- [ ] 8P.5c: schemas/model_registry.py — API response shape: use model_serializer or computed_field for flat backward-compat fields (NOT Python @property); update contracts/openapi/openapi.json + registryApi.ts
- [ ] 8P.5d: model_registry.py — _load_registry_json() checks INSTALLED_REGISTRY_PATH first; falls back to template
- [ ] 8P.5e: model_registry.py — _validate_entry() populates ModelLibraryState; partial companion handling (missing mmproj removes vision from available_capabilities, text chat preserved); discovery_state set correctly
- [ ] 8P.5f: model_registry.py — unregistered scanner: discovery_state=discovered, validation_status=unregistered, capabilities=[] (empty — no auto-assignment), variant=unknown
- [ ] 8P.5g: model_registry.py — GGUF metadata extraction (best-effort, non-blocking): architecture, model_max_context, parameters, chat_template, quantization from GGUF headers
- [ ] 8P.5h: models/registry.template.json — schema v3; asset_type, architecture, input_modalities, model_max_context on all entries; clarifying _note
- [ ] 8P.5i: registryApi.ts — ModelManifest, ModelLibraryState, ModelRuntimeHints TypeScript interfaces; RegistryEntry updated; context_limit → model_max_context migration in all consumers

**8P.6 — Canonical Documentation Updates**
- [ ] 8P.6a: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — "Local AI Core" → "Local AI Runtime" (canonical sections); test counts 88/38; Phase 8 sequence; arch doc cross-reference; model library invariants; ✅ DONE (Phase 8P planning step)
- [ ] 8P.6b: LLAMA_CPP_RUNTIME_ARCHITECTURE.md — "Local AI Core" → "Local AI Runtime"; scope note added; ✅ DONE (Phase 8P planning step)
- [ ] 8P.6c: VOICE_AND_AUDIO_ARCHITECTURE.md — "Local AI Core" → "Local AI Runtime" L7, L336; ✅ DONE (Phase 8P planning step)

**8P.7 — First-Run Data Migration**
- [ ] 8P.7: startup.py — first-run conditional migration: detect legacy data/companion.db → safe copy to COMPANION_DATA_ROOT/database/companion.db → verify → backup original → restart-safe
- [ ] 8P.7b: migration test — legacy DB present → migrated → schema verified → backup preserved

---

### 8B — Multimodal Image Attachment Foundation
Branch: `feature/multimodal-image-attachments` (based on merged 8P)
- [ ] 8B.1: migrations/versions/006_add_attachments.py (revision=006_add_attachments, down_revision=005_scope_message_constraints)
- [ ] 8B.2: models/attachment.py — Attachment ORM (UUIDPrimaryKeyMixin + TimestampMixin + OwnerMixin + SoftDeleteMixin); add relationships to Conversation + Message
- [ ] 8B.3: schemas/attachment.py — AttachmentOut (no storage_path), AttachmentRef, validation constants
- [ ] 8B.4: schemas/multimodal.py — TextContent, ImageAttachmentContent, ContentBlock (provider-independent)
- [ ] 8B.5: schemas/llm.py — ChatMessage.content: Union[str, List[ContentBlock]]
- [ ] 8B.6: schemas/message.py — MessageSend.attachment_ids[], MessageOut.attachments[]
- [ ] 8B.7: services/attachment_validator.py — Pillow, byte-header MIME, dimensions, megapixel, decompression bomb; PNG + JPEG only (WebP deferred)
- [ ] 8B.8: endpoints/attachments.py — POST upload, GET preview (Bearer auth, Blob response), DELETE soft-delete; path traversal guard; storage_path never in API response
- [ ] 8B.9: orchestrator.py — vision gate via available_capabilities (partial companion aware); provider-independent content_blocks
- [ ] 8B.10: llama_cpp.py — _translate_messages(); file IO via run_in_executor
- [ ] 8B.11: attachmentApi.ts — upload, delete, fetchAttachmentBlobUrl (URL.createObjectURL lifecycle, revokeObjectURL on cleanup)
- [ ] 8B.12: conversationApi.ts — attachment_ids[] in streamSendMessage
- [ ] 8B.13: AssistantComposer.tsx — vision gate (available_capabilities), file input, authenticated Blob previews, remove→DELETE, count limit
- [ ] 8B.14: ConversationMessageItem.tsx — authenticated Blob previews for committed history; revokeObjectURL on unmount
- [ ] 8B.15: test_attachments.py — migration, ORM parity, upload, BOLA, MIME, dimensions, size limits, lifecycle, history
- [ ] 8B.16: attachmentComposer.test.tsx — vision gate, mmproj-absent, upload, preview, remove, limit

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
