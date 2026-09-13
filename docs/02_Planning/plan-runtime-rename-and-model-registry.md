# Implementation Plan — Runtime Rename and Model Registry

> **Implementer:** Gemini
> **Planner:** Antigravity (reviewed by user)
> **Status:** Approved for implementation
> **Branch:** `feature/assistant-orchestration-and-memory` (continue on same branch)

---

## Architecture References — Read These First

| Document | Purpose |
|----------|---------|
| `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` | §11 runtime, §16.2 ModelRegistry, §34 Track R1/R2-lite |
| `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md` | §3 router launch — all path references use `provider/` currently; update to `runtime/` |

---

## Quick Reference

| Item | Value |
|------|-------|
| Feature branch | `feature/assistant-orchestration-and-memory` |
| Current test count | **49 passing** (must not decrease) |
| Current migration head | `003` |
| llama-server binary | currently `provider/llama.cpp/llama-server.exe` becomes `runtime/llama.cpp/llama-server.exe` |
| Models root | `models/` (project root) |
| Run tests | from `backend/`: `.venv\Scripts\pytest tests/ -v` |

---

## What Already Exists — Read Before Writing Code

| File | Status |
|------|--------|
| `backend/app/core/config.py` | Has `PROVIDER_DIR`, `LLAMA_CPP_BIN_DIR`, `BIN_DIR` alias, `MODELS_DIR` |
| `backend/app/services/llm/llama_cpp.py` | Uses `settings.LLAMA_CPP_BIN_DIR` |
| `.gitignore` line 94 | Already has `runtime/` — rename works immediately |
| `.gitignore` line 98 | Has `provider/` — must remove this line |
| `models/vision/` | Currently flat: all `.gguf` and `mmproj-*.gguf` at same level |
| `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md` | Contains `provider/llama.cpp` references |
| `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` | Directory tree uses `provider/` |
| `docs/02_Planning/plan-assistant-orchestration-and-memory.md` | Path references use `provider/` |

---

## Problems This Sprint Solves

1. `provider/llama.cpp/` contains native runtime engine binaries but collides with `LLMProvider` Python interface naming
2. Flat `models/vision/` has 10 loose files — companion pairing is implicit
3. `ModelsView.tsx` uses static `mockLocalModels` — new downloads never appear in UI
4. Hardcoded fallback `'Qwen2.5-7B-Instruct-Q4_K_M.gguf'` in `ModelsView.tsx` line ~149

---

## Phase 0 — Pre-flight Check

`powershell
cd d:\OtherProjects\AI-companion-project\backend
.venv\Scripts\pytest tests/ -v --tb=short 2>&1 | Select-String "passed|failed"
`

Expected: 49 passed. If not 49, STOP and report.

---

## Phase 1 — Rename provider/ to runtime/ (Filesystem)

Steps 1.1–1.3 must happen together. Intermediate state breaks LLAMA_CPP_BIN_DIR.

### 1.1 Move directories

`powershell
New-Item -ItemType Directory -Force "d:\OtherProjects\AI-companion-project\runtime"
Move-Item "d:\OtherProjects\AI-companion-project\provider\llama.cpp" "d:\OtherProjects\AI-companion-project\runtime\llama.cpp"
Move-Item "d:\OtherProjects\AI-companion-project\provider\whisper.cpp" "d:\OtherProjects\AI-companion-project\runtime\whisper.cpp"
Remove-Item "d:\OtherProjects\AI-companion-project\provider" -Recurse -Force
`

### 1.2 Verify

`powershell
Test-Path "d:\OtherProjects\AI-companion-project\runtime\llama.cpp\llama-server.exe"
Test-Path "d:\OtherProjects\AI-companion-project\runtime\whisper.cpp\main.exe"
Test-Path "d:\OtherProjects\AI-companion-project\provider"  # must be False
`

### 1.3 Update .gitignore

Remove ONLY the bare `provider/` line from `.gitignore` (currently line 98).
Do NOT add a new `runtime/` line — it is already on line 94.
The block should become:

`
providers/
`

(bare `provider/` removed, `providers/` stays)


---

## Phase 2 — Update Config Settings

File: `backend/app/core/config.py`

Replace the section below `# Local LLM Runtime`:

`python
# BEFORE:
    PROVIDER_DIR: Path = BASE_DIR.parent / "provider"
    LLAMA_CPP_BIN_DIR: Path = PROVIDER_DIR / "llama.cpp"
    BIN_DIR: Path = PROVIDER_DIR  # backward-compatibility alias

# AFTER:
    RUNTIME_DIR: Path = BASE_DIR.parent / "runtime"
    LLAMA_CPP_BIN_DIR: Path = RUNTIME_DIR / "llama.cpp"
    BIN_DIR: Path = RUNTIME_DIR  # backward-compatibility alias
`

Also update the section header comment:

`python
# BEFORE:
    # Local LLM Runtime (Track B4 & Sections 11-14)

# AFTER:
    # Native Runtime Engines & Local LLM (Track B4 & Sections 11-14)
`

### 2.1 Update comment in llama_cpp.py

Find any comment in `backend/app/services/llm/llama_cpp.py` referencing `provider/llama.cpp` and update to `runtime/llama.cpp`.

### 2.2 Verify config resolves correctly

`powershell
cd d:\OtherProjects\AI-companion-project\backend
.venv\Scripts\python -c "
from app.core.config import settings
exe = settings.LLAMA_CPP_BIN_DIR / 'llama-server.exe'
print('RUNTIME_DIR:', settings.RUNTIME_DIR)
print('LLAMA_CPP_BIN_DIR:', settings.LLAMA_CPP_BIN_DIR)
print('EXE EXISTS:', exe.exists())
"
`

Expected:
`
RUNTIME_DIR: D:\OtherProjects\AI-companion-project\runtime
LLAMA_CPP_BIN_DIR: D:\OtherProjects\AI-companion-project\runtime\llama.cpp
EXE EXISTS: True
`

Run: `.venv\Scripts\pytest tests/ -v` — must be **49 passed**.

---

## Phase 3 — Update Architecture Documentation

### 3.1 LLAMA_CPP_RUNTIME_ARCHITECTURE.md

File: `docs/04_Architecture/LLAMA_CPP_RUNTIME_ARCHITECTURE.md`

Targeted find-replace (do NOT rewrite wholesale):
- `provider/llama.cpp` → `runtime/llama.cpp`
- Any standalone `provider/` path reference → `runtime/`

### 3.2 AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md

File: `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md`

In the directory tree section, replace:
`
├── provider/
│   ├── llama.cpp/            # Pinned b10936 Vulkan x64 binaries
│   └── whisper.cpp/          # Local speech transcription binaries
`
with:
`
├── runtime/
│   ├── llama.cpp/            # Pinned b10936 Vulkan x64 binaries — gitignored
│   └── whisper.cpp/          # whisper.cpp Windows release — gitignored
`

Replace any prose `provider/llama.cpp` with `runtime/llama.cpp`.

### 3.3 plan-assistant-orchestration-and-memory.md

File: `docs/02_Planning/plan-assistant-orchestration-and-memory.md`

Find-replace:
- `provider/llama.cpp` → `runtime/llama.cpp`
- `provider/whisper.cpp` → `runtime/whisper.cpp`
- `PROVIDER_DIR` → `RUNTIME_DIR`

---

## Phase 4 — Reorganize models/vision/ into Per-Model Subdirectories

All gitignored. Zero Git impact.

### 4.1 Move files

`powershell
$v = "d:\OtherProjects\AI-companion-project\models\vision"

New-Item -ItemType Directory -Force "$v\qwen3-vl-2b-instruct" | Out-Null
Move-Item "$v\Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf"     "$v\qwen3-vl-2b-instruct\"
Move-Item "$v\mmproj-Qwen_Qwen3-VL-2B-Instruct-f16.gguf" "$v\qwen3-vl-2b-instruct\"

New-Item -ItemType Directory -Force "$v\qwen3-vl-2b-thinking" | Out-Null
Move-Item "$v\Qwen_Qwen3-VL-2B-Thinking-Q4_K_M.gguf"     "$v\qwen3-vl-2b-thinking\"
Move-Item "$v\mmproj-Qwen_Qwen3-VL-2B-Thinking-f16.gguf" "$v\qwen3-vl-2b-thinking\"

New-Item -ItemType Directory -Force "$v\qwen3-vl-4b-instruct" | Out-Null
Move-Item "$v\Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf"     "$v\qwen3-vl-4b-instruct\"
Move-Item "$v\mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf" "$v\qwen3-vl-4b-instruct\"

New-Item -ItemType Directory -Force "$v\qwen3-vl-4b-thinking" | Out-Null
Move-Item "$v\Qwen_Qwen3-VL-4B-Thinking-Q4_K_M.gguf"     "$v\qwen3-vl-4b-thinking\"
Move-Item "$v\mmproj-Qwen_Qwen3-VL-4B-Thinking-f16.gguf" "$v\qwen3-vl-4b-thinking\"

New-Item -ItemType Directory -Force "$v\qwen3-vl-8b-instruct" | Out-Null
Move-Item "$v\Qwen_Qwen3-VL-8B-Instruct-Q4_K_M.gguf"     "$v\qwen3-vl-8b-instruct\"
Move-Item "$v\mmproj-Qwen_Qwen3-VL-8B-Instruct-f16.gguf" "$v\qwen3-vl-8b-instruct\"
`

