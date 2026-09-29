# Multimodal and Media Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the storage, validation, lifecycle, and model ingestion boundaries for companion multimodal attachments and media assets:
- Image attachment ingestion, validation, and storage.
- Staged attachment claiming and message association.
- Multimodal context translation for local and cloud vision LLMs.
- Delivery status and boundaries across Phase 8B slices.
- Boundaries separating core image understanding from future media and generative rendering.

It governs the secure handling of binary visual inputs from user upload to model comprehension.

---

## 2. Durable Architecture & Invariants

### 2.1 Multimodal Vision Delivery State (Phase 8B)

Multimodal vision understanding is governed by the approved Phase 8B delivery roadmap:
- **Slices 8B.0–8B.6:** `COMPLETE / VERIFIED / MERGED` into verified `develop` baseline (`4b2f5fe3aa2a302b825408073d1b135bf2ff92e1`).
- **Slice 8B.7 (Persistent Message Attachment Rendering):** `NEXT / UNBLOCKED` (paused strictly during documentation reconciliation).
- **Slice 8B.8 (Full Integration & Phase Closure):** `PLANNED`.
- **Phase 8B Overall:** `IN PROGRESS`.

### 2.2 Approved Scope vs. Non-Image Media

- **PC V1 Approved Scope:** Strictly **image understanding** (PNG, JPEG) associated with user conversational messages.
- **Unpromoted Media Types:** Non-image attachments (e.g., PDF/OCR document ingestion, video clips, standalone audio recordings, direct camera feeds) are **not** approved PC V1 scope. They remain open for future milestone evaluation.
- **Generative Image Rendering:** The *Stable Diffusion Presence Renderer* is classified as `EXPERIMENTAL / NOT STARTED / FUTURE / UNSCHEDULED` in the Feature Promotion Map. It is distinct from conversational image understanding and is not a PC V1 requirement.

### 2.3 Security & Attachment Invariants

- **Ownership & BOLA Isolation:** Attachments are strictly scoped to the authenticated Profile (`owner_id`) and parent `conversation_id`. Cross-conversation attachment binding or cross-user access is prohibited.
- **Storage Path Containment:** Binary files are written strictly within the configured attachment storage directory (`settings.ATTACHMENT_DIR` under the resolved `COMPANION_DATA_ROOT`). All file path resolutions enforce strict canonical path containment to prevent directory traversal attacks.
- **Upload / File Validation:** File size (10 MiB raw file ceiling), route-specific multipart request envelope (12 MiB via `settings.MAX_ATTACHMENT_REQUEST_BODY_BYTES`), pure byte-signature inspection (PNG and JPEG), Pillow decoding verification, maximum pixel dimensions (max 8192×8192 px), maximum total pixels (max 32.0 MP), and corruption/decompression-bomb protection are enforced prior to permanent file storage. (The ceiling of maximum 4 attachments per message is a message-send validation constraint, not an upload-time storage check.)
- **Message-Send Validation & Staging Binding:** During message submission, the turn orchestrator validates `attachment_ids` syntax, uniqueness, the ceiling of maximum 4 attachments per message (`MAX_ATTACHMENTS_PER_MESSAGE = 4`), ownership/conversation scope isolation, and active/unclaimed availability.
- **Transaction & Rollback Semantics:**
  - *Atomic Turn Preparation (`prepare_turn`):* Validates attachment IDs, allocates the message sequence, inserts the user message row, inserts the assistant placeholder message row, claims the attachments, and commits the transaction once.
  - *Pre-Commit Failure:* If `prepare_turn` encounters an error or fails validation before the commit point, the transaction is rolled back cleanly, inserting no message rows and leaving staged attachments unclaimed.
  - *Post-Commit Persistence:* Once `prepare_turn` commits, the user message, assistant placeholder, and attachment bindings are permanently committed in the database.
  - *Streaming Failure / Disconnection Cancellation:* If `orchestrate_chat_stream` subsequently fails during token generation, the committed user message and attachment bindings remain; the assistant placeholder is marked `failed` (preserving any partial generated content). If generation is cancelled or client disconnection causes cancellation, the assistant placeholder is marked `cancelled` while committed preparation state remains.


