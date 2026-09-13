# Phase 8 Implementation Plan — PC Frontend Architecture, Multimodal & Polish

> **Implementer:** Gemini
> **Planner:** Antigravity (evidence-backed, correction pass applied)
> **Status:** Draft — awaiting final architecture review
> **Branch Strategy:** 3 sequential feature branches (Section 1)
> **Do not implement until user issues final APPROVED signal**

---

## Correction Summary (applied from review — do not revert)

| # | Original error | Correction applied |
|---|---------------|-------------------|
| 1 | Migration path `backend/alembic/versions/` | Corrected to `backend/migrations/versions/` |
| 2 | Abbreviated revision IDs `"005"` / `"006"` | Exact IDs: `005_scope_message_constraints` → `006_add_attachments` |
| 3 | Attachment model only partially used mixins | Full 4-mixin inheritance per repository convention |
| 4 | `back_populates` without matching Conversation side | Both Conversation + Message sides fully defined |
| 5 | Orchestrator built llama.cpp-specific `image_url` dict | Provider-independent typed content blocks; LlamaCppProvider translates |
| 6 | Sync base64 in async orchestrator path | Delegated to provider layer; async-safe boundary defined |
| 7 | `<img src="/api/.../preview">` without auth | Authenticated Blob fetch + `URL.createObjectURL` lifecycle |
| 8 | Attachment lifecycle undefined | Explicit 6-state lifecycle + orphan retention strategy |
| 9 | "mid-stream abort → attachment not committed" | Corrected: user message + image persist; only assistant generation cancelled |
| 10 | File size limit only | Full image safety: bytes, decoded dims, megapixel budget, decompression bomb |
| 11 | WebP assumed supported | WebP deferred until live end-to-end verification with pinned llama.cpp |
| 12 | `storage_path` incorporates user filename | UUID-based server-owned path; original filename as display metadata only |
| 13 | 8A plan narrower than Phase 8 objective | Added Header, navigation, Models progressive disclosure, Settings, offline states |
| 14 | `AssistantStatusBar` could invent telemetry | Explicit provenance rule: Measured/Configured/Estimated/Unavailable |
| 15 | History reload not addressed | Attachment metadata returned by GET messages; reload verification test added |
| 16 | Incomplete migration test plan | Full 006 migration tests: fresh, upgrade, downgrade, re-upgrade, schema parity |

---

## Section 1 — Branch Strategy

### Execution Order

```
develop  (baseline: 88 pytest, 38 vitest, 0 tsc errors, migration head 005_scope_message_constraints)
    │
    ├── feature/phase8-ui-foundation
    │       8A: Frontend only — zero backend schema changes, zero DB migrations
    │       ↓ merge to develop
    ├── feature/multimodal-image-attachments
    │       8B: Full stack — migration 006, storage, API, provider contract, frontend
    │       Based on merged 8A (multimodal composer depends on 8A design primitives)
    │       ↓ merge to develop
    └── feature/phase8-ui-integration-polish
            8C: No new features — mock cleanup, bundle, accessibility, final tests, docs
            Based on merged 8B
```

### Why 3 Branches

| Risk | 1 branch | 3 branches |
|------|----------|-----------|
| Migration 006 regression | Poisons all frontend work | Isolated to 8B |
| Revert unit | Cannot revert only attachment pipeline | 8B can be reverted without losing 8A |
| Review surface | ~200 files, unreviewable | Each branch is bounded and targeted |
| Test gate | All changes against one mixed baseline | Per-branch pass gate before next branch starts |

---

## Section 2 — Repository Evidence

| Finding | File | Line | Classification |
|---------|------|------|----------------|
| Paperclip adds fake string "doc_spec_v1.md" | `AssistantView.tsx` | 836 | **Confirmed Problem** |
| `streamSendMessage` sends `user_text: string` only | `conversationApi.ts` | 117 | **Confirmed Problem** |
| `MessageSend`: no attachment field | `schemas/message.py` | 9–12 | **Confirmed Problem** |
| `Message.content: Text` — string only | `models/message.py` | 29 | **Confirmed Problem** |
| No `attachments` table (migrations 001–005) | `migrations/versions/` | — | **Confirmed Problem** |
| `ChatMessage.content: str` — not multimodal | `schemas/llm.py` | 12 | **Confirmed Problem** |
| `Conversation` has no `attachments` relationship | `models/conversation.py` | 17–22 | **Confirmed Problem** |
| `HomeView.tsx` imports `mock/multilingualData.ts` | `HomeView.tsx` | 33 | **Technical Debt** |
| `mock/localAiData.ts` 17KB, `healthData.ts` 11KB still in bundle | `mock/` dir | — | **Technical Debt** |
| `AssistantView.tsx` 927 lines — monolith | `AssistantView.tsx` | — | **Technical Debt** |
| `BackendContext` already provides `registry`, `modelStatus`, `isOnline` | `BackendContext.tsx` | 18–34 | React Context adequate — no new state lib |
| WebP: not verified against pinned llama.cpp/Qwen3-VL path | Phase 7 walkthrough | — | **Deferred** |
| Video: not verified | Phase 7 walkthrough | — | **Deferred** |


---

## Section 3 — Phase 8A: Frontend Architecture & UX Harmonization

**Branch:** `feature/phase8-ui-foundation`
**Test gate:** >= 88 pytest (unchanged), >= 38 vitest, 0 tsc errors, clean build.
**Constraint:** Zero backend schema changes. Zero DB migrations. Zero new API endpoints.

### Disposition Review (repository-backed)

