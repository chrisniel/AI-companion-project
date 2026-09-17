"""Model registry schemas — Master Plan §16.2, §16.3 (Batch 8P.4 Schema v3)."""
from enum import Enum
from typing import Any, List, Literal, Optional
from pydantic import Field, computed_field, model_validator
from app.schemas.common import BaseSchema


class ModelCapability(str, Enum):
    chat = "chat"
    vision = "vision"
    reasoning = "reasoning"
    structured_output = "structured_output"
    tool_calling = "tool_calling"
    multilingual = "multilingual"


class ModelAssetType(str, Enum):
    gguf = "gguf"
    mmproj = "mmproj"
    lora = "lora"
    embedding = "embedding"
    tokenizer = "tokenizer"


class ModelVariant(str, Enum):
    instruct = "instruct"
    thinking = "thinking"
    base = "base"
    code = "code"
    unknown = "unknown"


class InputModality(str, Enum):
    text = "text"
    image = "image"
    audio = "audio"
    video = "video"


class ModelDiscoveryState(str, Enum):
    discovered = "discovered"
    registered = "registered"
    verified = "verified"
    incompatible = "incompatible"


class ReasoningMode(str, Enum):
    always_on = "always_on"
    toggleable = "toggleable"
    unsupported = "unsupported"
    unknown = "unknown"


class CapabilityProvenance(str, Enum):
    declared = "declared"
    detected = "detected"
    verified = "verified"
    unknown = "unknown"


class ValidationStatus(str, Enum):
    verified = "verified"
    missing_primary = "missing_primary"
    missing_companion = "missing_companion"
    unregistered = "unregistered"
    incompatible = "incompatible"


class CompanionFile(BaseSchema):
    role: str   # "mmproj" | "tokenizer"
    path: str   # relative to models/
    sha256: Optional[str] = None


class CapabilityEntry(BaseSchema):
    capability: ModelCapability
    supported: bool = True
    provenance: CapabilityProvenance = CapabilityProvenance.unknown


class CompanionArtifactStatus(BaseSchema):
    artifact: CompanionFile
    exists: bool = False


class GenerationDefaults(BaseSchema):
    temperature: Optional[float] = None
    top_p: Optional[float] = None
    top_k: Optional[int] = None
    min_p: Optional[float] = None
    repeat_penalty: Optional[float] = None


class ModelManifest(BaseSchema):
    """Stable identity and artifact metadata (what the artifact IS)."""
    id: str
    display_name: str
    asset_type: ModelAssetType = ModelAssetType.gguf
    family: str = ""
    architecture: str = ""
    variant: ModelVariant = ModelVariant.unknown
    parameters: str = ""
    quantization: str = ""
    reasoning_mode: ReasoningMode = ReasoningMode.unknown
    capabilities: List[ModelCapability] = Field(default_factory=list)
    input_modalities: List[InputModality] = Field(default_factory=list)
    model_max_context: Optional[int] = None
    runtime_compatibility: List[str] = Field(default_factory=list)
    primary_file: str
    companion_files: List[CompanionFile] = Field(default_factory=list)
    chat_template: Optional[str] = None
    license: str = ""
    source: str = ""
    sha256_primary: Optional[str] = None


class ModelLibraryState(BaseSchema):
    """Computed/local validation state (what the library knows)."""
    discovery_state: ModelDiscoveryState = ModelDiscoveryState.discovered
    validation_status: ValidationStatus = ValidationStatus.unregistered
    primary_file_exists: bool = False
    size_gb: Optional[float] = None
    companion_artifact_statuses: List[CompanionArtifactStatus] = Field(default_factory=list)
    available_capabilities: List[ModelCapability] = Field(default_factory=list)
    capability_provenance: List[CapabilityEntry] = Field(default_factory=list)


class ModelRuntimeHints(BaseSchema):
    """Non-authoritative runtime/hardware recommendations."""
    recommended_profiles: List[str] = Field(default_factory=list)
    estimated_vram_gb: float = 0.0
    estimated_ram_gb: float = 0.0
    generation_defaults: Optional[GenerationDefaults] = None