---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Backend Storage & Validation

Verified in `app.models.attachment.Attachment` (migration 006), `app.schemas.attachment`, and `app.services.attachment_validator`:
- **ORM Entity Schema:** `id` (UUIDv4), `conversation_id` (FK to `conversations.id`), `message_id` (FK to `messages.id`, nullable until claimed), `owner_id` (String), `filename_display` (String(255)), `storage_filename` (String(128)), `storage_path` (String(512)), `mime_type` (String(64), restricted to `image/png` or `image/jpeg`), `size_bytes` (Integer, max 10 MiB), `image_width` (Integer, nullable), `image_height` (Integer, nullable), `is_deleted` (Boolean), `deleted_at` (DateTime, optional), `created_at`, `updated_at`.
- **Pure Byte Signature Inspection:** Pure byte-signature inspection checks the initial byte sequence for PNG (`\x89PNG\r\n\x1a\n`) and JPEG (`\xff\xd8\xff`). WebP signatures (`RIFF`...`WEBP`) are detected solely so validation can reject WebP uploads as deferred. MIME detection is handled purely in application code without external file type inspection libraries, followed by Pillow decoding to verify raster integrity.
- **Decompression Bomb & Dimension Defenses:** Enforces dimension limits (`MAX_PIXEL_DIMENSION = 8192 px`) and total pixel boundaries (`MAX_MEGAPIXELS = 32.0 MP`) to defend against pixel-expansion denial-of-service without allocating full rasters.
- **Validation Pipeline:** Enforces MIME whitelist (`ALLOWED_MIME_TYPES = frozenset({"image/png", "image/jpeg"})`), raw size ceiling (`MAX_SIZE_BYTES = 10 * 1024 * 1024`), route multipart envelope (`settings.MAX_ATTACHMENT_REQUEST_BODY_BYTES = 12 * 1024 * 1024`), and pixel bounds (`8192 px`, `32.0 MP`) during upload. Message turn submission independently enforces the ceiling of maximum 4 attachments per message (`MAX_ATTACHMENTS_PER_MESSAGE = 4`).

### 3.2 Endpoints & Ingestion Pipeline

Verified in `backend/app/api/v1/endpoints/attachments.py` and `conversations.py`:
- `POST /api/v1/conversations/{conversation_id}/attachments`: Validates and uploads an image file (under 10 MiB file and 12 MiB request envelope limits), stores it on disk, and returns metadata.
- `GET /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview`: Serves raw binary image bytes authenticated via Bearer token with strict BOLA checks and path containment.
- `DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}`: Soft-deletes an attachment (`is_deleted = True`, `deleted_at = now()`).
- `prepare_turn` Binding: During `POST /api/v1/conversations/{conversation_id}/messages`, validates supplied `attachment_ids` format, uniqueness, and ceiling of maximum 4 attachments per message, verifies ownership, active/unclaimed availability, and conversation binding, and claims them within an atomic single-commit preparation transaction.

### 3.3 Multimodal Model Translation

Verified in `backend/app/services/attachment_service.py` and `app.services.llm`:
- **Media Resolver:** Resolves active attachment IDs into base64-encoded data URIs or disk paths for model consumption.
- **Vision Capability Gating:** Checked against `ModelRegistry.supports_vision`. If the active model lacks vision capabilities, attachments are rejected or handled via graceful fallback.
- **llama.cpp / OpenAI Format Translation:** Formats image payloads into OpenAI-compatible multimodal content arrays (`[{"type": "text", ...}, {"type": "image_url", ...}]`) supported by `llama.cpp` server and cloud providers.

### 3.4 Frontend Composer & Previews

