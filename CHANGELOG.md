# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project will use semantic versioning once releases begin.

## Unreleased

### Added — M3 Batch F: Pre-Limit Context Compaction, Rolling Conversation Summaries & Memory V2 Follow-On (`PC-MEM-001`..`005`, `PC-CLIENT-006`, `PC-CLIENT-009`)
- **Database Schema & Purge Lifecycle (`014_conversation_summaries_and_compaction`, `ConversationSummary`):** Added rolling episode digest storage (`from_sequence_no`, `to_sequence_no`, `compacted_message_count`, `token_estimate`, `source`, partial unique active index per conversation), cascade cleanup on conversation soft-delete and `ProfilePurgeService`, plus Migration `013` unused import cleanup.
- **Pre-Limit Context Compaction & Assistant Prompt Assembly (`compactor.py`, `orchestrator.py`, `config.py`):** Added `CONTEXT_COMPACTION_*` thresholds (`0.72` ratio, keep recent `8`, min `4`, summary `<= 180` tokens), `ConversationCompactor` automatic and manual compaction with deterministic `extractive_fallback`, `<recent_episode_digest>` prompt injection with `escape_prompt_xml_delimiters` sanitization, `GET /api/v1/conversations/{id}/summary` + `POST /api/v1/conversations/{id}/compact`, and **1-hop compacted in-stream continuation** (`build_continuation_messages`, `CONTEXT_COMPACTION_AUTO_CONTINUE_*`) seamlessly resuming length-truncated replies inside the same SSE stream while guarding short outputs and repetition cutoffs.
- **Memory V2 Follow-On & Batch E Hardening (`extractor.py`, `reconciler.py`, `retriever.py`, `schemas/memory.py`, `endpoints/memories.py`):** Added `+0.3` emotion-weighted importance boost (`<= 2.0`), single-step `(previously: ... until YYYY-MM)` temporal fact evolution trail, explicit `MemoryUpdate.clear_expires_at` Short-Term promotion flag, pre-slice `exclude_ids`, profile-scoped `recall_count` increment, keyword-lorebook exclusion from short-term fallback, defensive non-core flag stripping, FTS5 `NEAR` operator reservation, and null-safe JSON payload parsing.
- **Contracts, Dart SDK & Flutter Desktop UI:** Updated OpenAPI contract (`46` routes), `companion_api` DTOs/client/tests (`99/99`), `DesktopMemoryController.promoteMemory` (`clearExpiresAt: true`), `DesktopChatController` (summary state + atomic `selectConversation` loading), and `ChatScreen` (`Episode Digest` badge/dialog, responsive `Compact Context` button, and 1-click chat bubble memory/knowledge bookmark menu).

### Added — M3 Batch E: Memory & Knowledge Architecture V2, 3-Tier Lifecycle, Keyword Lorebooks & Option 2A Desktop UI (`PC-MEM-001`..`005`, `PC-CLIENT-009`)

- **Alembic Migration 013 & Tier Model (`013_memory_knowledge_and_triggers.py`, `backend/app/models/memory.py`)**:
  - Added `trigger_keywords` (`Text` JSON list) and `recall_count` (`Integer`, default `0`, `ck_memories_recall_count`) to `memories`, preserving FTS5 virtual table triggers and enforcing fail-closed downgrade safety.
  - Added tier helpers (`knowledge`, `long_term`, `short_term`) while strictly keeping temporary `expires_at` precedence (`is_short_term`) over `is_core`.
- **Deterministic 72h TTL, Explicit Intent Boost, Protection & Consolidation (`extractor.py`, `reconciler.py`)**:
  - Assigned deterministic 72-hour expiration (`DEFAULT_SHORT_TERM_TTL_HOURS = 72`) for situational context lacking an LLM-provided `expires_at`; promoted explicit *"Remember that..."* turns immediately (`user_verified = True`, `importance >= 1.5`).
  - Shielded Fixed Knowledge (`is_core`, `manual`, or keyword lorebook entries) from automatic `UPDATE`/`MERGE` mutation during background extraction and added cross-session ($\ge 12$h) consolidation/promotion for recurring short-term episodes.
- **Stem/Prefix Lorebooks, FTS5 Prefix Search & Multi-Section XML Assembly (`retriever.py`, `orchestrator.py`)**:
  - Added `get_triggered_knowledge` with normalized phrase and ASCII stem/prefix matching ($\ge 3$ chars), isolated keyword-gated entries out of unconditional `<user_core_profile>`, switched FTS5 retrieval to prefix queries (`token*`), and tracked `recall_count` with bounded ranking boosts.
  - Partitioned `<retrieved_memories>` in `AssistantOrchestrator._build_context` into `<user_core_profile>` ($\le 120$), `<triggered_knowledge_lore>` ($\le 150$), `<episodic_and_long_term_memories>` ($\le 200$), and `<short_term_context>` ($\le 100$) within the tight 2B context budget.
- **API, OpenAPI/Dart Parity & Option 2A Desktop Memory Control Center (`memories.py`, `companion_api`, Desktop UI)**:
  - Extended `GET /api/v1/memories` with `?tier=` filtering, keyword search, and profile-wide tier counts (`knowledge_count`, `long_term_count`, `short_term_count`); regenerated `contracts/openapi/openapi.json` and updated `companion_api` DTOs & `CompanionClient.listMemories`.
  - Delivered Option 2A inner left tier sub-menu (`MemoryTierSidebar` with compact narrow fallback), context-aware `+ Add Knowledge` / `+ Add Memory` / `+ Add Context` dialog defaults, Trigger Keyword inputs & `#keyword` pills, `RECALLED N×` & TTL badges, and 1-click **Promote** on short-term cards.
  - Verified with `788/788` backend pytest tests, OpenAPI + `companion_api` Dart parity checks (`97/97` tests), `flutter analyze` (`0` issues) + `353/353` Flutter desktop tests, and `248/248` Web Vitest tests + production build.

### Added — M3 Batch D: Persistent Bounded Emotion & Mood Engine, Pre-Generation Turn Appraisal, Natural Companion Grounding, and Live Mood UI (PC-CHAR-003, PC-CHAR-004)

- **Alembic Migration 012 & Persistent Mood Schema (`PC-CHAR-003`)**:
  - Added `backend/migrations/versions/012_character_mood_and_emotion.py` adding `current_mood` (`String(32)`), `mood_intensity` (`Integer`), and `mood_updated_at` (`DateTime(timezone=True)`) to `character_instances` alongside SQLite CHECK constraint `ck_character_instances_mood_invariants`.
  - Preserved all 5 dependent SQLite triggers (`trg_character_instances_immutable_provenance`, `trg_profiles_active_character_owner_insert`, `trg_profiles_active_character_owner_update`, `trg_character_instances_deactivate_clear_profile`, `trg_conversations_character_owner_insert`) and partial index `uq_character_instances_profile_legacy_id` across `batch_alter_table`, with loss-aware fail-closed downgrade protection.
- **Persistent Bounded Mood Engine & Deterministic Step Rebalancing (`PC-CHAR-003`)**:
  - Implemented `backend/app/services/emotion/mood_engine.py` supporting 6 bounded moods (`calm`, `cheerful`, `playful`, `empathetic`, `thoughtful`, `curious`), trait-derived baseline mood resolution (`resolve_baseline_mood`), and deterministic integer step rebalancing (`compute_decayed_mood`: 5 intensity points per 30 minutes toward `50`, settling to baseline mood after $\ge 4$ hours at equilibrium).
- **Pre-Generation Turn Appraisal Engine (`PC-CHAR-004`)**:
  - Implemented `backend/app/services/emotion/appraisal.py` (`appraise_user_turn`) performing `<1ms` deterministic lexical/heuristic turn appraisal across `user_distress`, `user_playful`, `user_gratitude`, `user_analytical`, `user_curiosity`, and `neutral_turn` while strictly preserving Decision D11 Mood Isolation.
  - Wired `CharacterService.appraise_and_update_conversation_mood()` into `AssistantOrchestrator` prior to prompt assembly so companion mood responds in-turn to the user's message.
- **Natural Companion Grounding, DRY Sampling & Stream Circuit Breaker (`PC-CHAR-002`)**:
  - Updated `resolve_turn_persona_prompt()` in `backend/app/services/character_service.py` to inject compact `Current Mood` and `Conversational Grounding` directives inside `<character_persona>`, eliminating theatrical `*stage directions*`, scripted self-interruptions, and repetitive catchphrases within the 4,096-token context budget.
  - Added native DRY anti-repetition sampling parameters (`dry_multiplier: 0.8`, `dry_base: 1.75`, `dry_allowed_length: 2`, `dry_penalty_last_n: 128`) in `backend/app/services/llm/llama_cpp.py` and sliding-window 4-gram stream degeneracy circuit breaker `_guard_repetitive_stream()` in `backend/app/services/assistant/orchestrator.py`.
- **Desktop Live Mood Badges & Dart SDK Parity (`PC-CLIENT-006`, `PC-CLIENT-007`)**:
  - Regenerated `contracts/openapi/openapi.json` and extended `CharacterInstanceOut` in `companion_api` with `currentMood`, `moodIntensity`, `moodUpdatedAt`, `moodEmoji`, `moodLabel`, and `moodBadgeText`.
  - Rendered live Mood + Emoji Glyph badges in `ChatScreen` header (`chat-header-mood-badge`), `ChatScreen` welcome card (`chat-welcome-mood-badge`), and `StudioInspectorPanel` header (`studio-inspector-mood-badge`), with automatic post-turn refresh on `SseDoneEvent`.

### Added — M3: Desktop Memory Control Center UI, Migration 011 Per-Profile Extraction Toggle, and Conflict Resolution (PC-CLIENT-009)

- **Desktop Memory Control Center (`PC-CLIENT-009`)**:
  - Implemented `DesktopMemoryController` managing reactive memory state, active profile synchronization, real-time filtering, conflict resolution, memory CRUD, and per-profile auto-extraction toggling.
  - Implemented `MemoryScreen` replacing placeholder screen with full Memory Control Center: header with auto-extraction switch, contradiction alert banner, multi-faceted search & filter bar, and memory item cards.
  - Implemented `MemoryConflictBanner` alerting users to unresolved contradictory beliefs (`source_type="conflict"`, `user_verified=False`) with side-by-side diff comparison and 1-click resolution actions: *Keep New*, *Keep Old (Discard New)*, and *Edit & Merge*.
  - Implemented `MemoryFilterBar` supporting live text query (`q`), scope chips (`all`, `profile`, `character`), category chips (`all`, `fact`, `preference`, `context`), and status chips (`all`, `verified`, `pending`, `conflicts`).
  - Implemented `MemoryItemCard` displaying category badges, scope indicators, status badges (`VERIFIED`, `PENDING REVIEW`, `CONFLICT`), core fact star pin toggle, inline approval, edit modal trigger, and confirmation-gated deletion.
  - Implemented `MemoryEditDialog` for creating manual memories or editing content, category, scope, and core fact pin status.
  - Wired `MemoryController` into `DesktopShell` and removed `'M3'` planned badge from `DesktopNavDestination.memory`.
- **Per-Profile Auto-Extraction Toggle & Migration 011**:
  - Authored Alembic Migration `011_profile_memory_extraction_toggle.py` adding `profiles.memory_extraction_enabled` (Boolean, default `True`, `server_default="1"`, NOT NULL) with SQLite trigger cycle handling.
  - Updated `Profile` ORM model, `ProfileMetadata`, and `ProfileUpdateRequest` to expose and manage `memory_extraction_enabled`.
  - Turned default extraction setting to `MEMORY_EXTRACTION_ENABLED = True` in `config.py`, dynamically guarded by the active profile's `memory_extraction_enabled` state.
