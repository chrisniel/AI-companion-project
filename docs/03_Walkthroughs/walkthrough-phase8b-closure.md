# Walkthrough: Phase 8B.7 & 8B.8 Persistent Attachment Rendering & Closure

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: Persistent message attachment rendering in the web history and full Phase 8B integration closure for PC V1.
- Audience: User, developer, maintainer
- Status: Implemented & Verified
- Last Updated: 2026-09-30

---

## 1. What Was Delivered

- **Persistent Message Attachment Rendering (8B.7):** Frontend Conversation history (`MessageOut`) now successfully parses and displays `AttachmentRef[]`. Images attached to past user messages are rendered with authenticated Blob URLs inside `ConversationMessageItem`.
- **Blob Lifecycle Safety:** Transient preview object URLs are eagerly revoked upon component unmount or identity change to avoid memory leaks.
- **Fail-Closed Validation:** Previews strictly enforce MIME-type allowlists (only `image/png` and `image/jpeg`).
- **Phase 8B Full Integration Verification (8B.8):** Successfully verified the full backend test suite, frontend Vitest suite, TypeScript compiler check, Vite production build, OpenAPI schema synchronization, and SQLite migration chain across the whole repository baseline.

## 2. Files Changed

- `frontend/web/src/components/workspace/ConversationMessageItem.tsx` — Updated to parse `attachments` from messages and render the `AttachmentPreviewRenderer` with authenticated Blob fetching.
- `frontend/web/src/components/workspace/AssistantView.tsx` & `AssistantMessageList.tsx` — Integrated attachment props and state mapping.
- `frontend/web/src/services/api/conversationApi.ts` & `types.ts` — Updated the frontend domain types and API response models to include `attachments`.
- `frontend/web/src/test/persistentAttachmentRendering.test.tsx` — New integration test suite asserting persistent attachment rendering behavior, fail-closed validation, and asynchronous URL lifecycle.
- `docs/04_Architecture/01_Domains/multimodal-and-media.md` — Updated the canonical domain architecture specification to document the finalized 8B verification status.
- `docs/02_Planning/ROADMAP.md` & `README.md` — Updated the active status tracking for Phase 8.

## 3. How the Logic Works

1. Event trigger: The user switches to a conversation or sends a message, which hydrates the frontend with `MessageOut` objects containing an array of `AttachmentRef`.
2. Validation: `ConversationMessageItem` examines each attachment; only allowed MIME types trigger preview rendering.
3. Core processing: The `AttachmentPreviewRenderer` maps each valid attachment to an async fetch against `attachmentApi.fetchAttachmentBlobUrl()`, bypassing direct `<img>` fetching to ensure BOLA/Bearer-token protection.
4. Completion: The fetched Blob is converted via `URL.createObjectURL` and rendered visually beneath the user message text.
5. Recovery/cancellation: If the frontend unmounts, or the user switches conversations, the cleanup `useEffect` immediately calls `URL.revokeObjectURL` to reclaim memory.

## 4. Key Concepts

- **Authenticated Blob Preview:** Instead of pointing an `<img>` tag directly at a server URL (which lacks `Authorization` header support), the application fetches the image via standard `fetch()` with the Bearer token, gets a Blob, and generates a local Object URL.
- **Fail-Closed Validation:** The strategy of defaulting to rejection for unknown or unsupported input. By strictly bounding previews to PNG/JPEG, the frontend avoids risking exploitation through unexpected payload injection.
- **Object URL Lifecycle:** `URL.createObjectURL()` allocates browser memory that is not automatically garbage-collected until the document unloads. Explicit revocation is mandatory.

## 5. Verification Steps

### Automated Checks

- [x] `python -m pytest tests/test_migration_safety.py` — Passed (15/15 migration tests, verifying migration/preflight/copy/restart/WAL safety under pytest isolation).
- [x] Alembic schema-chain verification — Passed (005 → 006 → 005 → head successfully executed against an explicit temporary COMPANION_DATA_ROOT).
- [x] `python -m pytest backend/tests` — Passed (321 backend tests).
- [x] `npm --prefix frontend/web run test -- --run` — Passed (193 frontend tests).
- [x] `npm --prefix frontend/web run lint` — Passed (TypeScript typecheck 0 errors).
- [x] `npm --prefix frontend/web run build` — Passed (Vite production bundle built).
- [x] `python scripts/check_openapi_contract.py --check` — Passed (zero OpenAPI schema drift).

### Manual / User-Owned Checks

- [ ] Step 1: Open the application and upload a supported image (PNG/JPEG).
- [ ] Step 2: Send the message and verify the image appears in the conversational history.
- [ ] Expected result: The image preview is clearly visible below the user message text and persists across application refreshes or conversation switching.

## 6. Safe Customization & Invariants

- Tunable parameters: None (frontend dimensions are styled via existing CSS standard classes).
- Invariants: Previews must use authenticated Blob fetching. Bypassing this for `<img> src` directly to the backend breaks the BOLA/Bearer token security boundary.

## 7. Troubleshooting

- Symptom: Broken image placeholders in message history.
  - Likely cause: The Bearer token has expired, or the user is unauthorized to view the attachment.
  - Resolution: Ensure the user session is active and the correct conversation ID scope is being requested.
- Symptom: Browser memory usage steadily increases.
  - Likely cause: `URL.revokeObjectURL` is not being called on component unmount.
  - Resolution: Check the `useEffect` cleanup return inside `AttachmentPreviewRenderer` or `AssistantComposer`.