| Area | Disposition | Evidence / Reason |
|------|-------------|------------------|
| Header architecture | **Implement in 8A** | Header renders model name + profile — needs truthful provenance labels from `modelStatus` |
| HomeView mock greeting | **Implement in 8A** | `HomeView.tsx` L33 imports `getLanguageAwareGreeting` from `mock/multilingualData.ts` — replace with static string or locale API |
| HomeView tasks/reminders | **Keep as-is** | HomeView quick-task list is a UX shortcut to `TasksView` — it doesn't need live API duplication of tasks data |
| Navigation / info hierarchy | **Keep as-is** | Current sidebar + workspace pattern is functional and verified through Phase 7; redesign not justified |
| Models progressive disclosure | **Implement in 8A** | Variant badges (Instruct/Thinking), applied vs requested profile labels, missing mmproj warnings — all grounded in `registryApi.ts` data already in `BackendContext.registry` |
| Performance profile UX | **Implement in 8A** | `applied_profile` vs `requested_profile` distinction must be visible; "Pending restart" badge when they differ |
| Settings organization | **Keep as-is** | `SettingsView.tsx` uses `BackendContext` — no mock data found; no structural redesign justified |
| Offline/degraded states | **Implement in 8A** | `AssistantView`, `ModelsView`, `HealthView` need explicit offline banner using `BackendContext.isOnline` consistently |
| Responsive PC layout | **Keep as-is** | Phase 7 verified on PC; no mobile breakpoint work in scope |
| State ownership | **Keep as-is** | `BackendContext` + local hooks is adequate; no new state library needed |
| Accessibility baseline | **Defer to 8C** | Tracked in 8C.3 |
| MemoryView mock data | **Implement in 8A** | Wire to live `memoryApi` (endpoint already exists) |
| HealthView mock data | **Implement in 8A** | Wire to `BackendContext.isOnline` + `modelStatus` |
| `mockConversations` in AssistantView | **Implement in 8A** | Remove import; `drawerConversations` already receives real API data |

---

### Batch 8A.1 — Mock Data Removal from Production Views

**[MODIFY]** `frontend/web/src/components/workspace/HomeView.tsx`
- Remove `import { getLanguageAwareGreeting } from '../../mock/multilingualData'` (L33)
- Replace greeting call with a static locale-aware greeting derived from `Date()` hours or a simple prop fallback. Keep the UX — remove the mock import only.
- Quick-task and reminder sections: **Keep as-is** (no mock import — they use local component state, verified)

**[MODIFY]** `frontend/web/src/components/workspace/AssistantView.tsx`
- Remove `import { mockConversations } from './ConversationHistoryDrawer'` (L49)
- `drawerConversations` is already populated from the real API — this import is stale

**[MODIFY]** `frontend/web/src/components/workspace/HealthView.tsx`
- Replace any `mock/healthData.ts` imports with `BackendContext.isOnline`, `BackendContext.modelStatus`
- Add explicit offline/degraded banner: when `!isOnline`, show "Core Offline" state

**[MODIFY]** `frontend/web/src/components/workspace/MemoryView.tsx`
- Wire to `memoryApi` live data (`GET /api/v1/memories`)
- Show loading/empty states; replace mock entries

**Verification:**
```powershell
# Confirm zero production mock imports remain after 8A.1:
grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
# Expected: only files inside frontend/web/src/test/
```

---

### Batch 8A.2 — AssistantView Decomposition

**Goal:** Break 927-line monolith. Behavior must be identical. All 38 existing vitest tests must pass.

**New files (inside `workspace/assistant/`):**

`AssistantComposer.tsx`
- Props: `conversationId`, `isBusy`, `assistantState`, `onSend(text, attachmentIds[])`, `onStop`, `onMicToggle`, `currentModel`
- State: `inputPrompt`, `pendingAttachments` (Phase 8A: text-name chips only — real images in 8B)
- **Paperclip in 8A:** renders disabled with `title="Image attachments enabled in Phase 8B"` — removes the fake `doc_spec_v1.md` appending behavior entirely

`AssistantMessageList.tsx`
- Props: `messages`, `isStreaming`, `streamingText`, `scrollRef`
- Auto-scroll logic extracted here

`AssistantStatusBar.tsx`
- Props: `modelStatus`, `activeModel`, `currentModel`
- **Provenance rule (non-negotiable):**
  - `applied_context_size` → label: "Context: {n} tokens (measured)"
  - `context_size` from requested profile (when applied is null) → "Context: {n} tokens (configured)"
  - `estimated_vram_gb` from registry → "~{n} GB VRAM (estimated)"
  - No value shown without a clear provenance label
  - If `modelStatus` is null → "Unavailable"
- `applied_profile !== requested_profile` → show amber "Profile change pending restart" badge

`AssistantErrorDisplay.tsx`
- Contains `classifyStreamError` logic extracted from current AssistantView
- Renders classified error with retry/dismiss actions

**Modified:**
`AssistantView.tsx` → becomes orchestrator (state + callbacks) that composes the four sub-components.

---

### Batch 8A.3 — Models Progressive Disclosure

**[MODIFY]** `frontend/web/src/components/workspace/ModelsView.tsx`

Using `BackendContext.registry` (already available — no new API call):
- Add variant badges: `variant === 'thinking'` → purple "Thinking 🧠" pill; `variant === 'instruct'` → sky "Instruct" pill
- Add `validationStatus === 'missing_companion'` → amber "⚠ mmproj missing" badge
- Profile panel: if `modelStatus.applied_profile !== modelStatus.requested_profile` → show amber "Pending restart" label next to applied profile
- Verify `applied_context_size`, `applied_gpu_layers` displayed with explicit "(applied)" vs "(configured)" labels, consistent with `AssistantStatusBar` provenance rule

---

### Batch 8A.4 — Deprecation Annotations

Add `@deprecated` JSDoc to each mock file header:
```typescript
/**
 * @deprecated Production views must not import from this file.
 * Retained as Vitest fixture only. Scheduled for deletion in Phase 8C.
 */
```

