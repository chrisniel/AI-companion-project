# AI Companion — Runtime Configuration, Persistent Data & Asset Library Architecture

> **Project:** AI Companion  
> **Backend service:** Local AI Runtime  
> **Document role:** Canonical architecture plan for naming, configuration, persistent data, model/voice assets, runtime modularity, character identity, and Phase 8 prerequisites  
> **Target repository path:** `docs/04_Architecture/AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md`  
> **Status:** Final planning baseline; implementation still requires explicit user approval  
> **Current implementation baseline:** Windows + `llama.cpp` b10936 Vulkan; current tested hardware is AMD RX 580 8 GB  
> **Last updated:** 2026-09-14

---

## 1. Purpose

This document captures architectural decisions that must not be lost while Phase 8 is being planned.

The AI Companion project must remain:

- provider-independent;
- character-independent;
- model-configurable;
- runtime-configurable;
- device-configurable;
- local-first;
- persistent across application reinstall where the user preserves data;
- modular enough to support future runtime distributions such as CUDA without redesigning the application contract.

This document does **not** authorize implementation by itself. It defines the architecture that Phase 8 planning and later implementation must follow.

The immediate Phase 8 sequence becomes:

```text
8A — Frontend Architecture & UX Foundation
        ↓
8P — Runtime Configuration & Persistent Asset Foundation
        ↓
8B — Multimodal Image Attachments
        ↓
8C — Integration, Accessibility & Polish
```

A later dedicated Model/Voice Import Manager may expand the asset-library capabilities defined here.

---

# 2. Canonical Naming and Identity

## 2.1 Product identity

The canonical product/ecosystem name is:

```text
AI Companion
```

This is the stable application/project identity.

Do not hardcode a character name as the application identity.

## 2.2 Backend identity

The canonical backend service name is:

```text
Local AI Runtime
```

`Local AI Core` is legacy terminology and should be removed from current/canonical architecture, UI, configuration labels, and active implementation where practical.

Historical walkthroughs may retain old wording when it accurately describes historical evidence.

## 2.3 Character identity

Characters are configurable profiles, never backend identity.

Example:

```text
AI Companion
└── Active Character
    └── Lisa
```

`Lisa` may be a default/example character but must not become:

- the application name;
- the backend name;
- the database name;
- the persistent data root name;
- the runtime engine name;
- the model-library root.

Likewise, `Aura` is not a canonical product or backend name.

## 2.4 Runtime/model identity

The following are distinct concepts:

```text
Product identity
!= backend service identity
!= character identity
!= runtime engine identity
!= acceleration backend
!= model identity
```

Example:

```text
Product:              AI Companion
Backend:              Local AI Runtime
Character:            Lisa
Runtime engine:       llama.cpp
Acceleration backend: Vulkan
Active model:         Qwen3-VL-4B-Instruct Q4_K_M
Profile:              Balanced
```

---

# 3. Architectural Layers

```text
┌───────────────────────────────────────────────┐
│                Client Layer                   │
│ React Web / Android / future desktop shell    │
└───────────────────────┬───────────────────────┘
                        │ authenticated API/SSE
                        ▼
┌───────────────────────────────────────────────┐
│              Local AI Runtime                 │
│                                               │
│ Assistant orchestration                       │
│ Configuration                                 │
│ Persistence                                   │
│ Model library                                 │
│ Memory                                        │
│ Tasks/scheduling                              │
│ Voice                                         │
│ Tools                                         │
│ Networking/security                           │
└───────────────────────┬───────────────────────┘
                        │ provider/runtime abstractions
                        ▼
┌───────────────────────────────────────────────┐
│                 Providers                     │
│ LLM / STT / TTS / VAD / Embedding / etc.      │
└───────────────────────┬───────────────────────┘
                        │ runtime-engine adapter
                        ▼
┌───────────────────────────────────────────────┐
│              Runtime Engine                   │
│ Current: llama.cpp b10936 Vulkan              │
│ Future: llama.cpp CUDA distribution           │
└───────────────────────────────────────────────┘
```

