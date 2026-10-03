# AI Companion — MOBILE-ARCH Handoff

> Date: 2026-10-03
> Status: Draft handoff for the next canonical architecture pass
> Next durable direction: MOBILE-ARCH — Phone/Mobile V1 Canonical Architecture Pass
> Repository: chrisniel/AI-companion-project

---

# 1. Purpose of this handoff

This document preserves the reasoning, decisions, workflow rules, architecture boundaries, and next-step context required to continue AI Companion work in a fresh AI session without reconstructing the previous long conversation from scratch.

It is NOT itself canonical architecture.

Before making architectural or implementation decisions, the reviewing agent must inspect the current repository and canonical documentation.

Canonical repository truth overrides this handoff if a conflict exists.

Historical archives are evidence, not normative architecture.

---

# 2. Human / AI workflow and Git authority

Chris is the sole Git mutation owner.

Only Chris performs:

- branch creation
- checkout/switch
- staging
- commit
- push
- merge
- reset
- rebase
- stash
- tags
- PR creation/merge

AI agents may perform read-only Git/repository inspection.

Agents must NOT perform Git-write operations.

Read-only examples are acceptable:

- git status
- git diff
- git log
- git show
- git rev-parse
- GitHub/API inspection

Do not use commands such as `git checkout <ref> -- <path>` or `git restore` because these mutate the working tree.

Before non-trivial edits:

1. inspect the current branch;
2. if on `develop` or `master`, STOP;
3. ask Chris to create/switch/push the task branch;
4. continue all coherent PLAN → IMPLEMENT → DOCUMENT → CLOSURE work on that same task branch.

Do not create new branches merely because a lifecycle stage changed.

Split branches only for genuinely independent delivery/risk boundaries.

---

# 3. Required delivery lifecycle

Use this workflow for non-trivial work:

1. PLAN
2. PLAN REVIEW
3. PLAN REVISION if findings exist
4. PLAN APPROVAL
5. IMPLEMENTATION
6. IMPLEMENTATION REVIEW / GATE
7. IMPLEMENTATION CORRECTION if findings exist
8. IMPLEMENTATION APPROVAL
9. DOCUMENTATION
10. DOCUMENTATION REVIEW / GATE
11. DOCUMENTATION REVISION if findings exist
12. DOCUMENTATION APPROVAL
13. CLOSURE
14. CLOSURE REVIEW / GATE
15. CLOSURE CORRECTION if findings exist
16. PR handoff
17. PR CI / final-source verification
18. squash merge to `develop`
19. read-only post-merge verification

Important distinctions:

- implementation intent is not implementation evidence;
- source/static verification is not PR verification;
- PR verification is not merge evidence;
- merge evidence is not post-merge CI evidence;
- historical archives may truthfully say “PR integration pending at closure checkpoint” and should not later be rewritten merely because the PR merged.

Do not create cleanup branches solely to append a merge SHA or post-merge CI result to historical closure records.

Only create corrective follow-up work if:
- current canonical truth is materially false,
- dependent work is blocked,
- or a real integration defect exists.

---

# 4. Branch-safe task tracking

Tracking model:

`docs/01_Tracking/task.md`
= durable milestone / integration direction only.

`docs/01_Tracking/active/task-[branch-slug].md`
= transient branch execution state.

`docs/01_Tracking/archive/task-[YYYY-MM-DD]-[branch-slug].md`
= historical closure evidence.

GitHub PRs
= PR/merge truth.

GitHub Actions
= CI execution truth.

Startup behavior:

On `develop`/`master`:
- read shared `docs/01_Tracking/task.md`.

On an ordinary task branch:
- read the matching active task.
- read shared task only when milestone/integration context is needed.

Archives are ignored by default unless performing retrospective/historical review.

---

# 5. Current completed PC architecture baseline

The PC V1 canonicalization is complete and already integrated.

Important integrated PC architecture decisions include:

## Primary PC client