Verified in `frontend/web/src/components/chat/`:
- **Staging Bar:** `AttachmentStagingBar` renders thumbnails of staged uploads with individual remove buttons.
- **Authenticated Previews:** Fetches binary data via authenticated API client and generates secure Object URLs (`URL.createObjectURL(blob)`).
- **Cleanup Guarantees:** Revokes Object URLs on component unmount to prevent browser memory leaks.
- **Transition Locks:** Disables file input during message streaming or active uploads.

### 3.5 Explicitly Unimplemented Capabilities

- **Frontend Conversation History Rendering (Slice 8B.7):** `NOT IMPLEMENTED YET`. Historical message bubbles do not yet render attached images; rendering is currently implemented only in the staging composer bar.
- **Integration Test Closure (Slice 8B.8):** `PLANNED`.
- **Live Hardware Vision Benchmarks:** Live RX 580 vision inference latency benchmarks are historical reference data, not a gating closure requirement.

---

## 4. Approved Target Architecture / Not Yet Implemented

The following target capabilities are approved under Phase 8B:

1. **Persistent Message Attachment Rendering (Slice 8B.7 / PC V1):**
   - Frontend `AttachmentRef` propagation and persistent user-message attachment rendering in conversation history.
   - Authenticated history Blob fetching with persistence across page reload and conversation switching.
   - Client-side Blob URL caching and revocation/cleanup.
   *(Note: High-resolution preview modals, pan/zoom interactions, or exact thumbnail card UI layouts belong to open design / design specification rather than locked architectural gates.)*
2. **Phase 8B Full Integration Closure (Slice 8B.8 / PC V1):**
   - Final Phase 8B integration and closure verification across the repository baseline, including:
     - Full backend test suite execution and verification.
     - Full frontend test suite execution and verification.
     - TypeScript compiler check (`tsc --noEmit`).
     - Vite production build verification (`npm run build`).
     - OpenAPI schema contract verification.
     - Database migration chain integrity verification.
     - Ephemeral data-root isolation test runs.
     - Active documentation and task tracker updates.
     - Final Phase 8B delivery and completion report.
     - End-to-end attachment upload, staging, turn preparation, SSE streaming with vision tokens, and history reload verification.
   *(Note: Live hardware RX 580 benchmarking remains historical reference data, not a gating closure requirement.)*

---

## 5. OPEN DESIGN

The following implementation choices are intentionally left open for subsequent technical design:

- **Non-Image Media Ingestion:** Architecture for PDF documents, audio clips, and OCR pipelines for post-V1 milestones.
- **Image Optimization & Transcoding:** Optional on-disk thumbnail generation or WebP compression to reduce disk footprint.
- **Attachment Retention & Trash Sweeps:** Automated background purge schedules for unreferenced or deleted attachments.
- **Generative Visual Presence:** Exploration of local diffusion models (Stable Diffusion) for companion visual mood expressions (classified as future experimental).

---

## 6. Security & Ownership Boundaries

- **Strict Path Containment:**
  ```python
  if not resolved_path.is_relative_to(base_storage_dir):
      raise CompanionSecurityError("Path traversal detected")
  ```
- **Broken Object Level Authorization (BOLA):** Every attachment access verifies `attachment.owner_id == authenticated_user_id` and `attachment.conversation_id == target_conversation_id`.
- **Pre-Processing DoS Protection:** Decompression bombs, oversized payloads, and spoofed files are rejected before image parsing consumes significant CPU or RAM.

---

## 7. Canonical Relationships & Cross-Links

- **Canonical System Baseline:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture, Multimodal Vision Understanding)
- **Feature Promotion Manifest:** [`docs/02_Planning/FEATURE_PROMOTION_MAP.md`](../../02_Planning/FEATURE_PROMOTION_MAP.md) (Multimodal Vision Understanding, Stable Diffusion Presence Renderer)
- **Active Implementation Plan:** [`docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`](../../02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md)
- **Assistant Domain Specification:** [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](assistant-and-conversations.md)