Files: `localAiData.ts`, `healthData.ts`, `deviceAndMemoryData.ts`, `logsData.ts`, `multilingualData.ts`
Do NOT delete — tests may still reference them.

---

### 8A Proposed Commit Message

```
feat(8a): frontend architecture — mock removal, view decomposition, provenance labels

- HomeView: remove mock/multilingualData import; replace greeting with Date-derived local greeting
- AssistantView: remove stale mockConversations import; extract Composer/MessageList/StatusBar/ErrorDisplay
- AssistantComposer: remove fake attachment chip behavior; Paperclip disabled with 8B notice
- AssistantStatusBar: provenance-labeled telemetry (measured/configured/estimated/unavailable)
- HealthView, MemoryView: wired to live BackendContext / memoryApi
- ModelsView: variant badges, mmproj warning, applied-vs-requested profile labels
- mock/*.ts: @deprecated annotations; retained as test fixtures
- All tests: >= 88 pytest, >= 38 vitest, 0 tsc errors, clean build
```


---

## Section 4 — Phase 8B: Multimodal Image Attachment Foundation

**Branch:** `feature/multimodal-image-attachments` (based on merged 8A)
**Test gate:** Migration 006 applies cleanly; >= 88 + new attachment tests pass; 0 tsc errors; clean build.

### Where Multimodal Information Is Currently Lost

```
AssistantView.tsx (composer)
  → attachments: string[] ← FAKE strings (L836) — removed in 8A
        ↓
  streamSendMessage({ userText }) ← no attachment field (conversationApi.ts L117)
        ↓
  POST /api/v1/conversations/{id}/messages
        ↓
  MessageSend: { user_text: str, client_message_id } ← no attachment_ids field
        ↓
  AssistantOrchestrator.handle_message()
        ↓
  ChatMessage: { role, content: str } ← STRING ONLY (schemas/llm.py L12)
        ↓
  LlamaCppProvider.chat_stream()
        ↓
  payload["messages"] = [{"role": "user", "content": text_string}]
        ↓ LOST — llama.cpp supports multimodal content-array format
```

---

### Attachment Lifecycle States

The following states must be explicitly tracked and handled:

| State | Description | Frontend action | Backend action |
|-------|-------------|-----------------|----------------|
| `selected` | File chosen from picker, not yet uploaded | Show spinner overlay on preview | — |
| `uploading` | POST in progress | Show progress indicator | Validate, write to storage, return AttachmentOut |
| `staged` | Uploaded, not yet bound to a message | Show preview, allow removal | `message_id = NULL` in DB |
| `committed` | Bound to persisted user message | Shown in conversation history | `message_id = <uuid>` in DB |
| `soft_deleted` | User cancelled from composer (staged), or message soft-deleted | Remove from UI | `is_deleted = True`, `deleted_at = now()` |
| `orphan_pending_cleanup` | Staged > 24h, send never occurred | — | Retention purge job marks for hard delete |

**Orphan retention rule:**
- Staged attachments with `message_id IS NULL` and `created_at < NOW() - 24h` are eligible for hard deletion by a periodic cleanup task (retention purge, already exists in project for message retention — extend it).
- Frontend must DELETE staged attachment immediately when user removes it from composer (not just remove React state).

**Cancellation semantics (corrected):**
- User message text + bound attachment IDs → persisted atomically when the POST request succeeds.
- If assistant generation is subsequently cancelled (mid-stream abort), the user message and its attachments remain committed in conversation history — consistent with Phase 5 established behavior.
- Only the partial assistant response follows Phase 5 cancellation handling.

---

### Batch 8B.1 — Migration 006

Create: `backend/migrations/versions/006_add_attachments.py`

```python
"""Add attachments table for multimodal message support.

Revision ID: 006_add_attachments
Revises: 005_scope_message_constraints
Create Date: 2026-09-14 06:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "006_add_attachments"
down_revision: Union[str, None] = "005_scope_message_constraints"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "attachments",
        sa.Column("id", sa.String(36), primary_key=True, nullable=False),
        sa.Column("owner_id", sa.String(64), nullable=False, index=True),
        sa.Column(
            "message_id", sa.String(36),
            sa.ForeignKey("messages.id", ondelete="CASCADE"),
            nullable=True, index=True,
        ),
        sa.Column(
            "conversation_id", sa.String(36),
            sa.ForeignKey("conversations.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("filename_display", sa.String(255), nullable=False),   # original user filename
        sa.Column("storage_filename", sa.String(128), nullable=False),   # UUID-based, server-owned
        sa.Column("storage_path", sa.String(512), nullable=False),       # NEVER returned to frontend
        sa.Column("mime_type", sa.String(64), nullable=False),
        sa.Column("size_bytes", sa.Integer, nullable=False),
        sa.Column("image_width", sa.Integer, nullable=True),
        sa.Column("image_height", sa.Integer, nullable=True),
        sa.Column(
            "is_deleted", sa.Boolean, nullable=False,
            default=False, server_default=sa.false(),
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False,
            server_default=sa.func.now(),
        ),
    )
    # Index for orphan cleanup query (staged + old)
    op.create_index(
        "ix_attachments_staged_created",
        "attachments",
        ["message_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_attachments_staged_created", table_name="attachments")
    op.drop_table("attachments")
```

**Migration safety notes:**
- `CASCADE` on FK: only fires on SQL hard-delete. Conversation/Message soft-delete (`is_deleted=True`) does NOT cascade to attachments automatically — soft-delete of parent must explicitly soft-delete children in service layer.
- `storage_path` and `storage_filename` are internal-only columns; the API schema must never expose them.
- `filename_display` preserves the user-supplied original filename for UI only.

