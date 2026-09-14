# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Post-8A documentation hygiene — awaiting merge
- Current Sprint: Phase 8 — PC Frontend Architecture, Runtime Config, Multimodal & Polish
- Branches: `feature/phase8-ui-foundation` → `feature/phase8-runtime-config` → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock removal, view decomposition, COMPANION_DATA_ROOT, terminology reconciliation, model schema split, image attachments, 100+ pytest / 50+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video/PDF. No CUDA. No new state library. No LFS/gitattributes changes.
- Plan: `docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 backend pytest, 132 frontend vitest, 0 tsc errors, migration head 005_scope_message_constraints (last verified Phase 8A baseline)

## Open Decisions — Resolved

| Decision | Resolution |
|----------|-----------|
| OD1: Default Windows data-root | **A** — `%LOCALAPPDATA%\AI Companion\Data` |
| OD2: Bootstrap locator | **A** — `%LOCALAPPDATA%\AI Companion\bootstrap.json` |
| OD3: Dev models vs installed library | **A** — Dev/bootstrap models remain under existing Git/LFS policy; installed/user-imported models use `COMPANION_DATA_ROOT/library/models/` |

## [CURRENT EXECUTION STATE — POST-8A DOCUMENTATION HYGIENE COMPLETED — READY FOR PHASE 8P]

- Status: Post-8A documentation hygiene — completed; Phase 8P next.
- Completed: Post-8A documentation hygiene reorganization pass (organized docs/02_Planning into phase-08, android, backend, templates; created navigation hubs at docs/02_Planning/README.md and docs/02_Planning/phase-08/README.md; repaired all docs links and relative walkthrough paths; enforced AGENTS.md hierarchy).
- Baseline: 88 backend pytest, 132 frontend vitest, 0 tsc errors, migration head 005_scope_message_constraints (last verified Phase 8A baseline; not rerun during docs pass).
- Scope Guard: Documentation-only under docs/**. Zero code changes. Zero deletions. ProjectWorkflowStarterKit untouched.
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

**8P.1 — Terminology Reconciliation**
- [ ] 8P.1a: Backend — grep/fix remaining "Local AI Core" in .py; reconciliation comment in config.py
- [ ] 8P.1b: Frontend — rename "Local AI Core" → "Local AI Runtime" in all 19 confirmed locations
- [ ] 8P.1c: Frontend tests — update assistantViewReliability.test.tsx error string assertions (mandatory — tests will fail without this)
- [ ] 8P.1d: ModelsView — fix GGUF/Vulkan label conflation; separate GGUF / Engine / Acceleration fields

**8P.2 — COMPANION_DATA_ROOT Bootstrap & Configuration Initialization**
- [ ] 8P.2: config.py — resolve_data_root() called before Settings instantiation: env COMPANION_DATA_ROOT > bootstrap.json data_root > default; DATABASE_PATH/DATABASE_URL derived from resolved root; SQLAlchemy engine constructed after
- [ ] 8P.2b: config.py — all derived path properties (DATABASE_DIR, DATABASE_PATH, LIBRARY_DIR, MODEL_LIBRARY_DIR, INSTALLED_REGISTRY_PATH, VOICE_LIBRARY_DIR, ATTACHMENT_DIR, IMPORT_INBOX_DIR, IMPORT_STAGING_DIR, CHARACTER_DIR, MEMORY_DIR); remove hardcoded DATABASE_URL; deprecate DATA_DIR, MODELS_DIR, LLAMA_MODELS_DIR

**8P.3 — Runtime Engine Fields**
- [ ] 8P.3: config.py — LLM_ENGINE, LLM_ACCELERATION, LLAMA_ENGINE_VERSION declarative fields
- [ ] 8P.3b: llama_cpp.py — _engine_version reads settings.LLAMA_ENGINE_VERSION

**8P.4 — Profile Portability**
- [ ] 8P.4: config.py — PROFILE_*_* env-overridable constants (RX 580 defaults preserved as current values)
- [ ] 8P.4b: llama_cpp.py — _get_profile_params() reads settings.PROFILE_*; remove inline RX 580 constants

**8P.5 — Model Registry Schema (Final)**
- [ ] 8P.5a: schemas/model_registry.py — new enums (ModelAssetType, ModelVariant, InputModality, ModelDiscoveryState, ReasoningMode, CapabilityProvenance) + sub-schemas (CompanionArtifactStatus, CapabilityEntry, GenerationDefaults, CompanionFile extended)
- [ ] 8P.5b: schemas/model_registry.py — ModelManifest (identity + artifact metadata, immutable; runtime_compatibility: List[str] = [] default), ModelLibraryState (computed validation state), ModelRuntimeHints (recommendations only), ModelRegistryEntry (composes all three + runtime_model_id + registry_source: Literal["factory","installed"])
- [ ] 8P.5c: schemas/model_registry.py — API response shape: use model_serializer or computed_field for flat backward-compat fields (NOT Python @property); update contracts/openapi/openapi.json + registryApi.ts
- [ ] 8P.5d: model_registry.py — _build_effective_registry(): load factory always; load installed if present; installed entry shadows factory on same stable id; empty installed does not hide factory; registry_source tag per entry; path resolution per source root (FACTORY_MODEL_ROOT vs MODEL_LIBRARY_DIR)
- [ ] 8P.5e: model_registry.py — _validate_entry(): missing mmproj -> vision removed from available_capabilities; text usable; model NOT prohibited from loading; missing primary -> unavailable
- [ ] 8P.5f: model_registry.py — unregistered scanner: capabilities=[], input_modalities=[], model_max_context=None, runtime_compatibility=[], variant=unknown (NO fabricated defaults)
- [ ] 8P.5g: model_registry.py — GGUF metadata extraction (best-effort, non-blocking): populate only reliably detected fields; no invented defaults
- [ ] 8P.5h: models/registry.template.json — schema v3; asset_type, architecture, input_modalities, model_max_context on all entries; clarifying _note
- [ ] 8P.5i: registryApi.ts — ModelManifest, ModelLibraryState, ModelRuntimeHints TypeScript interfaces; RegistryEntry updated; context_limit → model_max_context migration in all consumers

**8P.6 — Canonical Documentation Updates**
- [x] 8P.6a: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md — terminology, test baseline 88/38, Phase 8 sequence, arch doc cross-reference, model invariants
- [x] 8P.6b: LLAMA_CPP_RUNTIME_ARCHITECTURE.md — terminology, port corrected to 8085, Eco GPU layers corrected to 0, unverified flash-attention/KV-cache/batch rows removed, scope note added
- [x] 8P.6c: VOICE_AND_AUDIO_ARCHITECTURE.md — terminology, storage cross-reference note
- [x] 8P.6d: AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md — Section 33 rewritten from Open to Resolved Decisions (OD1/OD2/OD3)
- [x] 8P.6e: README.md — terminology; backend/database/runtime marked implemented; Phase 7 baseline (88 pytest/38 vitest) and Phase 8 active delivery
- [x] plan-phase8-pc-frontend-architecture-ux.md — complete rewrite, single authoritative version, no stale pass/supplement content

**8P.2c — Bootstrap Locator Tests**
- [ ] 8P.2c: bootstrap tests — missing locator -> default; valid locator -> locator path; invalid JSON -> warning + default; unavailable path -> warning + default; env var overrides all; DATABASE_URL uses canonical path; engine constructed after resolution

**8P.7 — First-Run Data Migration (multi-candidate aware)**
- [ ] 8P.7: startup.py — check both known legacy candidates (backend/data/companion.db + repo-root/data/companion.db); exactly one -> copy/verify/backup; multiple -> RuntimeError with paths; none -> fresh
- [ ] 8P.7b: _verify_migrated_db() — Alembic head check against settings.DATABASE_PATH (not env DATABASE_URL); migration test: no legacy, one legacy, two candidates

---

### 8B — Multimodal Image Attachment Foundation
Branch: `feature/multimodal-image-attachments` (based on merged 8P)
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