- **Memory API Query Filters & Approval Updates**:
  - Extended `GET /api/v1/memories` with query parameters: `q` (case-insensitive substring filter), `user_verified` (Boolean filter), and `source_type` (String filter).
  - Extended `PATCH /api/v1/memories/{memory_id}` with `user_verified` (which sets `last_verified_at = now()`) and `source_type`.
  - Injected `<memory_conflicts>` into `ChatOrchestrator` context assembly with companion-toned clarification instructions when unresolved conflicts exist.
- **Client Contract Parity**:
  - Updated `companion_api` Dart client and DTOs (`MemoryUpdate`, `ProfileMetadata`, `ProfileUpdateRequest`, and `CompanionClient.listMemories`) maintaining 100% contract parity with OpenAPI specification.


### Added — M3: Selective Automatic Memory Extraction & Deterministic Slot Reconciliation (PC-MEM-002)

- **Disclosure-Aware Skip Gate & Explicit Bypass (`PC-MEM-002`)**:
  - Implemented heuristic skip gate in `app.services.memory.extractor` that skips trivial conversational acknowledgments, standalone emojis, code blocks, and queries lacking self-disclosures.
  - Protected first-person disclosure markers (`I am`, `I'm`, `my`, `I have`, `I like`, `I love`, `I hate`, `I live`, `I work`, etc.), ensuring short personal disclosures (e.g. *"I'm vegetarian"*, *"I have celiac"*) are never skipped.
  - Implemented explicit intent filter matching commands (e.g., `^remember\b`, `^please remember\b`, `^don't forget\b`) that bypass heuristic filtering and set `confidence = 1.0`, `source_type = "user_explicit"`, and `user_verified = True`.
- **Structured Candidate Extraction & Model Readiness (`PC-MEM-002`)**:
  - Implemented `extract_memory_candidates` prompting the active LLM provider with a rigid JSON array schema with `content`, `category`, `scope`, `is_core`, `expires_at`, and `confidence`.
  - Added secret sanitization regex filters discarding candidate facts containing passwords, API keys, tokens, or credit cards.
  - Implemented model readiness pre-flight check (`provider.is_loaded()`) to avoid background model loading during standby.
- **Deterministic Slot Reconciliation Engine (`PC-MEM-002`)**:
  - Implemented `reconcile_candidate` in `app.services.memory.reconciler` applying 5 deterministic slot transitions:
    - `DUPLICATE`: Touches existing memory (`last_verified_at = now()`) without creating redundant database rows.
    - `NEW`: Inserts a new memory row with `source_type = "extracted"` and `user_verified = False` (or explicit intent flags).
    - `MERGE`: Enriches existing memory with additive details, setting `last_verified_at = now()`.
    - `UPDATE`: Updates existing memory when candidate indicates change or attribute supersession.
    - `CONFLICT`: Preserves existing memory intact and inserts candidate with `source_type = "conflict"` and `user_verified = False`, eliminating silent overwriting and preparing records for C3 UI resolution and conversational clarification.
  - Enforced scoping normalization coercing `scope = "character"` to `"profile"` if conversation has no active character instance, ensuring compliance with SQLite check constraint `ck_memories_character_scope`.
- **Zero-Latency Background Orchestration (`PC-MEM-002`)**:
  - Wired post-stream background extraction in `app.services.assistant.orchestrator` executing strictly after the assistant turn message is committed and `data: [DONE]\n\n` is delivered (0ms streaming overhead).
  - Isolated background database transactions using `get_session_factory()` with explicit `db.rollback()` on exception.
  - Added per-profile async lock serialization (`_profile_extraction_locks`) preventing local LLM GPU lease contention.
  - Configured dormant default `settings.MEMORY_EXTRACTION_ENABLED = False` until C3 UI ships.

### Added — M3: Memory Foundation, Scoping & Context Assembly (PC-MEM-001, PC-MEM-003, PC-MEM-005, PC-API-001)

- **Database Migration 010 & Scoping Columns (`PC-MEM-001`)**:
  - Added SQLite migration `010_memory_scoping_and_lifecycle.py` introducing `scope` (`profile` | `character`), `character_instance_id` (foreign key to `character_instances.id` with `RESTRICT` on delete), `valid_from` (`NOT NULL`, backfilled from `created_at`), `expires_at`, `last_verified_at`, and `is_core` (`NOT NULL DEFAULT 0`).
  - Enforced SQLite check constraints: `ck_memories_scope`, `ck_memories_character_scope` (character instance required for character scope and forbidden for profile scope), and `ck_memories_validity` (`expires_at IS NULL OR expires_at >= valid_from`).
  - Cycled SQLite triggers (`memories_fts_insert`, `memories_fts_update`, `memories_fts_delete`) and rebuilt FTS5 virtual table cleanly during batch table migration.
- **Scoped Retrieval & Temporal Exclusion (`PC-MEM-003`, `PC-MEM-005`)**:
  - Implemented character-scoped retrieval in `app.services.memory.retriever`: Profile memories are shared globally; character-specific memories are isolated to active conversation character instances; foreign character memories are excluded; Neutral Assistant conversations retrieve only profile memories.
  - Implemented query-time temporal exclusion with bound UTC parameter `:now` (`or_(Memory.expires_at.is_(None), Memory.expires_at > :now)`).
  - Implemented core-fact context assembly in `get_core_memories`: retrieves up to 5 non-temporary, profile-scoped permanent facts (`is_core = True` or `importance >= 1.5`, `expires_at IS NULL`), injected into orchestrator context assembly under dedicated 100-token budget and deduplicated against search hits.
- **REST API Endpoints & Purge Order (`PC-API-001`)**:
  - Added dedicated single-item fetch `GET /api/v1/memories/{memory_id}` with profile session ownership enforcement.
  - Added query filtering parameters to `GET /api/v1/memories`: `scope`, `character_instance_id`, `is_core`, and `include_expired`.
  - Added foreign character instance validation on `POST /api/v1/memories` and `PATCH /api/v1/memories/{id}`.
  - Enabled clearing expiration date on `PATCH /api/v1/memories/{id}` via `exclude_unset=True`.
  - Hardened `ProfilePurgeService` to delete `Memory` before `CharacterInstance` satisfying `RESTRICT` foreign key integrity, and included soft-deleted memories in 30-day retention purge.
- **OpenAPI Contract & Dart Client Parity (`companion_api`)**:
  - Added `MemoryCreate`, `MemoryUpdate`, `MemoryOut`, and `MemoryListOut` schemas in OpenAPI and Dart DTOs in `dto/memory_dto.dart`.
  - Implemented client CRUD methods `listMemories`, `getMemory`, `createMemory`, `updateMemory`, and `deleteMemory` in `CompanionClient`.
  - Updated parity scripts with 42 verified routes passing fail-closed static checks and unit tests.

### Added — M2: Recoverable Profile Deletion & Safe Purge Maintenance (PC-IDENTITY-005, PC-CLIENT-005)

- **Backend Recoverable Profile Deletion & Safe Purge (`PC-IDENTITY-005`)**:
  - Implemented loopback-only Host Admin endpoints: `DELETE /api/v1/profiles/{profile_id}` (soft-delete with 30-day recovery window), `GET /api/v1/profiles/deleted` (list recoverable deleted profiles), `POST /api/v1/profiles/{profile_id}/restore` (restore within window preserving prior child content deletions), `POST /api/v1/profiles/{profile_id}/purge` (immediate 5-phase physical-first purge), and `POST /api/v1/system/maintenance/purge-profiles` (manual maintenance sweep).
  - Enforced 5-phase permanent purge order: storage path pre-validation, atomic transition to `purging` status, physical file unlinking with per-file containment re-validation & crash-orphaned `.tmp_*` cleanup, transactional relational record deletion in strict foreign key order with SQLite FTS5 index synchronization, and profile metadata record deletion.
  - Implemented automatic purge sweeps at FastAPI application startup and hourly periodic background task (`asyncio.Task`) with clean shutdown cancellation.
  - Protected default profile and active sessions from deletion with fail-closed errors (`400 Bad Request`).
- **OpenAPI Contract & Dart Client Parity (`companion_api`)**:
  - Updated `ProfileMetadata` with `is_deleted`, `deleted_at`, and `purge_after` timestamp fields.
  - Added `PurgeMaintenanceResult` schema and DTO.
  - Implemented client methods `deleteProfile`, `listDeletedProfiles`, `restoreProfile`, `purgeProfile`, and `runPurgeMaintenance` with automated parity checks.
- **Flutter Desktop UI & Dialogs (`PC-CLIENT-005`)**:
  - Added "Delete Profile" and "Delete Selected" buttons with typed profile name confirmation dialog explaining the 30-day holding state.
  - Added "Recently Deleted" section with recovery countdown badge (`X days remaining`), "Restore", and "Permanently Delete" with typed name confirmation dialog.
  - Integrated controller state handling: session revocation, switching fallback to default profile, and catalog refresh.

### Added — M2: Local Profile Administration & Persistent Selection (PC-IDENTITY-004, PC-CLIENT-005)

- **Backend Local Profile Creation & Renaming (`PC-IDENTITY-004`)**:
  - Implemented loopback-only `POST /api/v1/profiles` (201 Created) and `PATCH /api/v1/profiles/{profile_id}` (200 OK) requiring Host Admin authority.
  - Enforced strict name validation: whitespace trimming, 1..32 character length, control character rejection, and case-insensitive uniqueness check (`409 Conflict`).
  - Guaranteed in-place renaming without UUID migration or session loss, preserving all owned conversations, messages, memories, tasks, and instances.
  - Maintained fail-closed rejection (`403 Profile unlock challenge is not available`) on any pre-existing PIN-protected Profiles while deferring PIN creation.
  - Implemented deterministic catalog ordering: `Profile.is_default.desc(), Profile.created_at.asc(), Profile.id.asc()`.
- **OpenAPI & Dart Client Parity**:
  - Added `ProfileMetadata`, `ProfileCreateRequest`, and `ProfileUpdateRequest` DTOs with `ConfigDict(extra="forbid")` parity.
  - Added `createProfile`, `renameProfile`, and acquire-before-teardown session exchange methods to `CompanionClient`.
- **Desktop Persistent Profile Selection & Acquire-Before-Teardown Switching (`PC-CLIENT-005`)**:
  - Implemented non-secret persistence in `%LOCALAPPDATA%\AI Companion\client_settings.json` (`selectedProfileId`, `selectedProfileSessionExpiry`, `profileExplicitlyLocked`).
  - Implemented acquire-before-teardown switching order (`ticket -> exchange -> revoke`) ensuring the active Profile remains intact if destination authorization fails.
  - Added explicit "Sign out" support revoking active credentials, setting `profileExplicitlyLocked = true`, and stopping automatic startup restoration.
  - Implemented `ProfileSelectorHeader` quick-switch popup in Desktop Navigation Rail, Create & Rename Profile dialogs, and `ProfileAccessCard` in Settings.

### Added — M2: Secure Host Lifecycle & Bounded Model-Loading Reliability (PC-HOST-005)