---

### Batch 8B.2 — Attachment ORM Model

Create: `backend/app/models/attachment.py`

The model inherits all four standard mixins, consistent with `Conversation` and `Message`:

```python
"""Attachment ORM model — Phase 8B multimodal foundation."""
from typing import Optional, TYPE_CHECKING
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.models.base import (
    UUIDPrimaryKeyMixin,
    TimestampMixin,
    OwnerMixin,
    SoftDeleteMixin,
)

if TYPE_CHECKING:
    from app.models.message import Message
    from app.models.conversation import Conversation


class Attachment(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin):
    """
    Staged or committed file attachment for a multimodal message.

    Lifecycle: selected → uploading → staged (message_id=None) → committed (message_id=<uuid>)
    Soft-delete: is_deleted + deleted_at provided by SoftDeleteMixin.
    CASCADE: SQL CASCADE only fires on hard-delete of parent row.
    Parent soft-delete must explicitly soft-delete attachments in service layer.
    Orphan cleanup: staged attachments older than 24h purged by retention job.
    """
    __tablename__ = "attachments"

    # FK relationships
    message_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("messages.id", ondelete="CASCADE"), nullable=True, index=True
    )
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # File metadata
    filename_display: Mapped[str] = mapped_column(String(255), nullable=False)   # original user filename
    storage_filename: Mapped[str] = mapped_column(String(128), nullable=False)   # UUID-based, server-owned
    storage_path: Mapped[str] = mapped_column(String(512), nullable=False)       # relative to DATA_DIR/attachments/; NEVER returned to API
    mime_type: Mapped[str] = mapped_column(String(64), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    image_width: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    image_height: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Relationships
    message: Mapped[Optional["Message"]] = relationship("Message", back_populates="attachments")
    conversation: Mapped["Conversation"] = relationship("Conversation", back_populates="attachments")
```

**[MODIFY]** `backend/app/models/conversation.py` — add the matching side:
```python
# Add to TYPE_CHECKING block:
from app.models.attachment import Attachment

# Add to Conversation class (after messages relationship):
attachments: Mapped[List["Attachment"]] = relationship(
    "Attachment",
    back_populates="conversation",
    cascade="all, delete-orphan",
    order_by="Attachment.created_at",
)
```

**[MODIFY]** `backend/app/models/message.py` — add the matching side:
```python
# Add to TYPE_CHECKING block:
from app.models.attachment import Attachment

# Add to Message class:
attachments: Mapped[List["Attachment"]] = relationship(
    "Attachment",
    back_populates="message",
    lazy="selectin",   # auto-load when message is fetched
)
```

**[MODIFY]** `backend/app/models/__init__.py` — add `Attachment` to the registry so Alembic detects it.

---

### Batch 8B.3 — Attachment Schemas

Create: `backend/app/schemas/attachment.py`

```python
"""Attachment schemas — Phase 8B multimodal."""
from datetime import datetime
from typing import Optional
from app.schemas.common import BaseSchema

# Phase 8B: PNG and JPEG verified. WebP deferred until live Qwen3-VL end-to-end test.
ALLOWED_MIME_TYPES: frozenset = frozenset({"image/png", "image/jpeg"})
MAX_SIZE_BYTES: int = 10 * 1024 * 1024          # 10 MB byte limit (before decode)
MAX_PIXEL_DIMENSION: int = 8192                  # max width or height in pixels
MAX_MEGAPIXELS: float = 32.0                     # 32 MP decoded budget
MAX_ATTACHMENTS_PER_MESSAGE: int = 4


class AttachmentOut(BaseSchema):
    """Attachment metadata returned to the frontend. storage_path is NEVER included."""
    id: str
    conversation_id: str
    message_id: Optional[str] = None
    filename_display: str               # original user filename, safe to show
    mime_type: str
    size_bytes: int
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    created_at: datetime


class AttachmentRef(BaseSchema):
    """Lightweight reference embedded in MessageOut."""
    id: str
    filename_display: str
    mime_type: str
    size_bytes: int
```

**[MODIFY]** `backend/app/schemas/message.py`

```python
# Add to imports:
from app.schemas.attachment import AttachmentRef, MAX_ATTACHMENTS_PER_MESSAGE

class MessageSend(BaseSchema):
    user_text: str = Field(..., min_length=1)
    client_message_id: Optional[str] = Field(default=None, max_length=64)
    attachment_ids: List[str] = Field(default_factory=list)
    # Validated in endpoint: max MAX_ATTACHMENTS_PER_MESSAGE, same owner, same conversation, not deleted, staged state

class MessageOut(BaseSchema):
    ...  # existing fields unchanged
    attachments: List[AttachmentRef] = Field(default_factory=list)
```

---

### Batch 8B.4 — Image Validation Service

Create: `backend/app/services/attachment_validator.py`

```python
"""
Image validation for uploaded attachments — Phase 8B.

Validation order (fail-fast):
1. Byte size limit (before any decode attempt)
2. MIME from file bytes (not Content-Type header) — use imghdr or struct header check
3. Decode with Pillow (already a Python dependency via other uses; if not, add explicitly)
4. Maximum pixel dimensions (MAX_PIXEL_DIMENSION per side)
5. Megapixel budget (MAX_MEGAPIXELS)
6. Decompression bomb protection (Pillow raises DecompressionBombError by default at 178MP;
   set Image.MAX_IMAGE_PIXELS = MAX_MEGAPIXELS * 1_000_000 explicitly)

Returns: (width, height, validated_mime_type)
Raises: AttachmentValidationError with user-readable message

Windows packaging note: Use Pillow (pillow >= 10.0) — already commonly included.
Do NOT add python-magic (requires libmagic binary, complicates Windows packaging).
Detect MIME from raw byte headers using struct / imghdr as primary check,
then validate with Pillow as secondary decode step.
"""
```

