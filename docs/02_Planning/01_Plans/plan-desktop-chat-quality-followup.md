# Desktop Chat Quality Follow-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address human Windows acceptance feedback across five scoped areas: propagate real finish reasons (`length`, `stop`, `cancelled`, error) end-to-end with continuation options, provide visible horizontal scrollbars and mouse/trackpad gestures for wide tables, guarantee textbook-grade mathematical typesetting for LaTeX equations, implement local conversation text zoom (80%–160% via Ctrl+Wheel and Ctrl+Plus/Minus/0), and add explicit authenticated model unload in Flutter Settings.

**Architecture:** 
- End-to-end finish-reason pipeline: `llama.cpp` upstream SSE chunk decoder captures `finish_reason` -> provider records `last_finish_reason` -> orchestrator passes bounded `max_tokens` against remaining context capacity, persists message status (`completed`, `length`, `cancelled`, `error`), and emits `finish_reason` in SSE `done` event -> Flutter client parses reason and renders an actionable "Response reached generation limit" indicator with a continuation turn.
- Markdown & Table Layout: `_MarkdownTableWidget` wraps horizontal `SingleChildScrollView` in a visible `Scrollbar` with `thumbVisibility: true` and `ScrollConfiguration` enabling mouse/trackpad drag, with constrained cell wrapping preventing clipping.
- Typesetting: Persona prompt prefers standard LaTeX delimiters (`\[ ... \]`, `\( ... \)`) for mathematical explanations; renderer supports complex integrals and multiline equations with copyable raw source and horizontal scroll.
- Conversation Zoom: `DesktopClientSettings` persists zoom level (0.8–1.6, default 1.0); `ChatScreen` wraps only the message viewport in `MediaQuery(textScaler: TextScaler.linear(zoom))` listening to Ctrl+Wheel and Ctrl+Plus/Minus/0 shortcuts without zooming application chrome.
- Model Unload: `CompanionClient.unloadModel()` calls authenticated `POST /api/v1/models/unload`; `SettingsScreen` renders an enabled "Unload Model / Free VRAM" control when model is loaded, blocked during active generation, with truthful status reporting.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2, llama.cpp HTTP server, Flutter Desktop (Windows), Dart, `flutter_math_fork`.

**Spec:** Human direction from `AI COMPANION — DESKTOP CHAT QUALITY FOLLOW-UP` (PC-CLIENT-006 / PC-CLIENT-010).

## Global Constraints

- Do not reopen the approved M2-H1 process supervision architecture.
- Do not blindly raise context size (keep balanced default at 4096), GPU allocation, or maximum output tokens.
- Keep generation reserve consistent with requested output capacity and actual model context.
- Preserve conversation history, partial output, and user drafts.
- Do not log private prompt text; log only token counts and finish reasons.
- No arbitrary HTML or JavaScript execution in Markdown/Math rendering.
- Do not automatically unload models on window hide or developer UI quit.
- Strictly no PR, merge, rebase, or force push.

## Review Focus

1. **Abrupt turn truncation in long conversations:** Upstream `finish_reason: "length"` must be truthfully preserved and displayed, not disguised as `"stop"`.
2. **Context overflow prevention:** Orchestrator must compute `max_tokens = min(default_max_tokens, context_capacity - prompt_tokens)` to prevent upstream crashes when prompts grow long.
3. **Table clipping on 1024px desktop:** Wide 8-column tables must have visible, interactive horizontal scrollbars and wrapped cells without overflowing parent message bubbles.
4. **Chrome zoom isolation:** Text zoom must apply strictly to conversation content and math, never scaling navigation rail, header bars, or settings forms.
5. **Model unload safety:** Unload must be rejected or disabled while turn generation is active, and failure must be truthfully reported.

---

### Task 1: Backend End-to-End Finish Reason & Token Budgeting (Area A)