The upper layers must not require Qwen, Vulkan, RX 580, Lisa, or a specific filesystem path.

---

# 4. Runtime Modularity

## 4.1 Current runtime

The current repository is verified around:

```text
engine:       llama.cpp
build:        b10936
platform:     Windows x86_64
acceleration: Vulkan
```

This remains the active implementation.

## 4.2 Future runtime distributions

Future runtime distributions may include:

```text
llama.cpp + CUDA
```

and potentially other supported engines later.

CUDA implementation is **not** Phase 8 scope.

The architecture must allow a future CUDA repository/distribution to implement the same stable runtime contract without changing application-level model, conversation, character, memory, or attachment contracts.

## 4.3 Runtime-engine descriptor

Conceptually the Local AI Runtime should be able to describe its engine using fields such as:

```text
engine
engine_version/build
platform
architecture
acceleration_backend
runtime_binary_path
supported_model_formats
runtime_capabilities
```

Example:

```text
engine: llama.cpp
build: b10936
platform: windows-x64
acceleration_backend: vulkan
```

Future:

```text
engine: llama.cpp
build: <future-build>
platform: windows-x64
acceleration_backend: cuda
```

## 4.4 Important terminology

A GGUF model is **not** a Vulkan model or CUDA model.

```text
GGUF model
    │
    ├── llama.cpp Vulkan runtime
    └── llama.cpp CUDA runtime
```

Compatibility depends on the runtime build supporting the model architecture and required artifacts.

Persistent model storage must therefore not be organized as:

```text
models/vulkan/
models/cuda/
```

Acceleration is runtime metadata, not model identity.

---

# 5. Configuration Architecture

Configuration must be layered rather than becoming an ever-growing `.env` file.

## 5.1 Configuration domains

The project should define configuration domains for:

```text
application
storage
runtime
runtime profiles
model library
active model
characters
voice
STT/TTS
providers
memory
network
security
developer/diagnostics
```

## 5.2 Configuration classes

Every configurable value must be classified as one of:

```text
1. built-in default
2. persistent machine configuration
3. persistent user configuration
4. environment/developer override
5. secret
6. runtime/session state
```

These categories must not be silently mixed.

## 5.3 Recommended precedence

Conceptually:

```text
built-in defaults
    ↓
persistent machine configuration
    ↓
persistent user configuration
    ↓
environment/developer override
    ↓
runtime/session override
```

Security-sensitive values remain subject to separate secret-handling rules.

## 5.4 `.env` policy

`.env` remains appropriate for:

- development/deployment overrides;
- bootstrap values;
- local test configuration;
- non-committed sensitive development values where currently required.

It must **not** become the primary persistent user-settings database.

## 5.5 Secrets

Secrets such as pairing tokens/API keys must not be placed casually in a portable, browsable data directory in plaintext.

Preferred future direction:

```text
Windows Credential Manager / OS secure storage
```

or an explicitly encrypted secrets store.

Non-sensitive configuration may live inside the persistent data root.

---

# 6. Persistent Data & Asset Root

## 6.1 One canonical root

The application must have one canonical configurable root:

```text
COMPANION_DATA_ROOT
```

Example user-selected paths:

```text
D:\AICompanionData
C:\Users\<user>\Documents\AI Companion
E:\AI\CompanionData
```

The root must be independent of:

- repository checkout path;
- installation directory;
- current working directory;
- character name;
- runtime-engine name.

## 6.2 Canonical directory layout

```text
<COMPANION_DATA_ROOT>/
│
├── database/
│   └── companion.db
│
├── attachments/
│   └── <owner-id>/
│       └── <conversation-id>/
│           └── <attachment-id>.<verified-extension>
│
├── library/
│   ├── models/
│   │   ├── llm/
│   │   ├── embeddings/
│   │   ├── rerankers/
│   │   ├── stt/
│   │   ├── tts/
│   │   ├── vad/
│   │   └── wake-word/
│   │
│   ├── voices/
│   └── registry/
│
├── characters/
│   └── <character-id>/
│
├── memory/
│   ├── indexes/
│   └── derived/
│
├── imports/
│   ├── inbox/
│   ├── staging/
│   └── rejected/
│
├── backups/
│
├── config/
│   └── non-secret persistent configuration
│
├── cache/
│
└── logs/
```

