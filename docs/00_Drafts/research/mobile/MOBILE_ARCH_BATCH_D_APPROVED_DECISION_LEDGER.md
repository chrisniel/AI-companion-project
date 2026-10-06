# AI Companion — MOBILE-ARCH Batch D Approved Decision Ledger

> **Purpose:** Durable working decision source for the reopened Mobile/Phone product reconciliation pass ("Batch D").
>
> **Status:** **APPROVED WORKING LEDGER — NOT YET CANONICAL**
>
> **Human approver:** Chris
>
> **Repository:** `chrisniel/AI-companion-project`
>
> **Working branch:** `docs/mobile-v1-canonicalization`
>
> **Observed branch head before Batch D promotion:** `cef9baee3d61a90c884e1915b49ff4978d583da7`
>
> **Existing PR:** #21 — must remain unmerged until Batch D reconciliation, canonical promotion, independent review, closure, and fresh PR CI are complete.
>
> **Critical rule:** This ledger records approved product/architecture decisions from the reconciliation discussion so that no implementation agent has to infer intent from scattered chats. It does **not** authorize silent edits to canonical architecture. Promotion happens only after an independent contradiction/reconciliation review.

---

## 0. Authority, interpretation, and workflow

### 0.1 Authority precedence

1. **Implemented source code, generated contracts, and automated tests** define current implementation truth.
2. **Existing accepted PC/shared canonical architecture and ADRs** define durable shared architecture unless explicitly reopened by Chris.
3. **Approved Batch D decisions in this ledger** define the intended Mobile/shared product reconciliation direction.
4. **Current Mobile canonical docs from Batches A–C** remain valid where not superseded/refined by Batch D.
5. Plans, handoffs, prototypes, archived docs, screenshots, benchmarks, and historical drafts are context/evidence only unless explicitly promoted.
6. If two locked decisions genuinely conflict, **STOP and report the conflict**. Do not invent a reconciliation.

### 0.2 Governance

- Chris is the sole Git mutation owner.
- AI agents do not create/switch branches, stage, commit, push, merge, reset, rebase, stash, tag, create PRs, or merge PRs.
- Keep this coherent Mobile reconciliation on the existing branch.
- Do not edit canonical docs during the first Batch D reconciliation/report step.
- Do not claim target architecture is implemented when it is not.
- Do not use the Kotlin Android prototype as production authority.
- Do not silently resurrect superseded ideas because they appear in an older file.

### 0.3 Required workflow

```text
Batch D decision ledger
→ independent contradiction/reconciliation review
→ Chris/GPT approval
→ canonical promotion in coherent domain batches
→ independent implementation/documentation review
→ planning spine/WBS/Golden/CI integration
→ closure review
→ PR update
→ fresh scoped CI
→ squash merge
→ read-only post-merge verification
```

### 0.4 Status vocabulary

- **LOCKED V1** — approved behavior for V1 architecture/product.
- **CONDITIONAL V1** — V1 supports the capability when device/provider/model/permission qualification succeeds; it is not required on every phone.
- **LOCKED SHARED** — shared PC/Mobile architecture decision.
- **MOBILE LATER / FUTURE** — approved direction, deliberately not Mobile V1.
- **IMPLEMENTATION OPEN** — behavior is decided, exact library/schema/threshold/API/UI detail is not.
- **RESEARCH** — evidence requirement or candidate, not an architecture dependency.
- **WITHDRAWN / SUPERSEDED** — do not reintroduce.

---

# 1. Mobile identity, local inference, resource governance

## D-PHONE-01 — Production-capable local LLM path
**Status:** LOCKED V1

Mobile V1 product implementation must include a real production-capable device-local LLM execution path for **qualified devices**.

- Local LLM is a Mobile V1 product capability.
- Not every supported phone must qualify.
- Core non-generative Mobile capabilities must remain usable without a local LLM.
- Exact model family, runtime, backend, size, quantization, and minimum hardware remain implementation/research open.
- Gemma 3 1B Q4 is a top research/reference candidate from current testing, **not** a permanent dependency.

## D-PHONE-01A — Orthogonal availability dimensions
**Status:** LOCKED V1

Host reachability, internet availability, and inference route are separate state dimensions.

- `STANDALONE_MOBILE` means PC-independent operation.
- Internet-offline is a separate condition.
- Inference route may be PC local, Mobile local, Cloud, or none.
- Internet availability does not imply Cloud LLM use.
- Read-only internet tools may operate independently of Cloud LLM authorization.

## D-PHONE-01B — Enrollment before normal Companion use
**Status:** LOCKED V1

- Normal Companion functions require enrollment with an authorized PC Host.
- Device binds to exactly one existing Profile.
- Unenrolled state exposes setup/pairing/troubleshooting/about/compatibility only.
- PC is required for enrollment, trust, binding, reassignment, and revocation, not continuous operation.
- After enrollment, Host may be offline and the phone can operate in `STANDALONE_MOBILE`.
- App reinstall/credential loss returns the client to unenrolled state unless an explicitly approved recovery flow exists.
- Cloud/API credentials do not substitute for enrollment.
- Conceptual lifecycle: `UNENROLLED`, `ENROLLED_ACTIVE`, `ENROLLED_REAUTH_REQUIRED`, `REVOKED`.
- Pairing UX direction: QR/code. Exact crypto/payload remains implementation open.

## D-PHONE-01C — Replaceable local models
**Status:** LOCKED V1

- Users may install/select/change/load/unload/remove approved local models.
- No model family is permanently mandated.
- Model capabilities use shared qualification semantics.
- Switching must truthfully disable unqualified capabilities.
- A model proposes tool intent; the gateway + D9 policy executes it.
- Reference models may exist without becoming architecture locks.

## D-PHONE-02 — Core survives without generative AI
**Status:** LOCKED V1

Loss, unload, thermal suspension, or absence of a local LLM must not disable Mobile core.

Core includes Tasks, Reminders/Alarms, cached state, sync/outbox, settings, model management, connection/enrollment status, notifications, and other deterministic/non-generative features.

Chat is available only through PC Runtime, qualified local LLM, or explicitly authorized Cloud LLM.

## D-PHONE-03 — Vendor-neutral Mobile execution
**Status:** LOCKED V1

- No permanent Qualcomm/Snapdragon/Adreno/Hexagon/MediaTek/Mali requirement.
- Model identity, runtime/provider, acceleration backend, and hardware remain distinct.
- CPU **SHOULD** be a broad fallback where supported, not an absolute universal guarantee.
- GPU/NPU/other acceleration is optional and capability-qualified.
- Requested backend and actual backend must be separately/truthfully reported.
- `AUTO` is recommended for ordinary users.
- Advanced UI may expose CPU/GPU/NPU only where supported.
- PocketPal GPU-layer settings are not proof of actual GPU execution.

