# Phase 8 Implementation Plan — PC Frontend Architecture, Multimodal & Polish

> **Implementer:** Gemini
> **Planner:** Antigravity (evidence-backed from repository inspection)
> **Branch Strategy:** 3 sequential feature branches (see Section 1)
> **Status:** Approved for implementation — do not implement until user confirms branch order

---

## Section 1 — Branch Strategy Recommendation

### Why 3 Branches Is Better Than One Massive PR

| Concern | One Branch | 3 Branches (Recommended) |
|---------|-----------|--------------------------|
| Review surface | Hundreds of files, impossible to reason about | Each PR is self-contained and reviewable |
| Risk isolation | A single broken migration poisons the whole PR | 8B (multimodal DB) is isolated; 8A and 8C never touch DB |
| Rollback | Cannot revert just the attachment pipeline | 8B can be reverted without losing 8A UI improvements |
| Test gate | All 88+ tests must pass against mixed changes | Each branch has a clear pass gate |
| Merge conflict surface | High — touches frontend + backend + DB at once | Low — each branch owns a bounded layer |
| Implementer parallelism | Sequential anyway, but harder to checkpoint | Clear phase completion checkpoints |

### Branch Execution Order

```
develop  (current clean baseline — 88 pytest, 38 vitest, 0 tsc errors)
    │
    ├── feature/phase8-ui-foundation          (8A — frontend only, no DB, no backend schema changes)
    │       ↓ merge to develop
    ├── feature/multimodal-image-attachments  (8B — full stack: DB migration 006, storage, API, provider)
    │       ↓ merge to develop
    └── feature/phase8-ui-integration-polish  (8C — integration, polish, bundle, accessibility, final tests)
```

> **Constraint:** 8B must be based on the merged 8A commit — multimodal frontend composer depends on the
> design system primitives introduced in 8A. 8C depends on both.

---

## Section 2 — Repository Evidence Summary

| Finding | Evidence | Classification |
|---------|----------|---------------|
| Attachment button adds fake strings `doc_spec_v1.md` | `AssistantView.tsx` L836 | **Confirmed Problem** |
| `streamSendMessage` sends `user_text: string` only — no attachment field | `conversationApi.ts` L117 | **Confirmed Problem** |
| `MessageSend` schema: `user_text` + `client_message_id` only | `backend/app/schemas/message.py` L9-12 | **Confirmed Problem** |
| `Message.content` is `Text` (string) — no attachment FK | `backend/app/models/message.py` L29 | **Confirmed Problem** |
| No `attachments` table in DB (migrations 001–005) | `backend/alembic/versions/` | **Confirmed Problem** |
| `mock/localAiData.ts` (17KB), `mock/healthData.ts` (11KB) still referenced by views | `frontend/web/src/mock/` | **Technical Debt** |
| `AssistantView.tsx` is 927 lines — monolith | `workspace/AssistantView.tsx` | **Technical Debt** |
| `mockConversations` imported into AssistantView from Drawer | `AssistantView.tsx` L49 | **Technical Debt** |
| 6 mock files totalling ~80KB still ship in dev bundle | `mock/` directory | **Technical Debt** |
| Paperclip icon, Mic button present but wired to no real function | `AssistantView.tsx` L833, L860 | **Product Improvement** |
| No image preview in composer | `AssistantView.tsx` composer section | **Product Improvement** |
| Model capability not surfaced in composer (vision gate) | `registryApi.ts` has `capabilities[]` but AssistantView ignores it | **Product Improvement** |
| `HomeView.tsx` 39KB — largest view, mostly mock data | `workspace/HomeView.tsx` | **Technical Debt** |
| `ScheduleView.tsx` 45KB — largest file in project | `workspace/ScheduleView.tsx` | **Technical Debt** |
| Video support via Qwen3-VL: **unverified** — Phase 2 verified image only | Phase 7 walkthrough | **Deferred** |
| React Context + hooks adequate for current state | `BackendContext.tsx` exists, no prop-drilling crisis found | No new state library needed |

---