### 4.2 Verify

`powershell
Get-ChildItem "d:\OtherProjects\AI-companion-project\models\vision" -Recurse -File |
  Select-Object DirectoryName, Name | Format-Table -AutoSize
`

Expected: 10 files, 2 per subdir, none loose at vision/ root.

---

## Phase 5 — Create models/registry.template.json

### 5.1 Add models/registry.json to .gitignore

In `.gitignore`, after the `models/*` block, append:
```
# Model registry — local instance; never commit
models/registry.json
```

### 5.2 Create models/registry.template.json

Write this file at `models/registry.template.json` (project root, committed to Git):

```json
{
  "_schema_version": "1",
  "_note": "Copy to models/registry.json (gitignored). All paths relative to models/.",
  "models": [
    {
      "id": "qwen3-vl-2b-instruct",
      "display_name": "Qwen3-VL 2B Instruct",
      "family": "Qwen3-VL",
      "variant": "instruct",
      "primary_file": "vision/qwen3-vl-2b-instruct/Qwen_Qwen3-VL-2B-Instruct-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-2b-instruct/mmproj-Qwen_Qwen3-VL-2B-Instruct-f16.gguf" }
      ],
      "quantization": "Q4_K_M",
      "parameters": "2.0B",
      "context_limit": 32768,
      "capabilities": ["chat", "vision", "multilingual"],
      "recommended_profiles": ["eco", "balanced"],
      "estimated_vram_gb": 2.4,
      "estimated_ram_gb": 0.6,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF"
    },
    {
      "id": "qwen3-vl-2b-thinking",
      "display_name": "Qwen3-VL 2B Thinking",
      "family": "Qwen3-VL",
      "variant": "thinking",
      "primary_file": "vision/qwen3-vl-2b-thinking/Qwen_Qwen3-VL-2B-Thinking-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-2b-thinking/mmproj-Qwen_Qwen3-VL-2B-Thinking-f16.gguf" }
      ],
      "quantization": "Q4_K_M",
      "parameters": "2.0B",
      "context_limit": 32768,
      "capabilities": ["chat", "vision", "reasoning", "multilingual"],
      "recommended_profiles": ["balanced", "maximum"],
      "estimated_vram_gb": 2.4,
      "estimated_ram_gb": 0.6,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-2B-Thinking-GGUF"
    },
    {
      "id": "qwen3-vl-4b-instruct",
      "display_name": "Qwen3-VL 4B Instruct",
      "family": "Qwen3-VL",
      "variant": "instruct",
      "primary_file": "vision/qwen3-vl-4b-instruct/Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-4b-instruct/mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf" }
      ],
      "quantization": "Q4_K_M",
      "parameters": "4.0B",
      "context_limit": 32768,
      "capabilities": ["chat", "vision", "multilingual"],
      "recommended_profiles": ["balanced", "maximum"],
      "estimated_vram_gb": 3.8,
      "estimated_ram_gb": 0.8,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF"
    },
    {
      "id": "qwen3-vl-4b-thinking",
      "display_name": "Qwen3-VL 4B Thinking",
      "family": "Qwen3-VL",
      "variant": "thinking",
      "primary_file": "vision/qwen3-vl-4b-thinking/Qwen_Qwen3-VL-4B-Thinking-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-4b-thinking/mmproj-Qwen_Qwen3-VL-4B-Thinking-f16.gguf" }
      ],
      "quantization": "Q4_K_M",
      "parameters": "4.0B",
      "context_limit": 32768,
      "capabilities": ["chat", "vision", "reasoning", "multilingual"],
      "recommended_profiles": ["balanced", "maximum"],
      "estimated_vram_gb": 3.8,
      "estimated_ram_gb": 0.8,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-4B-Thinking-GGUF"
    },
    {
      "id": "qwen3-vl-8b-instruct",
      "display_name": "Qwen3-VL 8B Instruct",
      "family": "Qwen3-VL",
      "variant": "instruct",
      "primary_file": "vision/qwen3-vl-8b-instruct/Qwen_Qwen3-VL-8B-Instruct-Q4_K_M.gguf",
      "companion_files": [
        { "role": "mmproj", "path": "vision/qwen3-vl-8b-instruct/mmproj-Qwen_Qwen3-VL-8B-Instruct-f16.gguf" }
      ],
      "quantization": "Q4_K_M",
      "parameters": "8.0B",
      "context_limit": 32768,
      "capabilities": ["chat", "vision", "multilingual"],
      "recommended_profiles": ["maximum"],
      "estimated_vram_gb": 5.8,
      "estimated_ram_gb": 1.2,
      "license": "Apache-2.0",
      "source": "https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF"
    }
  ]
}
```

