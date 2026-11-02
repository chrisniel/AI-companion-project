"""Character schemas for templates, presets, instances, and active selection (PC-CHAR-001, PC-CHAR-005)."""

from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


CharacterPresetId = Literal[
    "custom",
    "warm_companion",
    "playful",
    "formal_advisor",
    "tsundere",
    "kuudere",
    "dandere",
    "yandere",
]


class CharacterTraitVector(BaseModel):
    """Eight continuous personality trait dimensions (0-100)."""
    model_config = ConfigDict(from_attributes=True)

    warmth: int = Field(..., ge=0, le=100, description="Empathy, friendliness, and emotional warmth")
    teasing: int = Field(..., ge=0, le=100, description="Playfulness, banter, and lighthearted sarcasm")
    guardedness: int = Field(..., ge=0, le=100, description="Emotional reserve and boundary maintenance")
    directness: int = Field(..., ge=0, le=100, description="Candor, frankness, and communication directness")
    expressiveness: int = Field(..., ge=0, le=100, description="Emotional and linguistic expressiveness")
    affection: int = Field(..., ge=0, le=100, description="Affectionate phrasing and emotional closeness")
    formality: int = Field(..., ge=0, le=100, description="Grammatical and stylistic formality")
    verbosity: int = Field(..., ge=0, le=100, description="Sentence length and elaboration depth")


class CharacterPresetOut(BaseModel):
    """Candidate baseline trait configuration for a frozen personality preset."""
    model_config = ConfigDict(from_attributes=True)

    preset_id: CharacterPresetId
    label: str
    description: str
    traits: CharacterTraitVector


class CharacterTemplateOut(BaseModel):
    """Application-owned, immutable/versioned character template definition."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    template_version: int
    name: str
    summary: str
    lore: str
    system_prompt: str
    avatar_asset: str
    default_preset_id: Optional[CharacterPresetId] = None
    is_neutral_fallback: bool
    traits: Optional[CharacterTraitVector] = None
    created_at: datetime
    updated_at: datetime


class NeutralAssistantOut(BaseModel):
    """Immutable Neutral Assistant fallback definition."""
    model_config = ConfigDict(from_attributes=True)

    id: str = "neutral-assistant"
    compatibility_alias: str = "default"
    template_version: int = 1
    name: str = "Neutral Assistant"
    summary: str = "Objective, dependable system assistant fallback."
    system_prompt: str
    avatar_asset: str = "neutral_avatar"
    is_neutral_fallback: bool = True
    traits: Optional[CharacterTraitVector] = None
    lore: str = ""


class CharacterInstanceCreate(BaseModel):
    """Payload to instantiate a Profile-owned CharacterInstance snapshot from a template."""
    model_config = ConfigDict(extra="forbid")

    template_id: str = Field(..., min_length=1, max_length=64)
    preset_id: Optional[CharacterPresetId] = None
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    summary: Optional[str] = Field(None, max_length=500)
    lore: Optional[str] = None
    system_prompt: Optional[str] = None
    avatar_asset: Optional[str] = Field(None, min_length=1, max_length=255)
    traits: Optional[CharacterTraitVector] = None

    @field_validator("template_id")
    @classmethod
    def validate_template_id(cls, v: str) -> str:
        if v in ("neutral-assistant", "default"):
            raise ValueError("Neutral Assistant fallback is immutable and cannot be instantiated as an editable instance")
        return v


class CharacterInstanceUpdate(BaseModel):
    """Payload to update a Profile-owned CharacterInstance snapshot.
    
    Condition A:
    - Omitted fields mean unchanged.
    - Explicit null is rejected for fields that must retain non-null values.
    """
    model_config = ConfigDict(extra="forbid")

    name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    summary: Optional[str] = Field(default=None, max_length=500)
    lore: Optional[str] = Field(default=None)
    system_prompt: Optional[str] = Field(default=None)
    avatar_asset: Optional[str] = Field(default=None, min_length=1, max_length=255)
    preset_id: Optional[CharacterPresetId] = Field(default=None)
    traits: Optional[CharacterTraitVector] = Field(default=None)
    status: Optional[Literal["active", "archived"]] = Field(default=None)

    @model_validator(mode="before")
    @classmethod
    def validate_explicit_nulls(cls, values):
        if not isinstance(values, dict):
            return values
        # Reject explicit null for fields that cannot be null in database
        non_nullable_fields = [
            "name",
            "summary",
            "lore",
            "system_prompt",
            "avatar_asset",
            "preset_id",
            "traits",
            "status",
        ]
        for field in non_nullable_fields:
            if field in values and values[field] is None:
                raise ValueError(f"Field '{field}' cannot be null")
        return values


class CharacterInstanceOut(BaseModel):
    """Profile-owned character instance representation."""
    model_config = ConfigDict(from_attributes=True)

    id: str
    profile_id: str
    is_legacy_placeholder: bool = False
    legacy_character_id: Optional[str] = None
    template_id: Optional[str] = None
    source_template_version: Optional[int] = None
    name: str
    summary: str
    lore: str
    system_prompt: str
    avatar_asset: str
    preset_id: Optional[CharacterPresetId] = None
    traits: Optional[CharacterTraitVector] = None
    status: str
    is_active_for_profile: bool = False
    created_at: datetime
    updated_at: datetime


class ActiveCharacterStateOut(BaseModel):
    """Current active character state for the authenticated Profile."""
    model_config = ConfigDict(from_attributes=True)

    profile_id: str
    is_neutral_fallback: bool
    active_character_id: str
    active_character_instance_id: Optional[str] = None
    neutral_fallback: NeutralAssistantOut
    active_instance: Optional[CharacterInstanceOut] = None


class ActiveCharacterSelectRequest(BaseModel):
    """Request to select active character for the authenticated Profile."""
    model_config = ConfigDict(extra="forbid")

    character_id: str = Field(..., min_length=1, max_length=64, description="'default', 'neutral-assistant', or owned instance ID")