- **Track A — Authenticated Host Administration & Graceful Runtime Shutdown**:
  - Implemented loopback-only `POST /api/v1/system/shutdown` protected by `require_host_admin` and host secret verification, returning synchronous accepted status with shutdown correlation ID.
  - Implemented programmatic Uvicorn entrypoint in `backend/app/runtime_server.py` registering `uvicorn.Server` instance with `RuntimeLifecycleCoordinator`.
  - Implemented ASGI admission control returning `503 RUNTIME_SHUTTING_DOWN` immediately upon shutdown initiation while draining in-flight requests.
  - Enforced real database quiescence barrier awaiting `_pending_persistence_tasks` before engine disposal (`app.db.session.close_db()`).
  - Enforced strict provider lock ownership in `LlamaCppProvider` during inference drain and router shutdown (`_stop_managed_router_locked()`), preserving externally owned router processes and reporting truthful lock-timeout outcomes without concurrent unlocked mutations.
  - Implemented handle-bound Windows OS termination fallback in `WindowsRuntimeProcessSupervisor` using Win32 Job Object and entrypoint provenance verification to prevent PID reuse hazards.
  - Integrated cooperative 25-second shutdown window and 4 distinct outcome handlers (`CLEAN_SHUTDOWN`, `INCOMPLETE_CLEANUP_FALLBACK_TERMINATED`, `RECOVERY_FAILED_PID_UNKNOWN`, `SHUTDOWN_TIMEOUT_FORCE_TERMINATED`) in `DesktopRuntimeCoordinator`.
  - Added desktop tray and settings "Exit Companion" confirmation dialogs and incomplete-cleanup failure recovery dialogs with remote-host protection (`isRemoteHost == true`).
- **Track B — Bounded Model-Loading Reliability & Truthful Status Sync**:
  - Implemented bounded `90s` operation timeout on model load operations in `CompanionClient` and `DesktopChatController`.
  - Implemented lock-free snapshot `get_status()` in `LlamaCppProvider` during loading and transitional states, preventing client polling deadlocks.
  - Standardized canonical model ID normalization across backend endpoints and Flutter client.
  - Implemented 4-state truthful status reconciliation (`CONFIRMED_READY`, `CONFIRMED_FAILED`, `STILL_LOADING`, `STATUS_UNKNOWN_TIMED_OUT`) with manual "Refresh Model Status" recovery.

### Changed — Autonomous Delivery Workflow Reform (S1 Governance Revision)

- Replaced the mandatory ten-stage engineering delivery lifecycle with four cohesive phases (**Phase 1: Plan and Authorization**, **Phase 2: Autonomous Implementation and Verification**, **Phase 3: Documentation, Closure, and Draft PR**, and **Phase 4: Combined Independent Review and Human Merge**) in [`AGENTS.md`](AGENTS.md) and [`docs/06_Guides/DELIVERY_WORKFLOW.md`](docs/06_Guides/DELIVERY_WORKFLOW.md).
- Adopted agent-neutral governance terminology replacing AI vendor hardcoding with four distinct operational roles: Human Owner, Implementing Agent, Independent Reviewer, and CI System.
- Established a four-tier Risk-Based Supervision Matrix (**Level A — Routine Autonomous**, **Level B — Planned Autonomous**, **Level C — Sensitive Design**, and **Level D — Human-Controlled Operations**) targeting 1 human review for routine deliveries and 2 human reviews for substantial deliverables.
- Enforced scope-based, agent-agnostic Git mutation permissions granted by the Human Owner for the dedicated feature branch, preserving exclusive human authority over repository merges, protected branches, and destructive operations.
- Eliminated intermediate implementation review stops between implementation and documentation for ordinary authorized deliveries, enabling autonomous continuation from approved plan to complete review package.
- Aligned [`docs/02_Planning/02_Templates/implementation-plan-template.md`](docs/02_Planning/02_Templates/implementation-plan-template.md) with Phase 1 plan requirements and genuine stop conditions.

### Added — M3: Character Studio & Personality Prompt Modulator (Batch B)

- **8-Continuous-Trait Personality Prompt Modulator (`PC-CHAR-002`)**:
  - Implemented `compile_personality_modulation_block()` in `backend/app/services/character_service.py` mapping 8 continuous personality traits (0–100) across 5 calibrated behavioral bands (Very Low 0–19, Low 20–39, Balanced 40–59, High 60–79, Very High 80–100) into deterministic prompt instructions.
  - Always emits four paired directive lines covering all eight traits (Tone, Expression, Delivery, Register), including balanced trait-band clauses.
  - Implemented four prioritized interaction dynamics: Guarded Banter / Tsundere, Shy Devotion / Dandere, Stoic Care / Kuudere, and Analytical Precision.
  - Enforced mandatory Autonomy Guard whenever `affection >= 80` or preset is `yandere` ("- Autonomy Guard: Express devotion supportively; never use coercion, possessiveness, exclusivity, manipulation, or dependency claims.").
  - Enforced strict $\le 700$ characters length invariant (`MODULATION_BLOCK_MAX_CHARS = 700`), with mathematically conservative candidate maximum $\le 695$ characters confirmed by sampled test combinations.
  - Added pre-escaping bounding for user persona fields (`system_prompt` $\le 1,200$ chars, `lore` $\le 1,600$ chars) on word boundaries before XML-delimiter escaping inside lower-trust `<character_persona>` turn block.
- **Immersive Character Studio V1 (`PC-CLIENT-007`)**:
  - Built full-window immersive Character Studio in Flutter Desktop (`screens/studio_screen.dart`) replacing static forms with a character customization experience.
  - Added centered Character Showcase Stage (`character_showcase_stage.dart`) with transparent 2D character PNG portraits, on-screen zoom toolbar ($1.0\times..2.0\times$), pan/drag inspection, and procedural avatar fallback.
  - Implemented atmospheric Studio Backdrop Layer (`studio_backdrop_layer.dart`) supporting 4 environments (`Cozy Studio`, `Cyber Lounge`, `Twilight Balcony`, `Minimalist Vault`) with procedural gradient fallback.
  - Added translucent side dock panels: Left Library Panel with category browsing of Starter Templates, System Fallback, and My Characters; Right Inspector Panel with 8 trait sliders, per-trait reset, preset chips, dynamic "Custom" preset chip, backdrop selector, and persona fields.
  - Implemented sequential "Save & Activate" workflow in `DesktopStudioController`: saves draft via `PATCH /api/v1/characters/instances/{id}`, reconciles snapshot response, and sequentially activates the character via `PUT /api/v1/characters/active`.
  - Added single-flight mutation tokens, session fencing across profile switches, dirty draft tracking, unsaved changes discard confirmation dialogs, and snapshot-aware uncertain write reconciliation.
  - Established documented 3D renderer boundary abstraction in `character_stage_presenter.dart` isolating 2D sprite rendering from future 3D/glTF mesh renderers.
- **Desktop Chat Character Visibility & Turn Binding**:
  - Implemented dual-indicator chat header pills (`This Conversation: [Name]` and `New Conversations: [Name]`) and history drawer character badges.
  - Corrected empty conversation reuse: an untouched empty conversation is reusable only when its existing Character binding matches the intended Character; if the Character differs, the client creates a new conversation with the intended binding, preserving existing threads without silent rebinding.
  - Resolved character names truthfully from instance cache and neutral fallback.
- **Verification & Acceptance**:
  - Author-reported local automated tests passing: 641 backend pytest (including 17 tests in `test_character_personality_modulator.py`), 278 Flutter desktop tests, 248 React web tests across 16 test files, 0 Dart analyze warnings, and 0 Git diff whitespace errors.
  - Independent Implementation Gate review approved at commit `fd0c558`.
  - Human Windows Desktop manual acceptance confirmed across 14 checkpoints by Chris (Test 10 confirmed after acceptance correction).
  - Hosted PR CI Run 41638166724 passed 100% across all 7 jobs at PR candidate checkpoint `d50edd4`.
  - Stage 7 Combined Independent Documentation/Closure/PR Review approved; Stage 8 final pre-merge closure reconciliation completed on branch; PR #30 ready for human squash merge; post-merge integration CI and wider M2/M3 capabilities remain planned. Execution evidence is tracked in [archived branch task](docs/01_Tracking/archive/task-feature-m3-character-studio-personality-b.md).

### Fixed — Windows acceptance inspection budget

- Gave real-process launch and stale-lock recovery acceptance fixtures a bounded 15-second CIM inspection budget for shared runners. Production deadlines, provenance validation and dedicated timeout regressions remain unchanged.

### Fixed — Python 3.11 stream cancellation

- Preserved consumer cancellation when a provider token completes concurrently by using cancellation-safe token polling. Retained periodic Profile authority validation and cleanup; added deterministic consumer, blocked-provider and token-ready cancellation regressions.

### Fixed — PR #27 CI scheduling

- Serialized Desktop test files in CI so real Windows runtime acceptance checks do not compete with other test files; retained all tests, production deadlines and fail-closed process checks.

### Fixed — Windows Desktop Host Admin authority validation

- Replaced PowerShell `Get-Acl` module loading in `HostAdminSecretStore` with direct .NET CLR access control (`[System.IO.Directory]::GetAccessControl`, `[System.IO.File]::GetAccessControl`), resolving PowerShell 5.1 module-loading collisions in environments where modern PowerShell editions reside in `PSModulePath`. Preserved fixed-path constraints, reparse point rejection, and owner/SYSTEM SID checks; confirmed manual Windows Desktop Profile access acceptance.

### Implemented & Verified (2026-11-02 - M3: Character Foundation — Batch A)

- Added Alembic migration 009 with application-owned `character_templates`, profile-owned `character_instances`, column additions `profiles.active_character_instance_id` and `conversations.character_instance_id`, 8 SQLite triggers, and pre-migration SQLite WAL backup hook with dynamic head discovery.
- Seeded initial application-owned templates: `neutral-assistant` (immutable fallback with NULL traits), `warm-companion`, `playful-companion`, and `formal-advisor`.
- Implemented immutable Neutral Assistant fallback (`is_neutral_fallback = True`, NULL traits via SQLite CHECK constraints) accessible via `GET /api/v1/characters/neutral` and activatable via `PUT /api/v1/characters/active` (`character_id = "default"` or `"neutral-assistant"`) or `POST /api/v1/characters/active/reset-neutral`.
- Added personality preset catalog with 8 continuous dimensions (`warmth`, `teasing`, `guardedness`, `directness`, `expressiveness`, `affection`, `formality`, `verbosity` as 0–100 integers) and 8 approved presets (`custom`, `warm_companion`, `playful`, `formal_advisor`, `tsundere`, `kuudere`, `dandere`, `yandere`); enforced precedence where non-custom preset initializes traits from preset baseline, custom/omitted initializes from template baseline, and explicit traits override baseline values (requires complete 8-dimensional `CharacterTraitVector`; partial vectors rejected by schema).
- Preserved historical conversation identity and legacy `character_id` values via deterministic UUIDv5 legacy placeholder mapping (`canonical = f"{len(profile_id)}:{profile_id}|{len(legacy_character_id)}:{legacy_character_id}"`); added `include_legacy` query filter to `GET /api/v1/characters/instances` (default false); guarded against modification and deletion via API/service-layer validation, SQLite CHECK constraints limiting valid placeholder structure, trigger `trg_character_instances_immutable_provenance` protecting provenance columns, and `conversations.character_instance_id` foreign key RESTRICT constraints.
- Enforced ordered relational purge invariants: `CharacterInstance.profile_id` uses `ON DELETE CASCADE`, while `conversations.character_instance_id` uses `ON DELETE RESTRICT`, requiring conversation cleanup prior to deleting character instances.
- Implemented runtime turn persona resolution framing user character instructions inside a lower-trust, XML-escaped persona block with structural defense-in-depth.
- Enforced loss-aware fail-closed migration downgrade verifying substantive fields of seeded templates against `SEED_TEMPLATES` (excluding incidental timestamps) and refusing downgrade on modification, active selections, or user instances, preserving all user data intact.
- Implemented 11 character REST endpoints with profile isolation; synchronized OpenAPI 3.1 contract; added Dart DTOs and `CompanionClient` character methods with verified route and schema parity; updated React Web conversation creation for optional character ID.
- Batch A is implemented, locally verified, confirmed on Windows, and independently review-approved with minor documentation conditions; hosted CI Run #114 (and historical Run #113) passed 100%; same-branch closure records archived. Draft PR #29 updated for final verification; post-merge CI and wider M3 capabilities (Character Studio UI, dynamic personality, mood, relationship, voice) remain future work. Execution evidence is tracked in [archived branch task](docs/01_Tracking/archive/task-feature-m3-character-foundation-a.md).

