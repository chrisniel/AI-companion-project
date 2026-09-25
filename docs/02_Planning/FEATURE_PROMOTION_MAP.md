# AI Companion — Feature Promotion Map & Migration Manifest

> **Document Role:** Temporary reconciliation control manifest (Passes R10–R13).  
> **Status:** Active Working Manifest (Pass R10 Refinement)
> **Authority Precedence:** Normative architectural baseline is owned by [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md). Active execution state is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md). Detailed domain specifications reside in [`docs/04_Architecture/`](../04_Architecture/).  
> **Purpose:** Prevents informal, unreviewed, or deprecated ideas from drafts, historical archives, or recovery notes from silently becoming canonical architecture without explicit review, attribution, release allocation, and single canonical destination.

---

## 1. Governance & Taxonomy

Every feature or capability tracked through the reconciliation process is evaluated against three independent dimensions:

### 1.1 Intent Status
- **`LOCKED`**: Immutable architectural invariant; changes require formal architecture review and ADR.
- **`APPROVED`**: Confirmed product capability; implementation design may evolve.
- **`PROVISIONAL`**: Current direction, explicitly designated for near-term re-evaluation.
- **`OPEN DESIGN`**: Approved functional requirement whose exact technical mechanism remains open.
- **`EXPERIMENTAL`**: Exploratory research or prototyping effort; not committed release scope.
- **`DEFERRED`**: Valid capability intentionally postponed beyond near-term milestones.
- **`REJECTED`**: Explicitly excluded from ordinary assistant capability or supported trust model.

### 1.2 Delivery Status
- **`NOT STARTED`**: Approved/planned capability with zero codebase implementation.
- **`PLANNED`**: Scheduled for implementation with active or prerequisite planning in progress.
- **`IN PROGRESS`**: Actively under implementation on a dedicated branch.
- **`IMPLEMENTED`**: Code merged and present in the verified baseline.
- **`VERIFIED`**: Implemented and validated through automated test suites and repository checks.

### 1.3 Release Allocation
- **`PC V1`**: Mandatory delivery milestone for the initial PC-hosted ecosystem release.
- **`PC LATER`**: Approved PC capability scheduled for post-PC-V1 delivery tracks.
- **`ANDROID V1`**: Mandatory delivery milestone for the follow-on production mobile release.
- **`ANDROID LATER`**: Approved Android capability scheduled after Android V1.
- **`FUTURE / UNSCHEDULED`**: Evaluated capability without committed release scheduling.
- **`N/A`**: Applied to rejected capabilities or non-feature governance items.

### 1.4 Allowed Dispositions
- **`PRESERVE`**: Current canonical documentation is already accurate; retain as authoritative.
- **`PROMOTE`**: Previously draft, post-V1, or unmentioned item now formally approved into canonical architecture.
- **`CONSOLIDATE`**: Fragmented or duplicate statements unified into a single canonical destination.
- **`SUPERSEDE`**: Valid legacy statement formally replaced by an updated human decision.
- **`KEEP OPEN`**: Capability approved in principle while the implementation mechanism remains open design.
- **`DEFER`**: Valid capability explicitly scheduled for a later release milestone.
- **`REJECT`**: Explicitly excluded from ordinary assistant capability or supported trust model.
- **`ARCHIVE AS EVIDENCE`**: Historical documentation preserved strictly as non-normative context.

---

## 2. Strategic Feature Promotion Manifest (R10 Relock)