---

## Phase 6 — Backend: Model Registry Schema

Create: `backend/app/schemas/model_registry.py`

```python
"""Model registry schemas — Master Plan §16.2, §16.3."""
from enum import Enum
from typing import List, Optional
from app.schemas.common import BaseSchema


class ModelCapability(str, Enum):
    chat = "chat"
    vision = "vision"
    reasoning = "reasoning"
    structured_output = "structured_output"
    tool_calling = "tool_calling"
    multilingual = "multilingual"


class ValidationStatus(str, Enum):
    verified = "verified"
    missing_primary = "missing_primary"
    missing_companion = "missing_companion"
    unregistered = "unregistered"


class CompanionFile(BaseSchema):
    role: str   # "mmproj" | "tokenizer"
    path: str   # relative to models/


class ModelRegistryEntry(BaseSchema):
    """One logical model with physical artifacts and validated metadata."""
    id: str
    display_name: str
    family: str
    variant: str = "instruct"
    primary_file: str
    companion_files: List[CompanionFile] = []
    quantization: str = ""
    parameters: str = ""
    context_limit: int = 4096
    capabilities: List[ModelCapability] = []
    recommended_profiles: List[str] = ["balanced"]
    estimated_vram_gb: float = 0.0
    estimated_ram_gb: float = 0.0
    license: str = ""
    source: str = ""
    # Computed at runtime:
    validation_status: ValidationStatus = ValidationStatus.unregistered
    primary_file_exists: bool = False
    companion_files_valid: bool = True
    size_gb: Optional[float] = None
```

---

## Phase 7 — Backend: Model Registry Service

Create: `backend/app/services/model_registry.py`