## Section 3 — Phase 8A: Frontend Architecture & UX Harmonization

**Branch:** `feature/phase8-ui-foundation`
**Scope:** Frontend only. Zero backend schema changes. Zero DB migrations. Zero new API endpoints.
**Invariants to preserve:**
- `selected model != active model` (backend authority)
- `requested profile != applied profile`
- `MODEL_SLEEPING` semantic display
- All 88 pytest + 38 vitest tests continue to pass

### Batch 8A.1 — Mock Data Deprecation

**Goal:** Remove mock data from production render paths. Keep mock files in place as test fixtures only — do not delete them yet (per temp.txt instruction).

#### Files Changed

**[MODIFY]** `frontend/web/src/components/workspace/HomeView.tsx`
- Remove direct `import` of `localAiData.ts` mock models
- Replace mock model cards with real `registryApi.fetchModelRegistry()` data (already wired in `registryApi.ts`)
- Replace mock system stats with real `modelApi.fetchModelStatus()` data from `BackendContext`
- Preserve existing visual card layout — data source changes, not design

**[MODIFY]** `frontend/web/src/components/workspace/AssistantView.tsx`
- Remove `mockConversations` import (L49) — `ConversationHistoryDrawer` already receives `drawerConversations` from API
- Replace `import { mockConversations }` with nothing; the Drawer already has real data prop

**[MODIFY]** `frontend/web/src/components/workspace/HealthView.tsx`
- Replace `mock/healthData.ts` system info with `BackendContext` health endpoint data
- Keep loading/error states

**[MODIFY]** `frontend/web/src/components/workspace/MemoryView.tsx`
- Replace mock memories with real `memoryApi` data (endpoint already exists: `GET /api/v1/memories`)

**Verification:**
```powershell
cd frontend/web
npx tsc --noEmit          # 0 errors
npm run test              # 38 vitest tests pass
npm run build             # clean build; check bundle size vs baseline
```

---

### Batch 8A.2 — AssistantView Decomposition

**Goal:** Break 927-line monolith into focused sub-components. Behavior must be identical after refactor.

**New files:**
- `frontend/web/src/components/workspace/assistant/AssistantComposer.tsx` — input bar, send button, stop button, mic stub, attachment row (text name chips only for now; real images in 8B)
- `frontend/web/src/components/workspace/assistant/AssistantMessageList.tsx` — scrollable message area, auto-scroll logic
- `frontend/web/src/components/workspace/assistant/AssistantStatusBar.tsx` — model name, state badge, VRAM, context buffer display
- `frontend/web/src/components/workspace/assistant/AssistantErrorDisplay.tsx` — classified error display (already has `classifyStreamError` logic)

**Modified files:**
- `frontend/web/src/components/workspace/AssistantView.tsx` — becomes an orchestrator: state lives here, sub-components receive props + callbacks

> **Refactor rule (AGENTS.md):** Zero behavior change. All existing 38 vitest tests must pass unchanged.

**Verification:**
```powershell
npm run test              # all 38 pass
# Manual: send a message, cancel mid-stream, load a conversation — behavior identical
```

---

### Batch 8A.3 — Design System Consistency Pass

**Goal:** Standardize cards, badges, spacing, and empty states across all workspace views.

**Targeted fixes only (not full rewrites):**
- `ModelsView.tsx`: variant badges (`Instruct` / `Thinking 🧠`) — already designed in plan-runtime-rename-and-model-registry.md; implement now
- `CharactersView.tsx`: replace placeholder avatar with consistent card pattern from `HomeView` cards
- All views: ensure loading/empty/error states use `states/` sub-components consistently (check `workspace/states/` dir)
- `LogsView.tsx` (28KB): confirm log level color coding uses CSS vars, not hardcoded hex
- `SettingsView.tsx` (17KB): confirm theme/glass controls use `BackendContext` values, not duplicated local state

**Verification:**
```bash
# Visual only — manual check per AGENTS.md
# Automated: npx tsc --noEmit && npm run test
```

---

### Batch 8A.4 — Deprecation List (Document, Do Not Delete)