### Implemented & Locally Verified (2026-10-15 - M2: Profile Sessions & Cross-Profile Isolation — Batch B)

- Added migration 008 with Profile Sessions and single-use authorization grants; removed implicit Profile ownership defaults while preserving existing data, foreign keys and FTS5 behavior.
- Separated pairing diagnostics, independent Windows Host Admin authority and Profile Session personal-data access. Added explicit Desktop approval and browser proof-of-possession exchange without bearer credentials in URLs or browser storage.
- Enforced Profile isolation across conversations, messages, tasks, memories, attachments and ongoing streams; retained trusted maintenance authority for retention and fail-closed migration recovery.
- Added Flutter existing-Profile selection, DPAPI session storage, saved-Profile restoration and server-deadline expiry cleanup. `/auth/session/me` preserves Profile metadata and returns validated `expires_at` without renewing the session. Explicit switching revokes prior authority and clears private caches/subscriptions. React uses in-memory sessions; API contracts and client regressions were updated.
- Reconciled canonical architecture and delivery tracking. Batch B is implemented and locally verified; final independent Implementation, Documentation and Closure review is pending. Hosted PR CI has not run and Windows/Desktop/browser manual acceptance is pending. Full Profile CRUD, PIN enrollment, device enrollment and Character Studio remain future work; wider M2 remains **IN PROGRESS**. Exact local results and prepared PR handoff are recorded in the [branch task](docs/01_Tracking/active/task-feature-m2-profile-foundation-b.md).

### Added & Verified (2026-10-13 - M2: Profile Schema Foundation & Pre-Migration WAL Backup — Batch A)

- **Profile Schema Foundation (`PC-IDENTITY-001`)**:
  - Implemented Alembic migration 007 (`migrations/versions/007_profiles_and_owner_id_migration.py`) introducing the `profiles` table with unique, installation-specific Default Profile UUID and partial unique index (`uq_profiles_single_default`).
  - Added indexed `profile_id` foreign keys referencing `profiles.id` across `conversations`, `messages`, `tasks`, `memories`, and `attachments`.
  - Retained existing `owner_id` columns and indices across all five entity tables to preserve seamless backward compatibility for existing runtime operations and models.
  - Implemented dynamic context-sensitive default resolution (`resolve_default_profile_id`) in `ProfileMixin` and lifecycle hooks in the `Profile` model, ensuring newly created records receive a valid, consistent Default Profile association.
  - Implemented strict legacy owner validation (`app/db/legacy_owner_validation.py`) accepting only approved single-user aliases (`local_user`, `default_user`) and strictly failing closed on unexpected, empty, whitespace-only, case-variant, or NULL owner values prior to executing table rebuilding DDL.
  - Profile Sessions, multi-profile authorization, profile CRUD/switching APIs, and PIN security remain not implemented (deferred to Batch B and subsequent identity tasks).
- **Pre-Migration Safety Snapshot & Backup Resilience (`PC-RESILIENCE-002`)**:
  - Integrated automatic pre-migration SQLite WAL backup hook into startup (`prepare_database_schema()`) prior to applying schema migrations to existing databases.
  - Implemented collision-proof backup filenames using UTC microsecond timestamps and random UUID suffixes (`pre_<label>_<timestamp>_<suffix>.db`) in `app/db/backup.py`.
  - Staged backups to temporary files (`.<name>.partial`), verified with SQLite `PRAGMA integrity_check`, and published via hardlinks without overwriting existing verified snapshots.
  - Enforced fail-closed startup preflight checks inspecting existing databases: zero-byte files, invalid SQLite headers, or corrupt databases safely abort startup before any backup or migration attempt.
  - Implemented standalone verified restore utility (`restore_database_from_backup`) featuring quiescence probing (`BEGIN EXCLUSIVE`), pre-restore safety snapshotting, SQLite backup API restoration (preserving WAL/SHM sidecars), and automatic rollback on verification failure (live/automatic recovery remains deferred pending host-level writer quiescence controls across the complete restore operation).

### Added & Verified (2026-10-12 - M2-H1: Windows Runtime Process Supervision & Desktop Chat Quality)

- **Windows Runtime Supervision (`PC-HOST-001`)**:
  - Implemented decoupled, windowless runtime launch and supervision for the Local AI Runtime on Windows using `pythonw.exe` and `subprocess.CREATE_NO_WINDOW` for `llama-server.exe` child inference processes without popup console windows.
  - Added atomic kernel file-locking via `%LOCALAPPDATA%\AI Companion\runtime.lock` with `FileMode.append` and `RandomAccessFile.lock(FileLock.exclusive)`, writing strictly through the locked handle to eliminate truncation races.
  - Implemented double-checked locking under guard, authenticated identification (`POST /api/v1/auth/verify` with DPAPI pairing token) decoupled from public `GET /api/v1/health` reachability, and orthogonal supervision state modeling (`localLoopback` vs `remoteHost`).
  - Added safe stale-lock recovery, alien port conflict detection failing closed without process killing, and rotating file logging via `COMPANION_LOG_FILE` with secret redaction.
  - Integrated system tray menu ("Hide Window to Tray", developer-only "Quit UI Only", and disabled "Exit Companion (Full Shutdown - Planned PC-HOST-005)") and Settings supervision diagnostics.
  - Delivered external PowerShell acceptance test harness (`scripts/verify_windows_runtime_supervision.ps1`) executing all 6 core lifecycle scenarios against isolated test roots and ports.