## D-PHONE-04 — Replaceable speech providers
**Status:** LOCKED V1

- Local TTS and STT are independent, replaceable capabilities.
- No Kitten/Kokoro/Whisper/System/cloud provider is permanently mandated.
- Normal mode uses `Auto`; advanced mode may expose qualified selection.
- Existing evidence: Kitten felt faster/lighter but more robotic; Kokoro felt slower but more natural.
- STT has not yet been benchmarked on the phone.
- Cloud LLM, Cloud STT, and Cloud TTS permissions remain independent.

## D-PHONE-05 — Mobile model lifecycle
**Status:** LOCKED V1

Distinguish `installed`, `loaded/resident`, `active`, `unloaded`, and `removed`.

- Multiple artifacts may be installed.
- At most one resident generative LLM in Mobile V1.
- Switching is gated by memory, thermal, battery, backend, and compatibility.
- Speech/vision residency is budgeted separately.
- Unload never deletes.
- Removal/purge is explicit.

## D-PHONE-05A — Resource Governor + truthful UI
**Status:** LOCKED V1

- Progressive user-visible intervention.
- Non-critical pressure warns first and mitigates gracefully.
- Low-priority/background work is deferred first.
- Foreground work may finish where safe.
- User actions may include Continue, Reduce, Finish then cool, Stop & unload.
- Severe pressure may pause/stop inference.
- Critical/emergency pressure may force cancellation/unload after durable state preservation.
- User cannot override hardware protection.
- Automatic unload never deletes.
- Resource state, actual backend, model residency, and degradation reason are visible.
- Friendly presentation labels may map to platform states but cannot replace real Android thermal state.
- Exact thresholds remain open.

---

# 2. Shared context, compaction, retrieval, and conversation behavior

## D-SHARED-AI-01 — Context / generation / reasoning budget manager
**Status:** LOCKED SHARED

Refines the existing context assembler.

Distinguish native model max, configured runtime context, and effective safe context.

Reserve bounded room for system/security, Character/Personality, Memory, recent history, summaries, retrieved excerpts, tools, reasoning, and response.

- History/reasoning cannot consume the entire window.
- Resource Governor may reduce effective context.
- UI shows configured vs effective context and reason.
- Response/reasoning budgets are explicit.
- Tool-intent extraction gets a tight structured budget.
- Active conversation state persists before unload.
- Unsafe developer knobs cannot bypass security/data integrity.

## D-SHARED-AI-02 — Conversation context compaction & historical recall
**Status:** LOCKED SHARED

- Raw full transcript remains authoritative.
- Compaction never deletes/rewrites raw history.
- Summaries are persisted **derived conversation records**, not Memory.
- Summaries are rebuildable/invalidation-aware.
- Explicit `Compact context` is allowed.
- Automatic compaction occurs before context exhaustion using effective budget.
- Keep recent turns verbatim where practical.
- Older context uses summaries + relevant retrieved raw excerpts.
- Preserve conversation/branch/source-range/revision/model/policy provenance.
- History search may retrieve summary/raw turn/metadata excerpts.
- PC Host owns canonical raw history and canonical derived summaries.
- Standalone Mobile may create provisional local summaries for offline branches.
- Mobile always syncs raw authoritative turns.
- Host may accept, rebuild, or discard provisional summaries.
- Summaries do not auto-promote to Memory.

## D-SHARED-AI-03 — Unified context retrieval
**Status:** LOCKED SHARED

Keep separately searchable sources:

1. canonical Memory
2. conversation summaries
3. raw conversation excerpts
4. pending local context

Pending context may include pending explicit Memory intents and unsynced Mobile branch state.

Requirements: bounded retrieval, provenance, Profile isolation, Character isolation, Context Budget integration. Retrieval technology remains replaceable.

## D-PHONE-09 — Selective offline Memory replica
**Status:** LOCKED V1

Mobile keeps a bounded durable subset of canonical Memory.

May include explicitly pinned offline memories, bounded Profile continuity set, Character memories for cached Characters, and recently/on-demand fetched relevant memories.

- Exact selection algorithm open.
- User may mark Memory `Always available on this phone`.
- Pinned Memory survives ordinary cache eviction.
- Canonical cached Memory is read-only offline.
- Forget/delete/revocation/Profile purge propagate.
- Local retrieval stays bounded.

---

# 3. Conversation identity, streaming, queueing, regeneration

## D-SHARED-CONV-01 — Causal conversation identity & branching
**Status:** LOCKED SHARED

- Stable conversation UUID.
- Stable turn/submission identity.
- Preserve causal parentage.
- Conceptual metadata may include `parent_turn_id`, `branch_id`, `fork_from_turn_id`, `source_device_id`.
- Sequential continuation appends normally.
- True concurrent continuation from the same earlier head creates a branch.
- No timestamp/LWW interleaving.
- Branches preserved; raw turns authoritative.
- Disconnected Mobile branch persists locally before sync.
- Host is reconciliation authority.
- Host does not regenerate imported Mobile responses.
- Reconciliation may create a new continuation informed by multiple branches without rewriting originals.
- Branch UX may show `Conversation continued in two places`, counts, Continue PC branch, Continue Phone branch, Compare.
- Compare is non-destructive.
- One Profile → multiple phones remains **OPEN**.
- One Device → one Profile remains locked.
- No phone-to-phone canonical authority.

## D-SHARED-CONV-02 — Host-mediated live turn streaming
**Status:** LOCKED SHARED

Connected Mobile chat uses authenticated REST turn submission + SSE live generation. GET/history is for catch-up/recovery. WebSocket remains for full-duplex Voice.

Host owns the active turn and continues it across client disconnect. One Host inference may be observed by multiple authorized clients. True stale-head concurrency branches instead of silently appending.

## D-SHARED-CONV-03 — Active turn control
**Status:** LOCKED SHARED

### QUEUE
- current response finishes first
- queued user message becomes next turn
- durable once accepted
- queued message may be edited/removed **until execution begins**

### INTERRUPT_AND_SEND
- cancel active generation
- persist visible partial response as `INTERRUPTED`
- submit new user turn
- do not delete visible partial output
- interrupted content may remain context-marked

### FORK_FROM_HERE
- explicit branch
- not default normal follow-up

Committed side effects are not silently rolled back by prose interruption.

## D-SHARED-CONV-03A — Safe regeneration
**Status:** LOCKED SHARED