Add a comment block in `frontend/web/src/mock/localAiData.ts`:
```typescript
/**
 * @deprecated Production views must not import from this file.
 * Retained as test fixture only. See Phase 8A migration.
 * Scheduled for deletion in Phase 8C after all views confirmed migrated.
 */
```

Apply same deprecation comment to: `healthData.ts`, `deviceAndMemoryData.ts`, `logsData.ts`, `multilingualData.ts`.

**Do NOT delete the files** — some may still be used in tests.

---

### 8A Test Gate

```powershell
cd d:\OtherProjects\AI-companion-project\backend
.venv\Scripts\pytest tests/ -v --tb=short   # must be >= 88 passed

cd d:\OtherProjects\AI-companion-project\frontend\web
npx tsc --noEmit                             # 0 errors
npm run test                                 # >= 38 passed
npm run build                               # clean build
```

---

### 8A Proposed Commit Message

```
feat(8a): frontend architecture — mock deprecation, AssistantView decomposition, design system pass

- AssistantView: extract AssistantComposer, AssistantMessageList, AssistantStatusBar, AssistantErrorDisplay
- HomeView, HealthView, MemoryView: replace mock data with live API data
- AssistantView: remove mockConversations import (real data already wired)
- ModelsView: add variant badges (Instruct / Thinking) from registry
- mock/*.ts: add @deprecated annotations; retained as test fixtures
- Design system: standardize loading/empty/error states across workspace views
- All tests pass: 88 pytest, 38 vitest, 0 tsc errors, clean build

Track: Phase 8A — Frontend Architecture & UX Harmonization
```


---

## Section 4 — Phase 8B: Multimodal Image Attachment Foundation

**Branch:** `feature/multimodal-image-attachments` (based on merged 8A)
**Scope:** Full-stack — DB migration 006, attachment storage, upload API, schema changes, provider translation, frontend composer UX.

### Where Multimodal Information Is Currently Lost — Traced Pipeline

```
AssistantView.tsx (composer)
  └── attachments: string[]          ← FAKE: adds string "doc_spec_v1.md" (L836)
        ↓ handleSendMessage()
        ↓ streamSendMessage({ userText, ... })   ← NO attachment param
              ↓
        conversationApi.ts L117
              body: { user_text: string, client_message_id }   ← NO attachments key
                    ↓
        POST /api/v1/conversations/{id}/messages
              ↓
        MessageSend schema: user_text + client_message_id     ← NO attachment field
              ↓
        AssistantOrchestrator.handle_message()
              ↓
        ChatMessage: role + content: str                       ← STRING ONLY
              ↓
        LlamaCppProvider.chat_stream()
              ↓
        payload["messages"] = [{"role": "user", "content": text_string}]
              ↓ LOST — llama.cpp supports:
              ↓ {"role": "user", "content": [{"type": "text",...}, {"type": "image_url",...}]}
```

**Every contract in this chain must change for multimodal support.**

---

### Batch 8B.1 — DB Migration 006: Attachments Table

Create: `backend/alembic/versions/006_add_attachments.py`

```python
"""Add attachments table for multimodal message support.

Revision ID: 006
Revises: 005
"""
from alembic import op
import sqlalchemy as sa

revision = '006'
down_revision = '005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'attachments',
        sa.Column('id', sa.String(36), primary_key=True, nullable=False),
        sa.Column('owner_id', sa.String(36), nullable=False, index=True),
        sa.Column('message_id', sa.String(36),
                  sa.ForeignKey('messages.id', ondelete='CASCADE'),
                  nullable=True, index=True),   # nullable: attachment exists before message is saved
        sa.Column('conversation_id', sa.String(36),
                  sa.ForeignKey('conversations.id', ondelete='CASCADE'),
                  nullable=False, index=True),
        sa.Column('filename', sa.String(255), nullable=False),
        sa.Column('mime_type', sa.String(64), nullable=False),
        sa.Column('size_bytes', sa.Integer, nullable=False),
        sa.Column('storage_path', sa.String(512), nullable=False),  # relative to DATA_DIR/attachments/
        sa.Column('is_deleted', sa.Boolean, nullable=False, default=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table('attachments')
```