**Supported and deferred formats:**
| Format | Phase 8B | Reason |
|--------|----------|--------|
| `image/png` | ✅ Supported | PNG header `\x89PNG` — reliable byte detection |
| `image/jpeg` | ✅ Supported | JPEG header `\xFF\xD8\xFF` — reliable byte detection |
| `image/webp` | ⏳ Deferred | Not yet verified with pinned llama.cpp/Qwen3-VL path end-to-end |

---

### Batch 8B.5 — Attachment Upload API

Create: `backend/app/api/v1/endpoints/attachments.py`

**Endpoints:**
```
POST   /api/v1/conversations/{conversation_id}/attachments
         Accepts: multipart/form-data, field name "file"
         Auth: get_current_owner (Bearer)
         Validates:
           - conversation ownership
           - MIME from bytes (not Content-Type header)
           - byte size limit
           - decoded dimensions and megapixel budget
           - decompression bomb protection
         Storage:
           - storage_filename = attachment_uuid (no user filename in path)
           - storage_path = "attachments/{owner_id}/{conversation_id}/{attachment_id}"
           - Resolve path; assert within DATA_DIR before write (path traversal guard)
         Returns: AttachmentOut (no storage_path field)

GET    /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview
         Auth: get_current_owner (Bearer)
         Validates: attachment ownership, same conversation, not deleted
         Returns: image bytes, Content-Type: image/png or image/jpeg
         Note: Frontend must fetch as Blob via authenticated apiFetch — not via plain <img src>

DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}
         Auth: get_current_owner (Bearer)
         Action: soft-delete (is_deleted=True, deleted_at=now())
         Does NOT delete from filesystem — cleanup handled by retention purge
```

**Storage security invariants:**
1. `storage_filename` is always the attachment UUID — never incorporates user-supplied filename
2. `storage_path` is always `attachments/{owner_id}/{conversation_id}/{attachment_id}`
3. Full path = `settings.DATA_DIR / storage_path` — must be resolved and asserted inside DATA_DIR before any write/read
4. `storage_path` is never returned in any API response (not in `AttachmentOut` or `AttachmentRef`)
5. Preview endpoint resolves path and validates ownership before serving bytes

---

### Batch 8B.6 — Provider-Independent Multimodal Contract

**Rule:** The orchestrator must never construct llama.cpp-specific payload structures. The provider translates.

Create: `backend/app/schemas/multimodal.py`

```python
"""Provider-independent multimodal content block types — Phase 8B."""
from typing import List, Union
from pydantic import BaseModel


class TextContent(BaseModel):
    type: str = "text"
    text: str


class ImageAttachmentContent(BaseModel):
    """
    Application-level image reference. Carries attachment ID and resolved bytes.
    The provider layer translates this into its specific wire format.
    """
    type: str = "image_attachment"
    attachment_id: str
    mime_type: str
    # image_data populated by provider layer — not set by orchestrator
    # Kept out of this schema deliberately; provider receives attachment_id and resolves bytes itself


ContentBlock = Union[TextContent, ImageAttachmentContent]


class MultimodalMessage(BaseModel):
    role: str
    content_blocks: List[ContentBlock]
```

**[MODIFY]** `backend/app/schemas/llm.py` — update `ChatMessage`:

```python
class ChatMessage(BaseSchema):
    """Chat message — provider-independent. Content is str for text-only, List[ContentBlock] for multimodal."""
    role: Literal["system", "user", "assistant"]
    content: Union[str, List["ContentBlock"]]   # str preserved for backward compatibility
```

**[MODIFY]** `backend/app/services/assistant/orchestrator.py`

Orchestrator builds provider-independent message content:

```python
# Check vision capability via registry
registry = build_model_list()
active_entry = next((m for m in registry if m.id == active_model_id), None)
has_vision = active_entry and ModelCapability.vision in (active_entry.capabilities or [])

# Build content
if has_vision and message.attachments:
    content_blocks: List[ContentBlock] = []
    for att in message.attachments:
        if not att.is_deleted:
            content_blocks.append(ImageAttachmentContent(
                attachment_id=att.id,
                mime_type=att.mime_type,
            ))
    content_blocks.append(TextContent(text=user_text))
    chat_message = ChatMessage(role="user", content=content_blocks)
else:
    # Text-only path — backward compatible; attachments silently omitted if model lacks vision
    chat_message = ChatMessage(role="user", content=user_text)
```

**[MODIFY]** `backend/app/services/llm/llama_cpp.py` — translate in provider:

```python
async def _translate_messages(self, messages: List[ChatMessage]) -> List[dict]:
    """
    Translate provider-independent ChatMessage list into llama.cpp OpenAI-compatible wire format.
    Image bytes are read here (provider layer) via asyncio.get_event_loop().run_in_executor()
    to avoid blocking the async event loop during file IO.
    """
    import asyncio
    loop = asyncio.get_event_loop()
    result = []
    for msg in messages:
        if isinstance(msg.content, str):
            result.append({"role": msg.role, "content": msg.content})
        else:
            # Multimodal content blocks → llama.cpp OpenAI-compatible format
            wire_content = []
            for block in msg.content:
                if block.type == "text":
                    wire_content.append({"type": "text", "text": block.text})
                elif block.type == "image_attachment":
                    # Read bytes off event loop thread to avoid blocking
                    att_path = settings.DATA_DIR / "attachments" / ...  # resolve from attachment_id
                    image_bytes = await loop.run_in_executor(None, att_path.read_bytes)
                    b64 = base64.b64encode(image_bytes).decode()
                    wire_content.append({
                        "type": "image_url",
                        "image_url": {"url": f"data:{block.mime_type};base64,{b64}"}
                    })
            result.append({"role": msg.role, "content": wire_content})
    return result
```