- Regenerate creates alternate assistant response for the same user turn.
- No duplicate user message.
- Divergence occurs only when continuing from a chosen response alternative.
- Regeneration must not automatically replay committed state-changing tools.
- Existing action receipts may be reused as context.
- Explicit new intent is required to execute state-changing action again.
- `Edit & resend` may branch from edited user content.
- Exact DB representation remains open.

---

# 4. Character, Personality, Mood, Memory

## D-PHONE-06 — Character selection inherits D11
**Status:** LOCKED V1

Mobile uses the shared D11 Character/Personality/Emotion architecture. No competing Mobile Character schema.

Mobile may select cached/synced Characters for the bound Profile. Character switching never changes Profile, security/tool authority, Tasks, Health ownership, or other Profile-owned data. Conversations remain Character-bound.

## Character create/edit authority
**Status:** LOCKED V1 direction

Connected Mobile may expose Character Studio-like create/edit UI as a client over the Host canonical Character service using the same D11 traits/presets/contracts.

Offline canonical Character creation/editing is not Mobile V1. Temporary local drafts may exist later but are not canonical Characters.

### WITHDRAWN / SUPERSEDED
Do not resurrect:
- Mobile-local authoritative Character creation
- separate Mobile Character variant ownership
- separate Mobile-only Mood overlay

## D-PHONE-EMO-01 — Offline Emotion Event Synchronization
**Status:** LOCKED V1 direction

Mobile does not directly overwrite canonical persistent Mood values.

```text
offline interaction
→ typed bounded emotion event
→ durable outbox
→ optional provisional local expression
→ Host reconciliation
→ shared D11 Emotion policy
→ canonical Mood
```

Synchronize events, not arbitrary Mood numeric writes. Exact event taxonomy/schema/decay/confidence/retention/multi-device ordering remains open.

## D-PHONE-08 — Offline explicit Memory intent
**Status:** LOCKED V1

Explicit offline “remember this” becomes durable typed Memory intent with `PENDING_SYNC`.

On reconnect it goes through D7 reconciliation: NEW / MERGE / UPDATE / CONFLICT / REJECT.

Mobile must not claim pending intent is canonical Memory. Ordinary offline conversation does not autonomously create canonical Memory.

## D-PHONE-08A — Pending Memory overlay
**Status:** LOCKED V1

Pending explicit Memory intent may be used immediately by the local assistant for continuity, with provenance and clear distinction from cached canonical Memory. Accepted/reconciled Host Memory replaces the overlay.

---

# 5. Scheduling, Reminders, Alarms, temporal semantics

## D-SHARED-SCHED-01 — Stable scheduling identity
**Status:** LOCKED SHARED

Synchronizable Task, Reminder, Alarm, Routine, occurrence, and mutation identities use stable UUID-based identities. Profile owns entities; device origin/provenance is separate.

## D-PHONE-10 — Offline Reminder authoring
**Status:** LOCKED V1

Mobile-created Reminders may be fully managed offline: create, edit, cancel/delete, dismiss/snooze occurrence, local scheduling/delivery.

Host-created Reminder definitions remain read-only offline, though occurrence delivery/dismiss/snooze is allowed. Connected Mobile may edit through Host authority.

Use stable client ID, transactional local persistence, outbox, local provisional occurrence where needed, later Host reconciliation, revision conflict handling, and duplicate prevention.

## D-PHONE-11 — Offline Alarm authoring
**Status:** LOCKED V1

Mobile-created Alarms may be created/edited/armed offline, including recurrence, enable/disable, cancellation, presentation settings, dismiss/snooze.

Host-created Alarm definitions remain read-only offline, but may ring/present and accept dismiss/snooze/acknowledge.

Profile owns Alarm. Host owns canonical synchronized state. Origin Device determines offline mutation eligibility, not ownership. Synced Mobile-created Alarms survive device revocation as Profile data.

## D-SHARED-SCHED-02 — Cross-device presentation arbitration
**Status:** LOCKED SHARED

When connected, Host coordinates primary/secondary presentation.

### Reminders
Favor duplicate suppression. One primary presents; secondary stays synchronized/silent or takes over if primary unavailable.

### Alarms
Favor reliability. Primary rings first; standby remains locally armed. Explicit acknowledgement/dismiss/snooze propagates. Passive display does **not** count as acknowledgement. Unacknowledged primary may cause standby escalation after bounded grace.

Default `AUTO` may use reachability, active client, recent PC/phone activity, permissions, user preference, and future optional Presence/location evidence.

User direction: Automatic / Prefer PC / Prefer Phone / Both. Alarm variant may include Ring all available devices.

When coordination is impossible, prefer duplicate Alarm over missed Alarm.

## D-SHARED-SCHED-03 — Companion alert enrichment
**Status:** LOCKED SHARED

Occurrence is authoritative. Ring/chime/notification is deterministic presentation. Companion wording is optional enrichment.

AI generation never delays Alarm delivery. Deterministic fallback exists. Primary presenter speaks by default; standby may speak on escalation. Character/Mood affects presentation only, never schedule truth.

## D-SHARED-SCHED-04 — Temporal Intent Resolution
**Status:** LOCKED SHARED

Natural-language scheduling becomes typed temporal intent then deterministic resolution. LLM does not own calendar truth.

Conceptual types: exact, relative, calendar-relative, daypart, recurrence, explicit timezone, underspecified, ambiguous.

## D-SHARED-SCHED-04A — Field-level ambiguity & clarification
**Status:** LOCKED SHARED

Clarify only unresolved/material fields. Exact low-risk requests may execute under D9 without redundant confirmation. Vague phrases such as `later` or `in a bit` require clarification unless a deterministic preference exists.

## D-SHARED-SCHED-04B — Timezone & recurrence semantics
**Status:** LOCKED SHARED

Distinguish one-shot instant, floating local recurrence, and fixed-timezone recurrence. Clock/timezone changes reconcile deterministically.

## D-SHARED-SCHED-04C — Alarm strictness
**Status:** LOCKED SHARED

Material ambiguity in date/time/AM-PM/recurrence/timezone must be resolved before an Alarm is armed.

## D-SHARED-SCHED-04D — Cross-platform temporal parity
**Status:** LOCKED SHARED

Same input + same timezone/preferences must resolve equivalently on PC and Mobile. Share Golden test vectors.

## D-SHARED-SCHED-04E — Preference/history-informed temporal clarification
**Status:** LOCKED SHARED

Context priority:

1. explicit current instruction
2. current conversation
3. configured scheduling preferences
4. verified Profile Memory
5. repeated historical patterns
6. relevant summaries/history
7. clarify with user

Historical pattern → suggestion. Explicit preference → deterministic default. Repeated patterns do not automatically become Memory.