**Safety review before applying:**
- `message_id` nullable = attachment can be staged before message commit
- `CASCADE` on both FKs = attachment deleted when conversation or message deleted
- No large binary blobs in this table — `storage_path` points to filesystem

---

### Batch 8B.2 — Attachment ORM Model & Schema

Create: `backend/app/models/attachment.py`

```python
from typing import Optional, TYPE_CHECKING
from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.models.base import UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin, SoftDeleteMixin

if TYPE_CHECKING:
    from app.models.message import Message
    from app.models.conversation import Conversation


class Attachment(Base, UUIDPrimaryKeyMixin, TimestampMixin, OwnerMixin):
    """Staged or committed file attachment for a multimodal message."""
    __tablename__ = "attachments"

    message_id: Mapped[Optional[str]] = mapped_column(
        ForeignKey("messages.id", ondelete="CASCADE"), nullable=True, index=True
    )
    conversation_id: Mapped[str] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(64), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    storage_path: Mapped[str] = mapped_column(String(512), nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    message: Mapped[Optional["Message"]] = relationship("Message", back_populates="attachments")
    conversation: Mapped["Conversation"] = relationship("Conversation", back_populates="attachments")
```

Create: `backend/app/schemas/attachment.py`

```python
"""Attachment schemas — Phase 8B multimodal foundation."""
from datetime import datetime
from typing import Optional
from app.schemas.common import BaseSchema

# Allowed MIME types — Phase 8B scope: images only
ALLOWED_MIME_TYPES = {"image/png", "image/jpeg", "image/webp"}
MAX_ATTACHMENT_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB per image


class AttachmentOut(BaseSchema):
    id: str
    conversation_id: str
    message_id: Optional[str] = None
    filename: str
    mime_type: str
    size_bytes: int
    created_at: datetime
    # NOTE: storage_path is NEVER returned to frontend (security boundary)


class AttachmentRef(BaseSchema):
    """Lightweight reference embedded in MessageOut/MessageSend."""
    id: str
    filename: str
    mime_type: str
    size_bytes: int
```

---

### Batch 8B.3 — Update Message Model & Schema for Attachments

**[MODIFY]** `backend/app/models/message.py`

Add relationship:
```python
from app.models.attachment import Attachment
# In Message class:
attachments: Mapped[List["Attachment"]] = relationship(
    "Attachment", back_populates="message", lazy="selectin"
)
```

**[MODIFY]** `backend/app/schemas/message.py`

```python
# MessageSend: add optional attachment_ids
class MessageSend(BaseSchema):
    user_text: str = Field(..., min_length=1)
    client_message_id: Optional[str] = Field(default=None, max_length=64)
    attachment_ids: List[str] = Field(default_factory=list, max_length=4)
    # max 4 images per message — prevents context overflow

# MessageOut: add attachments list
class MessageOut(BaseSchema):
    ...existing fields...
    attachments: List[AttachmentRef] = Field(default_factory=list)
```

---

### Batch 8B.4 — Attachment Upload API

Create: `backend/app/api/v1/endpoints/attachments.py`

**Endpoints:**
```
POST   /api/v1/conversations/{conversation_id}/attachments
         — upload image, returns AttachmentOut with id
         — validates: MIME type in ALLOWED_MIME_TYPES, size <= 10MB, conversation ownership
         — stores to: DATA_DIR/attachments/{owner_id}/{conversation_id}/{attachment_id}/{filename}
         — never stores outside DATA_DIR

GET    /api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview
         — returns image bytes (Content-Type: image/png|jpeg|webp)
         — validates: attachment ownership, conversation membership, not deleted
         — used for thumbnail rendering in frontend

DELETE /api/v1/conversations/{conversation_id}/attachments/{attachment_id}
         — soft-delete (is_deleted=True), does NOT remove from filesystem immediately
         — filesystem cleanup handled by retention purge job (future)
```