| SOURCE | FEATURE | OLD STATUS | NEW INTENT STATUS | DELIVERY STATUS | RELEASE | CANONICAL DESTINATION | DISPOSITION | CONFLICT NOTES |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `SYSTEM_BASELINE.md` §2 | **Local Text LLM Inference** | Implemented (V1) | `LOCKED` | `VERIFIED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/runtime-and-models.md` | `PRESERVE` | Verified via `llama.cpp` Vulkan on RX 580 baseline. Durable PC V1 requirement is hardware/runtime-portable local inference under Local AI Runtime. |
| `SYSTEM_BASELINE.md` §2 | **Multimodal Vision Understanding** | In Progress (8B) | `APPROVED` | `IN PROGRESS` | `PC V1` | `docs/04_Architecture/01_Domains/multimodal-and-media.md` | `PRESERVE` | Slices 8B.0–8B.6 verified in `develop`. Slice 8B.7 (persisted rendering) is next; 8B.8 planned. Full Phase 8B remains in progress. |
| `SYSTEM_BASELINE.md` §2 | **Memory Persistence & Retrieval** | Implemented (V1) | `LOCKED` | `VERIFIED` | `PC V1` | `docs/04_Architecture/01_Domains/memory-and-personalization.md` | `PRESERVE` | Durable capability is persistent/retrievable memory under Profile ownership (Decision D7). Current verified implementation uses SQLite + FTS5 lexical keyword retrieval; FTS5 itself is not a permanent architectural constraint. Semantic/vector memory remains APPROVED / PC LATER. |
| `Context v2` §22 (P3) | **Selective Automatic Memory** | Unmentioned / Draft | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/memory-and-personalization.md` | `PROMOTE` | Approved PC V1 direction. Selective assistant-proposed memory capture under deterministic policy with user visibility and deletion control. Character-scoped memory remains Profile-owned. Extraction model, confidence logic, cadence, and schema remain OPEN DESIGN. |
| `SYSTEM_BASELINE.md` §2 | **Task CRUD & Lifecycle Foundation** | Implemented (V1) | `LOCKED` | `VERIFIED` | `PC V1` | `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` | `PRESERVE` | Task CRUD, soft-delete, and retention thresholds are implemented and verified in the baseline. Separated from future scheduling/reminder runtime under Decision D10. |
| `SYSTEM_BASELINE.md` §2 / `Context v2` §23 | **Reminder & Alarm Scheduling Foundation** | Unmentioned / Draft Gap | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` | `PROMOTE` | Promoted under Decision D10 as distinct scheduling entities with native Windows notification delivery, quiet hours, and best-effort wake. Detailed schemas, status enums, and scheduler engine remain OPEN DESIGN. |
| `PROACTIVE_COMPANION_ROUTINES.md` | **Bounded Companion Routines** | Post-V1 Planning | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/tasks-reminders-alarms-and-routines.md` | `PROMOTE` | Promoted to PC V1 under Decision D10. Configurable recurring check-ins with bounded scheduler proactivity; character layer controls phrasing. |
| `Context v2` §22 (P20) | **Multilingual Companion Interaction** | Voice Spec Draft | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/assistant-and-conversations.md` | `PROMOTE` | Interaction support across English, Tagalog, Japanese, and code-switching without promising full UI localization. Truthfully bounded by model/provider capabilities. Language detection/switching logic remains OPEN DESIGN. |
| `SYSTEM_BASELINE.md` §2 | **Conversational Voice (STT / TTS)** | Excluded Post-V1 | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/voice-and-audio.md` | `PROMOTE` | Promoted to PC V1 as provider-independent STT/TTS capability without wake word. Specific engines (Kokoro, Whisper) remain candidate adapters in domain specs. |
| `VOICE_AND_AUDIO_ARCHITECTURE.md` | **Wake Word Detection** | Post-V1 | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/01_Domains/voice-and-audio.md` | `DEFER` | Retained as post-PC-V1 speech capability. Decoupled from conversational voice. Candidate engine: `openWakeWord`. |
| `SYSTEM_BASELINE.md` §2 | **Public Current Information** | Excluded Post-V1 | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/03_Integrations/web-current-information.md` | `PROMOTE` | Promoted to PC V1 as provider-independent read-only WebSearch, Fetch, and Weather capabilities. Specific services (Tavily, Open-Meteo) remain candidate adapters. |
| `SECURITY_AND_TRUST_ARCHITECTURE.md` §6 | **Interactive Browser Automation** | Candidate Tool | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md` | `DEFER` | Form filling, session handling, and browser interaction remain deferred post-PC-V1. Candidate provider: Playwright. |
| `SECURITY_AND_TRUST_ARCHITECTURE.md` §5 | **Generic Shell / OS Administration** | Prohibited | `REJECTED` | `NOT STARTED` | `N/A` | `docs/04_Architecture/02_Data_and_Security/tool-permissions-and-actions.md` | `REJECT` | Arbitrary command shell / PowerShell / unrestricted OS execution is strictly PROHIBITED as a generic assistant tool (Risk 3 / DEFAULT DENY). Must NOT be promoted to PC Later. Narrow elevated actions require separate typed designs. |
| `SYSTEM_BASELINE.md` §3 | **Native Windows Notifications** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` | `PROMOTE` | Promoted to PC V1 under Decisions D2 and D10. Direct OS notification delivery ensures alerts trigger even when browser client is closed. Adapter mechanism is OPEN DESIGN. |
| `SYSTEM_BASELINE.md` §3 | **Windows Host Autostart at Login** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` | `PROMOTE` | Promoted to PC V1 under Decision D2. Decoupled host runtime launches automatically on user login. Exact Windows launch mechanism remains OPEN DESIGN. |
| `SYSTEM_BASELINE.md` §3 | **Native Desktop Shell (Tauri)** | Post-V1 | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/04_Infrastructure/windows-host-and-notifications.md` | `DEFER` | React Web remains primary UI for PC V1. Dedicated packaged desktop shell container deferred to PC Later. |
| `MEMORY_AND_CHARACTER_ARCHITECTURE.md` §4 | **Character Configuration Persistence** | Unimplemented | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md` | `PROMOTE` | PC V1 requires persistent Character configuration and persona continuity under PC host authority. Exact database schema remains OPEN DESIGN. |
| `MEMORY_AND_CHARACTER_ARCHITECTURE.md` §1 | **Separate Personality Configuration** | Merged in Persona | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md` | `PROMOTE` | Formalized under Decision D11 as separate behavioral style/trait configuration independent from visual lore. |
| `Context v2` §24 | **Lightweight Conceptual Emotion** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md` | `PROMOTE` | Promoted under Decision D11. Transient mood modulation without clinical/psychological claims. Exact state dimensions and decay remain OPEN DESIGN. |
| `Context v2` §24 | **Relationship State** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/01_Domains/characters-personality-and-emotion.md` | `DEFER` | Formalized under Decision D11 as a separate, opt-in, hidden-by-default capability scheduled for PC Later. Decoupled from Emotion and Personality. |
| `ROADMAP.md` §4 | **Semantic / Vector Memory** | Post-V1 | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/01_Domains/memory-and-personalization.md` | `DEFER` | Approved architectural track deferred beyond PC V1. FTS5 lexical search remains the verified PC baseline. |
| `ROADMAP.md` §4 | **Managed Online Model Downloading** | Post-V1 Track M-Acquisition | `APPROVED` | `NOT STARTED` | `PC LATER` | `docs/04_Architecture/04_Infrastructure/runtime-and-models.md` | `DEFER` | Managed public model-hub downloading is NOT a prohibited capability. Reclassified from audit-era exclusion to approved post-PC-V1 track. Exact downloader/hub integration remains open design. |
| `SYSTEM_BASELINE.md` §2 | **Optional Cloud LLM Fallback** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/runtime-and-models.md` | `PROMOTE` | Promoted to PC V1 as an opt-in fallback. Local inference remains default and primary; requires explicit credentials and egress transparency. |
| `Context v2` §22 | **Gaming / Low-Impact Resource Mode** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/performance-and-capacity.md` | `PROMOTE` | Promoted to PC V1 as a dynamic resource policy. Throttling and notification suppression mechanics remain OPEN DESIGN. |
| `ROADMAP.md` §6 | **Practical Backup & Recovery** | Audit Recom. | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/04_Infrastructure/backup-recovery-and-diagnostics.md` | `PROMOTE` | Promoted to PC V1 requirement. Database snapshot and asset recovery mechanisms remain OPEN DESIGN. |
| `SYSTEM_BASELINE.md` §2 | **PC Health Context Readiness** | Excluded Post-V1 | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/03_Integrations/health-and-wearables.md` | `PROMOTE` | Promoted to PC V1 as conceptual data contract readiness. Physical wearable synchronization belongs to Android V1. |
| `ANDROID_COMPANION_ARCHITECTURE.md` §1 | **Android Connected Sync** | Post-V1 | `APPROVED` | `NOT STARTED` | `ANDROID V1` | `docs/04_Architecture/01_Domains/android-companion.md` | `SUPERSEDE` | Reclassified from generic "post-V1" to Android V1 core capability. PC Local AI Runtime remains canonical persistent authority. Does not block PC V1. |
| `ANDROID_COMPANION_ARCHITECTURE.md` §3 | **Android Practical Offline LLM** | Post-V1 | `APPROVED` | `NOT STARTED` | `ANDROID V1` | `docs/04_Architecture/01_Domains/android-companion.md` | `SUPERSEDE` | Reclassified from generic "post-V1" to Android V1 requirement. Model family, format (GGUF or other), parameter size, and quantization remain OPEN DESIGN. |
| `ANDROID_COMPANION_ARCHITECTURE.md` §3 | **Android Device-Local TTS** | Post-V1 Optional | `EXPERIMENTAL` | `NOT STARTED` | `FUTURE / UNSCHEDULED` | `docs/04_Architecture/01_Domains/android-companion.md` | `KEEP OPEN` | Historical optional idea only ("where feasible"). Not an Android V1 requirement. No Android Later release commitment is currently locked. Preserved without premature approval or scheduling. |
| `SYSTEM_BASELINE.md` §2 | **Android Health Connect** | Excluded Post-V1 | `APPROVED` | `NOT STARTED` | `ANDROID V1` | `docs/04_Architecture/03_Integrations/health-and-wearables.md` | `SUPERSEDE` | Reclassified from generic "post-V1" to Android V1 core requirement for biometric context summaries. |
| `Master Plan` §4 | **Stable Diffusion Presence Renderer** | Post-V1 Brainstorm | `EXPERIMENTAL` | `NOT STARTED` | `FUTURE / UNSCHEDULED` | `docs/04_Architecture/01_Domains/multimodal-and-media.md` | `KEEP OPEN` | Exploratory generative presentation renderer; distinct from advanced Presence. Evaluated as experimental; design presentation notes cross-reference `05_Design/presence-and-visuals.md`. |
| `SYSTEM_BASELINE.md` §4 | **Multi-Profile Architecture** | Single-User Baseline | `PROVISIONAL` | `NOT STARTED` | `FUTURE / UNSCHEDULED` | `docs/04_Architecture/02_Data_and_Security/profiles-and-devices.md` | `KEEP OPEN` | Single-primary-user baseline preserved for V1 (Decision D8). Multi-profile support remains a possible future architectural consideration without an approved delivery commitment. |
| `SYSTEM_BASELINE.md` §3 | **Direct Public Internet Port Forwarding** | Prohibited | `REJECTED` | `NOT STARTED` | `N/A` | `docs/04_Architecture/02_Data_and_Security/authentication-and-secrets.md` | `REJECT` | Excluded from supported trust model. Network access bounded to Localhost, trusted LAN, and Tailscale mesh. |
| `ROADMAP.md` §2 | **Golden PC V1 Acceptance Journey** | Unmentioned | `APPROVED` | `NOT STARTED` | `PC V1` | `docs/04_Architecture/SYSTEM_BASELINE.md` | `PROMOTE` | Integrated end-to-end companion verification path proving seamless operation across all PC V1 capabilities. |

---

## 3. Migration Tracking Notes

1. **Staged Domain Architecture Mapping:** Each canonical destination listed above corresponds to the staged target architecture established in the approved reconciliation strategy. During Passes R10 and R11, semantics will be migrated and codified into these destinations before oversized legacy files are narrowed or retired.
2. **One Destination Invariant:** In accordance with reconciliation rules, every promoted capability points to exactly one normative architectural destination. Cross-cutting summaries in `SYSTEM_BASELINE.md` and UI presentation specs in `docs/05_Design/` serve as indexes or experience views, not duplicate normative owners.