class ModelRegistryEntry(BaseSchema):
    """Three-layer structured model registry entry with temporary flat compatibility bridge."""
    manifest: ModelManifest
    library_state: ModelLibraryState
    hints: ModelRuntimeHints
    runtime_model_id: str = ""
    registry_source: Literal["factory", "installed"] = "factory"

    @model_validator(mode="before")
    @classmethod
    def _migrate_flat_input(cls, data: Any) -> Any:
        """Allow instantiation via flat dict/kwargs for backward compatibility while enforcing BaseSchema extra='forbid'."""
        if isinstance(data, dict) and "manifest" not in data:
            known_top = {"runtime_model_id", "registry_source"}
            manifest_keys = {
                "id", "display_name", "asset_type", "family", "architecture", "variant",
                "parameters", "quantization", "reasoning_mode", "capabilities", "input_modalities",
                "model_max_context", "context_limit", "runtime_compatibility", "primary_file",
                "companion_files", "chat_template", "license", "source", "sha256_primary"
            }
            library_keys = {
                "discovery_state", "validation_status", "primary_file_exists", "size_gb",
                "companion_artifact_statuses", "companion_files_valid", "available_capabilities", "capability_provenance"
            }
            hints_keys = {
                "recommended_profiles", "estimated_vram_gb", "estimated_ram_gb", "generation_defaults"
            }
            all_known = known_top | manifest_keys | library_keys | hints_keys
            extras = {k: v for k, v in data.items() if k not in all_known}

            # Map context_limit -> model_max_context if not present
            manifest_dict = {}
            for k in manifest_keys:
                if k == "context_limit":
                    if "model_max_context" not in data and "context_limit" in data:
                        manifest_dict["model_max_context"] = data["context_limit"]
                elif k in data:
                    manifest_dict[k] = data[k]

            library_dict = {}
            for k in library_keys:
                if k == "companion_files_valid":
                    continue  # derived/computed
                if k in data:
                    library_dict[k] = data[k]

            hints_dict = {k: data[k] for k in hints_keys if k in data}

            res = {
                "manifest": manifest_dict,
                "library_state": library_dict,
                "hints": hints_dict,
                "runtime_model_id": data.get("runtime_model_id") or data.get("id", ""),
                "registry_source": data.get("registry_source", "factory"),
            }
            res.update(extras)
            return res
        return data

    # --- Temporary Flat Serialization Bridge (for existing Frontend & Test Contracts) ---

    @computed_field
    @property
    def id(self) -> str:
        return self.manifest.id

    @id.setter
    def id(self, val: str) -> None:
        self.manifest.id = val

    @computed_field
    @property
    def display_name(self) -> str:
        return self.manifest.display_name

    @display_name.setter
    def display_name(self, val: str) -> None:
        self.manifest.display_name = val

    @computed_field
    @property
    def family(self) -> str:
        return self.manifest.family

    @family.setter
    def family(self, val: str) -> None:
        self.manifest.family = val

    @computed_field
    @property
    def variant(self) -> str:
        return self.manifest.variant.value if isinstance(self.manifest.variant, ModelVariant) else str(self.manifest.variant)

    @variant.setter
    def variant(self, val: Any) -> None:
        self.manifest.variant = ModelVariant(val) if isinstance(val, str) else val

    @computed_field
    @property
    def primary_file(self) -> str:
        return self.manifest.primary_file

    @primary_file.setter
    def primary_file(self, val: str) -> None:
        self.manifest.primary_file = val

    @computed_field
    @property
    def companion_files(self) -> List[CompanionFile]:
        return self.manifest.companion_files

    @companion_files.setter
    def companion_files(self, val: List[CompanionFile]) -> None:
        self.manifest.companion_files = val

    @computed_field
    @property
    def quantization(self) -> str:
        return self.manifest.quantization

    @quantization.setter
    def quantization(self, val: str) -> None:
        self.manifest.quantization = val

    @computed_field
    @property
    def parameters(self) -> str:
        return self.manifest.parameters

    @parameters.setter
    def parameters(self, val: str) -> None:
        self.manifest.parameters = val

    @computed_field
    @property
    def context_limit(self) -> Optional[int]:
        return self.manifest.model_max_context

    @context_limit.setter
    def context_limit(self, val: Optional[int]) -> None:
        self.manifest.model_max_context = val

    @computed_field
    @property
    def capabilities(self) -> List[ModelCapability]:
        return self.manifest.capabilities

    @capabilities.setter
    def capabilities(self, val: List[ModelCapability]) -> None:
        self.manifest.capabilities = val

    @computed_field
    @property
    def recommended_profiles(self) -> List[str]:
        return self.hints.recommended_profiles

    @recommended_profiles.setter
    def recommended_profiles(self, val: List[str]) -> None:
        self.hints.recommended_profiles = val

    @computed_field
    @property
    def estimated_vram_gb(self) -> float:
        return self.hints.estimated_vram_gb

    @estimated_vram_gb.setter
    def estimated_vram_gb(self, val: float) -> None:
        self.hints.estimated_vram_gb = val

    @computed_field
    @property
    def estimated_ram_gb(self) -> float:
        return self.hints.estimated_ram_gb

    @estimated_ram_gb.setter
    def estimated_ram_gb(self, val: float) -> None:
        self.hints.estimated_ram_gb = val

    @computed_field
    @property
    def license(self) -> str:
        return self.manifest.license

    @license.setter
    def license(self, val: str) -> None:
        self.manifest.license = val

    @computed_field
    @property
    def source(self) -> str:
        return self.manifest.source

    @source.setter
    def source(self, val: str) -> None:
        self.manifest.source = val

    @computed_field
    @property
    def validation_status(self) -> ValidationStatus:
        return self.library_state.validation_status

    @validation_status.setter
    def validation_status(self, val: ValidationStatus) -> None:
        self.library_state.validation_status = val

    @computed_field
    @property
    def primary_file_exists(self) -> bool:
        return self.library_state.primary_file_exists

    @primary_file_exists.setter
    def primary_file_exists(self, val: bool) -> None:
        self.library_state.primary_file_exists = val

    @computed_field
    @property
    def companion_files_valid(self) -> bool:
        if not self.manifest.companion_files:
            return True
        if self.library_state.companion_artifact_statuses:
            return all(s.exists for s in self.library_state.companion_artifact_statuses)
        return self.library_state.validation_status != ValidationStatus.missing_companion

    @companion_files_valid.setter
    def companion_files_valid(self, val: bool) -> None:
        if not val and self.library_state.validation_status == ValidationStatus.verified:
            self.library_state.validation_status = ValidationStatus.missing_companion

    @computed_field
    @property
    def size_gb(self) -> Optional[float]:
        return self.library_state.size_gb

    @size_gb.setter
    def size_gb(self, val: Optional[float]) -> None:
        self.library_state.size_gb = val
