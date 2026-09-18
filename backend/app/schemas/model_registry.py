"""Model registry schemas — Master Plan §16.2, §16.3 (Batch 8P.4 Schema v3)."""
from enum import Enum
from typing import Any, List, Literal, Optional
from pydantic import Field
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
    """Three-layer structured model registry entry (Schema v3)."""
    manifest: ModelManifest
    library_state: ModelLibraryState
    hints: ModelRuntimeHints
    runtime_model_id: str = ""
    registry_source: Literal["factory", "installed"] = "factory"