---

# 6. Location / geofencing

## P-PHONE-LOC-01 — Opt-in Location Context
**Status:** MOBILE LATER / APPROVED FUTURE DIRECTION

Potential uses: location-aware alert arbitration, geofenced Reminders, arrival/departure reminders, location-aware weather/search, travel/context adaptation, future Presence.

Rules: opt-in, prefer event-oriented geofencing over continuous high-frequency GPS, Location is context not Memory, no hidden continuous tracking, background location requires explicit purpose/permission, no implied cloud egress, user can inspect/disable/purge retained location context, Character cannot override privacy, Location is evidence rather than absolute scheduling authority.

---

# 7. Routines, check-ins, widgets, companion tone

## D-PHONE-12 — Replicated Routine occurrences
**Status:** LOCKED V1

Mobile may cache/present bounded Host-authorized Routine occurrences while disconnected. Host decides schedule/intent. Mobile does not extend recurrence indefinitely after cached occurrences are exhausted.

## D-PHONE-12A — Routine presentation enrichment
**Status:** LOCKED V1

Qualified local AI/TTS may personalize Routine occurrence using permitted cached/local context, active Character, schedule/task state, authorized Health context, etc. Deterministic/template fallback is mandatory. Generation never owns the trigger.

## D-PHONE-12B — Routine authoring authority
**Status:** LOCKED V1

Connected Mobile may manage Routines through Host APIs and D9 Risk-2 policy. Offline Mobile V1 does not create canonical Routine, materially edit recurrence, expand capability envelope, or change permissions.

## D-PHONE-12C — Local Routine suppression
**Status:** LOCKED V1

User may pause/suppress Routine presentation on the current device while offline without rewriting the canonical Routine. A disable-everywhere request may become a pending Host mutation.

## D-PHONE-12D — Companion check-in surfaces
**Status:** LOCKED V1

Routine/check-in may appear as in-app card, notification, Mobile Home/dashboard widget, Android home-screen widget, optional spoken announcement, or chat continuation.

The Routine occurrence remains authoritative. Widget is presentation only.

Priority direction:
1. urgent missed Alarm/Reminder
2. today’s important Tasks
3. upcoming Alarm/Reminder
4. conflicts/sync issues
5. Routine-specific content
6. optional Character message

## D-PHONE-12E — Character-aware check-in tone
**Status:** LOCKED V1

Check-ins/widgets may use active D11 Personality and bounded Mood.

Stronger presets such as Yandere may use simulated phrases like “I missed you” or “I was lonely” when appropriate, provided real useful information follows, facts are not fabricated, and the system avoids coercive threats, isolation pressure, or punishment for non-interaction.

---

# 8. Standalone tools, web/current information

## D-PHONE-13 — Standalone Mobile Tool Gateway
**Status:** LOCKED V1

Qualified local Mobile models may invoke approved typed tools while Host is unavailable:

```text
Local Mobile LLM
→ typed tool intent
→ Mobile Tool Gateway
→ D9 deterministic policy
→ bounded adapter
→ confirmed result
→ response
```

Model has zero inherent execution authority.

## D-PHONE-13A — Local productivity tools
**Status:** LOCKED V1

Standalone tools may cover Tasks, Mobile-origin Reminders/Alarms, occurrence actions, and Schedule read access within existing authority.

## D-PHONE-13B — Read-only internet tools
**Status:** LOCKED V1

With internet, standalone Mobile may use bounded Web Search, public webpage fetch/read, and Weather adapters.

## D-PHONE-13C — Internet is not Cloud AI
**Status:** LOCKED V1

Internet availability does not authorize Cloud LLM. Local reasoning may use internet retrieval.

## D-PHONE-13D — Local Companion read tools
**Status:** LOCKED V1

Bounded local reads may include cached Memory, pending Memory intents, cached/local history, Character info, device capability, model/runtime status, sync state, and resource state.

## D-PHONE-13E — Explicitly excluded authority
**Status:** LOCKED V1 / REJECTED

No arbitrary shell, raw unrestricted filesystem, credential access, PC admin, Profile admin, device reassignment, network/security reconfiguration, unrestricted browser automation, or Host-only privileged actions.

## D-PHONE-13F — Tool capability qualification
**Status:** LOCKED V1

Tool invocation requires model/runtime qualification. Success is claimed only after adapter/backend confirmation, never because the model merely says “done.”

---

# 9. Voice / STT / TTS

## D-PHONE-14 — Composable Mobile Voice
**Status:** LOCKED V1

Voice is composed from independent STT, reasoning, and TTS routes: Local, Host, or separately authorized Cloud.

## D-PHONE-14A — Connected Mobile Voice
**Status:** LOCKED V1

Phone owns microphone capture, playback, audio focus, route changes, immediate mute, and UI. PC Runtime owns canonical connected STT/LLM/TTS/VAD/VoiceSession over authenticated full-duplex WebSocket.

## D-PHONE-14B — Local TTS
**Status:** CONDITIONAL V1

Qualified local TTS may operate independently of STT or local LLM and support conversation output plus approved alert/check-in speech.

## D-PHONE-14C — Local STT
**Status:** CONDITIONAL V1

Local STT is supported if qualification passes. V1 focuses on push-to-talk, tap-to-speak, or active Voice session. Continuous always-on STT is excluded.

## D-PHONE-14D — Full offline Voice
**Status:** CONDITIONAL V1

Available when local STT + local LLM + local TTS all qualify and current resources permit. Degrade compositionally if a component becomes unavailable.

## D-PHONE-14E — Voice route selection
**Status:** LOCKED V1

Default `Auto` considers Host availability, local qualification, resources, internet, and user cloud permissions. Actual route must be visible. Cloud components require independent consent.

## D-PHONE-14F — Explicit Voice session lifecycle
**Status:** LOCKED V1

No background eavesdropping. Voice begins through visible user action. An explicitly initiated active session may continue under proper Android foreground-service rules after screen lock with visible OS indication.

## D-PHONE-14G — Shared STT candidate qualification
**Status:** RESEARCH REQUIREMENT / LOCKED DIRECTION

Test `whisper.cpp` first on Mobile because it aligns with PC Voice architecture. Mobile qualification is separate. Measure English, Tagalog, Taglish, dates/numbers/times, latency, memory, battery, thermal, noise, barge-in. Replace if it fails without changing architecture.

### Shared Voice invariants
Mandatory barge-in, D9 parity with text, ephemeral raw audio by default, Voice is not authentication, cloud STT/TTS/LLM permissions separate, no wake word in V1, private proactive speech opt-in.

---

# 10. Health & wearables

