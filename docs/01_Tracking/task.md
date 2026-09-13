# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Draft — awaiting final architecture review
- Current Sprint: Phase 8 — PC Frontend Architecture, Multimodal & Polish
- Branch: `feature/phase8-ui-foundation` (current) → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock data removal, AssistantView decomposition, real image attachment pipeline, bundle optimization, 100+ pytest / 50+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video (unverified). No new state library.
- Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 pytest, 38 vitest, 0 tsc errors, migration head 005_scope_message_constraints

## [CURRENT EXECUTION STATE - CORRECTION PASS APPLIED, AWAITING USER FINAL REVIEW]

- Next Action: User and ChatGPT review revised plan; issue APPROVED signal before Gemini starts 8A.
- Active Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`

## Active Checklist — Phase 8

### 8A — Frontend Architecture & UX Harmonization
- [ ] 8A.1: Mock removal — HomeView greeting, AssistantView mockConversations, HealthView, MemoryView live wiring
- [ ] 8A.2: AssistantView decomposition — Composer (stub attach), MessageList, StatusBar (provenance), ErrorDisplay
- [ ] 8A.3: Models progressive disclosure — variant badges, mmproj warning, applied-vs-requested profile labels
- [ ] 8A.4: @deprecated annotations on all mock/*.ts files

### 8B — Multimodal Image Attachment Foundation
- [ ] 8B.1: Migration 006_add_attachments.py (exact revision chain, all mixin columns, indexes)
- [ ] 8B.2: Attachment ORM — all 4 mixins, UUID storage path, no user filename in path
- [ ] 8B.3: Conversation + Message models — back_populates="attachments" on both sides
- [ ] 8B.4: schemas/attachment.py — AttachmentOut (no storage_path), AttachmentRef
- [ ] 8B.5: schemas/multimodal.py — TextContent, ImageAttachmentContent (provider-independent)
- [ ] 8B.6: schemas/llm.py — ChatMessage.content Union[str, List[ContentBlock]]
- [ ] 8B.7: services/attachment_validator.py — Pillow, byte-header MIME, dims, megapixel, decompression bomb
- [ ] 8B.8: endpoints/attachments.py — upload, authenticated preview, soft-delete; storage security invariants
- [ ] 8B.9: Orchestrator — provider-independent content_blocks + vision gate (no llama.cpp structs here)
- [ ] 8B.10: LlamaCppProvider — _translate_messages(), file IO via run_in_executor (async safe)
- [ ] 8B.11: conversationApi.ts — attachment_ids[] in streamSendMessage
- [ ] 8B.12: attachmentApi.ts — uploadAttachment, deleteAttachment, fetchAttachmentBlobUrl
- [ ] 8B.13: AssistantComposer — real file input, Blob previews (URL.createObjectURL), vision gate, remove→DELETE
- [ ] 8B.14: ConversationMessageItem — authenticated Blob previews for committed history
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
