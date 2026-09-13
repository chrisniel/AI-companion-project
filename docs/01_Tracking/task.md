# Task Tracking: Active Task

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Planning Complete — Awaiting User Approval to Begin 8A
- Current Sprint: Phase 8 — PC Frontend Architecture, Multimodal & Polish
- Branch: `feature/phase8-ui-foundation` (current) → `feature/multimodal-image-attachments` → `feature/phase8-ui-integration-polish`
- Target: Mock data removal, AssistantView decomposition, real image attachment pipeline, bundle optimization, 100+ pytest / 50+ vitest
- Scope Guard: PC-first. No Android. No STT/TTS. No arbitrary file types. No video (unverified). No new state library.
- Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`
- Baseline: 88 pytest, 38 vitest, 0 tsc errors, migration head 005, branch develop

## [CURRENT EXECUTION STATE - PLAN WRITTEN, AWAITING USER START SIGNAL]

- Next Action: User confirms branch execution order and approves 8A start.
- Active Plan: `docs/02_Planning/plan-phase8-pc-frontend-architecture-ux.md`

## Active Checklist — Phase 8

- [ ] 8A.1: Mock data deprecation — HomeView/HealthView/MemoryView wired to live API
- [ ] 8A.2: AssistantView decomposition — Composer, MessageList, StatusBar, ErrorDisplay sub-components
- [ ] 8A.3: Design system consistency — variant badges, empty/loading/error states standardized
- [ ] 8A.4: @deprecated annotations on all mock/*.ts files
- [ ] 8B.1: Migration 006 — attachments table (CASCADE FKs, is_deleted, storage_path)
- [ ] 8B.2: Attachment ORM model + schemas (AttachmentOut, AttachmentRef)
- [ ] 8B.3: Message model + schema updated (attachment_ids[], attachments[])
- [ ] 8B.4: Attachment upload/preview/delete API endpoints with storage security
- [ ] 8B.5: AssistantOrchestrator multimodal payload + vision capability gate
- [ ] 8B.6: ChatMessage content Union[str, List] (provider-independent)
- [ ] 8B.7: Frontend attachmentApi.ts + AssistantComposer real upload + vision gate disable
- [ ] 8C.1: Delete deprecated mock files (after grep confirms no production imports)
- [ ] 8C.2: Bundle analysis + lazy-load if warranted
- [ ] 8C.3: Accessibility pass (aria-labels, focus management, keyboard nav)
- [ ] 8C.4: Final test suite — target 100+ pytest, 50+ vitest
- [ ] 8C.5: Walkthrough doc + AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md update + archive

## Completed — Phase 0–7 PC Stabilization (merged to develop 2026-09-14)

- [x] Phases 0–7: Full PC runtime stabilization — 88 pytest, 38 vitest, clean build, migration head 005
- [x] Runtime: singleton router ownership, profile correctness, VRAM telemetry, MODEL_SLEEPING
- [x] Frontend: AssistantView crash fix, WorkspaceErrorBoundary, SSE reliability
- [x] DB: migration 005 UNIQUE constraints on sequence_no and client_message_id