```python
"""
Model Registry service — Master Plan §16.2.
Reads models/registry.json and scans models/ for GGUF files.
Never writes to models/.
"""
import json
import logging
from pathlib import Path
from typing import List

from app.core.config import settings
from app.schemas.model_registry import (
    CompanionFile, ModelCapability, ModelRegistryEntry, ValidationStatus,
)

logger = logging.getLogger("app.services.model_registry")
_EXCLUDE_PREFIXES = ("mmproj-", "lfs-test")
_MIN_SIZE_BYTES = 100 * 1024 * 1024


def _load_registry_json() -> list:
    registry_path = settings.MODELS_DIR / "registry.json"
    if not registry_path.exists():
        logger.info("models/registry.json not found — using scan-only discovery")
        return []
    try:
        with open(registry_path, "r", encoding="utf-8") as f:
            return json.load(f).get("models", [])
    except Exception as exc:
        logger.warning(f"Failed to parse models/registry.json: {exc}")
        return []


def _scan_models_dir() -> List[Path]:
    results: List[Path] = []
    if not settings.MODELS_DIR.exists():
        return results
    for gguf in settings.MODELS_DIR.rglob("*.gguf"):
        if not gguf.is_file():
            continue
        if any(gguf.name.startswith(p) for p in _EXCLUDE_PREFIXES):
            continue
        if gguf.stat().st_size < _MIN_SIZE_BYTES:
            continue
        results.append(gguf)
    return results


def _validate_entry(entry: ModelRegistryEntry) -> ModelRegistryEntry:
    primary = settings.MODELS_DIR / entry.primary_file
    entry.primary_file_exists = primary.exists()
    if not entry.primary_file_exists:
        entry.validation_status = ValidationStatus.missing_primary
        return entry
    entry.size_gb = round(primary.stat().st_size / (1024 ** 3), 2)
    for companion in entry.companion_files:
        if not (settings.MODELS_DIR / companion.path).exists():
            entry.companion_files_valid = False
            entry.validation_status = ValidationStatus.missing_companion
            return entry
    entry.validation_status = ValidationStatus.verified
    return entry


def build_model_list() -> List[ModelRegistryEntry]:
    """
    1. Parse registry.json and validate each entry against disk.
    2. Scan models/ for any .gguf not in registry.
    3. Return: registered (instruct < thinking < base) then unregistered.
    """
    raw_entries = _load_registry_json()
    registered_primary_files: set = set()
    registered: List[ModelRegistryEntry] = []
    variant_order = {"instruct": 0, "thinking": 1, "base": 2}

    for raw in raw_entries:
        try:
            companion_files = [
                CompanionFile(role=c["role"], path=c["path"])
                for c in raw.get("companion_files", [])
            ]
            capabilities = []
            for cap_str in raw.get("capabilities", []):
                try:
                    capabilities.append(ModelCapability(cap_str))
                except ValueError:
                    pass
            entry = ModelRegistryEntry(
                id=raw["id"],
                display_name=raw.get("display_name", raw["id"]),
                family=raw.get("family", ""),
                variant=raw.get("variant", "instruct"),
                primary_file=raw["primary_file"],
                companion_files=companion_files,
                quantization=raw.get("quantization", ""),
                parameters=raw.get("parameters", ""),
                context_limit=raw.get("context_limit", 4096),
                capabilities=capabilities,
                recommended_profiles=raw.get("recommended_profiles", ["balanced"]),
                estimated_vram_gb=raw.get("estimated_vram_gb", 0.0),
                estimated_ram_gb=raw.get("estimated_ram_gb", 0.0),
                license=raw.get("license", ""),
                source=raw.get("source", ""),
            )
            entry = _validate_entry(entry)
            registered_primary_files.add(entry.primary_file)
            registered.append(entry)
        except Exception as exc:
            logger.warning(f"Skipping malformed registry entry: {exc}")

    registered.sort(key=lambda e: variant_order.get(e.variant, 99))

    unregistered: List[ModelRegistryEntry] = []
    for path in _scan_models_dir():
        relative = path.relative_to(settings.MODELS_DIR).as_posix()
        if relative in registered_primary_files:
            continue
        size_gb = round(path.stat().st_size / (1024 ** 3), 2)
        unregistered.append(ModelRegistryEntry(
            id=path.stem.lower().replace("_", "-").replace(".", "-"),
            display_name=path.stem,
            family="",
            variant="instruct",
            primary_file=relative,
            capabilities=[ModelCapability.chat],
            validation_status=ValidationStatus.unregistered,
            primary_file_exists=True,
            size_gb=size_gb,
        ))

    result = registered + unregistered
    logger.info(f"Model registry: {len(registered)} registered, {len(unregistered)} unregistered")
    return result
```

---

## Phase 8 — Backend: Registry API Endpoint

File: `backend/app/api/v1/endpoints/llm.py`

### 8.1 Add imports (with existing imports at top of file)

```python
from app.services.model_registry import build_model_list
from app.schemas.model_registry import ModelRegistryEntry
```

Check if `List` is already imported from `typing` — do not duplicate.

### 8.2 Add new endpoint after the existing GET /models/status route

```python
@router.get(
    "/models/registry",
    response_model=List[ModelRegistryEntry],
    summary="Get Model Registry",
)
async def get_model_registry(
    _: str = Depends(get_current_owner),
) -> List[ModelRegistryEntry]:
    """
    Return all known and discovered models with validation status,
    capabilities, VRAM estimates, and companion file status.
    Master Plan §16.2.
    """
    return build_model_list()
```

### 8.3 Test checkpoint

