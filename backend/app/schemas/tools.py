"""Pydantic v2 schemas for D9 deterministic tool policy, confirmations, audit, and Web info."""

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import Field

from app.schemas.common import BaseSchema


class WebSourceRefOut(BaseSchema):
    """Normalized source attribution link for read-only external retrieval."""

    title: str
    url: str
    domain: str
    snippet: Optional[str] = None


class ToolReceiptOut(BaseSchema):
    """Committed action receipt persisted on assistant turns (D-SHARED-CONV-03A)."""

    tool_name: str
    risk_tier: int
    provenance: str
    decision: str
    outcome_status: str
    summary: str
    duration_ms: Optional[int] = None


class ToolCatalogItemOut(BaseSchema):
    """Read-only description of a registered D9 typed tool."""

    name: str
    description: str
    risk_tier: int
    domain: str
    reversible: bool


class ToolCatalogOut(BaseSchema):
    """Catalog of registered D9 tools plus permanently rejected Risk 3 classes."""

    items: List[ToolCatalogItemOut] = Field(default_factory=list)
    prohibited_capabilities: List[str] = Field(default_factory=list)


class ToolPolicyOut(BaseSchema):
    """Combined profile D9 policy settings, global Kill Switch, and non-secret Web config."""

    profile_id: str
    global_kill_switch: bool
    kill_switch_updated_at: Optional[datetime] = None
    kill_switch_reason: Optional[str] = None
    risk0_policy: Literal["allow", "confirm", "deny"]
    risk1_explicit_policy: Literal["allow", "confirm", "deny"]
    risk1_suggested_policy: Literal["confirm", "deny"]
    risk2_policy: Literal["confirm", "deny"]
    weather_provider: Literal["open_meteo", "disabled"]
    web_search_provider: Literal["public_search", "searxng", "tavily", "brave", "disabled"]
    searxng_base_url: Optional[str] = None
    search_api_key_configured: bool = False
    updated_at: datetime


class ToolPolicyUpdate(BaseSchema):
    """Profile-scoped risk policy mutation payload."""

    risk0_policy: Optional[Literal["allow", "confirm", "deny"]] = None
    risk1_explicit_policy: Optional[Literal["allow", "confirm", "deny"]] = None
    risk1_suggested_policy: Optional[Literal["confirm", "deny"]] = None
    risk2_policy: Optional[Literal["confirm", "deny"]] = None


class KillSwitchStateOut(BaseSchema):
    """Persistent Global Tool Kill Switch status."""

    global_kill_switch: bool
    kill_switch_updated_at: Optional[datetime] = None
    kill_switch_reason: Optional[str] = None


class KillSwitchRequest(BaseSchema):
    """Toggle Global Tool Kill Switch (disengaging strictly requires Host Admin)."""

    enabled: bool
    reason: Optional[str] = Field(default=None, max_length=255)


class WebConfigUpdateRequest(BaseSchema):
    """Host-Admin-only Web retrieval provider configuration (secret stored out-of-DB)."""

    weather_provider: Optional[Literal["open_meteo", "disabled"]] = None
    web_search_provider: Optional[
        Literal["public_search", "searxng", "tavily", "brave", "disabled"]
    ] = None
    searxng_base_url: Optional[str] = Field(default=None, max_length=512)
    search_api_key: Optional[str] = Field(default=None, min_length=4, max_length=512)


class WebConfigOut(BaseSchema):
    """Non-secret Web retrieval provider configuration status."""

    weather_provider: Literal["open_meteo", "disabled"]
    web_search_provider: Literal["public_search", "searxng", "tavily", "brave", "disabled"]
    searxng_base_url: Optional[str] = None
    search_api_key_configured: bool = False


class WebApiKeyClearOut(BaseSchema):
    """Result of clearing the device-local Web Search API key."""

    cleared: bool
    search_api_key_configured: bool


class ToolConfirmationOut(BaseSchema):
    """Pending or resolved fingerprint-bound tool confirmation card."""

    id: str
    conversation_id: str
    tool_name: str
    risk_tier: int
    provenance: str
    target_summary: str
    arguments_preview: str
    fingerprint: str
    status: str
    expires_at: datetime
    created_at: datetime
    resolved_at: Optional[datetime] = None


class ToolConfirmationListOut(BaseSchema):
    """List of tool confirmations for the active profile."""

    items: List[ToolConfirmationOut] = Field(default_factory=list)
    total: int


class ToolConfirmationResolveRequest(BaseSchema):
    """Explicit user resolution for a pending confirmation."""

    decision: Literal["approve", "reject"]


class ToolConfirmationResolveResponse(BaseSchema):
    """Result of atomically resolving a pending confirmation."""

    confirmation: ToolConfirmationOut
    executed: bool
    outcome_status: str
    summary: str
    sources: List[WebSourceRefOut] = Field(default_factory=list)


class ToolAuditLogOut(BaseSchema):
    """Redacted tool audit record (zero prompts, secrets, or personal bodies)."""

    id: str
    profile_id: Optional[str] = None
    conversation_id: Optional[str] = None
    tool_name: str
    risk_tier: int
    provenance: str
    decision: str
    outcome_status: str
    duration_ms: Optional[int] = None
    source_domains: List[str] = Field(default_factory=list)
    error_code: Optional[str] = None
    created_at: datetime


class ToolAuditLogListOut(BaseSchema):
    """Paginated redacted tool audit ledger response."""

    items: List[ToolAuditLogOut] = Field(default_factory=list)
    total: int