**Storage security rules (non-negotiable):**
1. `storage_path` is always `attachments/{owner_id}/{conversation_id}/{attachment_id}/{safe_filename}`
2. `safe_filename = re.sub(r'[^a-zA-Z0-9._-]', '_', filename)[:128]`
3. Path must be resolved and confirmed to be inside `DATA_DIR` before write
4. No path traversal: reject filenames containing `..`, `/`, `\`
5. MIME is validated from file bytes (python-magic or file header check), NOT from Content-Type header

---

### Batch 8B.5 — Update AssistantOrchestrator for Structured Content

File: `backend/app/services/assistant/orchestrator.py`

The orchestrator currently builds:
```python
messages = [{"role": "user", "content": user_text}]
```

Change to:
```python
# If message has attachments AND active model has vision capability:
content = []
for attachment in message.attachments:
    if not attachment.is_deleted:
        image_path = settings.DATA_DIR / attachment.storage_path
        b64 = base64.b64encode(image_path.read_bytes()).decode()
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:{attachment.mime_type};base64,{b64}"}
        })
content.append({"type": "text", "text": user_text})
messages = [{"role": "user", "content": content if content else user_text}]
```

> If no attachments or model has no vision capability → `content` stays as plain string (backward compatible).

**Model capability check:**
```python
# In orchestrator, before building multimodal payload:
registry = build_model_list()
active_entry = next((m for m in registry if m.id == active_model_id), None)
has_vision = active_entry and ModelCapability.vision in active_entry.capabilities
```

---

### Batch 8B.6 — LlamaCppProvider: Multimodal Payload Translation

File: `backend/app/services/llm/llama_cpp.py`

The provider receives `ChatMessage` objects. Update `ChatMessage` schema to support structured content:

```python
# backend/app/schemas/llm.py — ChatMessage
class ChatMessage(BaseSchema):
    role: str
    content: Union[str, List[Dict[str, Any]]]  # str for text, list for multimodal
```

In `LlamaCppProvider.chat()` and `chat_stream()`, the payload already uses:
```python
payload = {"model": ..., "messages": formatted_messages, ...}
```

The `formatted_messages` list already passes through — no translation needed if the orchestrator builds the correct OpenAI-compatible structure. llama.cpp `/v1/chat/completions` already accepts the multimodal content array format.

**The provider layer is already correct for this.** The gap is only in the orchestrator → message schema chain.

---

### Batch 8B.7 — Frontend: Real Attachment Composer

**[MODIFY]** `frontend/web/src/services/api/conversationApi.ts`

```typescript
// Add to StreamMessageOptions:
export interface StreamMessageOptions {
  conversationId: string;
  userText: string;
  clientMessageId?: string;
  attachmentIds?: string[];    // NEW: list of pre-uploaded attachment IDs
  signal?: AbortSignal;
  onToken: (token: string) => void;
  onDone: () => void;
  onError: (error: Error, partialText?: string) => void;
}

// In body:
body: JSON.stringify({
  user_text: userText,
  client_message_id: clientMessageId || null,
  attachment_ids: attachmentIds || [],   // NEW
}),
```

Create: `frontend/web/src/services/api/attachmentApi.ts`

```typescript
/**
 * Attachment upload and preview API — Phase 8B multimodal.
 */
export interface AttachmentOut {
  id: string;
  conversation_id: string;
  message_id: string | null;
  filename: string;
  mime_type: string;
  size_bytes: number;
  created_at: string;
}

export const ALLOWED_MIME_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
export const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

export async function uploadAttachment(
  conversationId: string,
  file: File,
  apiKey: string,
): Promise<AttachmentOut> {
  // Validate client-side before upload
  if (!ALLOWED_MIME_TYPES.includes(file.type)) {
    throw new Error(`Unsupported file type: ${file.type}. Allowed: PNG, JPEG, WebP`);
  }
  if (file.size > MAX_SIZE_BYTES) {
    throw new Error(`File too large: ${(file.size / 1024 / 1024).toFixed(1)} MB. Max 10 MB.`);
  }
  const form = new FormData();
  form.append('file', file);
  const res = await fetch(
    `${BACKEND_BASE_URL}/api/v1/conversations/${conversationId}/attachments`,
    { method: 'POST', headers: { Authorization: `Bearer ${apiKey}` }, body: form }
  );
  if (!res.ok) throw new Error(`Upload failed: ${res.status}`);
  return res.json();
}