- **Desktop Chat Quality Follow-Up (`PC-CLIENT-006` / `PC-CLIENT-010`)**:
  - **Generation Completion & Limits:** Preserved upstream `finish_reason` end-to-end (`llama.cpp` -> per-request `GenerationStream` metadata -> orchestrator SSE `done` event -> Flutter client); prevented concurrency races across simultaneous turns; bounded token headroom against remaining context capacity; displayed clear "Response reached generation limit" indicator in chat with actionable continuation turn.
  - **Wide Tables:** Added visible horizontal scrollbar (`thumbVisibility: true`), touch/mouse/trackpad drag gesture configuration, and constrained text cell wrapping (80..360 px) in `_MarkdownTableWidget`.
  - **Mathematical Typesetting:** Integrated textbook LaTeX rendering via `flutter_math_fork` for display `\[ ... \]` and inline `\( ... \)` formulas with raw source copying, keeping literal fenced code blocks (` ```latex `) unconverted.
  - **Conversation Text Zoom:** Implemented scoped text zoom (80%–160%) via `Ctrl+Wheel` and `Ctrl+=/- /0` applied strictly to the conversation viewport, persisted across restarts in `%LOCALAPPDATA%\AI Companion\client_settings.json` under key `chatZoomLevel` with `COMPANION_CLIENT_SETTINGS_FILE` override support.
  - **Truthful Model Unload:** Added authenticated `POST /api/v1/models/unload` returning HTTP 409 when generating and HTTP 500 on failure; verified `model_loaded == false` before announcing success in Flutter Settings; preserved saved model selection.

### Added (2026-10-07 - MOBILE-ARCH: Mobile V1 Batch D Reconciliation & Canonical Promotion)

- **Mobile Batch D Canonical Promotion**: Promoted 104 approved product and architecture decisions across core baseline, conversation branching, memory overlays, local tool gateway, composable voice, conditional Health Connect, multimodal vision, and mobile companion UX.
- **Mobile Design & UX Baseline**: Authored `docs/05_Design/08_Mobile_Companion_Shell_and_UX.md` defining portrait-first shell navigation, hybrid SoftGlass / solid surface theme, companion check-in surfaces, and interaction language decoupling.
- **Golden Verification & CI Architecture**: Rebuilt `MOBILE_CHECKLIST.md` to exact locked MG1–MG18 structure with granular qualification classes; canonicalized tiered L1–L5 verification and future path-scoped CI direction in `mobile-capabilities-and-runtime.md`.
- **Master Planning & WBS Expansion**: Expanded `MOBILE_WBS.md` to 84 items across 16 streams with verified DAG integrity; updated master planning spine (`MASTER_CHECKLIST.md`, `DECISION_REGISTER.md`, `DECISION_DEBT.md`, `SPRINT_ROADMAP.md`, `DELIVERY_INDEX.md`, `DOCUMENTATION_MAP.md`); authored delivery walkthrough.

### Changed (2026-10-07 - MOBILE-ARCH: Batch D5.2 Closure Reconciliation Corrections)

- **Planning & Verification Alignment**: Reconciled AlarmManager exact alarm lifecycle permissions and degraded state handling, removed OOM zero-crash guarantees, established cross-host shared context budgeting assertions, refined composable voice degradation, aligned D9 confirmation vs execution evidence, and reconciled decision register entries to approved ledger source truth.
- **Reconciliation & Historical Supersession**: Reconciled planning and design specifications supersede earlier interim summary details recorded during initial promotion:
  - Current reconciled Mobile WBS comprises 88 items across 16 streams, not the earlier interim 84-item snapshot;
  - Current Mobile visual language is a hybrid aesthetic consisting of a Minimalist foundation + selective Neumorphism + contextual Glass / Liquid Glass, not a SoftGlass/Solid-only design;
  - Local Vision understanding is Conditional Mobile V1 on qualified hardware (`D-PHONE-16..16E`), with Host, authorized Cloud, and unavailable fallback routes;
  - The earlier Added entry remains preserved unchanged as historical point-in-time changelog evidence.

### Added (2026-10-04 - MOBILE-ARCH: Mobile V1 Canonical Architecture & Planning Pass)

- **Mobile Canonical Baseline & Decision Ledger**: Established `MOBILE_SYSTEM_BASELINE.md` defining the Satellite Device boundary, single-Profile binding (`ADR-0018`), and the Approved Mobile Decision Ledger covering 19 decision domains (§7).
- **Offline & Synchronization Architecture**: Established `mobile-offline-and-sync.md` defining local relational SQLite persistence, durable transactional outbox journal, per-domain synchronization protocols, deterministic conflict handling (no client last-write-wins), monotonic change cursors, tombstones, and revocation quarantine/erasure.
- **Runtime Capabilities & Native Reliability**: Established `mobile-capabilities-and-runtime.md` defining evidence-based hardware qualification (Tiers 0–3), single-model residency cap (`--models-max 1`), decoupled local/cloud inference, independent local TTS/STT, low-latency WebSocket audio streaming, Android foreground services, lifecycle management, and Keystore secret storage policy.
- **Health & Biometrics Boundary**: Established `health-and-wearables.md`, sequestering real Health Connect integration and biometric sync to Mobile Later (Post-V1).
- **Mobile Execution Planning & Readiness Checklist**: Created `MOBILE_WBS.md` with 65 canonical work items across 11 streams, `MOBILE_CHECKLIST.md` establishing Mobile readiness audit mapped to MG1–MG12, and synchronized master planning spine. Mobile architecture prerequisite for M1 satisfied without delivering production Mobile implementation.

### Added (2026-10-03 - PC-VERIFY-001: Classifier-Driven Scoped CI Matrix)

- **Scoped CI Policy**: Implemented classifier-driven workflow replacing automatic heavy CI on ordinary short-lived branch pushes.
- **Conditional Verification Lanes**: Added dedicated, conditionally executed `backend`, `frontend`, `contract`, and `docs-integrity` lanes.
- **Aggregate Gatekeeper**: Introduced fail-closed `ci-gate` for downstream dependency evaluation.
- **Release Verification Overrides**: Configured Full Verification forced overrides for `master` pushes/PRs and manual `workflow_dispatch`.
- **Deterministic Testing**: Added repository-owned `scripts/ci_policy.py` with deterministic Python policy tests.

### Added & Verified (2026-09-25 - Phase 8B: Multimodal Image Attachment Foundation - Slices 8B.0–8B.6)

- Multimodal Attachment Architecture: Established end-to-end image attachment pipeline across persistence, validation, API security, transactional binding, vision provider translation, and React Web composer UI.
- Persistence & Security Foundation: Added Alembic migration `006_add_attachments` with UUID primary key, timestamp, owner, and soft-delete mixins; implemented Pillow fail-fast image validation (10 MiB limit, PNG/JPEG magic bytes, 8192 px max dimension, 32 MP cap, decompression bomb guard); configured route-specific 12 MiB upload ceiling preserving 2 MiB global API envelope; enforced BOLA and path traversal isolation inside `ATTACHMENT_DIR`.
- Pre-Stream Transactional Binding: Introduced atomic pre-stream turn preparation transaction (`prepare_turn`) claiming staged attachments via conditional update before SSE streaming begins, ensuring clean HTTP 400/403/404/422 rejections and complete rollback without orphaned records or leaked locks on claim failures.
- Vision Provider Integration: Gated vision inference on active model `available_capabilities` (requiring companion `mmproj` projector); implemented sandboxed `media_resolver` handling asynchronous disk IO; translated pre-loaded image bytes into OpenAI-compatible `image_url` data URIs in `llama.cpp` provider while keeping public LLM API contracts string-only.
- Web Composer UI & Lifecycle: Built capability-gated paperclip button, client-side format/size validation, authenticated Blob preview rendering (`createObjectURL`), staged attachment removal with remote DELETE, fail-closed `outcome_unknown` handling on pre-acceptance network drops, conversation transition locking, and component unmount object URL revocation. Automated verification: 321 backend pytest tests passed, 185 frontend vitest tests across 9 files passed, 0 TypeScript compile errors, clean Vite production build, and 0 drift across 22 OpenAPI routes.

### Verified & Benchmarked (2026-09-14 - Phase 7: Full PC Integration Verification & Benchmarking)

- Cold-Boot & Database Integrity: Verified cold-boot baseline (0 llama processes, ports 8000/8085/3000 free, branch `feature/assistant-orchestration-and-memory`, migration head `005_scope_message_constraints`). Confirmed composite unique constraints `uq_messages_conversation_sequence` and `uq_messages_conversation_client_message_id`, verified removal of global uniqueness on `client_message_id`, soft-delete columns intact, and demonstrated expected downgrade limitation.
- Topology & Process Management: Verified exact 1 root router :8085 + 1 model worker process topology under FastAPI/Python. Launch configurations verified: Balanced (`--ctx-size 4096 --n-gpu-layers 28 --threads 6`, GPU mmproj, port 8085) and Eco (`--ctx-size 2048 --n-gpu-layers 0 --threads 4 --no-mmproj-offload`).
- Measured Resource Benchmarks: 
  - 2B Balanced: Load 5.72s, baseline VRAM 1128.80 MB, loaded VRAM 3829.71 MB (+2700.91 MB delta), router RAM 41.90 MB, worker RAM 1447.76 MB, TTFT 0.962s, gen speed 32.22 tok/s.
  - 2B Eco: Load 4.68s, baseline VRAM 1136.85 MB, loaded VRAM 1228.29 MB (+91.43 MB delta), router RAM 41.86 MB, worker RAM 2189.92 MB, TTFT 1.107s, gen speed 23.80 tok/s, verified CPU vision projector.
  - 4B Balanced Smoke: Load 15.47s, baseline VRAM 1176.80 MB, loaded VRAM 4734.11 MB (+3557.31 MB delta), router RAM 41.86 MB, worker RAM 2968.51 MB, TTFT 1.115s, gen speed 16.26 tok/s, clean unload freed 3551.41 MB in 1.59s.
- Assistant Lifecycle, Streaming & Recovery: Verified SSE chunk streaming with explicit terminal done, SQLite deterministic sequence numbering [1, 2, 3, 4], conversation rehydration, mid-stream cancellation with partial text preservation and immediate lock release (`generation_active=False`), and error recovery.
- Native Sleep & Wake: Model transitioned to `MODEL_SLEEPING` on idle threshold releasing 2661.21 MB VRAM (down to 1160.20 MB) while worker RAM dropped from 1447.45 MB to 301.64 MB; request woke model in 4.11s (3.601s wake latency) restoring `MODEL_READY` without process duplication.
- State Persistence & Clean Shutdown: Confirmed conversation history and model rehydration across Web UI and Core restarts. Clean shutdown verified 0 lingering processes, 0 open port listeners, and intact database tables (42 messages, 9 conversations). Automated test suites: 88 backend pytest tests, 38 frontend vitest tests, 0 tsc errors, and Vite production build passed.

### Fixed & Enhanced (2026-09-13 - Pass 10: llama.cpp Router Model Discovery, Port 8085 Migration & Status Synchronization)

- Router Discovery & Directory Depth: Pointed `llama-server` `--models-dir` directly to `models/vision` (`LLAMA_MODELS_DIR` in `backend/app/core/config.py`), enabling b10936 to automatically discover all 5 Qwen3-VL models and pair them with their `mmproj` companion projector artifacts.
- Non-Conflicting Port Migration: Migrated `LLAMA_ROUTER_PORT` from `8080` to `8085` (`LLAMA_SERVER_URL = "http://127.0.0.1:8085/v1"`), permanently resolving port collisions with external web development projects.
- Router Model ID Resolution: Added `runtime_model_id` to `ModelRegistryEntry` and `resolve_runtime_model_id()` helper, routing requests via model identifiers (`qwen3-vl-4b-instruct`) rather than raw filesystem paths. Included `"model"` parameter in `/v1/chat/completions` request payloads.
- Provider Auto-Detection & Cold Boot Truthfulness: Replaced top-level `glob("*.gguf")` with recursive `rglob("*.gguf")` in `manager.py` (excluding `mmproj*` and `lfs-test*`) to properly engage `LlamaCppProvider` when weights reside in subfolders. Initialized `MockLLMProvider` with `_is_loaded = False` and `_active_model = None` on cold boot.
- Live Router Residency & UI Synchronization: Refactored `LlamaCppProvider.get_status()` to parse router `/models` data array for verified `status.value == "loaded"` residency rather than guessing from disk. Replaced fuzzy `includes('Qwen')` matching in `ModelsView.tsx` with exact model ID matching and connected `liveModels` with per-model residency state to `ModelLibraryGrid`.
- Verification: 56/56 pytest automated tests passing (3 new tests added in `test_model_registry.py`); frontend verified clean via `npm run build` (0 TypeScript/Vite errors); live smoke test executed on AMD RX 580 Vulkan offload on port 8085 with 100% success across discovery, load, chat generation, and clean unload.

### Added & Enhanced (2026-09-13 - Pass 9: Dynamic Model Registry, Runtime Folder Separation & Per-Model Subdirectories - Track R2-lite)

- Runtime Folder Separation: Renamed root-level engine binary folder `provider/` → `runtime/` (`runtime/llama.cpp/` and `runtime/whisper.cpp/`), clarifying the architectural distinction between external native inference daemons and backend Python provider adapters. Updated `backend/app/core/config.py` (`RUNTIME_DIR`, `LLAMA_CPP_BIN_DIR`) and `.gitignore`.
- Per-Model Subdirectory Layout: Reorganized `models/vision/` into 5 clean per-model subdirectories (`qwen3-vl-2b-instruct`, `qwen3-vl-2b-thinking`, `qwen3-vl-4b-instruct`, `qwen3-vl-4b-thinking`, `qwen3-vl-8b-instruct`), collocating primary GGUF weights with their multimodal projector (`mmproj`) companion artifacts.
- Dynamic Model Registry Service & Schema: Created `ModelRegistryEntry` schema (`app/schemas/model_registry.py`) and read-only `model_registry` service (`app/services/model_registry.py`) supporting hybrid discovery (registry enrichment + disk scanning). Committed `models/registry.template.json` and gitignored local `models/registry.json`. Added `GET /api/v1/models/registry` endpoint and `available_registry` field to `ModelStatusResponse`.
- Safe Path Traversal & Model Loading: Refined path traversal verification in `LlamaCppProvider` to safely allow nested subfolder models within `MODELS_DIR` while strictly blocking directory-escape attempts (`..`, absolute paths).
- Web Models View Dynamic Wiring: Connected `ModelsView.tsx` to `fetchModelRegistry()`, dynamically rendering discovered models in `ModelLibraryGrid` with `Instruct`, `Thinking 🧠`, and `⚠ mmproj missing` variant badges, capability icons, and eradicated hardcoded model name fallbacks.
- Verification: 53/53 pytest tests passing (49 baseline + 4 registry unit/integration tests); frontend verified with `npm run build` (0 TypeScript/Vite errors).

### Added & Enhanced (2026-09-13 - Pass 8: Assistant Orchestration, Persistent Conversations & FTS5 Memory - Track B5)

- Persistent Conversations & Messages: Added `conversations` and `messages` tables with Alembic migration `003`. Implemented full CRUD, message history retrieval, and streaming SSE responses on `/api/v1/conversations`.
- SQLite FTS5 Memory Engine: Created `memories` table with matching `memories_fts` FTS5 virtual table and synchronization triggers. Built `MemoryRetriever` service with query sanitization, FTS5 reserved keyword protection, and multi-language token support.
- Assistant Orchestrator Service: Implemented `AssistantOrchestrator` managing token budgeting, persona configuration, per-conversation async locking (`_get_lock`), and strict trust framing wrapping retrieved memories in `<retrieved_memories>` as untrusted context.
- Runtime Process Safety & 9-State Model: Upgraded `LlamaCppProvider` to native router API (`/models/load`, `/models/unload`), implemented PID-scoped termination, eradicated all blind `taskkill /IM llama-server.exe` calls, and added 9-state runtime lifecycle enum.
- Web UI Persistence & 9-State Badges: Integrated `conversationApi` into `AssistantView.tsx` with auto-session loading, drawer history, and SSE message streaming. Updated `ModelsView.tsx` and `CurrentModelHero.tsx` with live 9-state runtime telemetry badges.
- Verification: 49/49 pytest unit/integration tests passing (16 new tests, 0 regressions); frontend verified with `npm run build` (0 TypeScript/Vite errors).

### Added & Enhanced (2026-09-13 - Pass 7: React Web Dashboard & Local AI Admin Controls - Track C2)

- Web Admin VRAM Controls: Added `POST /api/v1/models/load`, `POST /api/v1/models/unload`, and `PATCH /api/v1/models/profile` endpoints. Integrated tactile single-click **[ Load to VRAM ]** and **[ Unload VRAM ]** buttons into `ModelsView` and `CurrentModelHero`, allowing instant release of ~5 GB GPU memory without terminal commands.
- Windows Subprocess Reliability & Log Isolation: Switched `llama-server.exe` process spawning to `subprocess.Popen` to resolve Windows `NotImplementedError`, and relocated runtime logs outside `backend/` to root `data/llama_server.log` to prevent WatchFiles development auto-reload loops.
- Live SSE Streaming Chat: Connected `AssistantView.tsx` to `POST /api/v1/chat/completions` with real-time token streaming (`text/event-stream`), auto-scrolling message view, unloaded model warning notice with quick-load action, and user-interruptible generation via `AbortController`.
- Frontend API & Context Architecture: Created typed service layer in `frontend/web/src/services/api/` (`client.ts`, `healthApi.ts`, `modelApi.ts`, `chatApi.ts`) and `BackendContext.tsx` with 5-second health heartbeat polling and model telemetry.
- Telemetry & Model Selection Parity: Decoupled model selection in `ModelsView.tsx` so selected library cards preserve true identity, and fixed `CurrentModelHero.tsx` to display accurate `0.0 GB VRAM`, `0 tokens in use`, and `Vulkan Offload (AMD RX 580)` when unloaded.
- Verification: 33/33 backend pytest tests passing; frontend typecheck (`tsc --noEmit`) and Vite production bundle verified.

### Added & Enhanced (2026-09-12 - Pass 6: Local LLM Runtime Integration - Track B4)

- Abstract LLM Provider Architecture: Implemented `BaseLLMProvider` contract with `MockLLMProvider` (deterministic, instant testing engine) and `LlamaCppProvider` (dual-mode standalone `llama-server.exe` and in-process execution with AMD RX 580 VRAM offload).
- Hardware Profiles (Section 13): Configured `Eco` (2048 ctx, low threads), `Balanced` (4096 ctx, 28 GPU layers on RX 580), and `Maximum` (8192 ctx, 33 layers) performance tiers.
- Auto-Unload VRAM Lifecycle (Section 12): Added background activity monitor that automatically unloads model weights after 15 minutes (`LLM_IDLE_TIMEOUT_SECONDS = 900`) of inactivity, freeing VRAM for system and gaming.
- OpenAI-Compatible Chat Completions: Added `POST /api/v1/chat/completions` supporting streaming Server-Sent Events (`text/event-stream`) and synchronous JSON fallback, plus `GET /api/v1/models` for status inspection.
- Auto-Detection & Fallback: Added `LLMManager` singleton auto-detecting real GGUF weights in `models/` (>100 MB) and falling back gracefully to mock provider when weights are downloading.
- Verification: Added 5 comprehensive tests in `backend/tests/test_llm.py` (31/31 backend tests passing, 124/124 Android tests passing, live SSE streaming verified).

### Added & Enhanced (2026-09-12 - Pass 5: Task Reminders, Categories, and Soft Deletion)

- Task Categories & Reminders (Track B6): Added `category` (`general`, `work`, `personal`, `dev`, `shopping`, `health`) and reminder fields (`reminder_minutes_before`, `reminder_at`) to the SQLite `Task` model, Pydantic schemas, and API endpoints. Automatically calculates `reminder_at` timestamp from `due_date` and `reminder_minutes_before` during task creation and updates.
- Android Client Synchronization: Connected Android client to backend task categories and reminders. Updated `RemoteTaskDto`, `LocalAiRuntimeClient`, and `HttpTasksRepository` to serialize and parse `category` and `reminder_minutes_before`. Added `TaskDateTimeConverter.reminderToMinutes` and `minutesToReminder` for bidirectional conversions between mobile reminder labels and backend minute offsets.
- Soft Deletion & Recycle Bin (Section 16.1): Implemented safe two-stage deletion across backend endpoints. `DELETE /api/v1/tasks/{id}` now soft-deletes records (`is_deleted=True`, `deleted_at=utcnow()`), excluding them from default `GET /api/v1/tasks` listings while preserving database rows.
- Recycle Bin (Trash) APIs: Added `GET /api/v1/tasks/trash` (listing soft-deleted tasks with dynamic `expires_in_days` retention countdown), `POST /api/v1/tasks/{id}/restore` (recovering soft-deleted tasks back to active state), and `DELETE /api/v1/tasks/{id}/permanent` (hard deletion from trash).
- Automated Retention Policy: Added `DATA_RETENTION_DAYS: int = 30` setting in `config.py` and `purge_expired_trash()` service in `retention.py` with standalone CLI job runner (`python -m app.services.retention --days 30`).
- Database Migration: Created and applied non-destructive Alembic migration `002_tasks_reminders_and_soft_delete.py` with safe server defaults, ensuring zero data loss on existing records.
- Verification: Added comprehensive test scenarios in `backend/tests/test_tasks.py` and unit tests in `TaskDateTimeConverterTest.kt` (26/26 backend pytest tests passing, 124/124 Android unit tests passing, debug APK assembled).

### Security & Hardening (2026-09-12 - Pass 4: Backend Security V1.1.1 Corrective Pass)

- Minimal Public `/health` Response: Reduced public `GET /api/v1/health` response strictly to `{"status": "healthy"}` without leaking internal telemetry or database diagnostics. Transferred detailed system diagnostics (`database_connected`, `version`, `timestamp`) to authenticated `GET /api/v1/system/status`. Preserved 100% compatibility with Android `HealthDto`.
- Fail-Closed Router Architecture: Re-architected `backend/app/api/v1/router.py` into distinct `public_router` (strictly `/health`) and `protected_router` (enforcing `verify_token` dependency on all present and future mounted routes).
- Streaming Payload Body Size Limit (HTTP 413): Enhanced `PayloadLimitMiddleware` with an ASGI stream byte counter that intercepts and terminates streaming or chunked payloads exceeding 2 MB (`settings.MAX_REQUEST_BODY_BYTES`) with HTTP 413 `PAYLOAD_TOO_LARGE`, even when `Content-Length` header is absent.
- CORS Wildcard Rejection & Scheme Validation: Added Pydantic validator in `backend/app/core/config.py` rejecting wildcard `*` origins and schemeless origins with `ValueError` on startup.
- Request ID Sanitization: Added regex validation (`^[a-zA-Z0-9_-]{1,64}$`) to `SecurityAndTracingMiddleware`, discarding malicious or oversized `X-Request-ID` headers and generating safe `req_<uuid4_hex>` server fallbacks.
- Automated Verification: Added comprehensive negative security tests in `test_security_hardening.py` and updated `test_health.py`. All 22 backend pytest tests passing, and all 122 Android unit tests passing.

### Added & Fixed (2026-09-12 - Pass 3)

- Task Due Date Calculation & SQLite Database Persistence: Resolved the defect where `tasks.due_date` remained `null` in SQLite database (`companion.db`). Created `TaskDateTimeConverter.kt` to calculate concrete dates from relative quick chips (`Today`, `Tomorrow`, `Next Week`) and custom Calendar selections, pair them with 12-hour AM/PM times (`12:00 PM`, `09:30 AM`), and format standard ISO-8601 strings (`YYYY-MM-DDTHH:MM:SS`).
- Authoritative Task Due Date Serialization: Updated `LocalAiRuntimeClient.kt` and `HttpTasksRepository.kt` to dispatch `due_date` in `createTask` (`POST /api/v1/tasks`) and `updateTask` (`PATCH /api/v1/tasks/{id}`). Reconstructed relative labels (`Today`, `Tomorrow`, or `MMM dd, yyyy`) and 12-hour times upon retrieval, while safely preserving local `reminder` and `category` selections.
- Unit Testing Suite & Verification: Added 7 unit tests in `TaskDateTimeConverterTest.kt` (122/122 total unit tests passing in 1m) and compiled fresh debug APK (`app-debug.apk`).

### Added & Fixed (2026-09-12 - Pass 2)

- Reachability Button & Continuous Draft Persistence: Bound "Save & Test Reachability" button to `Connecting` state, eliminating button freeze. Added continuous draft auto-saving on text field changes in `ConnectionScreen.kt` and preserved token in `AppViewModel.kt` so inputs never wipe when leaving or refocusing menus.
- Task Creation Form Senior Accessibility & Readability Redesign: Overhauled `TaskCreateEditSheet.kt` for senior readability with large 14-16sp typography, 48-54dp touch targets, 3 large quick date/time options (`Today`, `Tomorrow`, `Next Week` / `09:00 AM`, `12:00 PM`, `06:00 PM`), prominent dedicated full-width `Calendar` and `Time` picker buttons, and enlarged category/priority chips with high-contrast borders.
- Pull-to-Refresh Gesture Unblocking: Fixed `SoftBounceOverscroll.kt` to allow downward scroll deltas (`available.y > 0f`) to pass through directly to `PullToRefreshBox`. Added vertical scrolling to `EmptyTasksView` so pull-to-refresh triggers even on empty lists, with custom glassmorphic indicators on both Home and Tasks screens.
- Verified with 115/115 passing unit tests (`gradlew.bat testDebugUnitTest`) and fresh APK build (`app-debug.apk`).

### Added & Fixed (2026-09-12)

- Android Sync Resilience & State Persistence: Fixed `SharedPreferencesConnectionRepository` with synchronous `.commit()` disk writes and default host `192.168.254.100`. Keyed `remember` and `LaunchedEffect` in `ConnectionScreen.kt` preventing form state resets when switching tabs or reopening the screen.
- Bi-Directional SQLite Task Completion Synchronization: Resolved task completion mismatch where phone UI toggled locally but the PC SQLite database (`companion.db`) remained pending. Corrected `HttpTasksRepository` to transmit `PATCH /api/v1/tasks/{id}` with `nextStatus` to the active runtime, and properly partitioned `POST` for new tasks and `PATCH` for existing tasks.
- Material 3 Calendar DatePicker & 12-Hour AM/PM TimePicker: Replaced free-text date/time inputs in `TaskCreateEditSheet.kt` with native Material 3 `DatePickerDialog` (with quick chips `Today`, `Tomorrow`, `Next Week`), 12-hour AM/PM `TimePicker` dialog (with quick chips `09:00 AM`, `12:00 PM`, `06:00 PM`), and structured reminder interval chips.
- Pull-to-Refresh Integration: Added Material 3 `PullToRefreshBox` on `HomeScreen.kt` (refreshing backend health and tasks) and `TasksScreen.kt` (refreshing remote tasks from SQLite database).
- Verified with 115/115 passing unit tests (`gradlew.bat testDebugUnitTest`) and clean APK build (`app-debug.apk`).

### Added (2026-09-12)

- Android Backend Connection & Reachability Probe: Added persistent connection preferences (`SharedPreferencesConnectionRepository`) for host IP, port, and pairing key. Added real-time reachability probing (`GET /api/v1/health` with latency calculation) and pairing token validation (`POST /api/v1/auth/verify`) in `LocalAiRuntimeClient` (OkHttp 4.12.0) with dynamic UI connection status updates.
- Cleartext LAN Network Security Configuration: Configured Android network security config permitting cleartext HTTP on private RFC 1918 subnets (`192.168.x.x`, `10.x.x.x`, `172.16.x.x`, Tailscale `100.x.x.x`, and emulator loopbacks) while enforcing HTTPS globally. Added `INTERNET` and `ACCESS_NETWORK_STATE` permissions.
- Live Tasks CRUD Synchronization & Offline Resilience: Implemented `HttpTasksRepository` with optimistic local UI mutations and asynchronous PC SQLite database synchronization. Provided air-gapped fallback so the app functions seamlessly and retains local tasks when the PC runtime is offline or disconnected.
- Automated Integration Tests & APK Build: Added 5 integration tests in `NetworkIntegrationUnitTest.kt` (115/115 unit tests passing in 1m 42s with zero warnings) and compiled debug APK (`app-debug.apk`).

### Security & Hardening (2026-09-12)

- Backend Security Hardening V1.1: Eliminated raw pairing token logging on application startup. Enforced default-deny authentication architecture at FastAPI sub-router boundaries (`/auth`, `/tasks`), keeping only `/health` explicitly public.
- Request Boundaries & CORS Tightening: Added `PayloadLimitMiddleware` rejecting payloads > 2 MB with HTTP 413, restricted CORS to explicit HTTP methods and headers without wildcards, and gated Swagger UI/OpenAPI docs to `ENVIRONMENT == "development"`.
- Automated Verification Suite: Added 6 automated security tests in `backend/tests/test_security_hardening.py` (18 total tests passing in 0.31s with zero warnings).

### Added

- Local AI Core Backend Bootstrapping & OWASP API Security: Initialized `backend/` using Python 3.13, FastAPI, SQLAlchemy 2.0 (asyncio + `aiosqlite`), and Alembic migrations. Implemented zero-configuration 32-byte pairing token authentication (`secrets.token_urlsafe(32)`), constant-time token verification (`secrets.compare_digest`), strict Pydantic v2 mass-assignment guards (`extra="forbid"`), and strict CORS origin whitelisting.
- First Vertical Slice (Health & Tasks CRUD): Delivered public probe (`/api/v1/health`), protected host telemetry (`/api/v1/system/status`), pairing check (`/api/v1/auth/verify`), and complete Tasks CRUD endpoints with status/priority filtering, backed by asynchronous SQLite with Write-Ahead Logging (`PRAGMA journal_mode=WAL`).
- Automated Pytest Suite & OpenAPI Contract Export: Added 12 automated unit and integration tests passing in 0.22s with in-memory SQLite fixtures (`pytest` + `httpx`), exported OpenAPI 3.1 contract to `contracts/openapi/openapi.json`, and published interactive Swagger documentation at `http://127.0.0.1:8000/docs`.

### Added & Fixed

- Assistant Tab Autoscroll Optimization: Pre-positioned `listState` at the latest message upon entering the Assistant workspace with zero animated scrolling lag; `animateScrollToItem` is now selectively triggered only when new messages are appended or during active LLM token streaming.
- Custom UI Wallpaper Frosted Blur: Added `Modifier.blur(18.dp)` to custom image background rendering in `AppShell.kt`, bringing gallery wallpapers into visual parity with built-in aura presets.
- Viewport-Level Floating Vault Popover on Home: Replaced the inline layout-expanding card in `HomeScreen.kt` with a direct trigger to the root `VaultPopoverOverlay`, ensuring the Vault displays as a floating glassmorphic popover with a dismissible scrim without shifting or pushing down feed content.
- Real-Time Horizontal Swipe Tracking: Implemented 1:1 tactile touch translation (`swipeOffset` with `graphicsLayer { translationX }`) across root destinations in `AppShell.kt`, providing immediate visual feedback during finger drag with natural spring snapping.
- Direction-Aware Bottom Navigation Slide Transitions: Aligned bottom navigation destination transitions in `AppShell.kt` with `AnimatedContent` direction-aware spring slide and fade animations (`dampingRatio = 0.82f, stiffness = Spring.StiffnessMediumLow`, `slideInHorizontally(it/3) + fadeIn(220)` & `slideOutHorizontally(-it/4) + fadeOut(180)`), eliminating intermediate screen flashes when jumping between non-adjacent tabs while keeping horizontal swipe gestures responsive.
- OLED Battery Saver & Reduced Mode Button/Pill Parity: Updated `SelectablePill`, `SelectionCardItem`, and `SettingsSectionTabs` in `SettingsScreen.kt` to strictly honor `ThemeMode.OLED_BATTERY_SAVER` (flat `#121214` obsidian containers with `#1F1F23` hairline borders and zero drop shadows) and `EffectsLevel.REDUCED` (`isLightweight = true`, minimal shadow depth).
- Settings Appearance Neumorphic Naming & Scrollable Background Row: Renamed visual effects header to `"NEUMORPHIC VISUAL EFFECTS"` and added `.horizontalScroll(rememberScrollState())` to the Mobile Background row in `SettingsScreen.kt` so all 4 options (`[Built-in]`, `[Custom Image UI]`, `[Gradient]`, `[Solid]`) are fully visible and selectable.
- Decoupled Background Layer & Custom Wallpaper Photo Decoding: Fixed custom image decoding in `AppShell.kt` to decode device gallery images, rendered under glass with contrast scrim, and decoupled `AppBackgroundLayer` beneath `renderScaffold()` so selecting background types never recreates the Scaffold or resets scroll position.
- Overscroll Viewport Boundary Clipping: Added `.clipToBounds()` before the graphics layer in `SoftBounceOverscroll.kt`, ensuring bouncing content strictly stays within the scrollable viewport without rendering over top bars or tabs.
- Global Animated Vault Popover Overlay: Wired top bar avatar across all primary and secondary screens to open the floating animated glassmorphic Vault Popover overlay showing on-device SQLite vault status, host connection details, and a direct settings link.

### Fixed

- 60Hz Display Lock on High-Refresh Screens: Dynamically query `display.supportedModes` in `MainActivity.kt` to configure `preferredDisplayModeId` and `preferredRefreshRate` matching the hardware's maximum available capability (60Hz, 90Hz, 120Hz, 144Hz, 165Hz), unlocking native 120Hz fluid motion on Infinix ZERO ULTRA and modern devices instead of falling back to the 60Hz battery-saver default.
- Multi-Tab Traversal Spike on Bottom Navigation: In `AppShell.kt`, bottom navigation taps to non-adjacent destinations (e.g. Home to More) now execute a direct jump via `scrollToPage(targetIndex)`, bypassing the layout and composition spikes of traversing screens 1, 2, and 3. Physical horizontal swiping retains 1:1 finger tracking between adjacent screens.
- Horizontal Swipe Lag & Tab Hitching: Set `beyondViewportPageCount = 2` in `HorizontalPager` to keep adjacent tab screens pre-warmed in memory, and replaced fixed 200ms tweens with natural velocity-tracking spring physics (`dampingRatio = 0.90f`).
- Restored Authentic Dual-Light Neumorphism: Reverted `isLightweight` default to `false` in `SoftNeumorphic.kt`, `SoftGlassCard.kt`, and `SoftButtons.kt`, fully restoring rich 3D physical dual-light clay depth and specular highlights in Light and Dark modes. Retained thread-safe `BlurFilterCache` (`ConcurrentHashMap<Int, BlurMaskFilter>`) to eliminate native Skia object reallocations and GC stutter.
- Scroll Momentum & Fast Fling Recovery: Fixed `SoftBounceOverscroll.kt` fling velocity interception where fast downward/upward swipes bounced back instead of flinging through content; implemented direction-aware velocity filtering (`onPreFling` returns `Velocity.Zero` when flinging into content to pass 100% velocity to child scrollables while spring-animating overscroll to 0 concurrently), immediate touch-down gesture cancellation (`animJob?.cancel()`), and synchronous state updates via `mutableFloatStateOf(0f)`.

### Changed

- Effects Level Semantics (`Reduced`, `Normal`, `Enhanced`): On `Reduced`, glass visual effects (frosted border gradient, translucent surface, specular highlight, ambient aura glow) remain identical to `Normal` (`specularAlpha = 0.22f`), while only the neumorphic 3D shadow depth is reduced (`shadowFactor = 0.20f`). `Enhanced` delivers visibly deeper shadow contrast (`shadowFactor = 1.5f`) and boosted specular highlights (`specularAlpha = 0.35f`).
- Native Infinix Zero Ultra OLED Pitch-Black Theme: Refined `ThemeMode.OLED_BATTERY_SAVER` across `Theme.kt`, `Color.kt`, `AppShell.kt`, `SoftGlassCard.kt`, and `SoftButtons.kt` to pure pitch black (`#000000`) with zero glassmorphism, zero ambient glows, and zero neumorphic drop/inset shadows. Cards render as flat obsidian containers (`#121214`) with subtle hairline dividers (`#1F1F23`) and high-contrast typography (`#FFFFFF`).

### Added

- Real Android Photo Picker for Custom UI Wallpapers: Integrated `ActivityResultContracts.PickVisualMedia()` in `SettingsScreen.kt` with persistent URI permissions and safe full-screen decoding (`ImageDecoder` / `BitmapFactory`) in `AppShell.kt`.

- "OLED Battery Saver" pure pitch-black (`#000000`) theme mode for AMOLED displays in `SoftGlassTheme`: completely turns off physical screen pixels, sets drop-shadow elevation to 0 (eliminating GPU fill-rate overhead and gray halo artifacts), renders luminous hairline borders, and emphasizes high-contrast glowing accents and typography.
- Persistent appearance and theme storage via `SharedPreferencesAppearanceRepository`, ensuring user selections for theme mode (`Light`, `Dark`, `OLED Battery Saver`), built-in background presets, solid finishes, and effects level survive process recreation and device reboots.
- Contrast calibration for Light and Dark themes: elevated Light Mode muted text and icons (`TextMutedLight = #334155`, Slate-700) for sharp readability against light clay surfaces, and brightened Dark Mode muted icons (`TextMutedDark = #94A3B8`, Slate-400) preventing them from fading into charcoal backgrounds.
- Real Local AI Core Host Network Configuration card in `ConnectionScreen.kt`: editable Host IP/Hostname, Port, and API Token inputs with reachability validation and persistent state saving.
- On-Device Hybrid Failover controls in `ModelsScreen.kt`: dual-engine routing architecture featuring auto-failover toggle, on-device quantized LLM card (`Gemma-2-2B` / `Qwen-2.5-1.5B`), edge neural voice synthesis card (`Kokoro-82M ONNX` at <0.3x RTF), SAF model file import (`.gguf` / `.onnx`), in-app chunked downloader, and on-device RAM allocation gauge.
- Architectural design and canonical plan updates in `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` documenting the Hierarchical Model Routing Architecture, Dynamic Network Heartbeats, zero-dependency model storage, and AMOLED power optimization.
- Momentum-driven two-phase spring bounce overscroll physics in `SoftBounceOverscroll.kt`: absorbs fast fling inertia by smoothly translating content outside container bounds to a velocity-scaled apex before snapping back with authentic rubber-band spring recoil (`DampingRatioMediumBouncy`, `StiffnessLow`).
- Universal overscroll coverage across all primary and secondary scrollable screens, dialogs, and sheets (`AssistantHistorySheet`, `MemoryScreen`, `ConnectionAndSyncBanners`, `TasksScreen`, `HomeScreen`, `MoreScreen`, `AssistantScreen`, `CharactersScreen`, `ModelsScreen`, `DevicesScreen`, `AlarmsScreen`, `PermissionsScreen`, `ConnectionScreen`, `PlaceholderScreen`, `VoiceModeScreen`).
- Pure black (`Color.Black`) tinting for unselected bottom navigation menu items (`Home`, `Tasks`, `Health`, `More`) in Light Mode, preserving center Assistant action button styling.
- Auto-dismissing elevated status toast in `SettingsScreen` (2.6s cancellable coroutine timeout, full-screen tap-anywhere overlay dismiss, elevated 68dp above bottom navigation bar, enlarged typography and CheckCircle status icon).
- Interactive profile avatar popover on Home screen revealing user profile, host connection status indicator, and settings link.
- Compact language selection dropdown menu in Home Assistant Hero (`[ 🌐 Auto ▾ ]`) supporting English, Filipino, Japanese, and Mixed Mode.
- Subtle spring bounce physics to `HorizontalPager` fling gestures (`dampingRatio = 0.82f`) and bottom tab navigation clicks.
- Smooth animated horizontal spring transitions (`AnimatedContent`) for Settings section category switching.
- Horizontal swipe navigation across 5 primary tabs (`Home | Tasks | Assistant | Health | More`) via `HorizontalPager` with 1:1 physical finger tracking and neighbor screen pre-composition (`beyondViewportPageCount = 1`).
- Directional sliding transitions between primary tabs and animated push/pop sliding for secondary destinations in `NavHost`.
- Liquid glass transition depth transformation (`graphicsLayer` scale and alpha damping during swipe gestures) to eliminate abrupt screen content pop-in.
- Back button return-to-Home handling (`BackHandler`) ensuring secondary tabs transition back to Home before exiting the app.
- Soft Glass simulated neumorphic rendering engine (`SoftNeumorphic.kt`) implementing zero-allocation directional dual-shadows (`softNeumorphicRaised`) and recessed wells (`softInsetWell`) for battery-efficient tactility matching the React web client.
- Light and dark ambient background presets parity (4 Light: Aurora Mist, Pearl Bloom, Cloud Glass, Lavender Flow; 4 Dark: Midnight Aurora, Graphite Waves, Deep Violet, Blue Ember) and 4 light solid finishes.
- User-adjustable Contrast Scrim Opacity (0–60%) and Background Brightness (50–150%) sliders in Appearance settings.
- Floating center elevated Assistant action button in bottom navigation with 52dp circular touch target, 26dp icon, and instant 120ms feedback.
- Clean-chat initial launch state with starter prompt suggestion cards.
- Sticky Settings section tabs pinned outside the scroll container with automatic scroll-to-top on section switch.
- Windows Gradle wrapper (`gradlew.bat`, `gradlew`, `gradle-wrapper.jar`) and companion client guide in `android/README.md`.
- Application-scoped manual `AppContainer` (`CompanionApplication`) and Jetpack `AppViewModelProvider.Factory` for constructor-injected ViewModels.
- Shared in-memory `TasksRepository`, `ScheduleRepository`, and `AlarmsRepository` interfaces and fake implementations.
- Unified `AppearanceRepository` with typed `AppearancePreferences` (`ThemeMode`, `ThemeSource`, `AccentPreset`, `BuiltInBackgroundPreset`, `EffectsLevel`).
- Standardized AI-assisted documentation workflow, numbered documentation scaffold, active task tracking, and an approval-gated master-plan reconciliation plan.
- Reconciled the canonical master plan with repository-verified status, external Android Batch 12 progress, Google AI Studio workflow boundaries, current testing facts, and an explicit open model-storage decision.
- Added a major-change commit handoff rule: the AI proposes a commit message and the user manually commits and pushes.
- Organized the canonical master plan, historical drafts, current web-productionization plan, accepted LFS ADR, documentation map, project-input checklist, completed-task archive, and delivery walkthrough.
- Set AI repository access to read-only by default, with edits requiring explicit task-specific authorization.

### Fixed

- Eliminated More screen button navigation layout jump / drop-down glitch: removed conditional dynamic collapse of `Scaffold.topBar` in `AppShell.kt` which was causing abrupt 56dp viewport shifts on click, migrating top bars into authoritative, steady internal layouts inside individual screens.
- Calibrated fluid momentum overscroll physics in `SoftBounceOverscroll.kt`: reduced `maxOverscrollPx` stretch ceiling to 140f, applied quadratic progressive resistance (`(1 - dragRatio)^2 * 0.32f`) to prevent abrupt rubber-band resistance freezing, increased high-speed fling collision threshold to 650f px/s, and clamped maximum apex bounce displacement to <=85px.
- Resolved zero-height semantics clipping on Home screen user avatar popover overlay: replaced artificial 0-height custom layout placement with natural layout bounds and top padding, restoring full visibility in Robolectric accessibility tests.
- Resolved multi-node test ambiguity on `topbar_connection_indicator` in `NavigationRobolectricTest`: updated Compose test assertion to query `.onFirst().assertIsDisplayed()` to handle pre-composed adjacent screens safely.
- Suppressed native Android 12+ stretch `EdgeEffect` rendering distortion via `LocalOverscrollConfiguration provides null` in `SoftGlassTheme`.
- Calibrated physical dual-shadow neumorphic engine in `SoftNeumorphic.kt`: tightened top-left specular highlight offset and blur radius (down to 1.5–4dp) and lowered specular alpha (`0.10f` in dark mode), completely eliminating upward foggy shadow bleed over section headers and container borders above.
- Enhanced authentic neumorphic inset well accuracy in `softNeumorphicInset` and `SoftGlassCard.kt`: increased inner shadow blur radius up to 16dp for soft, deep concave recession, and preserved natural surface background color (`SoftTheme.colors.surface` / `actualBackgroundColor`) on selected cards instead of swapping to an artificial darker slab color (`surfacePressed`).
- Resolved monstrous 1-character-wide vertical letter-snake bug in `CapabilityHubCard` (`PermissionsScreen.kt`) and `PlaceholderScreen.kt` (`About` screen) caused by horizontal row crowding; repositioned `StatusBadge` cleanly below long titles inside `Column(modifier = Modifier.weight(1f))` with full horizontal clearance.
- Eliminated touch-intercepting full-screen overlay in `SettingsScreen.kt` so users can immediately interact with other controls during toast display without extra dismissal taps; reduced auto-dismiss timeout from 2.6s to a snappy 1.4 seconds with smooth fade-out.
- Streamlined Home screen user avatar by removing redundant, clipped online status dot, and upgraded `SoftAvatar` to render an integrated 1.5dp glowing status border ring around the avatar circle (Green = Online, Orange = Reconnecting, Red = Offline) that is completely impervious to container clipping.
- Expanded vertical selection card spacing in `SettingsScreen.kt` to `10.dp` across Theme Source, Glass Visual Effects, and Ambient Presets, adding generous `8.dp` negative space below section titles.
- Resolved indefinitely persisting status toast in `SettingsScreen` that required manual tapping on "X"; implemented auto-dismiss timer and smooth 240ms vertical fade transitions.
- Restored authentic physical dual-shadow `BlurMaskFilter` neumorphic rendering engine (`softNeumorphicRaised` and `softNeumorphicInset`) as default across the application, preserving physical 3D clay extrusion and concave inset depth while integrating `EffectsLevel` under Appearance settings so users can freely choose between Authentic Neumorphic (default) and Lightweight GPU fallback mode (battery saver).
- Eliminated continuous 120Hz infinite recomposition loops in `ConnectionIndicator`, `CompactConnectionIndicator`, `PulsingConnectingDot`, and `AuditioningPulseContainer` that drained battery and starved UI threads; steady states (`Local`, `Remote`, `Offline`) now render static calm dots with 0 Choreographer overhead, while active connecting animations defer properties to off-thread `Modifier.graphicsLayer`.
- Resolved motion dizziness and visual disorientation during tab swiping by removing 3D scale dips and alpha damping from `HorizontalPager` containers, establishing clean 1:1 lateral tracking.
- Eliminated jarring teleportation during bottom tab navigation clicks; unified tab transitions to smooth 180ms tween animations (`FastOutSlowInEasing`).
- Reduced memory consumption and background rendering work by setting `HorizontalPager` `beyondViewportPageCount` to 0.
- Eliminated notch, hole-punch camera, and status bar clock collisions across custom top-bar screens (`SettingsScreen`, `PermissionsScreen`, `CharactersScreen`, `ConnectionScreen`, and `AssistantScreen`) by applying explicit `statusBarsPadding()` to their root header layouts.
- Removed duplicate top navigation bars and double back buttons in System Hub sub-screens (`ModelsScreen`, `DevicesScreen`, and `MemoryScreen`) by omitting redundant local headers when embedded within `AppShell`'s authoritative `AppTopBar`.
- Fixed off-center, bottom-crowded telemetry layout in Home screen `WellnessGlanceCard` items, vertically and horizontally centering metrics (`Arrangement.Center`, `Alignment.CenterHorizontally`) with balanced breathing room.
- Eliminated multi-color neon rainbow borders on `ScheduleScreen` agenda cards, unifying them with the standard `SoftGlassTheme` subtle hairline border while enabling 2-line title wrapping (`maxLines = 2`) to prevent mid-word truncation.
- Fixed awkward vertical letter wrapping in metadata tags across `TaskRowItem` (using `FlowRow`), `DevicesScreen` latency text, `RedundancyStatusCard` failover status, and `MemoryScreen` tags via `softWrap = false` and `TextOverflow.Ellipsis`.
- Resolved asymmetrical button heights in Settings language toggles (`[English]` vs `[Filipino / Tagalog]`) by establishing a uniform `minHeight = 44.dp` touch target with centered text alignment.
- Prevented floating action buttons (FAB) from obscuring the bottom-most list items in `AlarmsScreen` and `MemoryScreen` by expanding `LazyColumn` bottom content padding to `112.dp`.
- Restored subtle hairline borders on dark mode glass cards (`SoftGlassCard.kt`) for crisp edge definition without heavy visual outlines.
- Eliminated the artificial glowing border ring around selected bottom navigation items by replacing high-opacity 1.5dp strokes and cyan gradients with delicate 0.75dp hairline borders (`rgba(255, 255, 255, 0.12)` in dark mode, `0.35` in light mode) and soft dual drop shadows matching the web client `--neu-nav-embossed` design tokens.
- Fixed transition lag and frame drops during bottom navigation switching by eliminating screen destruction and re-instantiation through pager pre-composition.
- Resolved pre-composition semantics ambiguity in Robolectric UI tests by scoping duplicate element selectors.
- Surgically anchored the root `data/` ignore rule to `/data/` in `.gitignore` so Android data source packages (`com.example.data.*`) are properly tracked.
- Eliminated parallel theme state across `AppViewModel` and `SettingsViewModel`, making `AppearanceRepository` the single authority for appearance preferences with dynamic runtime system resolution.
- Connected built-in atmospheric backgrounds, curated gradients, solid finishes, and safe custom accent hex parsing with fallback to `AppearanceRepository` and `AppShell`.
- Neutralized prototype labels and strings, establishing generic "Local AI Core (Simulated)" terminology and "License Not Selected" About metadata.

### Changed

- Renamed Android application label and fallback navigation title to "AI Companion".
- Aligned dark mode canvas and surface tokens to neutral stealth matte charcoal and obsidian graphite (`#0E1015`, `#14161C`, `#1F2229`, `#121419`) matching pure neumorphic depth references while retaining subtle translucent glass headers.
- Switched default brand accent from cyan to deep Royal Blue (`#1D4ED8` / `#60A5FA`).
- Streamlined Home screen header: removed redundant `AppTopBar`, added dynamic model status subtitle (`● Aura is online`), and nested profile telemetry inside the interactive avatar popover card.
- Refined Assistant composer layout: constrained action buttons to 36dp with 8dp spacing and explicit touch bounds to eliminate touch collision, styled Send with raised soft neumorphic elevation, and added dynamic inset-to-emboss morphing on the message text box.
- Reordered bottom navigation to `Home | Tasks | Assistant | Health | More` with floating center action button.
- Eliminated screen transition lag by replacing un-animated NavHost mount/unmount with 120ms GPU-accelerated crossfades (`fadeIn` 120ms / `fadeOut` 90ms with `LinearOutSlowInEasing`) and decoupled background canvas.
- Converted Assistant chat system events, tool actions, and memory recalls into compact single-line expandable notification pills that do not dominate the conversation.
- Removed quick theme toggle buttons from contextual top bars (`AppTopBar` and `AssistantHeader`), consolidating theme controls into Settings -> Appearance.
- Refined the Android prototype into an architecturally aligned V1.1 companion client for the Windows PC Local AI Core host.
- Unified `SoftGlassTheme` to consume authoritative appearance preferences and dynamically resolve dark mode at runtime via Compose's `isSystemInDarkTheme()`.
- Calibrated Soft Glass V1.1 visuals with translucent light mode surfaces, removed heavy dark mode card outlines, and added dynamic atmospheric glow backgrounds in `AppShell`.
- Linked `HomeViewModel` and `FakeHomeRepository` dynamically to shared task, schedule, and alarm repositories.
- Corrected top-level navigation stacking in `AppShell` for quick action navigation.

### Removed

- Pruned unused dependencies and plugins (Firebase, Retrofit, Room) and removed AI Studio export artifacts (`metadata.json`, `.env.example`).
- Purged misleading on-device LLM/NPU/GGUF claims, aligning strings and status models with the Windows PC Local AI Core host.