Directories may be created lazily. The architecture does not require empty directories to exist before their feature is used.

## 6.3 Data root vs application installation

Persistent user/machine data:

```text
database
conversation history
attachments
memories
characters
imported models
imported voices
registries
backups
non-secret persistent settings
```

Application/runtime installation:

```text
frontend bundle
backend source/binaries
Python/Node dependencies
llama.cpp executable/runtime DLLs
future CUDA runtime binaries
installer/application executables
```

Runtime binaries must remain outside the persistent user-data root.

## 6.4 Database URL

The database location must be derived from the resolved persistent root using an absolute path.

Do not maintain two unrelated sources of truth such as:

```text
DATA_DIR = ...
DATABASE_URL = sqlite:///./data/companion.db
```

The resolved architecture is:

```text
COMPANION_DATA_ROOT
    └── database/
        └── companion.db
```

The SQLite connection URL is derived from that absolute resolved path.

## 6.5 Relocatable paths

Paths stored inside registries and metadata should be relative to the relevant root whenever possible.

Good:

```text
library/models/llm/<model-id>/model.gguf
```

Avoid persisting:

```text
D:\AICompanionData\library\models\...
```

inside every model record unless an external-library override explicitly requires an absolute path.

This allows:

```text
D:\AICompanionData
→ E:\AICompanionData
```

without rewriting every asset record.

---

# 7. Remembering a Custom Data Root

A configurable root creates a bootstrap problem: the application must know where the root is before it can read configuration from that root.

The architecture therefore permits a tiny platform bootstrap locator outside the main data root.

On Windows this may be implemented using one of:

```text
%LOCALAPPDATA%\AI Companion\bootstrap.json
Windows registry
installer-maintained per-user locator
```

The locator must contain only bootstrap information such as:

```text
data_root
schema_version
```

It is **not** a second user-data store.

It must not contain:

- conversation history;
- attachments;
- model files;
- memory;
- characters;
- secrets.

Normal uninstall should preserve the locator by default if persistent user data is preserved.

If the locator is absent on reinstall, the application should offer:

```text
Use default data location
Locate existing AI Companion data folder
Create new data folder
```

This preserves the one-persistent-data-root invariant while still making a custom location discoverable.

---

# 8. Uninstall/Reinstall Persistence

Normal uninstall must remove application/runtime files but leave user data intact unless the user explicitly asks to delete data.

Expected behavior:

```text
Uninstall AI Companion
    ↓
application/runtime removed
    ↓
COMPANION_DATA_ROOT preserved
    ↓
reinstall
    ↓
resolve existing data root
    ↓
open existing companion.db
    ↓
restore conversations, attachments, characters, libraries
```

A destructive uninstall option may later expose:

```text
[ ] Also delete my AI Companion data and conversation history
```

It must be explicit and opt-in.

---

# 9. Existing Data Migration

The current repository/runtime may contain data in legacy project-relative locations.

8P must define and test a migration strategy.

Conceptual first-run logic:

```text
new persistent database exists?
│
├── yes → use it
│
└── no
    ├── legacy database found?
    │    └── yes → copy/migrate safely
    └── no → create fresh database
```

Rules:

- never overwrite an existing newer persistent database automatically;
- never delete the legacy database before the migrated copy is verified;
- verify schema revision and row integrity;
- preserve a backup during migration;
- migration must be restart-safe;
- path migration must not alter unrelated repository files.

---

# 10. Repository Model-Storage Policy Boundary

The current repository has an established Git/LFS model-storage policy.

8P must **not** silently change `.gitattributes`, `.lfsconfig`, LFS remotes, or repository model tracking.

Distinguish two concerns:

```text
Repository development/bootstrap model assets
→ existing Git/LFS policy

Installed application / user-imported runtime model library
→ COMPANION_DATA_ROOT/library/models/
```