export function getAttachmentPreviewUrl(conversationId: string, attachmentId: string): string {
  return `${BACKEND_BASE_URL}/api/v1/conversations/${conversationId}/attachments/${attachmentId}/preview`;
}
```

**[MODIFY]** `frontend/web/src/components/workspace/assistant/AssistantComposer.tsx` (from 8A)

Replace fake attachment chips with real image upload:
```tsx
// State
const [pendingAttachments, setPendingAttachments] = useState<AttachmentOut[]>([]);
const fileInputRef = useRef<HTMLInputElement>(null);

// Paperclip click → trigger hidden file input (image/* only)
// On file select → uploadAttachment() → add to pendingAttachments
// On send → pass pendingAttachments.map(a => a.id) as attachmentIds to streamSendMessage
// After send → clear pendingAttachments
```

**Attachment preview row:**
```tsx
{pendingAttachments.length > 0 && (
  <div className="flex gap-2 flex-wrap px-2 pt-2">
    {pendingAttachments.map((att) => (
      <div key={att.id} className="relative group w-14 h-14 rounded-lg overflow-hidden border border-[var(--color-border-subtle)] bg-[var(--color-surface-raised)]">
        <img
          src={getAttachmentPreviewUrl(conversationId, att.id)}
          alt={att.filename}
          className="w-full h-full object-cover"
        />
        <button
          onClick={() => setPendingAttachments(prev => prev.filter(a => a.id !== att.id))}
          className="absolute top-0.5 right-0.5 w-4 h-4 rounded-full bg-rose-500/80 text-white text-xs flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
        >×</button>
      </div>
    ))}
  </div>
)}
```

**Vision gate — disable attachment button if model has no vision:**
```tsx
const hasVision = currentModel?.capabilities?.includes('vision') ?? false;

<button
  onClick={() => hasVision ? fileInputRef.current?.click() : void 0}
  disabled={!hasVision || !conversationId}
  title={!hasVision ? 'Active model does not support image input' : 'Attach image (PNG, JPEG, WebP)'}
  ...
>
  <Paperclip />
</button>
```

---

### 8B Test Gate

```powershell
# Backend
cd backend
.venv\Scripts\alembic upgrade head     # migration 006 applied cleanly
.venv\Scripts\pytest tests/ -v         # >= 88 + new attachment tests pass

# Frontend
cd frontend/web
npx tsc --noEmit                        # 0 errors
npm run test                            # >= 38 + new attachment tests pass
npm run build                           # clean build
```

**New tests required:**
- `backend/tests/test_attachments.py` — upload, preview, ownership validation, path traversal rejection, MIME rejection, size rejection, cascade delete
- `frontend/web/src/test/attachmentComposer.test.tsx` — upload trigger, preview render, vision gate disable, send with attachment IDs, clear after send

---

### 8B Proposed Commit Message

```
feat(8b): multimodal image attachment foundation

- migration 006: attachments table (id, owner, message_id, conversation_id, filename,
  mime_type, size_bytes, storage_path, is_deleted, CASCADE FKs)