- Flutter Desktop is the production Windows client.
- React Web remains a supported browser/remote/regression client.
- React is NOT deprecated.
- Existing Kotlin Android code is prototype/reference evidence only.
- Intended production mobile foundation is Flutter.

## Local AI Runtime

- independent Python/FastAPI process;
- owns canonical conversations, memories, scheduler state, characters, personality, emotion, tasks, routines, model/provider state, policies, notification events, account/profile data, etc.;
- Flutter owns UI, window/tray behavior, native presentation, device/microphone/audio/file-picker concerns.

Runtime lifetime is independent from Flutter UI lifetime.

Closing Flutter does not imply stopping Runtime.

## Storage

- APP_INSTALL_ROOT = replaceable installer-owned application software location.
- DATA_ROOT = `%LOCALAPPDATA%\AI Companion\Data\`
- LIBRARY_ROOT = `%LOCALAPPDATA%\AI Companion\Library\`
- model/provider binaries and caches are separate from canonical user data.

## Model/provider architecture

Separate:
- model identity
- provider/runtime
- acceleration backend
- physical hardware

Current PC implementation may use llama.cpp/Vulkan, but architecture must remain provider/format independent.

## Account / Profile / Device / Session

- one local Account;
- multiple isolated Profiles;
- one human = one Profile;
- Work/Personal contexts for the same human are NOT separate Profiles;
- Profiles contain Characters/settings contexts;
- Device is a durable enrolled endpoint;
- browser tabs are Sessions, not Devices;
- mobile/satellite device binds to exactly one Profile;
- reassignment/revocation is controlled from PC;
- provider/model library/hardware are account/host-owned, not Profile-owned.

## Characters / Personality / Emotion

Eight continuous personality traits, each 0–100:

- Warmth
- Teasing
- Guardedness
- Directness
- Expressiveness
- Affection
- Formality
- Verbosity

Presets are editable starting points, not rigid classes.

Character Instances are Profile-owned snapshots/configurations derived from templates.

Template updates must never silently mutate existing Character Instances.

Emotion is bounded and persistent, but:
- never changes facts,
- never changes safety,
- never changes permissions,
- never changes scheduler correctness,
- never changes tool authority.

## Memory

Separate:
- full conversation history
- Memory
- retrieval/context
- Emotion

Memory extraction is deterministic-policy mediated.

LLM does not write canonical memory directly.

Candidate flow:

completed turn
→ candidate
→ structured candidate
→ deterministic policy
→ AUTO-SAVE / PROPOSE / IGNORE
→ reconciliation

Secrets are excluded.

Forget removes retrieval/context immediately and uses tombstones to prevent resurrection.

## D9 Actions / Tools

Pipeline:

Model
→ Typed Request
→ Deterministic Policy
→ Narrow Adapter
→ Capability

Risk model:

- Risk 0: read-only
- Risk 1: reversible
- Risk 2: significant, confirmation default
- Risk 3: generic shell/filesystem/admin capability rejected

No raw generic shell authority.

External content, memory, conversation history, local model, and cloud model have no independent authority.

Confirmation is bound to action + target + parameters + Profile + session + expiry/fingerprint.

## Scheduler

Task, Reminder, Alarm, Routine are distinct.

Runtime `SchedulerService` owns durable schedule truth.

Must handle:
- recurrence
- timezone
- restart
- wake
- clock change
- missed events
- snooze
- quiet hours
- stale routines

Alarms may bypass quiet hours depending on configuration.
Reminders/Routines respect quiet hours.

## Voice

Flutter owns hardware/audio I/O.

Runtime owns:
- STT/TTS orchestration
- VAD/session state
- provider lifecycle

Voice transport uses WebSocket.

Mandatory barge-in.

Wake word deferred.

## Local/cloud

Fresh PC defaults to `LOCAL_ONLY`.

Optional explicit fallback modes may include:
- LOCAL_FIRST
- CLOUD_PREFERRED
- CLOUD_ONLY

Resource pressure must never silently send private content to cloud.

Cloud memory is a separate permission.

## Remote access

No direct router port forwarding.

Preferred trusted-device path:
- Tailscale.

Preferred browser/internet path:
- named Cloudflare Tunnel + Cloudflare Access.

Cloudflare Access does not replace application authentication.

## Backup/recovery

Back up:
- database
- Profile assets
- configuration
- tombstones

Do not back up:
- model binaries
- provider binaries
- caches
- logs
- secrets

Restore flow:
stage
→ verify
→ confirm
→ quiesce
→ safety backup
→ activate
→ restart
→ verify

---

# 6. Golden PC V1 verification groups

The final PC V1 release gate has 14 groups:

G1 — lifecycle/startup/process
G2 — Account/multi-Profile/privacy
G3 — Runtime/models/D6
G4 — conversations/queues/multimodal
G5 — Character/Personality/Emotion
G6 — Memory/history
G7 — D9 actions/tools
G8 — scheduler/notifications
G9 — voice/barge-in
G10 — web/current information
G11 — local/cloud behavior
G12 — Low-Impact/Gaming mode
G13 — backup/delete/restore/reset
G14 — remote/resilience

---

# 7. PC-VERIFY-001 CI modernization

CI modernization was implemented in the delivery:

`chore/ci-scoped-matrix`

PR:
#20

The architecture is classifier-driven.

Current lane design:

- classifier — Ubuntu
- backend — Windows / Python 3.11
- frontend — Windows / Node 22
- contract — Windows / Python 3.11
- docs-integrity — Ubuntu
- ci-gate — Ubuntu, always-running aggregate gate

Policy source:

`scripts/ci_policy.py`

Tests:

`scripts/tests/test_ci_policy.py`

Current rules:

ordinary short-lived branch push
→ no automatic CI workflow

PR → develop
→ scoped/path-aware verification

push → develop
→ scoped integration verification

PR → master
→ Full Verification

push → master
→ Full Verification

workflow_dispatch
→ Full Verification

backend/**
→ backend + contract

frontend/**
→ frontend

contracts/**
→ contract

scripts/check_openapi_contract.py
→ contract

docs/**
and allowed root Markdown
→ docs-integrity

unknown/shared/config/CI paths
→ conservative Full Verification

CI gate is fail-closed:
- required lane must succeed;
- unrequired lane must be skipped;
- malformed/missing requirement output fails;
- failed/cancelled/skipped required lanes fail.

Branch protection is NOT automatically implied by ci-gate existence.

Repository branch-protection settings remain a separate GitHub configuration concern.

## Docs-integrity refinement

The docs-integrity lane should protect documentation responsibility, not act as repository-wide whitespace police.

Its useful responsibilities are:

- canonical doc presence;
- documentation-specific integrity checks;
- docs-only PR verification.

It should not reject unrelated Python/YAML whitespace merely because docs-integrity ran.

---

# 8. Current delivery sequence

The intended durable sequence is:

PC architecture canonicalization — COMPLETE
↓
PC-VERIFY-001 CI modernization — COMPLETE / PR integration verification pending until merged
↓
MOBILE-ARCH — NEXT
↓
M1 Flutter Desktop Client Foundation
↓
M2 PC Companion Foundation
↓
M3 Intelligence & Productivity
↓
M4 Voice, Tools & Current Information
↓
M5 Integration / Resilience / Hardening
↓
Golden PC V1 Acceptance

Critical distinction:

MOBILE-ARCH is a prerequisite before M1.

Mobile IMPLEMENTATION does not block PC V1 unless a future approved decision changes that.

---

# 9. MOBILE-ARCH objective

MOBILE-ARCH must canonicalize the production Phone/Mobile V1 architecture BEFORE PC Flutter implementation begins.

The purpose is NOT to independently reinvent AI Companion on mobile.

The mobile architecture must:

1. inherit shared ecosystem rules from the PC/system baseline;
2. identify genuinely shared concerns;
3. identify PC-specific concerns;
4. identify mobile-specific concerns;
5. resolve mobile constraints before Flutter package/application boundaries are frozen;
6. create the Mobile System Baseline;
7. create the Mobile WBS / planning spine;
8. determine how PC and Mobile Flutter code should share packages;
9. convert existing mobile evidence into reviewed architectural decisions.

Do not copy PC implementation assumptions where mobile constraints differ.

Do not duplicate shared architecture merely because the client is mobile.

---

# 10. Expected Flutter direction to evaluate during MOBILE-ARCH

Conceptual direction only, NOT yet locked:

flutter/
  apps/
    desktop/
    mobile/
  packages/
    shared domain/auth/profile/conversation/etc.

Potential shared concerns:

- API contracts
- Account/Profile concepts
- Character identity/configuration
- Memory concepts
- conversation models
- D9 action request/confirmation concepts
- scheduler domain objects
- session/auth semantics
- shared validation/domain models
- reusable design tokens/UI primitives where appropriate

PC-specific concerns include:

- Windows window lifecycle
- tray integration
- Windows native notifications
- Windows Task Scheduler
- desktop file picker/admin surfaces
- host Runtime supervision
- PC-only configuration/admin screens

Mobile-specific concerns include:

- Android lifecycle
- background execution restrictions
- battery optimization
- foreground services where justified
- Android permission model
- notification channels
- offline operation
- sync/outbox behavior
- mobile storage/cache strategy
- connectivity transitions
- local inference resource constraints
- thermal constraints
- secure mobile credentials
- Android platform integration
- eventual wearables/Health Connect evaluation if approved

Do not lock the exact package layout before the MOBILE-ARCH analysis is complete.

---

# 11. Existing Android status

Current Kotlin/Compose Android code is:

PROTOTYPE / REFERENCE EVIDENCE ONLY.

It must not be silently promoted into the production architecture.

Production mobile direction is Flutter unless MOBILE-ARCH produces a reviewed reason to change that.

Package identity currently preserved:

`com.cnl.aicompanion`

One mobile/satellite device binds to one Profile.

Provider/API/device credentials remain local to the device.

---

# 12. Mobile benchmark evidence already collected

The user previously tested PocketPal on:

Infinix ZERO ULTRA
- Dimensity 920
- 8 GB RAM
- Android 13

Approximate observed benchmark evidence:

Gemma 3 270M Q8
- prompt processing ≈ 172.79 t/s
- token generation ≈ 25.56 t/s
- memory ≈ 754 MB

Llama 3.2 1B
- prompt processing ≈ 42.87 t/s
- token generation ≈ 12.37 t/s

Qwen 3.5 0.8B
- prompt processing ≈ 62.49 t/s
- token generation ≈ 14.81 t/s

Qwen 3 0.6B
- prompt processing ≈ 52.31 t/s
- token generation ≈ 11.75 t/s

These numbers are RESEARCH EVIDENCE ONLY.

They must not automatically become architecture.

During MOBILE-ARCH:

- store benchmark screenshots/raw evidence under something like:

  `docs/00_Drafts/research/mobile/benchmarks/infinix-zero-ultra/`

- distinguish:
  raw measurement
  interpretation
  recommendation
  canonical decision

- evaluate realistic:
  memory budget
  battery cost
  thermal behavior
  sustained throughput
  background restrictions
  offline usefulness
  model loading time
  context-size tradeoffs
  provider/runtime options

The user may re-upload the benchmark screenshots in the new chat.

---

# 13. Mobile architecture questions that still need deliberate resolution

MOBILE-ARCH must investigate and decide, not assume:

## Shared Flutter structure

- one repo, separate desktop/mobile apps?
- which packages are genuinely shared?
- which UI components should share code?
- which services require platform adapters?

## Mobile runtime topology

Possible questions:

- Does mobile run a lightweight local runtime?
- Does mobile communicate with the PC Runtime when available?
- Does it use cloud independently?
- What is the priority/fallback order?
- Can it operate offline?
- What features remain available offline?

## Sync

Decide:

- authoritative source per object/domain;
- PC↔mobile synchronization model;
- conflict behavior;
- offline mutation/outbox model;
- reconnect reconciliation;
- duplicate prevention;
- tombstone propagation;
- profile isolation;
- character/memory/scheduler sync boundaries;
- whether some domains intentionally do not sync.

Do not blindly choose Room/outbox merely because it appeared in older drafts.

## Local storage

Evaluate appropriate Flutter/mobile persistence behind repository/adapters.

Exact DB technology is not yet locked.

## Local mobile inference

Evaluate:
- candidate provider/runtime;
- small-model classes;
- supported hardware tiers;
- optional local model behavior;
- whether mobile inference is mandatory or opportunistic;
- when PC/cloud fallback is allowed.

## Background work

Explicitly account for Android restrictions:

- battery optimization
- Doze
- WorkManager-like scheduling if applicable
- foreground services
- notification requirements
- network availability
- OS process death

## Notifications

Clarify:
- mobile native notification presentation;
- scheduler truth ownership;
- local alarms vs server/PC-backed events;
- missed events;
- duplicate suppression;
- offline behavior.

## Permissions/privacy

Define:
- microphone
- media/files
- notifications
- location if ever needed
- health/wearables if ever enabled
- Bluetooth if needed
- background access

Use minimum permission principle.

## Voice

Reuse shared voice/session concepts while respecting mobile audio lifecycle.

## Security

Preserve:
- per-device revocable credentials;
- no shared master secret;
- one Profile per satellite mobile device;
- Profile identity determined by auth/session;
- transport encryption;
- revocation from PC;
- no arbitrary Profile assertion by clients.

---

# 14. Mobile canonical deliverables expected

MOBILE-ARCH should eventually produce a focused canonical set rather than one giant document.

Likely artifacts may include:

- MOBILE_SYSTEM_BASELINE.md
- mobile-client-and-lifecycle.md
- mobile-storage-and-offline.md
- mobile-sync-and-reconciliation.md
- mobile-auth-and-device-binding.md
- mobile-local-inference.md
- mobile-notifications-and-background-work.md
- mobile-voice-and-audio.md
- mobile-performance-and-capacity.md
- mobile-security-and-privacy.md

Exact names may be adjusted after repository inspection.

Also update:

- DOCUMENTATION_MAP
- DELIVERY_INDEX
- SPRINT_ROADMAP
- WBS
- MASTER_CHECKLIST
- DECISION_REGISTER / ADRs if new accepted architecture decisions require them

Do NOT start by editing all of these.

Start with PLAN.

---

# 15. CI direction for Flutter

Future CI should remain classifier-driven and scoped.

Expected eventual conceptual lanes:

classifier
├── backend
├── contract
├── frontend-web
├── docs-integrity
├── flutter-desktop
├── flutter-mobile
└── ci-gate

Potential behavior:

shared Flutter package change
→ desktop + mobile Flutter verification

desktop-only Flutter change
→ desktop Flutter lane only

mobile-only Flutter change
→ mobile Flutter lane only

shared OpenAPI/domain/auth/Profile change
→ applicable generated client/shared tests

Avoid Android emulator/device tests for every trivial Dart change.

Prefer:

cheap shared Dart/unit/widget verification
→ Linux when platform-independent

Windows integration tests
→ only for actual Windows-specific behavior

Android/emulator/platform verification
→ only where mobile platform behavior requires it

Exact CI rules belong to later implementation once Flutter structure is frozen.

---

# 16. Remaining PC milestones after MOBILE-ARCH

## M1 — Flutter Desktop Client Foundation

- scaffold production Flutter Windows app;
- window/tray lifecycle;
- theme/design system;
- REST/SSE client;
- OpenAPI-derived/mechanically checked Dart client;
- PC Flutter CI;
- preserve React Web as supported browser/remote/regression client.

## M2 — PC Companion Foundation

- Windows autostart
- native notifications
- multi-Profile DB migration
- Device/Session/Profile foundations
- D6 controlled model import
- storage relocation
- host/runtime lifecycle hardening

## M3 — Intelligence & Productivity

- Character Studio
- templates/instances
- eight personality traits
- bounded Emotion
- Profile/Character Memory
- extraction/reconciliation
- temporary memory/revalidation
- SchedulerService
- Tasks/Reminders/Alarms/Routines

## M4 — Voice, Tools & Current Information

- STT/TTS
- VAD
- voice conversation
- mandatory barge-in
- D9 policy engine
- read-only WebSearch/WebFetch/Weather
- SSRF containment

## M5 — Integration / Resilience / Hardening

- Low-Impact/Gaming
- lightweight model substitution
- backup
- restore
- Factory Reset
- remote hardening
- local/cloud fallback
- release stabilization

Then execute Golden PC V1.

---

# 17. Style of reasoning expected from the AI reviewer

Do not reflexively agree.

Challenge assumptions.

Differentiate:

- evidence
- inference
- proposal
- approved decision
- implementation fact
- historical evidence
- future target

Do not claim something is implemented merely because documentation describes it.

When reviewing another AI agent:

- inspect actual source/repo;
- do not trust self-reported success;
- identify concrete line/file-level findings;
- prefer surgical corrections once architecture is stable;
- avoid reopening resolved architecture without a genuine contradiction.

---

# 18. Commit-message convention

Whenever a user-visible checkpoint is ready for Chris to push, always include one short one-line Conventional Commit suggestion.

Example:

`docs(mobile): establish mobile architecture baseline`

Do not bury the commit suggestion inside a long paragraph.

---

# 19. Immediate startup procedure for the next AI session

Before beginning MOBILE-ARCH:

1. inspect current branch;
2. inspect `develop`;
3. determine whether PR #20 was merged;
4. if merged, inspect the squash merge SHA;
5. inspect the post-merge `develop` CI result;
6. verify the integrated CI source matches the approved behavior;
7. do NOT create a cleanup branch merely to write merge evidence into the historical archive;
8. then inspect:

   - AGENTS.md
   - docs/01_Tracking/task.md
   - docs/06_Guides/DOCUMENTATION_MAP.md
   - docs/04_Architecture/SYSTEM_BASELINE.md
   - docs/02_Planning/00_Master/DELIVERY_INDEX.md
   - docs/02_Planning/00_Master/SPRINT_ROADMAP.md
   - docs/02_Planning/00_Master/WBS.md
   - docs/02_Planning/00_Master/BACKLOG.md
   - docs/02_Planning/00_Master/MASTER_CHECKLIST.md
   - docs/02_Planning/00_Master/DECISION_REGISTER.md
   - docs/02_Planning/00_Master/DECISION_DEBT.md
   - relevant ADRs
   - current Android prototype/reference code
   - relevant Flutter/PC-client architecture docs
   - this handoff

9. summarize current truth before proposing changes;
10. produce a MOBILE-ARCH PLAN only;
11. stop for human review before editing canonical architecture.

---

# 20. First MOBILE-ARCH task

The first task is NOT implementation.

The first task is:

Create a formal MOBILE-ARCH plan describing:

- documents/files to inspect;
- mobile evidence to collect;
- PC/shared/mobile boundary questions;
- proposed architecture decision sequence;
- benchmark incorporation method;
- canonical deliverables;
- WBS/planning updates;
- unresolved decisions requiring human input;
- explicit non-goals;
- review/approval gates.

Do not edit canonical architecture until that PLAN is reviewed and approved.

---

# 21. Benchmark images

If benchmark screenshots are not present in the repository, the user may re-upload them in the new chat.

Do not require the screenshots before initial repository reconstruction.

Use them during the research/evidence phase of MOBILE-ARCH.

The screenshots are supporting evidence, not normative truth.

---

# End of handoff