## D-PHONE-15 — Health Connect conditional Mobile V1
**Status:** CONDITIONAL V1 — intentionally supersedes current canonical `Mobile Later`

Health Connect returns to Mobile V1 as optional, read-only, consent-driven, non-clinical. A phone/user without usable Health Connect remains valid V1.

## D-PHONE-15A — Granular metric authorization
**Status:** LOCKED V1

Independent metric permissions. Candidate categories: active calories, blood pressure, body temperature, distance, heart rate, oxygen saturation/SpO₂, sleep, steps/activity. Only claim what the source actually supplies.

## D-PHONE-15B — Read-only Health ingestion
**Status:** LOCKED V1

Read approved Health Connect data. No Companion health-record write-back in V1.

## D-PHONE-15C — Health is separate from Memory
**Status:** LOCKED SHARED

Health readings/trends are Health-domain context, not D7 Memory. Explicit user preferences may separately become Memory through D7.

## D-PHONE-15D — Shared PC/Mobile Health context
**Status:** LOCKED V1 direction

PC and Mobile use the same normalized Health context contract. Mobile is the Health Connect ingestion point. Authorized useful normalized context may sync to PC.

## D-PHONE-15E — Health Connect aggregation boundary
**Status:** LOCKED V1

Prefer Health Connect over vendor-specific wearable adapters. Direct vendor integration is not V1-required unless Health Connect cannot provide an important source.

## D-SHARED-HEALTH-01 — Unified Health Context
**Status:** LOCKED SHARED

Normalized Health data preserves source, measurement time, last updated, freshness, and provenance. Sync what is useful for approved Companion behavior, not arbitrary unlimited high-frequency telemetry by default.

## D-SHARED-HEALTH-02 — Non-clinical wellness awareness
**Status:** LOCKED SHARED

Health may support awareness, personalization, trends/baselines, gentle check-ins, wellness suggestions, and caring Character responses. It may not diagnose, prescribe, claim treatment, claim medical certainty, or invent emergency detection.

## D-SHARED-HEALTH-03 — Health-aware check-ins
**Status:** LOCKED SHARED

Authorized Health context may enrich Routine/check-in/widget/conversation behavior while keeping underlying facts deterministic and Character presentation separate.

## D-SHARED-HEALTH-04 — Health egress isolation
**Status:** LOCKED SHARED

Cloud LLM permission + Health permission does not authorize Health-to-cloud. Health-to-cloud use requires separate explicit authorization.

---

# 11. Vision / multimodal

## D-PHONE-16 — Conditional local Vision in Mobile V1
**Status:** CONDITIONAL V1 — intentionally supersedes current canonical post-V1-only disposition

Qualified phones/models may perform local still-image understanding in Mobile V1.

## D-PHONE-16A — Camera-to-attachment
**Status:** LOCKED V1

Still camera/gallery input feeds the shared attachment/multimodal conversation architecture. Camera capture is an input adapter, not a new vision domain.

## D-PHONE-16B — Multimodal route selection
**Status:** LOCKED V1

Image inference may route to PC Host local vision, qualified Mobile local VLM, separately authorized Cloud multimodal model, or unavailable. Internet does not imply Cloud Vision permission.

## D-PHONE-16C — Vision qualification
**Status:** LOCKED V1

Vision must be evidence-qualified. Success at one task does not imply universal OCR/spatial/location/fine-detail/medical visual competence. Existing Qwen 3.5 0.8B phone evidence proves feasibility but also hallucination risk.

## D-PHONE-16D — Offline multimodal persistence
**Status:** LOCKED V1

Offline image turns/attachments/local responses persist durably and later sync without Host regeneration.

## D-PHONE-16E — Explicit-capture V1 boundary
**Status:** LOCKED V1

V1 supports bounded user-initiated still-image capture/selection. Ambient continuous camera, background sensing, surveillance-style observation, and live AR environmental sensing are excluded from V1.

## D-SHARED-VISION-01 — Vision does not automatically create Memory
**Status:** LOCKED SHARED

Image observation remains conversation/media context unless D7 explicitly accepts/proposes Memory.

---

# 12. Future Presence / AR / expression assets

## P-SHARED-PRESENCE-01 — Embodied Companion Presence
**Status:** FUTURE / APPROVED DIRECTION

Character may reference static 2D, expression bundle, Live2D, VRM/3D, or other approved renderable assets. Presence remains separate from Character identity, Personality, Mood, and Voice.

## P-PHONE-AR-01 — Mobile AR Companion Presence
**Status:** FUTURE / APPROVED DIRECTION

Explicit user-started AR sessions may place/animate the same Character in the physical environment.

## P-PHONE-AR-02 — Bounded scene awareness
**Status:** FUTURE / APPROVED DIRECTION

AR rendering does not require continuous VLM inference. Optional scene understanding may use qualified Mobile/Host/cloud multimodal. Still-image cloud permission does not automatically authorize continuous live-camera streaming.

## P-PRESENCE-02 — Remote expression asset discovery
**Status:** EXPERIMENTAL LATER

Future explicit user-driven web/media search and import for expression assets is allowed as an experiment.

V1 guaranteed fallback is emoji. Existing local Character expression assets may be used. Do not auto-fetch random web GIFs on Mood changes. Imported remote assets should become local reusable assets rather than permanent hotlinks.

Background camera surveillance remains rejected.

---

# 13. Mobile UX / navigation / visual language / language

## D-PHONE-UX-01 — Companion-centered Mobile shell
**Status:** LOCKED V1

Primary navigation: `Home / Schedule / COMPANION / Activity / More`, with visually emphasized center Companion action.

## D-PHONE-UX-01A — Icon-first navigation
**Status:** LOCKED V1

Custom icons allowed. Visible labels may disappear in normal presentation, but semantic/accessibility labels are mandatory. Accessibility/large-font modes may show labels.

## D-PHONE-UX-02 — Contextual Companion Home
**Status:** LOCKED V1

Home is a prioritized contextual Companion surface, not a static enterprise dashboard. May surface Character presence, Routine/check-in, today’s Schedule, Health context, important conflicts, sync state, and quick actions when truthful/authorized.

## D-PHONE-UX-03 — Unified Companion interaction surface
**Status:** LOCKED V1

Text, Voice, camera, and still-image/media input converge on the same Character-bound conversation experience.

## D-PHONE-UX-04 — Unified Schedule experience
**Status:** LOCKED V1

Tasks, Reminders, Alarms, and Routines remain distinct entities presented through one coherent Mobile Schedule surface.

## D-PHONE-UX-05 — Activity & reconciliation inbox
**Status:** LOCKED V1