- backend: Attachment ORM model + AttachmentOut/AttachmentRef schemas
- backend: Message.attachments relationship (selectin loaded)
- backend: MessageSend.attachment_ids[] + MessageOut.attachments[]
- backend: POST/GET preview/DELETE /api/v1/conversations/{id}/attachments/*
  (MIME validation from bytes, path security, DATA_DIR boundary, 10MB limit)
- backend: AssistantOrchestrator — structured multimodal content when attachments present
  + model registry vision capability gate (no vision → plain text, backward compatible)
- backend: ChatMessage.content: Union[str, List[Dict]] (provider-independent)
- frontend: attachmentApi.ts — uploadAttachment, getAttachmentPreviewUrl
- frontend: AssistantComposer — real file input, image previews, vision gate disabled state
- frontend: conversationApi.streamSendMessage — attachment_ids[] param
- frontend: MessageOut type — attachments?: AttachmentRef[]
- tests: test_attachments.py, attachmentComposer.test.tsx

Video support: DEFERRED — Phase 2 verified image only; video requires frame extraction
PDF/OCR/audio: DEFERRED — out of scope (temp.txt Phase 8 constraint)

Track: Phase 8B — Multimodal Image Attachment Foundation
```


---

## Section 5 — Phase 8C: Integration, Accessibility & Polish

**Branch:** `feature/phase8-ui-integration-polish` (based on merged 8B)
**Scope:** No new backend features. No new DB migrations. Polish, delete deprecated code, final test coverage, bundle optimization.

### Batch 8C.1 — Delete Deprecated Mock Files (Now Safe)

After 8A and 8B confirm all views use real data:
- Verify no remaining production imports from `mock/` (run `grep -r "from '.*mock/" src/` — must return zero results outside `test/`)
- Delete: `mock/localAiData.ts`, `mock/healthData.ts`, `mock/deviceAndMemoryData.ts`, `mock/logsData.ts`, `mock/multilingualData.ts`
- Keep: `mock/characterData.ts` only if CharactersView still uses it as placeholder (check in 8C)

**Verify before deleting:**
```powershell
grep -r "from '.*mock/" frontend/web/src --include="*.tsx" --include="*.ts" -l
# Expected: only test files. If any views still import mock/ → fix first, then delete
```

---

### Batch 8C.2 — Bundle Analysis & Performance

**Baseline evidence (collect in 8C, not before):**
```bash
npm run build 2>&1 | grep "dist/"     # collect chunk sizes post-8B
npx vite-bundle-analyzer dist/        # or rollup-plugin-visualizer
```

**Expected wins from 8A/8B:**
- Mock data removal saves ~80KB from bundle
- No new heavy dependencies should be introduced in 8A or 8B

**If bundle > 1MB uncompressed after tree-shaking:** identify top chunks and add `React.lazy()` / dynamic import for the largest workspace views (ScheduleView is 45KB — candidate for lazy load).

---

### Batch 8C.3 — Accessibility Pass

Targeted only — no framework changes:
- All icon-only buttons in `AssistantComposer` must have `aria-label` (send, stop, mic, attach)
- `ConversationMessageItem` — ensure `role="article"` or `role="listitem"` on message bubbles
- Image attachment previews: `alt={att.filename}` (already in 8B plan)
- Keyboard: `Tab` navigation through composer buttons, `Enter` on attachment removes it
- Focus: after send, focus returns to input field

---

### Batch 8C.4 — Final Test Coverage

**New tests in 8C:**
- `frontend/web/src/test/phase8Integration.test.tsx`
  - Full send flow with attachment: upload → preview renders → send with IDs → chat message shows image
  - Vision gate: text-only model → attachment button disabled → cannot send with image
  - Conversation persistence: reload page → conversation restores with attachment previews
  - Model sleeping: send triggers wake → correct MODEL_SLEEPING → MODEL_READY cycle
  - Cancellation with attachment: mid-stream abort → attachment not committed to message

**Backend regression check:**
```powershell
.venv\Scripts\pytest tests/ -v --tb=short 2>&1 | tail -5
# Expected: all passes, no regressions from 8A/8B
```

---

### Batch 8C.5 — Documentation Update

**[MODIFY]** `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`
- Update status table: Assistant orchestration & memory → `Repository-verified implementation`
- Add multimodal row: `Multimodal image attachments → Repository-verified implementation`
- Update test count

**[CREATE]** `docs/03_Walkthroughs/walkthrough-phase8-multimodal-attachments.md`
- Follow 7-section template from `docs/03_Walkthroughs/walkthrough-template.md`
- Document upload flow, storage security, vision gate, provider translation, test results

**[MODIFY]** `docs/01_Tracking/task.md`
- Archive Phase 8 tasks per `docs/01_Tracking/archive/task-YYYY-MM-DD-phase8-ui-multimodal.md`

---

### 8C Test Gate — Final

```powershell
cd backend
.venv\Scripts\pytest tests/ -v         # final count (target: 100+)
cd frontend/web
npx tsc --noEmit                        # 0 errors
npm run test                            # final count (target: 50+)
npm run build                           # verify bundle size reduced vs develop baseline
```

---

### 8C Proposed Commit Message

```
feat(8c): integration polish — mock cleanup, bundle optimization, accessibility, final tests

- Delete deprecated mock/*.ts files (all views confirmed on live API data)
- Bundle: lazy-load ScheduleView if bundle analysis warrants it
- Accessibility: aria-labels on all composer buttons, focus management
- test: phase8Integration.test.tsx covering attachment flow, vision gate, conversation reload
- docs: AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md status table updated
- docs: walkthrough-phase8-multimodal-attachments.md (7-section template)
- task.md: archived to docs/01_Tracking/archive/

Track: Phase 8C — Integration, Accessibility & Polish
```

---

## Section 6 — Deferred / Out of Scope

| Item | Classification | Reason |
|------|---------------|--------|
| Video input via Qwen3-VL | Deferred | Phase 2 verified image only; video requires frame extraction — unverified in repo |
| PDF ingestion / OCR | Deferred / Out of scope | temp.txt explicit constraint |
| Audio upload | Deferred / Out of scope | temp.txt explicit constraint |
| Android multimodal UI | Deferred | PC-first scope constraint |
| Document RAG | Deferred | Out of Phase 8 scope |
| Arbitrary file types | Deferred | temp.txt explicit constraint |
| New state management library (Redux, Zustand) | Not needed | BackendContext + React hooks adequate — no prop-drilling crisis found |

---

## Section 7 — Non-Negotiable Invariants Across All Phases

1. `backend runtime authority` — frontend never computes model state; always reads from backend
2. `selected model != active model` — UI must preserve this distinction throughout 8A/8B/8C
3. `requested profile != applied profile` — ModelsView must keep showing both
4. `MODEL_SLEEPING` — correctly displayed in AssistantStatusBar after 8A decomposition
5. Storage security — attachment `storage_path` never returned to frontend; preview via API only
6. No base64 blobs in `messages.content` — attachments live in `attachments` table only
7. All original 88 pytest tests pass after every branch merge
8. `models/registry.json` remains gitignored; `registry.template.json` remains committed
9. No `git add`, `git commit`, or `git push` by Gemini — user commits manually

---

## Section 8 — task.md Update Instructions

After each branch merges, update `docs/01_Tracking/task.md` in-place:

```markdown
## Active Checklist — Phase 8

- [x] 8A.1: Mock data deprecation + HomeView/HealthView/MemoryView live wiring
- [x] 8A.2: AssistantView decomposition (Composer, MessageList, StatusBar, ErrorDisplay)
- [x] 8A.3: Design system consistency pass + variant badges
- [x] 8A.4: @deprecated annotations on mock files
- [ ] 8B.1: Migration 006 — attachments table
- [ ] 8B.2: Attachment ORM + schemas (AttachmentOut, AttachmentRef)
- [ ] 8B.3: Message model + schema updated for attachments
- [ ] 8B.4: Attachment upload/preview/delete API endpoints
- [ ] 8B.5: Orchestrator multimodal payload + vision gate
- [ ] 8B.6: ChatMessage Union[str, List] content type
- [ ] 8B.7: Frontend attachmentApi.ts + AssistantComposer real upload
- [ ] 8C.1: Delete deprecated mock files
- [ ] 8C.2: Bundle analysis + lazy load if warranted
- [ ] 8C.3: Accessibility pass
- [ ] 8C.4: Final test suite (target 100+ pytest, 50+ vitest)
- [ ] 8C.5: Documentation update + walkthrough
```