A future transition of existing development models into the installed persistent library requires an explicit migration plan and user authorization.

---

# 11. Model Library Architecture

## 11.1 Model library is not Qwen-specific

The currently verified Qwen3-VL models are tested defaults/examples.

They are not a whitelist.

The architecture must allow any compatible user model that the configured runtime can validate and execute.

Examples may include:

```text
Qwen
Llama
Gemma
Mistral
Phi
other llama.cpp-compatible GGUF architectures
```

Compatibility must be verified rather than assumed from the file extension alone.

## 11.2 Logical model vs artifact

Separate the logical model concept from a particular quantized artifact.

Conceptually:

```text
Logical model:
Qwen3-VL-4B-Instruct

Artifacts:
├── Q8_0
├── Q5_K_M
└── Q4_K_M
```

Initial implementation may register each artifact independently, but the schema must not make future grouping impossible.

## 11.3 Model metadata vs runtime settings

This is a strict invariant.

Model metadata describes what the artifact **is**.

Runtime configuration describes how the current machine **runs** it.

Example:

```text
MODEL METADATA
model_context_limit = 32768
quantization = Q4_K_M
architecture = qwen3vl
vision = true
```

versus:

```text
RUNTIME STATE/CONFIG
runtime_context_size = 4096
gpu_layers = 28
threads = 6
profile = balanced
model_awake = true
```

Never collapse these into one field.

---

# 12. Model Manifest Contract

The persistent model manifest/registry should support the following concepts.

## 12.1 Identity

```text
id
display_name
asset_type
family
architecture
variant
```

`variant` is optional/extensible and may contain:

```text
instruct
thinking
base
chat
code
other
null
```

No feature should assume every model family uses the same variants.

## 12.2 Artifact metadata

```text
primary_artifact
parameter_count
quantization
file_size
hash/integrity
original_filename
imported_at
source
license
```

Quantization should preferably be read from GGUF metadata rather than inferred only from filenames.

## 12.3 Context

Keep separate:

```text
model_context_limit
runtime_context_size
```

A model that supports 32K may intentionally run at 2K/4K on constrained hardware.

## 12.4 Capabilities

The manifest should be capable of expressing:

```text
chat
vision
reasoning
tool_calling
structured_output
multilingual
code
```

Future capabilities may include:

```text
audio_input
audio_output
video_input
```

but must not be claimed until the provider/runtime path is actually supported and verified.

## 12.5 Modalities

Explicitly track supported input/output modalities where relevant:

```text
text
image
future audio
future video
```

Do not gate vision merely because a filename contains `VL`.

## 12.6 Companion artifacts

A model may require additional artifacts such as:

```text
vision_projector / mmproj
tokenizer companion
other runtime-required resource
```

The library must support:

```text
primary artifact present
companion artifact missing
```

without pretending the whole model is necessarily unusable for all capabilities.

Example:

```text
text chat: available
vision: unavailable until mmproj is installed
```

## 12.7 Chat template/tokenizer behavior

Where reliable, detect and preserve the model's chat template metadata.

Using the wrong chat template may allow generation while severely degrading behavior.

The default policy is:

```text
GGUF-provided chat template
→ use when supported

registry override
→ only where required and justified
```

## 12.8 Runtime compatibility

Track compatibility separately from identity.

Conceptually:

```text
engine
minimum_build (optional)
tested_build
tested_platform
tested_acceleration
compatibility_status
```

Example:

```text
engine: llama.cpp
tested_build: b10936
tested_acceleration: [vulkan]
```

This means "verified here", not "the model is a Vulkan model."

## 12.9 Generation recommendations

The registry may store recommended defaults:

```text
temperature
top_p
top_k
min_p
repeat_penalty
```

These are recommendations, not immutable model metadata.

Runtime/user/character configuration may override them.

---

# 13. Reasoning / Thinking Architecture

Do not equate a display label with a capability.

Bad assumption:

```text
variant == thinking
therefore reasoning must always be enabled
```

Preferred model:

```text
variant: thinking
capabilities: [chat, reasoning]
reasoning_mode: always_on | toggleable | unsupported | unknown
```

Some model families may use dedicated thinking weights.

Others may expose reasoning via:

- chat-template option;
- provider/runtime flag;
- generation mode.

Feature gating must rely on validated capability metadata, not merely a filename.

---

# 14. Model Validation States

The model library should distinguish at least:

```text
discovered
registered
verified
incompatible
```

Recommended semantics:

### Discovered

A candidate artifact exists and basic metadata can be read.

### Registered

The artifact has a normalized manifest and known library identity.

### Verified

The configured Local AI Runtime has successfully validated the required path, for example:

```text
load succeeds
text generation succeeds
vision succeeds when claimed/applicable
```

### Incompatible

The configured runtime cannot safely use the artifact.

Do not confuse:

```text
file exists
```

with:

```text
model works
```

---

# 15. Capability Confidence / Provenance

Capabilities should eventually preserve provenance such as:

```text
declared
detected
verified
unknown
```

Example:

```text
vision:
  supported: true
  provenance: verified

reasoning:
  supported: true
  provenance: metadata

tool_calling:
  supported: unknown
```

An initial implementation may simplify this representation, but the architecture must leave room for it.

Do not infer complex capabilities purely from arbitrary filenames.

---

# 16. Model Import Architecture

Full import UI is not required in 8P, but the contract must be defined now.

Target flow:

```text
source/import
    ↓
staging
    ↓
validate file
    ↓
read GGUF metadata
    ↓
identify architecture
    ↓
read parameter/quantization/context/template metadata
    ↓
find companion artifacts
    ↓
derive candidate capabilities
    ↓
runtime compatibility validation
    ↓
install to persistent model library
    ↓
register manifest
```

The system should auto-detect information whenever reliable.

The user should not be forced to manually fill fields that can be safely extracted from the artifact.

Unknown compatible GGUFs must not be rejected merely because they are absent from a factory registry.

---

# 17. Web Import Behavior

Browser security means a normal Web UI should not be granted arbitrary filesystem authority.

For normal/smaller assets:

```text
browser file picker
→ authenticated upload
→ imports/staging
→ validation
→ persistent library
```

For very large local GGUF files, a same-PC upload may be inefficient.

A future PC workflow may provide a controlled import inbox:

```text
<COMPANION_DATA_ROOT>/imports/inbox/
```

with UI actions such as:

```text
Open Import Folder
Scan Imports
Validate
Install
```

A future native desktop shell may use a native path broker/file picker.

The backend must never accept unrestricted arbitrary filesystem paths from a browser client.

---

# 18. Model Registry Locations

Distinguish:

```text
repository factory/template registry
vs
installed user/runtime registry
```

Recommended target:

```text
Repository:
models/registry.template.json
→ development/factory examples

Persistent data root:
library/registry/models.json
→ installed runtime state
```

The factory registry must remain an example/bootstrap source, not a whitelist.

Relative asset paths are preferred.

---

# 19. Performance Profiles

`Eco`, `Balanced`, and `Maximum` are execution presets.

They are not universal hardware constants.

The current RX 580 + Vulkan values are a verified machine/runtime profile set.

Future hardware/runtime combinations may resolve the same profile names to different technical values.

Conceptually:

```text
Profile name
    +
runtime engine
    +
acceleration backend
    +
machine capabilities
    ↓
resolved execution parameters
```

Parameters may include:

```text
context size
GPU layers
CPU threads
batch parameters
KV cache mode
mmproj offload
idle timeout
```

The UI must continue distinguishing:

```text
requested profile
!= applied profile
```

and:

```text
configured value
!= measured value
!= estimated value
```

---

# 20. Voice and Speech Asset Architecture

Voice architecture follows the same runtime-vs-asset separation.

## Runtime/provider code

Examples:

```text
TTS engine runtime
STT engine runtime
VAD engine
provider adapter
```

belong with application/runtime distribution.

## Persistent assets

Examples:

```text
voice packs
TTS model weights
STT model weights
custom speaker resources
```