Human-readable Activity may contain missed alerts, Routine check-ins, sync completion/conflicts, pending Memory reconciliation, reconnection notices, resource/model degradation, permission issues, and tool/action receipts. No raw debug-log dump as ordinary UX.

## D-PHONE-UX-06 — Truthful capability status
**Status:** LOCKED V1

Compact normal-state indicator with drill-down for Host connection, inference route, STT/TTS route, sync, resource state, permissions. Avoid permanent badge clutter.

## D-PHONE-UX-07 — Graceful standalone UX
**Status:** LOCKED V1

Host loss is a capability transition, not an app-wide failure. Continue local functions and mark only unavailable capabilities.

## D-PHONE-UX-08 — Hybrid Mobile visual language
**Status:** LOCKED V1

### Foundation: Minimalism
Controls information density, typography, iconography, spacing, hierarchy, and unnecessary controls.

### Structural/tactile surfaces: selective Neumorphism
Use selectively for controls, cards, tactile buttons, navigation, sliders, sheets.

### Floating/contextual surfaces: Glassmorphism / Liquid Glass
Use for overlays, navigation, Companion cards, modal sheets, transient surfaces, selected states, Presence elements.

### OLED default
Default Mobile appearance is OLED-first.

Available modes remain OLED (default), Dark, Light, System.

Appearance may include accents, built-in backgrounds, custom image, gradients, solids, effects level, reduced effects, reduced motion.

Resource Governor may reduce applied effects without rewriting the chosen appearance.

## D-PHONE-UX-09 — Companion language vs UI language
**Status:** LOCKED V1

Companion interaction language is separate from application UI localization. Full UI localization only exists when translated resources exist.

## D-PHONE-UX-10 — Lightweight Mood Presence
**Status:** LOCKED V1

Mobile V1 may represent Mood via available Character expression asset, lightweight approved local animation, static portrait, or emoji/mood-glyph fallback. Emoji is the guaranteed lightweight V1 fallback. Visual expression is presentation, not authoritative Mood state.

## D-SHARED-LANG-01 — Extensible language registry
**Status:** LOCKED SHARED

Do not freeze languages into a permanent enum. Use extensible registry/capability semantics and standard identifiers where possible.

Current targets may include English, Filipino/Tagalog, Japanese. Future qualification may add Cebuano/Bisaya, Korean, Russian, etc. Adding a language must not redesign architecture.

## D-SHARED-LANG-02 — Qualified language capability
**Status:** LOCKED SHARED

Advertise full language support only when relevant LLM/STT/TTS components qualify. `Auto` may support natural code-switching where providers/models qualify.

---

# 14. Shared Flutter workspace / code sharing

## D-SHARED-FLUTTER-01 — Shared workspace, separate apps
**Status:** LOCKED SHARED

Desktop and Mobile are separate Flutter app targets inside one shared workspace. Exact paths/names remain open. Neither app imports the other app.

## D-SHARED-FLUTTER-02 — Share contracts, not every implementation
**Status:** LOCKED SHARED

Share stable domain models, DTOs/contracts, IDs, validation, repository interfaces, capability semantics, platform-neutral state/controller logic, and Golden fixtures.

Do not force identical repository/platform implementations.

## D-SHARED-FLUTTER-03 — Shared typed Host client
**Status:** LOCKED SHARED

One shared client layer implements REST, SSE, Voice WebSocket contracts, authentication injection, typed errors, and reconnect semantics. Desktop and Mobile may use different transport configuration.

## D-SHARED-FLUTTER-04 — Shared repository contracts
**Status:** LOCKED SHARED

Share repository/service contracts where semantically common; implementations remain capability-aware and platform-specific as needed.

## D-SHARED-FLUTTER-05 — Platform adapter isolation
**Status:** LOCKED SHARED

Shared packages do not directly import Android/Windows APIs. Platform contracts may represent secure storage, notifications, audio, camera, location, Health, Alarm scheduler, background work. Concrete adapters are isolated.

## D-SHARED-FLUTTER-06 — Shared design primitives, platform composition
**Status:** LOCKED SHARED

Share typography roles, spacing, corners, semantic colors, accent model, accessibility sizing, surface roles, animation policy, icon semantics. Desktop and Mobile compose them differently.

Current WBS `SoftGlass`-only wording should be revised.

## D-SHARED-FLUTTER-07 — Cross-language semantic parity
**Status:** LOCKED SHARED

Where Host Python and Mobile Dart/native implement the same behavior, machine-readable Golden fixtures/test vectors define parity, especially for temporal semantics, IDs, sync conflicts, conversation branching, tool-intent structures, health normalization, and capability records.

## D-SHARED-FLUTTER-08 — Shared feature core, platform-specific presentation
**Status:** LOCKED SHARED

Share domain models, repository contracts, controllers/view-model/domain state where appropriate, validation, test fixtures, reusable components.

Allow separate Desktop/Mobile screen composition and navigation.

“One codebase” does **not** mean one giant responsive screen full of `if (isMobile)` branches.

## D-PHONE-FLUTTER-01 — Kotlin prototype as evidence only
**Status:** LOCKED V1

Existing Kotlin/Compose `android/` is prototype/UX/research/migration evidence only. Production Flutter recovers intent and approved behavior, then redesigns against canonical architecture. Do not mechanically translate Kotlin to Dart.

---

# 15. Mobile Golden acceptance architecture

## D-MOBILE-VERIFY-01 — Product-centered Mobile Golden Gate
**Status:** LOCKED V1

Expand MG1–MG12 into MG1–MG18:

1. **MG1 Enrollment, Identity & Profile Isolation**
2. **MG2 Security, Secrets & Protected Transport**
3. **MG3 Connected Companion Operation**
4. **MG4 Standalone Mobile Core**
5. **MG5 Durable Offline State & Synchronization**
6. **MG6 Conversations, Branches & Turn Control**
7. **MG7 Context, Memory & Historical Recall**
8. **MG8 Character, Mood & Companion Continuity**
9. **MG9 Tasks, Reminders, Alarms & Temporal Semantics**
10. **MG10 Cross-Device Alert Arbitration**
11. **MG11 Routines, Check-ins & Companion Surfaces**
12. **MG12 Local Tools & Current Information**
13. **MG13 Voice & Speech Composition**
14. **MG14 Local Models, Resources & Capability Qualification**
15. **MG15 Health-Aware Companion**
16. **MG16 Multimodal Vision**
17. **MG17 Mobile UX, Accessibility & Personalization**
18. **MG18 Full Companion Journey**

### Key coverage expectations

**MG4 standalone:** Home, Schedule, Tasks, Mobile-created Reminders/Alarms, cached Character/Memory, Activity, Settings, model management, local notifications, truthful degradation.

