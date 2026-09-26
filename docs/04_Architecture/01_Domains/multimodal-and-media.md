# Multimodal and Media Architecture

> **Document Role:** Focused staged domain architecture specification (Pass R11.2).  
> **Authority Precedence:** Focused staged specification authored during R11.2. AUTHORITY TRANSFER PENDING R11.4. Current legacy canonical documents remain primary authority until explicit R11.4 human review and authorization. Primary canonical authority remains in [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) (§2 Core Architecture) until the formal R11.4 Authority Transfer Gate is reviewed and authorized.

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
- **Storage Path Containment:** Binary files are written strictly within the configured storage directory (`DATA_DIR/attachments`). All file path resolutions enforce strict canonical path containment to prevent directory traversal attacks.
- **Strict Pre-Upload Validation:** File size (10 MiB cap), multipart request ceilings (11 MiB fail-closed), magic byte validation, dimensions (max 4096×4096), and megapixel limits (max 16.8 MP) are enforced prior to permanent storage.
- **Staging & Atomic Claiming:** Attachments are uploaded in a staged state (`message_id = NULL`) and claimed by a message within an atomic turn preparation transaction. Failed turns execute clean rollback.

---

## 3. Current Verified Implementation

Repository source code and test suites verify the following baseline reality:

### 3.1 Backend Storage & Validation

Verified in `app.models.attachment.Attachment` (migration 006) and `app.services.attachment_validator`:
- **Entity Schema:** `id` (UUIDv4), `conversation_id` (FK to `conversations.id`), `message_id` (FK to `messages.id`, nullable until claimed), `owner_id` (String), `filename_original`, `filename_display`, `storage_path`, `mime_type` (`image/png` or `image/jpeg`), `size_bytes` (max 10 MiB), `width_px`, `height_px`, `is_deleted` (Boolean), `deleted_at`, `created_at`, `updated_at`.
- **Magic Byte Sniffing:** Inspects the first 16 bytes using Python `magic` / pure-Python header signatures; rejects spoofed file extensions.
- **Decompression Bomb Protection:** Pillow `Image.MAX_IMAGE_PIXELS` set to 17,000,000 to defend against pixel-expansion denial-of-service.
- **Validation Pipeline:** Enforces MIME whitelist (`image/png`, `image/jpeg`), size limit (`10 * 1024 * 1024` bytes), and dimension limits (`MAX_DIMENSION = 4096`).

### 3.2 Endpoints & Ingestion Pipeline

Verified in `backend/app/api/v1/endpoints/attachments.py` and `conversations.py`:
- `POST /api/v1/conversations/{conversation_id}/attachments`: Uploads and validates an image file, stores it on disk, and returns metadata.
- `GET /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview`: Serves raw binary image bytes authenticated via Bearer token with strict BOLA checks and path containment.
- `DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}`: Soft-deletes an attachment (`is_deleted = True`, `deleted_at = now()`).
- `prepare_turn` Binding: During `POST /api/v1/conversations/{conversation_id}/messages`, validates supplied `attachment_ids`, verifies they are active and unclaimed in the target conversation, and binds them to the user message atomically.

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
   - The frontend conversation history view renders responsive thumbnail cards for all attachments referenced by historical user messages.
   - Clicking thumbnails opens a high-resolution preview modal with pan/zoom controls.
2. **Phase 8B Full Integration Closure (Slice 8B.8 / PC V1):**
   - End-to-end automated testing verifying upload, staging, turn preparation, SSE streaming with vision tokens, and history reload across page refreshes.

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