```powershell
.venv\Scripts\pytest tests/ -v --tb=short 2>&1 | Select-String "passed|failed"
```

Must be **49 passed**.

---

## Phase 9 — Frontend: Registry API Service

### 9.1 Check existing API helper pattern

Before writing this file, open `frontend/web/src/services/api/index.ts` and confirm the exact exported names for the auth header helper and base URL constant. Use the same pattern as `modelApi.ts`.

### 9.2 Create `frontend/web/src/services/api/registryApi.ts`

```typescript
/**
 * Model Registry API — fetches the live model list from the backend.
 * Master Plan §16.2 — ModelRegistry
 */
import { getAuthHeaders, BACKEND_BASE_URL } from './index';

export type ModelVariant = 'instruct' | 'thinking' | 'base' | string;
export type ModelCapability =
  | 'chat' | 'vision' | 'reasoning'
  | 'structured_output' | 'tool_calling' | 'multilingual';
export type ValidationStatus =
  | 'verified' | 'missing_primary' | 'missing_companion' | 'unregistered';

export interface CompanionFile {
  role: string;
  path: string;
}

export interface RegistryEntry {
  id: string;
  display_name: string;
  family: string;
  variant: ModelVariant;
  primary_file: string;
  companion_files: CompanionFile[];
  capabilities: ModelCapability[];
  recommended_profiles: string[];
  estimated_vram_gb: number;
  estimated_ram_gb: number;
  quantization: string;
  parameters: string;
  context_limit: number;
  license: string;
  source: string;
  validation_status: ValidationStatus;
  primary_file_exists: boolean;
  companion_files_valid: boolean;
  size_gb: number | null;
}

export async function fetchModelRegistry(apiKey: string | null): Promise<RegistryEntry[]> {
  if (!apiKey) return [];
  try {
    const res = await fetch(`${BACKEND_BASE_URL}/api/v1/models/registry`, {
      headers: getAuthHeaders(apiKey),
    });
    if (!res.ok) {
      console.warn('[registryApi] Failed to fetch model registry:', res.status);
      return [];
    }
    return res.json() as Promise<RegistryEntry[]>;
  } catch {
    return [];
  }
}
```

---

## Phase 10 — Frontend: Types

File: `frontend/web/src/types.ts`

### 10.1 Add type exports near the top (with existing type exports)

```typescript
export type ModelVariant = 'instruct' | 'thinking' | 'base' | string;
export type ModelCapability =
  | 'chat' | 'vision' | 'reasoning'
  | 'structured_output' | 'tool_calling' | 'multilingual';
export type ValidationStatus =
  | 'verified' | 'missing_primary' | 'missing_companion' | 'unregistered';
```

### 10.2 Add optional fields to LocalModel interface

At the end of the `LocalModel` interface, add:

```typescript
  // Registry-enriched fields — populated when backend is online
  variant?: ModelVariant;
  capabilities?: ModelCapability[];
  validationStatus?: ValidationStatus;
  hasCompanion?: boolean;
  companionFilesValid?: boolean;
```

---

## Phase 11 — Frontend: Wire ModelsView.tsx

File: `frontend/web/src/components/workspace/ModelsView.tsx`

### 11.1 Add import at top

```typescript
import { fetchModelRegistry, RegistryEntry } from '../../services/api/registryApi';
```

### 11.2 Add live registry useEffect

The existing line stays as offline fallback:
```typescript
const [models, setModels] = useState<LocalModel[]>(mockLocalModels);
```

Directly after ALL useState declarations (before any existing useEffect blocks), add:

```typescript
// Load live model list from backend registry on mount
useEffect(() => {
  if (!apiKey) return;
  fetchModelRegistry(apiKey)
    .then((entries) => {
      if (entries.length === 0) return; // keep mock fallback if empty or offline
      const live: LocalModel[] = entries.map((e: RegistryEntry) => ({
        id: e.id,
        name: e.display_name,
        family: e.family,
        parameters: e.parameters,
        quantization: e.quantization,
        sizeGb: e.size_gb ?? 0,
        contextWindow: e.context_limit,
        status: 'unloaded' as const,
        engine: 'llama.cpp',
        isCloud: false,
        vramUsageGb: e.estimated_vram_gb,
        ramUsageGb: e.estimated_ram_gb,
        filePath: e.primary_file,
        description: `${e.variant} · ${e.capabilities.join(', ')} · ${e.license}`,
        variant: e.variant,
        capabilities: e.capabilities,
        validationStatus: e.validation_status,
        hasCompanion: e.companion_files.length > 0,
        companionFilesValid: e.companion_files_valid,
      }));
      setModels(live);
    })
    .catch(() => { /* silent fallback to mockLocalModels */ });
}, [apiKey]);
```

