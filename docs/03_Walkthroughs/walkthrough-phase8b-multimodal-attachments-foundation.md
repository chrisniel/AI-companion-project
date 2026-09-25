# Walkthrough: Phase 8B Multimodal Image Attachment Foundation (Slices 8B.0–8B.6)

> [!NOTE]
> **Historical Delivery Evidence**  
> This walkthrough records repository state and verification at the time of delivery (Phase 8B foundation: Slices 8B.0 through 8B.6). It is non-authoritative for future milestone scope. Verify current implementation against active source code and automated tests, and consult [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and canonical domain specifications for active architectural truth.
>
> **Deferred Implementation Boundary:**
> - **8B.7 — Persistent / History Image Rendering:** NEXT / not included in this delivery
> - **8B.8 — Full Integration & Closure:** PLANNED / not included in this delivery
> - **Phase 8C — UI Integration, Accessibility & Polish:** PLANNED / BLOCKED

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Purpose: End-to-end multimodal image attachment foundation across persistence, validation, secure API, transactional binding, vision provider translation, and Web composer UI.
- Audience: Developers, maintainers, code reviewers
- Status: Implemented & Verified (Slices 8B.0–8B.6)
- Last Updated: 2026-09-25

---

## 1. What Was Delivered

Phase 8B establishes the complete multimodal foundation enabling users to attach images in the React Web Assistant composer, upload and validate them securely, transactionally bind them to user chat messages, resolve and decode them through a sandboxed media resolver, and translate them into OpenAI-compatible `image_url` data URIs for vision-capable local LLM inference under `llama.cpp`.

This walkthrough documents the verified foundation spanning slices **8B.0 through 8B.6**:

- **8B.0 — Readiness Reconciliation:**
  - Verified repository baseline on `feature/multimodal-image-attachments` against merged `develop` commit `7458881f`.
  - Reconciled four foundational readiness questions without premature code churn:
    1. *Request Body Ceiling:* Preserved the global 2 MiB ceiling (`settings.MAX_REQUEST_BODY_BYTES`) while configuring a route-specific 12 MiB envelope limit (`settings.MAX_ATTACHMENT_REQUEST_BODY_BYTES`) strictly for `POST /api/v1/conversations/{id}/attachments`, accommodating multipart framing while capping decoded image files at 10 MiB.
    2. *Upload Transport & Dependencies:* Selected standard `multipart/form-data` with FastAPI `UploadFile` and scheduled explicit runtime dependencies (`Pillow` and `python-multipart`).
    3. *Cascade Soft-Delete Ownership:* Enforced cascade soft-deletion of child attachments on conversation deletion (`DELETE /conversations/{id}`) and explicit single-attachment soft-deletion (`DELETE /conversations/{id}/attachments/{attachment_id}`).
    4. *Model Metadata Registration:* Corrected `backend/app/db/base.py` to aggregate all models for deterministic Alembic discovery.

- **8B.1 — Persistence Foundation:**
  - Authored Alembic migration `backend/migrations/versions/006_add_attachments.py` introducing the `attachments` table under down-revision `005_scope_message_constraints`.
  - Enforced all 4 standard mixins: `UUIDPrimaryKeyMixin`, `TimestampMixin` (`created_at`, `updated_at`), `OwnerMixin` (`owner_id`), and `SoftDeleteMixin` (`is_deleted`, `deleted_at`).
  - Implemented explicit Alembic DDL defaults (`server_default=sa.func.now()`, `server_default=sa.false()`) and 7 deterministic indexes (including `(message_id, created_at)` and `owner_id`).
  - Created SQLAlchemy ORM `Attachment` model in `backend/app/models/attachment.py` with bidirectional relationships on `Conversation` (`cascade="all, delete-orphan"`) and `Message` (`lazy="selectin"`).
  - Consolidated `backend/app/db/base.py` importing `Task`, `Conversation`, `Message`, `Memory`, and `Attachment` for reliable metadata discovery and parity testing.

- **8B.2 — Contracts & Image Validation:**
  - Defined public schemas in `backend/app/schemas/attachment.py` (`AttachmentOut` and `AttachmentRef`), strictly excluding internal filesystem paths (`storage_path`).
  - Defined internal provider-independent multimodal types in `backend/app/schemas/multimodal.py` (`TextContent`, `ImageAttachmentRef`, `ResolvedImageContent`, `ContentBlock`).
  - Updated `backend/app/schemas/llm.py` so internal `ChatMessage.content` accepts `Union[str, List[ContentBlock]]` while keeping external API schemas text-only.
  - Implemented Pillow-backed fail-fast validation in `backend/app/services/attachment_validator.py`: magic byte inspection (PNG `\x89PNG\r\n\x1a\n`, JPEG `\xff\xd8\xff`), 10 MiB file size limit, 8192 px max dimension, 32.0 megapixel budget, and decompression bomb protection.
  - Added `attachment_ids: List[str]` to `MessageSend` and `attachments: List[AttachmentRef]` to `MessageOut`.

- **8B.3 — Secure Attachment API:**
  - Implemented route-specific payload middleware exception in `backend/app/main.py`.
  - Created `backend/app/api/v1/endpoints/attachments.py` with three secured routes:
    - `POST /api/v1/conversations/{conversation_id}/attachments`: Authenticated upload streaming in 64 KiB chunks, Pillow validation, exclusive temporary file creation (`mode="xb"`), collision-free UUID naming, atomic promotion, and failure rollback (unlinking temp files on database error without touching collisions). Returns `AttachmentOut` (HTTP 201).
    - `GET /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview`: Authenticated binary preview stream validating ownership, active status, path containment within `settings.ATTACHMENT_DIR`, and disk existence. Returns `FileResponse`.
    - `DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}`: Soft-delete marking `is_deleted=True, deleted_at=utc_now()`. Returns HTTP 204 (repeat returns 404).
  - Enforced Broken Object Level Authorization (BOLA) across all routes: callers can only access attachments belonging to their authenticated `owner_id` and the specified active `conversation_id`.

- **8B.4 — Transactional Message Binding:**
  - Solved the pre-stream validation dilemma: separated turn preparation from SSE token streaming into an atomic pre-stream transaction executed by `prepare_turn()`.
  - Implemented `claim_attachments_for_message()` in `backend/app/services/attachment_service.py` using an atomic conditional SQL update:
    ```sql
    UPDATE attachments
    SET message_id = :message_id
    WHERE id = :attachment_id
      AND owner_id = :owner_id
      AND conversation_id = :conversation_id
      AND message_id IS NULL
      AND is_deleted = FALSE
    RETURNING id;
    ```
  - Zero-row classification: Any failure to claim (foreign owner, wrong conversation, already committed, or soft-deleted) aborts the transaction, rolls back user and assistant placeholder messages, and returns HTTP 400/403/404/422 **before** the `StreamingResponse` begins.
  - Explicit lock ownership transfer: `send_message_stream` acquires `asyncio.Lock` and transfers it to `orchestrate_chat_stream()`, guaranteeing release in `finally:` on success, client disconnect, cancellation, or error.
  - Conversation soft-deletion cascades soft-deletion to all active child attachments in a single transaction while preserving physical files on disk. (Physical deletion / retention cleanup for soft-deleted attachment files is deferred and not implemented in slices 8B.0–8B.6; its owning milestone must be established by future planning).

- **8B.5 — Vision Provider Integration:**
  - Implemented `backend/app/services/assistant/media_resolver.py` providing sandboxed disk reads, ownership verification, canonical storage path containment (`COMPANION_DATA_ROOT / storage_path` inside `ATTACHMENT_DIR`), MIME/size/signature revalidation, and threadpool-offloaded asynchronous reads.
  - Updated `orchestrate_chat_stream()` in `backend/app/services/assistant/orchestrator.py`:
    - Truthful vision gate: checks `ModelCapability.vision in active_entry.library_state.available_capabilities` (requires active model and companion `mmproj` projector).
    - Assembles `ContentBlock`s (`ResolvedImageContent` + `TextContent`) for vision-capable models; safely falls back to text-only prompt if vision capability is absent.
  - Updated `backend/app/services/llm/llama_cpp.py`: `_translate_messages()` maps `ResolvedImageContent` to OpenAI-compatible `image_url` data URIs (`data:{mime_type};base64,{b64}`).
  - Preserved strict provider decoupling: `LlamaCppProvider` and `MockLLMProvider` never access the filesystem or database directly.

- **8B.6 — Web Attachment Composer:**
  - Implemented `frontend/web/src/services/api/attachmentApi.ts`: `uploadAttachment` (`apiFetch` + `FormData`), `deleteAttachment` (`apiFetch`), and `fetchAttachmentBlobUrl` using raw authenticated `fetch()` -> `response.blob()` -> `URL.createObjectURL()` (raw fetch is used to receive binary Blobs without triggering `apiFetch`'s JSON decoding).
  - Updated `AssistantComposer.tsx`:
    - Capability-gated paperclip button: active only when `currentModel` has `vision` in `available_capabilities`, an active conversation exists, and `attachments.length < 4`.
    - Hidden file input accepting `image/png,image/jpeg` with client-side 10 MiB checks.
    - Staged preview cards displaying `filename_display`, `size_bytes`, and removal button.
  - Synchronous lifecycle state machine in `AssistantView.tsx`:
    - Rollback of uploaded record on Blob preview fetch failure.
    - Explicit staged removal calling `deleteAttachment` API; preserves card on network failure.
    - Fail-closed conversation transition lock (`conversationTransitionRef`) preventing concurrent actions during conversation creation/switching.
    - `outcome_unknown` handling on ambiguous transport failures before HTTP acceptance.
    - Component unmount cleanup: always revokes in-memory Blob object URLs (`URL.revokeObjectURL()`); if composer lifecycle state is definitely safe and idle, performs best-effort remote `DELETE` on definitely-staged attachment rows; if any send, upload, removal, or conversation-transition action is in-flight or uncertain, strictly refrains from issuing destructive remote `DELETE` requests to preserve user data.

### Deferred Boundaries (Explicitly Out of Scope)
- **8B.7 — Persistent / History Image Rendering:** Fetching and displaying attachments on historical conversation message bubbles (`MessageOut.attachments`), message reload persistence, and message bubble object URL lifecycle (NEXT / UNBLOCKED). Under this explicit boundary, attachments appearing staged in the composer and binding transactionally upon send, but not yet rendering inside persisted message history bubbles, is expected incremental milestone behavior and not an 8B.6 defect.
- **8B.8 — Full Integration & Phase Closure:** Cross-stack integration verification, full regression suite execution, and formal Phase 8B closure report. (PLANNED).
- **Phase 8C:** Accessibility polish, mock file deletion, bundle optimization, and final PR closure. (PLANNED / BLOCKED).
- **WebP Support:** Deferred; requires verified compatibility with pinned `llama.cpp` Vulkan builds and Qwen3-VL vision projectors.
- **Physical Retention Purge:** Physical deletion / retention cleanup for soft-deleted attachment files is deferred and not implemented in slices 8B.0–8B.6. Its owning milestone must be established by future planning.

---

## 2. Files Changed

### 2.1 Persistence & Database Migration
- `backend/migrations/versions/006_add_attachments.py` — Alembic migration creating `attachments` table with 4 mixins, DDL defaults, and 7 indexes.
- `backend/app/models/attachment.py` — SQLAlchemy ORM model for `Attachment` with relationships to `Conversation` and `Message`.
- `backend/app/models/conversation.py` — Added `attachments` relationship with cascade soft-delete support.
- `backend/app/models/message.py` — Added `attachments` relationship (`lazy="selectin"`).
- `backend/app/models/__init__.py` — Registered and re-exported `Attachment`.
- `backend/app/db/base.py` — Consolidated model aggregation importing `Task`, `Conversation`, `Message`, `Memory`, and `Attachment` for deterministic Alembic discovery.

### 2.2 Schemas & Validation Contracts
- `backend/app/schemas/attachment.py` — Public schemas `AttachmentOut` and `AttachmentRef`; canonical constants (`MAX_SIZE_BYTES = 10MB`, `MAX_ATTACHMENTS_PER_MESSAGE = 4`, `ALLOWED_MIME_TYPES`).
- `backend/app/schemas/message.py` — Added `attachment_ids` to `MessageSend` and `attachments` to `MessageOut`.
- `backend/app/schemas/multimodal.py` — Internal provider-independent multimodal types (`TextContent`, `ImageAttachmentRef`, `ResolvedImageContent`, `ContentBlock`).
- `backend/app/schemas/llm.py` — Updated internal `ChatMessage.content` to `Union[str, List[ContentBlock]]` while preserving text-only public contracts.
- `backend/app/services/attachment_validator.py` — Pillow-backed fail-fast image validation (magic bytes, size, dimensions, megapixels, decompression bomb protection).
- `backend/pyproject.toml` & `backend/requirements.txt` — Added runtime dependencies: `Pillow>=10.4.0`, `python-multipart>=0.0.31`, and pinned `sqlalchemy[asyncio]>=2.0.32`.

### 2.3 API Endpoints & Services
- `backend/app/core/config.py` — Added `MAX_ATTACHMENT_REQUEST_BODY_BYTES = 12 * 1024 * 1024` (12 MiB multipart envelope).
- `backend/app/main.py` — Configured route-specific payload limit exception for attachment upload route.
- `backend/app/api/v1/endpoints/attachments.py` — Secure upload (`POST`), authenticated Blob preview (`GET`), and soft-delete (`DELETE`) endpoints with BOLA protection.
- `backend/app/api/v1/endpoints/conversations.py` — Refactored `send_message_stream` with pre-stream preparation transaction, lock transfer, active attachment mapping in `list_messages`, and cascading soft-delete in `delete_conversation`.
- `backend/app/services/attachment_service.py` — Attachment ID syntax validation and atomic conditional update `claim_attachments_for_message()` with failure classification.

### 2.4 Orchestration & LLM Providers
- `backend/app/services/assistant/media_resolver.py` — Sandboxed filesystem resolution, path traversal defense, MIME/signature revalidation, and asynchronous threadpool reading.
- `backend/app/services/assistant/orchestrator.py` — Extracted `prepare_turn()`, integrated vision capability gating on `available_capabilities`, multimodal content block assembly, and safe token estimation.
- `backend/app/services/llm/llama_cpp.py` — Updated `_translate_messages()` to map `ResolvedImageContent` to base64 data URIs; fail-closed generation lock release.
- `backend/app/services/llm/mock.py` — Updated mock provider to ignore image blocks safely without simulated vision.
- `backend/app/services/model_registry.py` — Canonicalized model matching helper `find_model_registry_entry()`.

### 2.5 Frontend Web Client & UI
- `frontend/web/src/services/api/attachmentApi.ts` — TypeScript API client: `uploadAttachment` (`apiFetch` + `FormData`), `deleteAttachment` (`apiFetch`), and `fetchAttachmentBlobUrl` (raw authenticated `fetch()` -> binary `Blob` -> `URL.createObjectURL()`).
- `frontend/web/src/services/api/conversationApi.ts` — Added `attachment_ids` to `StreamMessageOptions`.
- `frontend/web/src/components/workspace/assistant/AssistantComposer.tsx` — Capability-gated paperclip button, hidden file input, staged attachment preview chips with metadata, and removal action.
- `frontend/web/src/components/workspace/AssistantView.tsx` — Synchronous attachment lifecycle state machine, preview rollback, explicit removal semantics, conversation transition locks, and unmount object URL revocation.

### 2.6 Contract & Testing Infrastructure
- `contracts/openapi/openapi.json` — Synchronized OpenAPI specification reflecting 22 routes with zero drift.
- `backend/tests/test_attachments.py` — 18 tests for migration 006, mixins, defaults, indexes, and ORM parity.
- `backend/tests/test_attachment_api.py` — 35 tests for upload limits, validation, collision avoidance, previews, soft-delete, and BOLA.
- `backend/tests/test_attachment_binding.py` — 27 tests for atomic binding transaction, pre-stream rejection, rollback, and concurrency.
- `backend/tests/test_media_resolver.py` — 22 tests for path containment, disk reads, and traversal defense.
- `backend/tests/test_llama_translator.py` — 13 tests for multimodal data URI formatting and fail-closed locks.
- `backend/tests/test_assistant_orchestrator.py` — Regression tests for streaming lifecycle, prompt translation, and multimodal content delivery.
  *(Note: `backend/tests/test_conversations.py` was not modified in Phase 8B; pre-existing test coverage confirms conversation cascade soft-delete behavior).*
- `frontend/web/src/test/attachmentApi.test.ts` — 18 unit tests for frontend attachment API client.
- `frontend/web/src/test/attachmentComposer.test.tsx` — 20 integration tests for composer capability gating, staging, previews, removal, and send payloads.

---

## 3. How the Logic Works

### 3.1 Happy Path: End-to-End Multimodal Turn Execution

```mermaid
sequenceDiagram
    autonumber
    participant User as User
    participant Composer as AssistantComposer (Web)
    participant CoreAPI as Core API (:8000)
    participant DB as SQLite (companion.db)
    participant Disk as Local Storage (Data/attachments/)
    participant Orch as Orchestrator & MediaResolver
    participant Router as llama.cpp Router (:8085)

    Note over User,Router: 1. Capability Gating & Staging
    User->>Composer: Selects image file (PNG/JPEG)
    Composer->>Composer: Client-side validation (MIME, <= 10 MiB, count <= 4)
    Composer->>CoreAPI: POST /api/v1/conversations/{id}/attachments (multipart/form-data)
    CoreAPI->>CoreAPI: Validate Pillow header, size, dimensions, megapixels
    CoreAPI->>Disk: Exclusive temp create ("xb") -> atomic rename to UUID filename
    CoreAPI->>DB: INSERT INTO attachments (message_id=NULL, is_deleted=FALSE)
    CoreAPI-->>Composer: 201 Created (AttachmentOut: id, filename, size, mime)
    Composer->>CoreAPI: GET /api/v1/conversations/{id}/attachments/{id}/preview
    CoreAPI-->>Composer: 200 OK (image/png binary stream)
    Composer->>Composer: URL.createObjectURL(blob) -> display preview chip

    Note over User,Router: 2. Atomic Pre-Stream Turn Preparation
    User->>Composer: Enters prompt & clicks Send
    Composer->>CoreAPI: POST /api/v1/conversations/{id}/messages (SSE, attachment_ids=[id])
    CoreAPI->>CoreAPI: Acquire conversation asyncio.Lock
    CoreAPI->>DB: BEGIN TRANSACTION (prepare_turn)
    CoreAPI->>DB: INSERT INTO messages (user turn)
    CoreAPI->>DB: INSERT INTO messages (assistant placeholder)
    CoreAPI->>DB: UPDATE attachments SET message_id = user_id WHERE id IN (...) AND message_id IS NULL
    CoreAPI->>DB: COMMIT TRANSACTION
    CoreAPI-->>Composer: HTTP 200 OK (Headers accepted; SSE stream established)
    CoreAPI->>CoreAPI: Transfer asyncio.Lock ownership to stream generator

    Note over User,Router: 3. Vision Resolution & Model Inference
    CoreAPI->>Orch: orchestrate_chat_stream(PreparedTurn, lock)
    Orch->>Orch: Check ModelCapability.vision in active_entry.available_capabilities
    Orch->>Orch: MediaResolver.resolve_image_content()
    Orch->>Disk: Verify path in ATTACHMENT_DIR & read file bytes asynchronously
    Orch->>Router: POST /v1/chat/completions (text + base64 data-URI image blocks)
    Router-->>CoreAPI: Stream token chunks
    CoreAPI-->>Composer: data: {"type": "token", "content": "..."}
    Router-->>CoreAPI: Stream complete ([DONE])
    CoreAPI->>DB: Update assistant message (status="completed", content=full_text)
    CoreAPI->>CoreAPI: Release asyncio.Lock in finally:
    Composer->>Composer: URL.revokeObjectURL() on staged chips
```

### 3.2 Detailed Step-by-Step Logic

1. **Capability Gating & Staging (Composer UI):**
   - The paperclip button inspects `currentModel?.library_state?.available_capabilities`. If `vision` is missing (or if `mmproj` projector is absent), the button is disabled with a helpful tooltip.
   - When clicked, a hidden `<input type="file" accept="image/png,image/jpeg" />` prompts the user.
   - The frontend validates MIME type, 10 MiB size limit, and staged attachment count (< 4).
   - Valid files are uploaded via `uploadAttachment()` as `multipart/form-data` with Bearer auth.
   - Upon HTTP 201 receipt, the frontend immediately calls `fetchAttachmentBlobUrl()` to retrieve a secure binary Blob and creates an in-memory object URL via `URL.createObjectURL()`.

2. **Backend Upload & Storage Promotion:**
   - In `attachments.py`, `POST /attachments` verifies conversation existence and user ownership (`BOLA`).
   - Request bytes are read in 64 KiB chunks and validated by `attachment_validator.py` using Pillow:
     - Header magic bytes checked (`\x89PNG\r\n\x1a\n` or `\xff\xd8\xff`).
     - Decoded dimensions <= 8192 px; total megapixels <= 32.0 MP; decompression bomb guards active.
   - The file is written using Python's exclusive creation mode `open(temp_path, "xb")` to prevent overwriting existing files.
   - An `Attachment` row is inserted into SQLite with `message_id = None` (staged state).
   - The temporary file is promoted to its final UUID-based path via atomic `os.rename()`.
   - On any failure during validation, writing, or DB flush, the transaction rolls back, temporary files are unlinked, and zero orphan records or files survive.

3. **Pre-Stream Turn Preparation Transaction (`prepare_turn`):**
   - When the user sends a turn containing `attachment_ids`, the request hits `POST /conversations/{id}/messages`.
   - Before any HTTP headers or SSE response bodies are sent:
     - The per-conversation `asyncio.Lock` is acquired.
     - `prepare_turn()` initiates an atomic SQLite transaction.
     - A user `Message` and an assistant placeholder `Message` are inserted.
     - `claim_attachments_for_message()` executes a conditional `UPDATE` setting `message_id = user_message.id` where `id IN (:attachment_ids)` and `message_id IS NULL` and `is_deleted = FALSE`.
     - If the number of claimed rows does not match `len(attachment_ids)`, the transaction rolls back completely: the user message is discarded, the assistant placeholder is discarded, any partially updated attachments revert to staged state, and an HTTP 400/403/404/422 error is returned to the client.
     - If all claims succeed, the transaction commits. The endpoint constructs the `StreamingResponse` and transfers the `asyncio.Lock` to the generator.

4. **Media Resolution & Vision Wire Translation:**
   - Inside `orchestrate_chat_stream()`, the orchestrator verifies whether the active model has `vision` in `available_capabilities`.
   - If vision is available:
     - `media_resolver.py` is called for each bound attachment.
     - The resolver verifies that the attachment exists, belongs to the caller, belongs to the current conversation, is bound to the current turn, and is not deleted.
     - It resolves `(COMPANION_DATA_ROOT / attachment.storage_path).resolve()` and strictly asserts that the resulting absolute path resides inside `settings.ATTACHMENT_DIR`.
     - File bytes are read asynchronously via `asyncio.to_thread` and packaged into `ResolvedImageContent(mime_type, data)`.
     - The orchestrator wraps these into internal `ContentBlock` structures alongside the user's `TextContent`.
   - `LlamaCppProvider._translate_messages()` translates `ResolvedImageContent` into OpenAI-compatible `image_url` data URIs (`data:{mime_type};base64,{b64}`).
   - If the active model lacks vision, attachments are ignored and only text is passed to the provider, preventing inference errors.

### 3.3 Explicit Failure & Recovery Paths

| Failure Scenario | Layer | Behavior & Recovery State |
| :--- | :--- | :--- |
| **Upload Validation Failure** | Backend Validator | Pillow rejects corrupted bytes, > 10 MiB size, > 8192 px, or spoofed MIME. Returns HTTP 413 or 422. Zero DB rows created; temp file unlinked. Frontend displays error toast. |
| **Blob Preview Fetch Failure** | Frontend View | If `fetchAttachmentBlobUrl` fails after an upload, the frontend enters rollback: calls `deleteAttachment` API to soft-delete the orphan row, discards staged state, and warns the user. |
| **Staged Removal Failure** | Frontend View | If user clicks "Remove" on a staged chip and the `DELETE` API call fails (network drop), the frontend **preserves** the chip in the composer with an error banner, preventing silent desynchronization between UI and DB. |
| **Pre-Stream Rejection** | Backend Endpoint | If `attachment_ids` contains an invalid, cross-conversation, foreign-owner, soft-deleted, or already-claimed ID, `prepare_turn` rolls back the entire transaction. Returns HTTP 400/403/404/422 **before** SSE headers. Zero messages created. Staged attachments remain staged. |
| **Pre-Acceptance Transport Drop** | Frontend Client | If the network drops before HTTP response headers are received (`sendPhase === 'accepting'`), the frontend marks state as `outcome_unknown`. Composer retains draft text and staged attachments so user does not lose work. |
| **Mid-Stream Cancellation** | Backend Stream | If user clicks "Stop" or closes socket mid-stream (`asyncio.CancelledError`), the stream catches cancellation in `finally:`. The committed user message and bound attachments **remain preserved** in history. Assistant placeholder status is set to `"cancelled"`. `asyncio.Lock` is released immediately. |
| **Post-Acceptance Inference Failure** | Backend Stream | If llama.cpp crashes or throws an exception during generation, the stream emits a typed error frame (`{"type": "error"}`), updates assistant placeholder status to `"failed"`, commits the DB, and releases `asyncio.Lock`. Bound attachments remain safely committed to the user message. |
| **Conversation Departure / Unmount** | Frontend Lifecycle | When user navigates away or switches conversations, `AssistantView` cleanup always revokes all active in-memory Blob object URLs (`URL.revokeObjectURL()`). If composer lifecycle is definitely safe and idle, it performs best-effort remote `DELETE` on definitely-staged attachments; if any upload, removal, send, or transition is in-flight or in an uncertain state, it strictly refrains from destructive remote `DELETE` to prevent data loss. |

---

## 4. Key Concepts

### 1. Staged Attachment
An uploaded attachment file that has been validated and persisted in the database with `message_id = NULL`. It represents an image prepared by the user in the composer that is ready to be sent with the next chat turn. Staged attachments can be previewed or explicitly removed by the user. If left uncommitted, they remain staged until claimed by a send turn or purged by future retention cleanup.

### 2. Transactional Binding
The atomic database operation occurring during `prepare_turn()` where one or more staged attachment IDs are formally linked to a user `Message` record by setting `message_id = user_message.id`. This update is conditional (`message_id IS NULL`, `owner_id = user`, `conversation_id = conv`, `is_deleted = FALSE`). If any attachment in the request cannot be claimed, the entire turn preparation transaction rolls back, preventing partial messages or half-bound attachments.

### 3. Authenticated Blob URL
An in-memory browser URL (`blob:http://localhost:5173/...`) generated by calling `URL.createObjectURL(blob)` on binary image data retrieved via raw authenticated `fetch()` (since the shared `apiFetch` client JSON-decodes responses). Because standard browser `<img src="/api/...">` tags cannot pass HTTP `Authorization: Bearer <token>` headers, authenticated endpoints require fetching the image as a binary `Blob` with explicit auth headers and transforming it into an object URL for display.

### 4. Vision Capability Gate
The multi-layer gating mechanism determining whether multimodal features are active. The frontend checks `ModelCapability.vision in activeModel.library_state.available_capabilities` (which requires both a vision-capable GGUF and a verified companion `mmproj` projector). The backend orchestrator independently verifies this capability before resolving image bytes. If vision is absent, the UI disables attachment inputs, and the backend degrades gracefully to text-only inference.

### 5. Fail-Closed Lifecycle
An architectural safety principle where any ambiguity, transport drop, or validation error results in a safe, non-destructive state that prevents data loss or corruption:
- If turn preparation fails, no partial messages survive.
- If network drops before HTTP acceptance, the client assumes `outcome_unknown` and preserves draft text and staged attachments.
- If generation is cancelled mid-stream, committed attachments and user messages are preserved.
- If a preview fetch fails, the uploaded backend record is cleanly rolled back.

---

## 5. Verification Steps

### 5.1 Automated Checks

All automated checks were executed and verified against the implementation baseline and pushed delivery commits:

- **Walkthrough Delivery Baseline:**
  - Verified Commit SHA: `7693640f9961ad695be69ddaab945fd4f8b9a7ad`
  - GitHub Actions CI Run: **#20 (SUCCESS)**
- **Historical Delivery Milestones:**
  - Implementation Baseline SHA: `58af6f282b5533409ce4794235422504cbd80a7c` (CI Run #18: SUCCESS)
  - Documentation Closure SHA: `6ba0628b80a0607593d524cf248cf93d2948e3c8` (CI Run #19: SUCCESS)

| Verification Suite | Target | Observed Result | Status |
| :--- | :--- | :--- | :--- |
| **Backend Test Suite** | `pytest backend/tests/` | **321 passed** (0 failures, 0 regressions) | `PASS` |
| **Frontend Test Suite** | `npm --prefix frontend/web test -- --run` | **185 passed** across 9 test files | `PASS` |
| **TypeScript Typecheck** | `npx --prefix frontend/web tsc --noEmit` | **0 errors** | `PASS` |
| **Frontend Production Build** | `npm --prefix frontend/web run build` | Vite production build passed | `PASS` |
| **OpenAPI Contract Parity** | `python scripts/check_openapi_contract.py` | **22 routes**, zero drift detected | `PASS` |
| **Attachment Migration Chain** | Alembic `005 -> 006 -> 005 -> 006` | Clean upgrade, downgrade, and re-upgrade | `PASS` |
| **ORM & DDL Schema Parity** | `test_attachments.py::test_attachment_orm_parity` | Exact match on columns, types, defaults, indexes | `PASS` |

### 5.2 Manual / User-Owned Verification Checks

The following step-by-step checklist confirms visual, experiential, and hardware behavior:

- [ ] **Step 1: Verify Capability Gating on Model Without Vision**
  - Launch Web UI (`npm run dev`) and Backend (`uvicorn app.main:app`).
  - Ensure the Web client already has the valid local pairing credential configured for the current development session before testing protected model/attachment endpoints.
    *(Known UI limitation at delivery: pairing-key onboarding/error presentation is not fully wired in the current Settings UI and is outside the 8B.0–8B.6 multimodal scope).*
  - In Models view, ensure a text-only model or no model is loaded.
  - Navigate to Assistant chat view.
  - **Expected Result:** Paperclip icon in composer is disabled; hovering shows tooltip indicating vision capability is unavailable.

- [ ] **Step 2: Verify Capability Gating with Qwen3-VL Vision Model**
  - In Models view, load `qwen3-vl-2b-instruct` or `qwen3-vl-4b-instruct` (requires companion `mmproj` projector).
  - Return to Assistant chat view.
  - **Expected Result:** Paperclip icon is active and enabled.

- [ ] **Step 3: Staging, Client Validation & Blob Preview**
  - Click the paperclip icon and select a valid PNG or JPEG image (< 10 MiB).
  - **Expected Result:** Upload succeeds (HTTP 201), preview endpoint is called, and a staged preview card appears above the composer showing thumbnail, filename, and file size.
  - Try selecting an unsupported file (e.g., `.txt` or `.webp`) or a file > 10 MiB.
  - **Expected Result:** Client-side error toast rejects the file immediately without making a network request.

- [ ] **Step 4: Explicit Staged Removal**
  - Click the "X" (Remove) button on a staged attachment card.
  - **Expected Result:** Frontend issues `DELETE /api/v1/conversations/{id}/attachments/{id}` (HTTP 204), revokes the local object URL, and removes the chip from the composer.

- [ ] **Step 5: Send Multimodal Turn & Verify Binding**
  - Attach 1 or 2 images and type a prompt (e.g., "Describe what you see in this image").
  - Click Send.
  - **Expected Result:** Staged preview cards clear from composer; turn is accepted; user bubble renders; assistant streams response describing image content.

*(Note: Slice 8B.8 covers full test suite execution, TypeScript check, production build, OpenAPI contract synchronization, migration chain verification, ephemeral data-root isolation, active documentation updates, and Phase 8B completion reporting. Live hardware/model smoke on the RX 580 Vulkan runtime may be conducted as available, but is not currently a locked 8B.8 requirement).*

---

## 6. Safe Customization & Invariants

### 6.1 Tunable Parameters

The following parameters are centrally defined in backend configuration and schemas:

| Parameter | Location | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `MAX_ATTACHMENT_REQUEST_BODY_BYTES` | `backend/app/core/config.py` | `12 * 1024 * 1024` (12 MiB) | Multipart upload envelope ceiling for attachment endpoint only. |
| `MAX_REQUEST_BODY_BYTES` | `backend/app/core/config.py` | `2 * 1024 * 1024` (2 MiB) | Global HTTP body limit for all standard endpoints. |
| `MAX_SIZE_BYTES` | `backend/app/schemas/attachment.py` | `10 * 1024 * 1024` (10 MiB) | Maximum decoded image file size. |
| `MAX_ATTACHMENTS_PER_MESSAGE` | `backend/app/schemas/attachment.py` | `4` | Maximum number of attachments permitted per message. |
| `MAX_PIXEL_DIMENSION` | `backend/app/schemas/attachment.py` | `8192` px | Maximum allowable width or height per image side. |
| `MAX_MEGAPIXELS` | `backend/app/schemas/attachment.py` | `32.0` MP | Maximum allowable total pixel count (`width * height / 1M`). |
| `ALLOWED_MIME_TYPES` | `backend/app/schemas/attachment.py` | `{"image/png", "image/jpeg"}` | Permitted image formats (WebP deferred). |

### 6.2 Architectural Invariants

1. **Storage Path Privacy:** The internal filesystem path (`storage_path`) is **never** exposed in any public API schema, OpenAPI response, or frontend interface.
2. **Authenticated Previews Only:** Browsers are never directed to load images via raw `<img src="/api/...">` tags. All previews must be retrieved via authenticated `Blob` fetches and rendered as object URLs.
3. **Provider DB/Filesystem Decoupling:** `LlamaCppProvider` and `MockLLMProvider` must **never** perform database queries, construct storage paths, or perform filesystem IO. All binary reading and validation belongs exclusively to `media_resolver.py`.
4. **Public LLM API String-Only:** Public `/api/v1/chat/completions` request schemas remain strictly string-only. Internal multimodal blocks (`ResolvedImageContent`) are strictly confined to internal orchestrator-to-provider interfaces and never leak into OpenAPI contracts.
5. **Atomic Claim or Abort:** Pre-stream attachment binding in `prepare_turn()` must be all-or-nothing. If any single attachment ID in a send payload cannot be claimed, the transaction rolls back completely before any streaming response headers are sent.
6. **Cancellation History Preservation:** If an assistant stream is cancelled or encounters an error mid-generation, the user message and its committed attachments **must remain preserved** in history.
7. **Strict Path Containment:** All resolved attachment file paths must be strictly verified to reside within `settings.ATTACHMENT_DIR.resolve()`. Any path escaping this boundary must raise a traversal security exception.

---

## 7. Troubleshooting

| Symptom | Likely Cause | Resolution |
| :--- | :--- | :--- |
| **Paperclip icon is permanently disabled** | 1. No active conversation selected.<br>2. Loaded model lacks `vision` in `available_capabilities`.<br>3. Model is vision-capable but companion `mmproj` projector is missing on disk. | 1. Select or create a conversation.<br>2. Load a vision model (e.g. Qwen3-VL).<br>3. Verify the `mmproj-*.gguf` file exists in `models/vision/` alongside the model GGUF. |
| **Attachment rejected with HTTP 413** | File size exceeds 10 MiB limit or multipart request exceeds 12 MiB envelope limit. | Compress or resize the image to under 10 MiB before uploading. |
| **Attachment rejected with HTTP 422** | 1. Unsupported MIME type (e.g., WebP, GIF, PDF).<br>2. Magic bytes do not match PNG or JPEG headers.<br>3. Dimensions exceed 8192 px or 32 MP budget. | 1. Ensure file is standard PNG or JPEG.<br>2. Do not rename non-image files to `.png` or `.jpg`.<br>3. Downscale images exceeding 8192 px on a side. |
| **Preview image fails to load after upload** | Frontend failed to fetch binary Blob from preview endpoint (auth token expired or network drop). | Check browser console network tab; verify `Authorization: Bearer` header is present. Frontend will automatically trigger rollback of staged attachment. |
| **Staged removal fails / chip remains** | Network drop or backend failure during `DELETE /api/v1/conversations/{id}/attachments/{id}`. | Frontend preserves the chip to prevent state desynchronization. Retry deletion when backend connectivity is restored. |
| **Send request freezes in "outcome_unknown"** | HTTP connection dropped before backend accepted turn headers. | Draft text and staged attachments are preserved in composer. Check backend server logs and retry send once connection is restored. |
| **Backend error: "ATTACHMENT_NOT_FOUND" or "ATTACHMENT_FORBIDDEN"** | Turn payload attempted to claim an attachment belonging to another user, another conversation, or an already-claimed attachment. | Staged attachments can only be sent once within their original conversation. Re-upload image if attempting to send in a different conversation. |
| **Images visible in composer but missing from chat history bubbles after send** | Historical message attachment rendering is assigned to slice 8B.7 (`MessageOut.attachments` rendering). | Expected incremental milestone behavior. Slice 8B.6 delivers composer staging and transactional turn binding; persistent history rendering is scheduled next in 8B.7. |
| **Database locked / contention error** | Unexpected concurrent SQLite write contention. | Inspect active runtime processes and server logs, ensure SQLite WAL mode is active (`PRAGMA journal_mode=WAL`), and retry once contention clears. (Source does not implement automatic retry/backoff). |

---