belong under:

```text
<COMPANION_DATA_ROOT>/library/
```

Future import flow:

```text
select/import
→ staging
→ validate provider compatibility
→ install persistent asset
→ registry update
```

The full voice-import UI is deferred unless separately approved.

---

# 21. Character Architecture

Character configuration lives under:

```text
<COMPANION_DATA_ROOT>/characters/<character-id>/
```

A future character package may contain:

```text
character manifest
avatar
system-prompt resources
preferred voice reference
language preferences
optional character assets
```

Example conceptual manifest:

```text
id: lisa
display_name: Lisa
preferred_voice_id: <voice-id>
```

The character may reference a voice but does not own the voice file itself.

Shared models and voices must not be duplicated underneath character folders.

Conversation `character_id` semantics must remain independent from application/runtime identity.

---

# 22. Multimodal Attachment Storage

Actual image bytes must live on the filesystem, not inside normal SQLite message text/BLOB fields.

Recommended structure:

```text
<COMPANION_DATA_ROOT>/
└── attachments/
    └── <owner-id>/
        └── <conversation-id>/
            ├── <attachment-id>.png
            └── <attachment-id>.jpg
```

SQLite stores metadata and relationships such as:

```text
attachment ID
owner
conversation ID
message ID
display filename
MIME type
size
dimensions
relative storage path
timestamps
soft-delete state
```

The original user filename is display metadata only.

The physical filename is server-generated.

The API must never expose raw internal storage paths.

---

# 23. Attachment Persistence Across Reinstall

Preserving the image directory alone is insufficient.

The following must persist together:

```text
companion.db
+
attachments/
```

because the database provides the relationship:

```text
conversation
→ user message
→ attachment metadata
→ physical image
```

Required reinstall acceptance journey:

```text
create conversation
→ upload image
→ send image + text
→ receive assistant response
→ stop application
→ replace/reinstall application/runtime files
→ preserve COMPANION_DATA_ROOT
→ relaunch
→ open existing DB
→ reopen conversation
→ text history restored
→ image metadata restored
→ original image preview loads successfully
```

---

# 24. Attachment Lifecycle

At minimum:

```text
selected
→ uploading
→ staged
→ committed
→ soft_deleted
→ cleanup/purged
```

A staged attachment is uploaded but not yet bound to a user message.

When a user removes a staged image from the composer, the backend must be told to cancel/delete it; removing React state alone is insufficient.

When a user message is accepted:

```text
text + attachment bindings
```

must persist consistently.

If assistant generation is later cancelled:

```text
user message + image remain
assistant response becomes cancelled/partial according to existing stream semantics
```

Do not delete a valid user attachment merely because assistant generation was interrupted.

---

# 25. Image Safety

Phase 8B image ingestion must validate more than file size.

Required controls:

```text
byte-size limit
actual file signature/MIME validation
decoded image validation
maximum width/height
megapixel budget
decompression-bomb protection
attachment-count limit
total per-message resource budget
safe server-owned filenames
path containment validation
ownership/conversation checks
```

Initial required formats:

```text
PNG
JPEG
```

WebP remains disabled until verified end-to-end against the pinned Local AI Runtime path.

---

# 26. Provider-Independent Multimodal Contract

The Assistant Orchestrator must not construct llama.cpp/OpenAI-specific `image_url` payload dictionaries.

Application-level representation should use typed provider-independent content blocks.

Conceptually:

```text
ChatMessage
└── content blocks
    ├── TextContent
    └── ImageContent
```

Storage resolution should be handled by a persistence/media service.

Preferred flow:

```text
Assistant Orchestrator
        ↓
Attachment / Media Resolver
        ↓
validated application image resource
        ↓
LLMProvider
        ↓
LlamaCppProvider adapter
        ↓
llama.cpp wire format
```

The LLM provider must not become responsible for understanding the application's database schema.

---

# 27. Android Architecture

Current priority:

```text
Android
    ↓ authenticated LAN/remote API
PC Local AI Runtime
    ↓
PC persistent data root
```