> A future Gemini/Ollama provider translates the same `ChatMessage(content_blocks=[...])` into its own wire format without changing `AssistantOrchestrator`.

---

### Batch 8B.7 — Conversation History: Attachment Restoration

**[MODIFY]** `backend/app/api/v1/endpoints/conversations.py` — `GET /{id}/messages`

Ensure `MessageOut.attachments` is populated from `Message.attachments` relationship (already `lazy="selectin"` on the ORM — will auto-load). Verify in serialization.

**Frontend reload verification path:**
1. Upload image → send → generation completes
2. Reload page (F5)
3. `GET /conversations/{id}/messages` → `MessageOut.attachments: [AttachmentRef]`
4. Frontend renders message with attachment preview via authenticated Blob fetch

---

### Batch 8B.8 — Frontend: Authenticated Preview Fetch

**[MODIFY]** `frontend/web/src/components/workspace/assistant/AssistantComposer.tsx`

```typescript
// Authenticated image preview — NOT plain <img src="...">
// Browser requests via <img src> do not attach Authorization headers.
async function fetchAttachmentPreview(
  conversationId: string,
  attachmentId: string,
  apiKey: string,
): Promise<string> {
  const res = await fetch(
    `${BACKEND_BASE_URL}/api/v1/conversations/${conversationId}/attachments/${attachmentId}/preview`,
    { headers: { Authorization: `Bearer ${apiKey}` } }
  );
  if (!res.ok) throw new Error('Preview fetch failed');
  const blob = await res.blob();
  return URL.createObjectURL(blob);
}

// In component:
useEffect(() => {
  // Create object URLs for staged attachment previews
  const urls: string[] = [];
  (async () => {
    for (const att of pendingAttachments) {
      const url = await fetchAttachmentPreview(conversationId, att.id, apiKey);
      urls.push(url);
    }
    setPreviewUrls(urls);
  })();
  return () => {
    // Revoke on cleanup — no memory leak
    urls.forEach(URL.revokeObjectURL);
  };
}, [pendingAttachments]);
```

Also applies to `ConversationMessageItem.tsx` when rendering committed attachment history — use the same authenticated Blob fetch pattern.

---

### Batch 8B.9 — Frontend: Real Attachment Composer & Vision Gate

**[MODIFY]** `frontend/web/src/components/workspace/assistant/AssistantComposer.tsx`

```typescript
const hasVision = currentModel?.capabilities?.includes('vision') ?? false;

// File input (hidden):
<input
  ref={fileInputRef}
  type="file"
  accept="image/png,image/jpeg"   // WebP not accepted until verified
  multiple={false}                // one at a time (up to MAX_ATTACHMENTS_PER_MESSAGE total)
  className="hidden"
  onChange={handleFileSelected}
/>

// Paperclip button:
<button
  onClick={() => hasVision && conversationId ? fileInputRef.current?.click() : undefined}
  disabled={!hasVision || !conversationId || pendingAttachments.length >= 4}
  title={
    !hasVision
      ? 'Active model does not support image input'
      : !conversationId
      ? 'Start a conversation first'
      : pendingAttachments.length >= 4
      ? 'Maximum 4 images per message'
      : 'Attach image (PNG, JPEG)'
  }
>
  <Paperclip />
</button>
```

**Staged attachment removal:**
```typescript
async function handleRemoveAttachment(attId: string) {
  // Invoke DELETE endpoint — do not just remove from React state
  await deleteAttachment(conversationId, attId, apiKey);
  setPendingAttachments(prev => prev.filter(a => a.id !== attId));
  // Revoke object URL for memory cleanup
}
```

Create: `frontend/web/src/services/api/attachmentApi.ts`

```typescript
export const ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg'];  // WebP deferred
export const MAX_SIZE_BYTES = 10 * 1024 * 1024;
export const MAX_ATTACHMENTS_PER_MESSAGE = 4;

export async function uploadAttachment(
  conversationId: string, file: File, apiKey: string
): Promise<AttachmentOut> { ... }

export async function deleteAttachment(
  conversationId: string, attachmentId: string, apiKey: string
): Promise<void> { ... }

export async function fetchAttachmentBlobUrl(
  conversationId: string, attachmentId: string, apiKey: string
): Promise<string> { ... }  // returns URL.createObjectURL — caller must revoke
```

---

### 8B Test Plan

**`backend/tests/test_attachments.py`**

Migration tests:
- Fresh DB → upgrade to 006 → verify schema (table exists, all columns, indexes, FKs)
- 005 → 006 upgrade
- 006 → 005 downgrade (table dropped, 005 constraints intact)
- 005 → 006 → 005 → 006 (re-upgrade)
- ORM schema parity: `Attachment` model columns match migration columns exactly
- `SoftDeleteMixin`: `is_deleted` default false, `deleted_at` nullable
- `OwnerMixin`: `owner_id` String(64)
- `TimestampMixin`: `created_at` + `updated_at` not null
- FKs: FK to `messages.id` + FK to `conversations.id`

Endpoint tests:
- Upload PNG → 201, AttachmentOut returned, no storage_path field
- Upload JPEG → 201
- Upload WebP → 422 (rejected until verified)
- Upload PNG but Content-Type: image/jpeg → MIME validated from bytes not header
- Upload file > 10MB → 413
- Upload oversized image (> MAX_PIXEL_DIMENSION) → 422
- Upload image > MAX_MEGAPIXELS → 422
- Upload decompression bomb PNG → 422
- Upload with wrong conversation_id (BOLA) → 404
- Upload with correct conversation but wrong owner → 403
- Preview with correct auth → 200, image bytes
- Preview with wrong owner → 403
- DELETE staged attachment → 204, is_deleted=True in DB
- DELETE already-deleted attachment → 404
- Send message with valid attachment_id → 200, MessageOut.attachments populated
- Send message with deleted attachment_id → 422
- Send message with other-owner attachment_id → 422
- Send message with other-conversation attachment_id → 422
- Send message with 5 attachment_ids (over limit) → 422
- GET conversation messages → MessageOut.attachments includes AttachmentRef
- Reload path: send with attachment → GET messages → AttachmentRef present

