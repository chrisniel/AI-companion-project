"""Model registry schemas — Master Plan §16.2, §16.3."""
from enum import Enum
from typing import List, Optional
from pydantic import Field
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
    runtime_model_id: str = ""
    display_name: str
    family: str = ""
    variant: str = "instruct"
    primary_file: str
    companion_files: List[CompanionFile] = Field(default_factory=list)
    quantization: str = ""
    parameters: str = ""
    context_limit: int = 4096
    capabilities: List[ModelCapability] = Field(default_factory=list)
    recommended_profiles: List[str] = Field(default_factory=lambda: ["balanced"])
    estimated_vram_gb: float = 0.0
    estimated_ram_gb: float = 0.0
    license: str = ""
    source: str = ""
    # Computed at runtime:
    validation_status: ValidationStatus = ValidationStatus.unregistered
    primary_file_exists: bool = False
    companion_files_valid: bool = True
    size_gb: Optional[float] = None