Therefore:

- uninstalling Android should not delete canonical conversation history;
- Android image uploads are stored by the PC Local AI Runtime;
- Android reconnect/reinstall can restore history after pairing/reconnection.

Future Android-local inference is a separate architecture.

If Android later runs models locally, it may use the same **logical** data/library layout but must obey Android-specific storage and uninstall rules.

Do not assume the Windows physical storage path model applies directly to Android.

---

# 28. Phase 8 Integration

## 8A — Frontend Architecture & UX Foundation

Purpose:

- remove production mock state;
- decompose Assistant UI;
- preserve backend runtime truth;
- improve model/profile provenance;
- audit navigation/Header/Home/Models/Settings/degraded states;
- no database migration.

## 8P — Runtime Configuration & Persistent Asset Foundation

Must establish:

```text
canonical naming
Local AI Runtime terminology
configuration layering
persistent data root
bootstrap locator
database relocation strategy
persistent model/voice/character library layout
model manifest contract
model metadata vs runtime state separation
runtime-engine abstraction
factory registry vs installed registry
legacy path migration strategy
```

8P must not silently alter Git/LFS policy.

## 8B — Multimodal Image Attachments

Builds on 8P:

```text
attachment DB migration
filesystem image persistence
image validation
attachment lifecycle
provider-independent image blocks
llama.cpp translation
authenticated previews
conversation-history restoration
vision-capability gating
```

## 8C — Integration, Accessibility & Polish

Includes:

```text
deprecated mock cleanup
bundle analysis
accessibility
integration tests
documentation reconciliation
final UX consistency
```

---

# 29. Deferred Features

The following are explicitly deferred unless separately approved:

```text
CUDA runtime implementation
full arbitrary-model import UI
automatic Hugging Face downloads
model conversion
automatic quantization
model marketplace
full benchmarking/recommendation wizard
PDF ingestion / OCR
document RAG
video ingestion
audio attachment ingestion
Android local LLM runtime
complete voice-import UI
```

Their architecture must remain possible, but they do not block image attachments once 8P is established.

---

# 30. Canonical Documentation Reconciliation

8P should audit current canonical/current documents for stale assumptions including:

```text
"Local AI Core" terminology
Qwen presented as fixed/required
RX 580 profile values presented as universal
repository-relative model/data paths presented as permanent
stale llama.cpp port/flag examples
character names used as backend/product identity
```

Historical walkthroughs should not be rewritten merely for terminology if doing so would falsify historical evidence.

The master implementation plan should summarize rather than duplicate this entire document.

Suggested canonical links:

```text
AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
    → references this document

LLAMA_CPP_RUNTIME_ARCHITECTURE.md
    → owns current llama.cpp lifecycle/runtime specifics

AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md
    → owns configuration, persistent storage, identity, asset library, model-manifest rules
```

---

# 31. Required Invariants

The following must remain true across Phase 8:

1. Backend runtime state is authoritative.
2. Selected model is not automatically the active model.
3. Requested profile is not automatically the applied profile.
4. Sleeping is distinct from unloaded/stopped.
5. No fabricated telemetry.
6. Product identity is `AI Companion`.
7. Backend identity is `Local AI Runtime`.
8. Character identity is configurable.
9. Qwen is a verified default, not a whitelist.
10. Vulkan is the current acceleration backend, not a property of GGUF models.
11. Model metadata is distinct from runtime configuration.
12. Persistent user data does not depend on the install/repository directory.
13. Actual image bytes remain filesystem-backed.
14. SQLite stores attachment metadata/relationships.
15. Application/runtime binaries remain outside the persistent data root.
16. Secrets remain separate from ordinary portable configuration.
17. Provider-specific wire formats remain inside provider adapters.
18. Current Git/LFS policy is not changed without explicit authorization.
19. Unknown model capabilities are not invented from filenames.
20. Full model/voice import UI may be deferred without weakening the underlying asset contract.

---

# 32. 8P Acceptance Criteria

8P is architecture-complete only when the implementation plan can demonstrate all of the following.

### Naming