**Files:**
- Modify: `backend/app/services/llm/base.py`
- Modify: `backend/app/services/llm/llama_cpp.py:45-85, 1010-1060`
- Modify: `backend/app/services/llm/mock.py:150-180`
- Modify: `backend/app/services/assistant/orchestrator.py:315-400`
- Modify: `backend/app/api/v1/endpoints/llm.py:235-255`
- Test: `backend/tests/test_assistant_orchestrator.py`
- Test: `backend/tests/test_runtime_boundary_regressions.py`

**Interfaces:**
- Consumes: Upstream `choices[0].finish_reason` from `llama-server` SSE stream.
- Produces: `provider.last_finish_reason: Optional[str]`, `data: {"type": "done", "finish_reason": "length"|"stop"|"cancelled", ...}\n\n`, and `Message.status = "length"|"completed"|"cancelled"|"error"`.

- [x] **Step 1: Write the failing tests for finish_reason propagation and context budgeting**
  - In `backend/tests/test_assistant_orchestrator.py`: test that when upstream provider yields tokens and ends with `finish_reason="length"`, the orchestrator SSE stream emits `{"type": "done", "finish_reason": "length"}`, persists assistant message with `status="length"`, logs token counts without prompt text, and sets `max_tokens` bounded by remaining context.
  - In `backend/tests/test_runtime_boundary_regressions.py`: test `_decode_stream_event` and `_server_stream_tokens` capturing `"length"` vs `"stop"`.

- [x] **Step 2: Run tests to verify failure**
  - Run: `.\venv\Scripts\pytest backend/tests/test_assistant_orchestrator.py -k "finish_reason" -v`
  - Expected: FAIL (`finish_reason` expected "length", got "stop").

- [x] **Step 3: Implement upstream finish_reason capture in `LlamaCppProvider` & `MockLLMProvider`**
  - In `backend/app/services/llm/llama_cpp.py`: update `_decode_stream_event` to return `(token, done, finish_reason)` or invoke an `on_finish` callback.
  - In `_server_stream_tokens` and in-process `_worker`: store `self.last_finish_reason = reason`.
  - In `MockLLMProvider`: add `self.last_finish_reason = getattr(self, "configured_finish_reason", "stop")`.

- [x] **Step 4: Implement bounded token budgeting and finish_reason SSE emission in `orchestrator.py`**
  - Calculate `available_generation_tokens = max(1, context_capacity - prompt_tokens)`.
  - Pass `max_tokens = min(1024, available_generation_tokens)` to `provider.generate_stream(..., max_tokens=...)`.
  - Read `finish_reason = getattr(provider, "last_finish_reason", "stop") or "stop"`.
  - Set `asst_msg.status = "length" if finish_reason == "length" else "completed"`.
  - Emit `done_data = json.dumps({"type": "done", "finish_reason": finish_reason, "prompt_tokens": prompt_tokens, "completion_tokens": completion_tokens})`.
  - Log: `logger.info(f"Turn generation completed: conv_id={conversation_id}, prompt_tokens={prompt_tokens}, completion_tokens={completion_tokens}, finish_reason={finish_reason}")`.

- [x] **Step 5: Run tests to verify pass**
  - Run: `.\venv\Scripts\pytest backend/tests/test_assistant_orchestrator.py backend/tests/test_runtime_boundary_regressions.py -v`
  - Expected: PASS.

---

### Task 2: Flutter Desktop Chat Finish Reason & Generation Limit UI (Area A)

**Files:**
- Modify: `frontend/flutter/apps/desktop/lib/features/chat/desktop_chat_controller.dart:650-735`
- Modify: `frontend/flutter/apps/desktop/lib/screens/chat_screen.dart:820-920`
- Test: `frontend/flutter/apps/desktop/test/desktop_chat_test.dart`

**Interfaces:**
- Consumes: `SseDoneEvent.finishReason`.
- Produces: `MessageOut.status = 'length'`, UI badge "Response reached generation limit" with "Continue response" button calling `controller.sendMessage("Continue")`.

- [x] **Step 1: Write the failing tests for finish_reason handling in `desktop_chat_test.dart`**
  - Test: when `SseDoneEvent(finishReason: 'length')` is received, the assistant turn updates to `status: 'length'`.
  - Test: when `status == 'length'`, `ChatScreen` renders "Response reached generation limit" badge and a "Continue response" button.
  - Test: tapping "Continue response" sends a continuation prompt as a new turn.
  - Test: when stream disconnects without `SseDoneEvent`, it transitions to interrupted rather than normal completion.