**`frontend/web/src/test/attachmentComposer.test.tsx`**
- Paperclip disabled when model has no vision capability
- Paperclip disabled when no active conversation
- File upload triggers POST, preview renders via authenticated Blob URL
- Remove attachment triggers DELETE endpoint + revokes object URL
- Send with attachment IDs in payload
- Attachment count limit enforced at 4
- WebP file rejected client-side with user message

---

### 8B Proposed Commit Message

```
feat(8b): multimodal image attachment foundation

- migrations/versions/006_add_attachments.py (006_add_attachments → 005_scope_message_constraints)
- Attachment ORM: all 4 mixins (UUID, Timestamp, Owner, SoftDelete), UUID storage path
- Conversation + Message models: matching back_populates="attachments" relationships
- schemas/attachment.py: AttachmentOut (no storage_path), AttachmentRef, ALLOWED_MIME_TYPES
- schemas/multimodal.py: TextContent, ImageAttachmentContent, MultimodalMessage (provider-independent)
- schemas/llm.py: ChatMessage.content Union[str, List[ContentBlock]]
- schemas/message.py: MessageSend.attachment_ids[], MessageOut.attachments[]
- services/attachment_validator.py: Pillow-based, byte header MIME, dimension + megapixel + decompression bomb protection
- endpoints/attachments.py: POST upload, GET preview (auth Bearer, no img-src), DELETE soft-delete
- orchestrator: provider-independent content_blocks; vision capability gate from registry
- LlamaCppProvider: _translate_messages() — llama.cpp OpenAI wire format; file IO via run_in_executor
- attachmentApi.ts: uploadAttachment, deleteAttachment, fetchAttachmentBlobUrl (URL.createObjectURL lifecycle)
- AssistantComposer: real file input, authenticated Blob previews, vision gate, remove triggers DELETE
- conversationApi.ts: attachment_ids[] in streamSendMessage
- ConversationMessageItem: authenticated Blob previews for committed attachments in history

WebP: DEFERRED — not yet verified with pinned llama.cpp/Qwen3-VL
Video: DEFERRED — Phase 2 verified image only
PDF/OCR/audio: OUT OF SCOPE

Tests: test_attachments.py (migration, upload, BOLA, validation, lifecycle, history)
       attachmentComposer.test.tsx (vision gate, upload, preview, remove, limit)

Track: Phase 8B — Multimodal Image Attachment Foundation
```


---

## Section 5 — Phase 8C: Integration, Accessibility & Polish

**Branch:** `feature/phase8-ui-integration-polish` (based on merged 8B)
**Test gate:** No new features. All test counts at final targets. Clean build. All mock imports gone.

### Batch 8C.1 — Delete Deprecated Mock Files

**Before deleting — mandatory verification:**
```powershell
grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
# Must return ONLY test files (e.g., frontend/web/src/test/*.ts)
# If any non-test file is listed → fix the import first, then delete
```

**Delete after verification:**
- `frontend/web/src/mock/localAiData.ts`
- `frontend/web/src/mock/healthData.ts`
- `frontend/web/src/mock/deviceAndMemoryData.ts`
- `frontend/web/src/mock/logsData.ts`
- `frontend/web/src/mock/multilingualData.ts`

Decide `characterData.ts` in 8C based on whether `CharactersView` still imports it.

---

### Batch 8C.2 — Bundle Analysis & Performance

```bash
npm run build 2>&1 | grep "dist/"
npx vite-bundle-visualizer   # or rollup-plugin-visualizer if already installed
```

Expected bundle reduction: ~80KB from mock file removal.

If any single chunk > 500KB uncompressed: apply `React.lazy()` + `Suspense` to that view.

Primary candidate: `ScheduleView.tsx` (45KB source) — evaluate lazy load if it's in a large chunk.

---

### Batch 8C.3 — Accessibility

All icon-only composer buttons: `aria-label` (send, stop, mic, attach, remove-attachment).
Keyboard: `Tab` through composer controls; `Enter` removes staged attachment chip; `Esc` closes history drawer.
`ConversationMessageItem`: `role="article"` on each message bubble.
`AttachmentPreview` images: `alt={att.filename_display}`.
Focus: after send, return focus to input field.
Skip links or landmark `aria-label` on main navigation sidebar.

---

### Batch 8C.4 — Final Test Coverage

**`frontend/web/src/test/phase8Integration.test.tsx`**

Integration scenarios:
- Upload image → send → generation completes → F5 → reopen conversation → image preview visible (authenticated Blob fetch)
- Upload image → send → cancel mid-stream → user message + image remain in history (not lost)
- Text-only model: attachment button disabled; sending text succeeds normally
- Staged attachment removal: DELETE endpoint called; object URL revoked; preview gone from composer
- 5th image blocked client-side with error message
- PNG upload: succeeds. JPEG upload: succeeds. WebP upload: rejected with message.
- Vision-capable model selected → attachment button enabled → model switched to text-only → button disables, pending attachments cleared with user warning.

**Backend regression final:**
```powershell
cd backend
.venv\Scripts\pytest tests/ -v --tb=short
# Target: 100+ passed (88 baseline + ~15 new attachment tests)
```

---

### Batch 8C.5 — Documentation