### 11.3 Fix the hardcoded model name fallback

Find (around line 149):
```typescript
selected.id === 'm-1' ? (modelStatus?.available_models?.[0] || 'Qwen2.5-7B-Instruct-Q4_K_M.gguf') : selected.name,
```

Replace with:
```typescript
selected.filePath || modelStatus?.available_models?.[0] || selected.name,
```

### 11.4 Add variant badges to model cards

Find the component that renders individual model cards — likely inside
`frontend/web/src/components/workspace/models/ModelLibraryGrid.tsx` or a child card component.

After the model name display, add:

```tsx
{/* Variant badge */}
{model.variant === 'thinking' && (
  <span className="text-xs px-1.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 font-medium ml-1">
    Thinking 🧠
  </span>
)}
{model.variant === 'instruct' && (
  <span className="text-xs px-1.5 py-0.5 rounded-full bg-sky-500/20 text-sky-300 font-medium ml-1">
    Instruct
  </span>
)}
{/* Companion warning */}
{model.hasCompanion && !model.companionFilesValid && (
  <span className="text-xs px-1.5 py-0.5 rounded-full bg-amber-500/20 text-amber-400 font-medium ml-1">
    ⚠ mmproj missing
  </span>
)}
```

---

## Phase 12 — Tests

Create: `backend/tests/test_model_registry.py`

```python
"""Tests for model registry service — Master Plan §16.2."""
import json
import importlib
import pytest
from unittest.mock import patch


def test_scan_excludes_mmproj_and_small_files(tmp_path):
    """Auto-scan must not surface mmproj-* or files under 100 MB."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    (models_dir / "vision").mkdir(parents=True)
    # Valid primary model
    (models_dir / "vision" / "TestModel-Q4.gguf").write_bytes(b"x" * (101 * 1024 * 1024))
    # Companion — excluded by prefix
    (models_dir / "vision" / "mmproj-TestModel.gguf").write_bytes(b"x" * (200 * 1024 * 1024))
    # Too small — excluded by size
    (models_dir / "vision" / "small.gguf").write_bytes(b"x" * (50 * 1024 * 1024))

    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        found = mr._scan_models_dir()

    names = [p.name for p in found]
    assert "TestModel-Q4.gguf" in names
    assert "mmproj-TestModel.gguf" not in names
    assert "small.gguf" not in names


def test_missing_registry_json_returns_scan_only(tmp_path):
    """build_model_list returns scan-only results when registry.json is absent."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    models_dir.mkdir()
    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        result = mr.build_model_list()
    assert isinstance(result, list)


def test_registry_validates_missing_primary(tmp_path):
    """Entry with missing primary_file gets validation_status=missing_primary."""
    from app.core.config import settings
    models_dir = tmp_path / "models"
    models_dir.mkdir()
    registry = {
        "_schema_version": "1",
        "models": [{
            "id": "test-model",
            "display_name": "Test",
            "family": "Test",
            "variant": "instruct",
            "primary_file": "vision/nonexistent.gguf",
            "companion_files": [],
            "quantization": "Q4_K_M",
            "parameters": "4B",
            "context_limit": 4096,
            "capabilities": ["chat"],
            "recommended_profiles": ["balanced"],
            "estimated_vram_gb": 4.0,
            "estimated_ram_gb": 0.8,
            "license": "Apache-2.0",
        }]
    }
    (models_dir / "registry.json").write_text(json.dumps(registry), encoding="utf-8")
    with patch.object(settings, "MODELS_DIR", models_dir):
        import app.services.model_registry as mr
        importlib.reload(mr)
        result = mr.build_model_list()
    assert len(result) == 1
    assert result[0].validation_status == "missing_primary"
    assert result[0].primary_file_exists is False


def test_registry_endpoint_requires_auth(client):
    """GET /api/v1/models/registry must reject unauthenticated requests."""
    res = client.get("/api/v1/models/registry")
    assert res.status_code in (401, 403)
```