- [x] **Step 2: Run tests to verify failure**
  - Run: `flutter test test/desktop_chat_test.dart -n "generation limit"`
  - Expected: FAIL.

- [x] **Step 3: Implement controller and UI handling for generation limit**
  - In `desktop_chat_controller.dart`: on `SseDoneEvent`, update assistant message status to `event.finishReason ?? 'completed'`.
  - On `onDone`: if state was still `generating` without `SseDoneEvent`, set status to `'interrupted'` and report error.
  - In `chat_screen.dart`: under the assistant message bubble, if `msg.status == 'length'`, render warning container:
    - Icon: `Icons.timer_outlined` or `Icons.hourglass_bottom_rounded`.
    - Label: `Response reached generation limit`.
    - Button: `FilledButton.tonalIcon(label: Text('Continue response'), icon: Icon(Icons.arrow_forward_rounded), onPressed: () => chatCtrl.sendMessage('Continue'))`.

- [x] **Step 4: Run tests to verify pass**
  - Run: `flutter test test/desktop_chat_test.dart`
  - Expected: PASS.

---

### Task 3: Wide Table Horizontal Scrollbar & Cell Constraint (Area B)

**Files:**
- Modify: `frontend/flutter/apps/desktop/lib/features/chat/assistant_markdown_view.dart:986-1080`
- Test: `frontend/flutter/apps/desktop/test/assistant_markdown_view_test.dart`

**Interfaces:**
- Consumes: Markdown table tokens.
- Produces: `_MarkdownTableWidget` with dedicated `ScrollController`, visible `Scrollbar`, mouse drag support, and constrained text wrapping.

- [x] **Step 1: Write the failing test for wide table scrollbar and cell wrapping**
  - In `assistant_markdown_view_test.dart`: test an 8-column table with wide descriptions on a 1024x640 viewport.
  - Assert that `Scrollbar` is present with `thumbVisibility: true`.
  - Assert that cells have constrained max widths so text wraps without clipping.

- [x] **Step 2: Run test to verify failure**
  - Run: `flutter test test/assistant_markdown_view_test.dart -n "Scrollbar"`
  - Expected: FAIL (`Scrollbar` not found).

- [x] **Step 3: Implement `_MarkdownTableWidget` improvements**
  - Convert `_MarkdownTableWidget` to `StatefulWidget` to maintain its own `ScrollController`.
  - Wrap `SingleChildScrollView` in `Scrollbar(controller: _scrollController, thumbVisibility: true)`.
  - Add `ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}))`.
  - Wrap cell contents in `ConstrainedBox(constraints: const BoxConstraints(minWidth: 80, maxWidth: 360), child: SelectableText.rich(...))` to wrap long text while preserving column alignment.

- [x] **Step 4: Run test to verify pass**
  - Run: `flutter test test/assistant_markdown_view_test.dart`
  - Expected: PASS.

---

### Task 4: Professional Mathematical Typesetting & Prompt Guidance (Area C)

**Files:**
- Modify: `backend/app/services/assistant/orchestrator.py:50-55` (system prompt guidance)
- Modify: `frontend/flutter/apps/desktop/lib/features/chat/assistant_markdown_view.dart:1100-1245`
- Test: `frontend/flutter/apps/desktop/test/assistant_markdown_view_test.dart`

**Interfaces:**
- Consumes: Display LaTeX `\[ ... \]` and inline LaTeX `\( ... \)`.
- Produces: Beautifully typeset mathematical formulas (integrals, limits, fractions) with copyable raw source.