```text
AI Companion
Local AI Runtime
configurable character identity
```

are represented consistently in active/canonical architecture.

### Configuration

Configuration domains and precedence are documented.

Runtime/session state is not stored as immutable model metadata.

Secrets are separated.

### Storage

There is one canonical resolved `COMPANION_DATA_ROOT`.

Database path is derived from it.

Runtime/install paths are outside it.

Custom root relocation behavior is defined.

### Migration

Legacy DB migration is safe, backup-preserving, and restart-safe.

### Model library

Current Qwen defaults can coexist with discovered/imported compatible GGUFs.

Factory registry is not a whitelist.

Model manifests can represent architecture, quantization, context, capabilities, modalities, companions, compatibility, validation and integrity.

### Runtime modularity

The current Vulkan implementation remains intact.

A future CUDA runtime can implement the same runtime contract without changing model identity or higher-level application contracts.

### Persistence

A simulated application reinstall with preserved data root restores:

```text
database
conversation history
configuration
registered assets
```

8B will later extend this acceptance path to image attachments.

---

# 33. Resolved Decisions

The following decisions were open during Phase 8P planning and have been resolved by the user.

## 33.1 Default Windows data-root location — Resolved

**Decision:** `%LOCALAPPDATA%\AI Companion\Data`

The root is configurable via the `COMPANION_DATA_ROOT` environment variable. No hardcoded default path may be assumed in code that does not first check the env var.

## 33.2 Advanced external library overrides — Deferred

Default policy: single data root. Per-library overrides (e.g. model library on a separate drive) are a **future/deferred feature**. Backups must clearly state whether external assets are included if overrides are later enabled.

## 33.3 Bootstrap locator implementation — Resolved

**Decision:** `%LOCALAPPDATA%\AI Companion\bootstrap.json`

The locator file contains only `data_root` and `schema_version`. No user content or secrets belong in the locator.

## 33.4 Development models vs installed-library migration — Resolved

**Decision:** Development and bootstrap models remain under the existing repository Git/LFS policy. Installed/user-imported models use `COMPANION_DATA_ROOT/library/models/`. The implementation must not change LFS policy, `.gitattributes`, or `.lfsconfig` without explicit user authorization.

---

# 34. Recommended Future Architecture Documents

After this architecture is accepted, specialized documents may be added as needed:

```text
docs/04_Architecture/
├── AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md
├── AI_COMPANION_RUNTIME_CONFIGURATION_AND_ASSET_ARCHITECTURE.md   ← this document
├── LLAMA_CPP_RUNTIME_ARCHITECTURE.md
├── MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md                     ← optional deeper model spec
└── VOICE_AND_AUDIO_ARCHITECTURE.md
```

A dedicated `MODEL_LIBRARY_AND_REGISTRY_ARCHITECTURE.md` becomes useful when the full model-import manager is planned.

Until then, the model contract in this document is the architecture baseline.

---

# 35. Final Architecture Summary

```text
AI Companion
│
├── Local AI Runtime
│   │
│   ├── Configuration System
│   ├── Persistence
│   ├── Assistant Orchestration
│   ├── Memory
│   ├── Tools
│   ├── Voice
│   └── Provider Interfaces
│
├── Runtime Engine
│   ├── Current: llama.cpp Vulkan
│   └── Future: llama.cpp CUDA
│
├── Persistent Data Root (configurable)
│   ├── database
│   ├── attachments
│   ├── models
│   ├── voices
│   ├── characters
│   ├── memory/indexes
│   ├── imports/staging
│   ├── backups
│   └── non-secret configuration
│
├── Model Library
│   ├── Qwen verified defaults
│   └── arbitrary compatible validated models
│
├── Characters
│   └── configurable, e.g. Lisa
│
└── Clients
    ├── React Web
    └── Android
```

The central design rule is:

> **Stable interfaces and persistent user-owned data define the product. Models, characters, voices, runtime engines, acceleration backends and filesystem locations are configurable implementations around those interfaces.**

This prevents current defaults from becoming permanent architectural constraints.