### 12.1 Final test run

```powershell
cd d:\OtherProjects\AI-companion-project\backend
.venv\Scripts\pytest tests/ -v --tb=short
```

Expected: **53 passed** (49 original + 4 new).

---

## Phase 13 — Update docs/01_Tracking/task.md

After all phases pass, update `task.md` IN-PLACE (do not prepend, do not add duplicate headings):

1. Change the sprint name line to:
   `- Current Sprint: Track R2-lite — Runtime Rename & Model Registry`
2. Change the branch line to remain:
   `- Branch: feature/assistant-orchestration-and-memory`
3. Update CURRENT EXECUTION STATE block to reflect completion
4. Append new checklist items as `[x]` completed:
   ```
   - [x] Task R2-lite.1: Rename provider/ → runtime/ filesystem + config + .gitignore
   - [x] Task R2-lite.2: Reorganize models/vision/ into per-model subdirectories
   - [x] Task R2-lite.3: Create models/registry.template.json committed template
   - [x] Task R2-lite.4: Backend ModelRegistryEntry schema + model_registry service
   - [x] Task R2-lite.5: Backend GET /api/v1/models/registry endpoint
   - [x] Task R2-lite.6: Frontend registryApi.ts + LocalModel type extensions
   - [x] Task R2-lite.7: ModelsView.tsx — live registry load + hardcoded name fix + variant badges
   - [x] Task R2-lite.8: test_model_registry.py — 4 tests, 53 total passing
   - [x] Task R2-lite.9: Update all arch docs provider/ → runtime/
   - [ ] Task R2-lite.10: Manual verification checklist (user-owned)
   ```

---

## Phase 14 — Proposed Commit Message (User Reviews and Commits Manually)

```
feat(r2-lite): runtime rename, per-model subdirs, and dynamic model registry

- filesystem: provider/ → runtime/ (gitignored native engine binaries)
- config: PROVIDER_DIR → RUNTIME_DIR; LLAMA_CPP_BIN_DIR → runtime/llama.cpp/
- gitignore: remove bare `provider/` line (runtime/ already on line 94)
- models/vision/: flat files → 5 per-model subdirectories
- models/registry.template.json: new committed template
- backend: ModelRegistryEntry schema (variant, capabilities, companion_files,
  validation_status, size_gb)
- backend: model_registry service (registry-assisted auto-discovery, companion
  validation, graceful fallback when registry.json absent)
- backend: GET /api/v1/models/registry (protected_router, Master Plan §16.2)
- frontend: registryApi.ts + LocalModel type extensions (variant, capabilities,
  validationStatus, hasCompanion, companionFilesValid)
- frontend: ModelsView.tsx — live registry on mount, mock fallback if offline;
  fix hardcoded Qwen2.5-7B-Instruct-Q4_K_M.gguf → entry.primary_file
- frontend: variant badges (Instruct / Thinking) + mmproj missing warning
- docs: all provider/ → runtime/ references updated
- tests: test_model_registry.py — 4 new tests (53 total passing)

Resolves: Track R2-lite (Master Plan §16.2 ModelRegistry)
Out of scope: runtime-manifest.json, verify-runtimes.ps1, providers/ rename
```

---

## Non-Negotiable Invariants

1. `runtime/` is always gitignored — never `git add` any binary
2. `models/registry.json` is always gitignored — only `registry.template.json` committed
3. Model load calls always use `entry.filePath` / `entry.primary_file`, never a hardcoded filename
4. `build_model_list()` is strictly read-only — never writes to `models/`
5. All original 49 tests must pass after Phase 2 and Phase 8
6. `RUNTIME_DIR` is always `BASE_DIR.parent / "runtime"` — no hardcoded absolute paths
7. No new Alembic migration needed for this sprint — registry is a JSON file only

---

## Scope Guard — Out of This Sprint

Version-pinned subdirs `runtime/llama.cpp/b10936/windows-vulkan-x64/` ·
`runtime-manifest.json` SHA256 checksums · `verify-runtimes.ps1` / `download-models.ps1` ·
`models/wakeword/`, `models/embedding/`, `models/reranker/` placeholders ·
`backend/app/providers/` directory rename · ModelRegistry SQLite persistence ·
IPC auth key for llama-server (Track R2 proper)