- [x] **Step 1: Write tests for textbook calculus integral and display math**
  - In `assistant_markdown_view_test.dart`: add test rendering exact textbook equation:
    `\[\int_1^\infty \frac{1}{x^2}\,dx = \left[-\frac{1}{x}\right]_{1}^{\infty} = 1\]`.
  - Assert `SelectableMath` renders display math with integral and limits.
  - Test multiline math with alignment and copy functionality.
  - Test that literal fenced code ```latex is NOT converted to math widget.

- [x] **Step 2: Run tests to verify current behavior and gaps**
  - Run: `flutter test test/assistant_markdown_view_test.dart -n "textbook"`
  - Expected: Verify behavior against the new formula.

- [x] **Step 3: Update `DEFAULT_PERSONA` in orchestrator & fine-tune math display**
  - In `orchestrator.py`: add system instruction: `"When providing mathematical formulas or steps, use standard display LaTeX delimiters \\[ ... \\] or inline \\( ... \\) rather than fenced code blocks."`
  - In `assistant_markdown_view.dart`: ensure multiline display math properly preserves LaTeX spacing and does not break on line breaks.

- [x] **Step 4: Run tests to verify pass**
  - Run: `flutter test test/assistant_markdown_view_test.dart`
  - Expected: PASS.

---

### Task 5: Conversation Text Zoom with Persistence & Gestures (Area D)

**Files:**
- Modify: `frontend/flutter/apps/desktop/lib/platform/desktop_client_settings.dart`
- Modify: `frontend/flutter/apps/desktop/lib/screens/chat_screen.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_chat_test.dart`
- Test: `frontend/flutter/apps/desktop/test/desktop_client_settings_test.dart`

**Interfaces:**
- Consumes: Ctrl+Wheel, Ctrl+Plus/Minus/0 shortcuts.
- Produces: Persistent `chatZoomLevel` (0.8–1.6) applying strictly to conversation viewport via `MediaQuery.textScaler`.

- [x] **Step 1: Write tests for zoom settings persistence and chat zoom interactions**
  - In `desktop_client_settings_test.dart`: test `readChatZoomLevel` and `writeChatZoomLevel` (default 1.0, clamp between 0.8 and 1.6).
  - In `desktop_chat_test.dart`: test `ChatScreen` keyboard shortcuts (`Ctrl+=`, `Ctrl+-`, `Ctrl+0`) and Ctrl+Wheel altering the conversation text scaler without altering header/composer text sizes.

- [x] **Step 2: Run tests to verify failure**
  - Run: `flutter test test/desktop_client_settings_test.dart test/desktop_chat_test.dart -n "zoom"`
  - Expected: FAIL.

- [x] **Step 3: Implement zoom settings in `DesktopClientSettings`**
  - Add `Future<double> readChatZoomLevel({double defaultValue = 1.0})`.
  - Add `Future<void> writeChatZoomLevel(double zoomLevel)`. Clamped to `0.8..1.6`.

- [x] **Step 4: Implement zoom gestures and scoped text scaling in `ChatScreen`**
  - Add `double _zoomLevel = 1.0`. Load on `initState()` via `_effectiveClientSettings.readChatZoomLevel()`.
  - Wrap `_buildMessageList` in `Listener(onPointerSignal: _handlePointerSignal, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_zoomLevel)), child: ...))`.
  - Add shortcut actions for `LogicalKeyboardKey.equal` (zoom in), `LogicalKeyboardKey.minus` (zoom out), `LogicalKeyboardKey.digit0` (reset).
  - On zoom change: `_effectiveClientSettings.writeChatZoomLevel(_zoomLevel)`.

- [x] **Step 5: Run tests to verify pass**
  - Run: `flutter test test/desktop_client_settings_test.dart test/desktop_chat_test.dart`
  - Expected: PASS.

---

### Task 6: Explicit Model Unload Control in Flutter Settings (Area E)

**Files:**
- Modify: `frontend/flutter/packages/companion_api/lib/client/companion_client.dart`
- Modify: `frontend/flutter/apps/desktop/lib/screens/settings_screen.dart`
- Test: `frontend/flutter/packages/companion_api/test/companion_client_test.dart`
- Test: `frontend/flutter/apps/desktop/test/settings_screen_test.dart`

**Interfaces:**
- Consumes: Authenticated `POST /api/v1/models/unload`.
- Produces: `CompanionClient.unloadModel()`, "Unload Model / Free VRAM" button in `SettingsScreen`.

- [x] **Step 1: Write failing tests for client unload and settings screen unload button**
  - In `companion_client_test.dart`: test `unloadModel()` sends `POST /api/v1/models/unload` with auth header and returns `ModelStatusResponse`.
  - In `settings_screen_test.dart`: test that when model is loaded, "Unload Model / Free VRAM" button is enabled; when tapped, invokes `unloadModel()` and updates UI; test that when turn generation is active, unload is disabled or rejected.

- [x] **Step 2: Run tests to verify failure**
  - Run: `flutter test test/settings_screen_test.dart`
  - Expected: FAIL (`unloadModel` missing).

- [x] **Step 3: Implement `unloadModel()` in `CompanionClient`**
  - Add `Future<ModelStatusResponse> unloadModel()` in `companion_client.dart`.

- [x] **Step 4: Implement Unload Model button and handler in `SettingsScreen`**
  - Add `Future<void> _unloadModel()` in `_SettingsScreenState`.
  - Verify `chatController?.isGenerating != true`.
  - Call `client.unloadModel()`, update `_modelStatus`, report result truthfully, and notify `chatController`.
  - Render "Unload Model / Free VRAM" button in Active Model Card and loaded model entry.

- [x] **Step 5: Run tests to verify pass**
  - Run: `flutter test test/settings_screen_test.dart`
  - Expected: PASS.

---

### Task 7: Full Verification, Documentation & Remote Push (Area F)

**Files:**
- Modify: `docs/01_Tracking/active/task-m2-windows-runtime-supervision.md`
- Verify: Full Flutter tests, backend pytest, linter checks.

- [x] **Step 1: Run full verification suite**
  - `dart analyze frontend/flutter/` (0 issues)
  - `flutter test frontend/flutter/apps/desktop` (95 passed)
  - `dart test frontend/flutter/packages/companion_core` (passed)
  - `dart test frontend/flutter/packages/companion_api` (56 passed)
  - `pytest backend/tests` (148 passed)
  - `python scripts/check_dart_openapi_parity.py` (0 discrepancies)
  - `python scripts/verify_llama_windowless.py` (passed empirical isolated check)

- [x] **Step 2: Update active task tracking**
  - Record the quality follow-up items under PC-CLIENT-006 and PC-CLIENT-010 in `task-m2-windows-runtime-supervision.md`.

- [x] **Step 3: Commit and HTTPS push**
  - Scoped changes committed with Conventional Commits.
  - HTTPS push to `feature/m2-windows-runtime-supervision`.
  - Remote HEAD verified.

---

### Correctness Fixes (Post-Implementation Review)

#### Correctness Fix A: Truthful Model Unload Verification
- **Issue:** `POST /api/v1/models/unload` previously ignored provider `unload_model()` return value, and Flutter displayed success on HTTP 200 without checking if the model actually unloaded.
- **Resolution:**
  - `POST /api/v1/models/unload` returns `409 Conflict` if turn generation is active.
  - Returns `500 Internal Server Error` if provider unload fails or if `status.model_loaded` remains `True`.
  - Flutter Settings checks that `status.model_loaded == false` before announcing success (`"Model unloaded successfully."`).
  - Reports failure truthfully without claiming unevidenced VRAM reclamation.
  - Regression tests added in `backend/tests/test_llm.py` and `frontend/flutter/apps/desktop/test/desktop_settings_test.dart`.

#### Correctness Fix B: Request-Scoped Finish Reasons
- **Issue:** `BaseLLMProvider.last_finish_reason` was shared mutable state on a singleton provider, causing race conditions where concurrent conversation streams could overwrite each other's terminal finish reason.
- **Resolution:**
  - Carried completion reasons directly within per-request `GenerationStream` metadata and `GeneratedText`.
  - Interleaving concurrent conversation streams maintain isolated terminal finish reasons without cross-talk.
  - Verified with multi-turn concurrent regression test in `backend/tests/test_assistant_orchestrator.py`.