**MG6 conversation:** SSE, offline local, authorized cloud, stable IDs, no Host regeneration, causal branches, Compare, queue, edit/remove queued before execution, interrupt/send, safe regenerate.

**MG7 context:** canonical Memory, pending overlay, Profile/Character scope, offline replica/pinning, summaries, raw history, provenance, no silent canonical Memory creation from ordinary offline chat.

**MG8 Character:** D11 traits/presets, cached Character, shared Mood, emotion-event sync, Character-bound history, emoji/expression fallback, no reattribution of Profile-owned data.

**MG9 scheduling:** offline Task CRUD, Mobile-origin Reminder/Alarm CRUD, Host-origin definition protection offline, UUID, snooze/dismiss, timezone, floating/fixed recurrence, NLP scheduling, ambiguity clarification, PC/Mobile parity. Golden phrases include “in 20 minutes”, “tomorrow evening”, “every weekday at 7”, “7 AM or PM?”, “next Friday”.

**MG10 arbitration:** PC preference where appropriate, phone standby, Reminder duplicate suppression, Alarm escalation, explicit dismissal propagation, passive display ≠ acknowledgement, connection-loss fallback, disconnected duplicate > missed Alarm.

**MG11 routines:** Host-authorized occurrence replication, offline presentation, no autonomous extension, missed occurrence collapse, local suppression, Character-aware wording, deterministic fallback, Home check-in/widget data.

**MG12 tools:** Tasks/Reminders/Alarms/Schedule/Memory/history/Web Search/WebFetch/Weather under D9; internet ≠ Cloud LLM.

**MG13 Voice:** Host pipeline, local STT+LLM+TTS, typed+local LLM+TTS, local STT+text; Whisper qualification, barge-in, lock-screen session, audio focus, route loss, cloud isolation, raw audio ephemerality.

**MG14 resources:** install/load/unload/switch/remove, one resident LLM, backend truth, CPU fallback where supported, thermal/memory/battery/context/capability gating.

**MG15 Health (conditional):** Health Connect permissions, metric granularity/source/freshness, unavailable ≠ zero, sleep/steps/heart rate/SpO₂/BP/temp/distance/calories, PC/Mobile normalized parity, Health ≠ Memory, non-clinical check-in, cloud-health consent.

**MG16 Vision (conditional):** camera/gallery attachment, Host/local/cloud routes, offline persistence, provenance, no silent cloud, Vision ≠ Memory.

**MG17 UX:** Home/Schedule/Companion/Activity/More, icon-first nav, screen reader semantics, OLED default, Dark/Light/System, hybrid Minimal+Neumorphic+Liquid Glass, reduced motion/effects, Companion language, extensible registry, code-switching, large-font usability.

**MG18 full journey:** enroll → Character → sync → disconnect PC → local chat → Task → Reminder → Routine check-in → Health → photo/Vision → Voice → reconnect → conflict resolution → continuity verification → revoke device.

## D-MOBILE-VERIFY-02 — Required vs Conditional qualification
**Status:** LOCKED V1

Golden results classify capabilities as REQUIRED, CONDITIONAL, OPTIONAL, or DEFERRED.

Examples:
- offline Task CRUD — REQUIRED
- production local LLM path — REQUIRED architecture/product path, per-device execution conditional
- local STT — CONDITIONAL
- Health Connect — CONDITIONAL
- local VLM — CONDITIONAL
- AR Presence — DEFERRED
- wake word — DEFERRED

## D-MOBILE-VERIFY-03 — Integrated Companion journey
**Status:** LOCKED V1

Release gate must prove the system as one coherent Companion product, not only isolated subsystems.

Exact test count, emulator/physical devices, benchmark thresholds, and cadence remain open.

---

# 16. CI architecture direction

## D-CI-01 — Flutter path-scoped verification
**Status:** LOCKED DIRECTION

Future conceptual lanes:

```text
classifier
├── backend
├── contract
├── frontend-web
├── docs
├── flutter-shared
├── flutter-desktop
└── flutter-mobile
```

## D-CI-02 — Shared-package fan-out
**Status:** LOCKED DIRECTION

Shared Flutter package changes run both Desktop and Mobile verification. Desktop-only → Desktop. Mobile-only → Mobile. Android-native adapter → Mobile + relevant Android tests.

## D-CI-03 — Tiered Mobile verification
**Status:** LOCKED DIRECTION

L1 Dart/domain/unit; L2 storage/package integration; L3 Android emulator/platform; L4 physical hardware; L5 live Host/network integration.

Do not run L3/L4/L5 for every trivial UI/Dart change. Hardware/thermal/exact-alarm/audio/Health/model qualification run at suitable milestones/gates.

## D-CI-04 — Do not implement Flutter CI before Flutter exists
**Status:** LOCKED DIRECTION

Document future routing in Batch D. Do not add active Flutter CI jobs to `.github/workflows/ci.yml` until M1 creates the actual Flutter workspace/dependencies.

---

# 17. Research / qualification requirements

## Gemma 3 1B cross-device qualification
**Status:** RESEARCH REQUIREMENT

Deliberately test Gemma 3 1B and other candidates on both PC and Mobile against a shared Companion capability suite.

Qualification record should conceptually bind:

```text
model artifact
+ quantization
+ runtime
+ runtime version
+ backend
+ hardware
+ context config
= qualification record
```

Test conversation, instruction following, Character adherence, context retention, English, Tagalog, Taglish, Japanese where relevant, structured scheduling, Task/Reminder extraction, safe tool intent, summarization, compaction, history continuation, and vision for multimodal candidates.

A model may qualify for some capabilities and not others. No single model must do everything.

---

# 18. Explicit future/deferred boundaries

Not Mobile V1 requirements unless another decision above explicitly says otherwise:

- always-on wake word
- background/ambient microphone eavesdropping
- ambient/background continuous camera
- AR Companion Presence
- Live2D/VRM/3D Presence
- remote expression-asset search/import
- direct vendor wearable integrations unless Health Connect is insufficient
- autonomous Mobile Routine recurrence beyond Host-issued occurrences
- unrestricted browser automation
- generic shell/terminal/system administration
- phone-to-phone canonical synchronization authority
- full UI translation for languages without actual localization resources

---

# 19. Explicit implementation-open / decision-debt items

Do **not** ask an implementation agent to invent these during reconciliation unless a contradiction requires human decision:

- exact local LLM runtime/backend
- exact model family/size/quantization
- exact Mobile minimum hardware
- exact CPU/GPU/NPU adapter
- exact context thresholds
- exact thermal/battery thresholds
- exact SQLite/Flutter persistence package
- exact sync table/schema names
- exact emotion event taxonomy
- exact Memory replica selection algorithm
- exact Alarm escalation grace
- exact daypart defaults
- exact temporal parsing library
- exact STT/TTS/VAD engines
- exact Voice codec/frame format
- exact Health schema/retention/cadence/baseline algorithm
- exact VLM qualification thresholds
- exact cloud provider/model list
- exact widget technology/refresh cadence
- exact icons/layout/spacing/animation timings
- exact Flutter package names/count
- exact state-management library
- exact generated-client technology
- exact CI emulator/physical matrix
- exact benchmark thresholds
- one Profile → multiple Mobile devices remains open
- exact Presence/AR implementation

---

# 20. Known canonical contradictions Batch D must reconcile

| Current canonical/plan wording | Approved Batch D direction |
|---|---|
| Mobile local LLM described as optional auxiliary capability | Mobile V1 product includes a real production-capable local LLM path for qualified devices; core still works without it |
| Host/internet/cloud expressed as coupled modes | Host reachability, internet, inference route are orthogonal |
| Character/Memory mostly cached read-only | Character stays D11; explicit offline Memory intent + pending overlay + selective offline replica approved |
| Reminder offline creation prohibited | Mobile-created Reminders may be authored/managed offline |
| Alarm canonical config PC-only | Mobile-created Alarms may be authored/managed offline; Host-created definitions read-only offline |
| Routine cached-view-only offline | Mobile may present bounded Host-authorized Routine occurrences offline |
| Health Connect = Mobile Later | Health Connect restored as optional/conditional read-only Mobile V1 |
| Local VLM = post-V1 only | Qualified local still-image Vision becomes conditional Mobile V1 |
| MG1–MG12 | Expand to product-centered MG1–MG18 |
| SoftGlass-only wording | Hybrid Minimalist + selective Neumorphism + Glass/Liquid Glass; OLED default |
| Prototype nav `Home / Tasks / Assistant / Health / More` | `Home / Schedule / Companion / Activity / More` |
| `Assistant` product-facing label | Prefer `Companion` in Mobile product UX where appropriate |
| fixed prototype language enum | Extensible language registry/capability qualification |
| Mobile screens implied as generic/shared | Share feature core; allow platform-specific Desktop/Mobile screens |
| Health/Vision/Routines listed as V1 non-goals in current WBS/PR | Update WBS/PR after canonical promotion |
| Current PR #21 claims MOBILE-ARCH complete | MOBILE-ARCH is reopened for Batch D until re-closed |

---

# 21. Canonical promotion targets after reconciliation approval

## Architecture
- `docs/04_Architecture/MOBILE_SYSTEM_BASELINE.md`
- `docs/04_Architecture/01_Domains/android-companion.md`
- `docs/04_Architecture/01_Domains/assistant-and-conversations.md`
- `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md`
- `docs/04_Architecture/01_Domains/memory-and-personalization.md`
- `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md`
- `docs/04_Architecture/01_Domains/voice-and-audio.md`
- `docs/04_Architecture/01_Domains/multimodal-and-media.md`
- `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md`
- `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md`
- `docs/04_Architecture/03_Integrations/health-and-wearables.md`
- `docs/04_Architecture/04_Infrastructure/mobile-offline-and-sync.md`
- `docs/04_Architecture/04_Infrastructure/mobile-capabilities-and-runtime.md`
- `docs/04_Architecture/04_Infrastructure/runtime-and-models.md`
- `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md`

## Design
Create/update Mobile-focused design specs under `docs/05_Design/` only after architecture ownership is aligned. Design must not redefine architecture.

## Planning
- `docs/02_Planning/00_Master/MOBILE_WBS.md`
- `docs/02_Planning/00_Master/MOBILE_CHECKLIST.md`
- `docs/02_Planning/00_Master/DECISION_REGISTER.md`
- `docs/02_Planning/00_Master/SPRINT_ROADMAP.md`
- `docs/02_Planning/00_Master/DELIVERY_INDEX.md`
- `docs/02_Planning/00_Master/DECISION_DEBT.md`
- `docs/06_Guides/DOCUMENTATION_MAP.md`
- PR #21 title/body/status after re-closure

The current 65-item Mobile WBS will need expansion/revision because several approved product-facing domains are absent or intentionally deferred in the old version.

---

# 22. Batch D first-step instructions for Gemini / Antigravity

When this ledger is supplied:

1. Read it completely.
2. Inspect the actual current branch and confirm the head.
3. Read current canonical PC/shared and Mobile docs named above.
4. Treat this as an **approved working decision source**, not proof canonical docs were already updated.
5. Do **not** edit canonical architecture yet.
6. Produce a reconciliation report mapping every decision to:
   - existing canonical owner
   - preserve / refine / supersede / new promotion
   - current contradiction
   - required canonical destination
   - planning/WBS/Golden impact
   - implementation-open details
7. Explicitly verify no Batch D decision conflicts with locked PC D7/D9/D10/D11, Voice, Runtime, identity/security, or multimodal architecture.
8. If a true conflict exists, **STOP and report it**. Do not invent.
9. Identify stale statements in current Mobile docs, WBS, checklist, roadmap, decision register, and PR #21.
10. Do not modify production code.
11. Do not modify `.github/workflows/ci.yml` yet.
12. Do not promote into canonical docs until Chris/GPT independently reviews the reconciliation report.
13. Do not change Git state.
14. Return:
    - exact files inspected
    - reconciliation matrix
    - contradictions
    - missing decisions
    - proposed promotion batches
    - files to edit in each batch
    - recommended commit checkpoints
    - one-line Conventional Commit suggestion for ledger/report checkpoint

---

# 23. Do-not-forget product summary

The reconciled Mobile product is not merely a remote PC chat client.

It is an enrolled Profile-bound Companion client that can, depending on capability and permission:

- operate independently of the PC
- run a local LLM
- converse offline
- preserve/sync conversation causality
- use Character/Personality/Mood
- retain selective Memory context
- accept explicit offline Memory intent
- manage Tasks
- create/manage Mobile-origin Reminders and Alarms offline
- receive Host-authorized Routine check-ins offline
- use typed local tools
- search/read public web/current information without requiring Cloud LLM
- use connected or composable local Voice
- read authorized Health Connect context for non-clinical personalization
- understand still images through Host/local/cloud multimodal routes
- present an OLED-first, Companion-centered Mobile UX
- degrade truthfully on weaker hardware
- preserve PC Host canonical authority and shared domain contracts

The point of this ledger is to ensure none of that disappears again because the next agent reads an older summary first.