**[MODIFY]** `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
- Update Multimodal row to "Repository-verified implementation"
- Update test count totals

**[CREATE]** `docs/03_Walkthroughs/walkthrough-phase8-multimodal-attachments.md`
- Follow `docs/03_Walkthroughs/walkthrough-template.md` (7-section format)
- Include: attachment lifecycle diagram, storage path security, vision gate, provider translation, test results, WebP deferral reason

**[MODIFY]** `docs/01_Tracking/task.md` — mark all 8A/8B/8C items complete; archive sprint.

---

### 8C Proposed Commit Message

```
feat(8c): integration polish — mock cleanup, bundle, accessibility, final tests, docs

- Delete mock/localAiData.ts, healthData.ts, deviceAndMemoryData.ts, logsData.ts, multilingualData.ts
  (verified: zero production imports remain)
- Bundle: lazy-load ScheduleView if analysis warrants; measure vs develop baseline
- Accessibility: aria-labels, role=article on messages, focus management, keyboard nav
- test: phase8Integration.test.tsx — reload, cancellation, vision gate switch, limits
- docs: walkthrough-phase8-multimodal-attachments.md (7-section template)
- docs: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md updated
- task.md: archived to docs/01_Tracking/archive/task-YYYY-MM-DD-phase8-ui-multimodal.md

Track: Phase 8C — Integration, Accessibility & Polish
```

---

## Section 6 — Deferred / Out of Scope

| Item | Classification | Evidence |
|------|---------------|---------|
| WebP image support | Deferred until live Qwen3-VL verification | Not yet tested in pinned llama.cpp path |
| Video input | Deferred | Phase 2 only verified image; video requires frame extraction |
| PDF / OCR | Out of scope | temp.txt explicit constraint |
| Audio upload / STT | Out of scope | temp.txt explicit constraint |
| Android multimodal UI | Deferred | PC-first scope constraint |
| Document RAG | Out of scope | Phase 8 constraint |
| Arbitrary file types | Out of scope | temp.txt explicit constraint |
| New state library (Redux/Zustand) | Not needed | BackendContext + hooks adequate |
| Mobile responsive layout | Out of scope | PC-first scope |
| Retention purge job for orphan attachments | Defer to Phase 9 | Strategy defined; implementation in next sprint |

---

## Section 7 — Non-Negotiable Invariants

1. **Backend runtime authority** — frontend never computes model state; reads from backend only
2. **selected model ≠ active model** — preserved in AssistantStatusBar + ModelsView
3. **requested profile ≠ applied profile** — both displayed with explicit labels
4. **MODEL_SLEEPING semantics** — correctly shown in AssistantStatusBar
5. **storage_path never returned** — `AttachmentOut` / `AttachmentRef` have no storage path field
6. **No base64 in messages.content** — attachment bytes live in filesystem; DB only stores metadata
7. **CASCADE ≠ soft-delete** — service layer must explicitly soft-delete attachments when parent soft-deleted
8. **All original 88 pytest tests pass** after every branch merge
9. **No git add / commit / push by Gemini** — user commits manually after review
10. **Provider independence** — orchestrator uses `ContentBlock` types; `LlamaCppProvider` translates

---

## Section 8 — Updated task.md Checklist

After each batch completes, update `docs/01_Tracking/task.md` in-place:

```markdown
## Active Checklist — Phase 8

- [ ] 8A.1: Mock data removal (HomeView greeting, AssistantView mockConversations, HealthView, MemoryView)
- [ ] 8A.2: AssistantView decomposition (Composer stub, MessageList, StatusBar with provenance, ErrorDisplay)
- [ ] 8A.3: Models progressive disclosure (variant badges, mmproj warning, applied-vs-requested profile)
- [ ] 8A.4: @deprecated annotations on mock/*.ts files
- [ ] 8B.1: Migration 006_add_attachments.py (correct revision chain, full columns, indexes)
- [ ] 8B.2: Attachment ORM (all 4 mixins, UUID storage path, both relationship sides)
- [ ] 8B.3: Conversation + Message models updated (back_populates="attachments")
- [ ] 8B.4: schemas/attachment.py (AttachmentOut, AttachmentRef, no storage_path in API)
- [ ] 8B.5: schemas/multimodal.py (TextContent, ImageAttachmentContent, provider-independent)
- [ ] 8B.6: schemas/llm.py ChatMessage content Union[str, List[ContentBlock]]
- [ ] 8B.7: services/attachment_validator.py (Pillow, byte header MIME, dims, megapixel, bomb protection)
- [ ] 8B.8: endpoints/attachments.py (upload, preview auth, delete; storage security)
- [ ] 8B.9: Orchestrator: provider-independent content_blocks + vision gate
- [ ] 8B.10: LlamaCppProvider: _translate_messages(), file IO via run_in_executor
- [ ] 8B.11: conversationApi.ts: attachment_ids[] in streamSendMessage
- [ ] 8B.12: attachmentApi.ts: upload, delete, fetchAttachmentBlobUrl (object URL lifecycle)
- [ ] 8B.13: AssistantComposer: real upload, authenticated Blob previews, vision gate, remove triggers DELETE
- [ ] 8B.14: ConversationMessageItem: authenticated Blob previews for history
- [ ] 8B.15: GET messages returns AttachmentRef[] for history reload
- [ ] 8C.1: Delete deprecated mock files (grep verification first)
- [ ] 8C.2: Bundle analysis + lazy-load if warranted
- [ ] 8C.3: Accessibility pass (aria-labels, focus, keyboard, role=article)
- [ ] 8C.4: Final test suite (target 100+ pytest, 50+ vitest)
- [ ] 8C.5: Walkthrough + MASTER_IMPLEMENTATION_PLAN update + archive
```
