"""Typed Decision D9 tool catalog with strict schema validation and Risk 0-3 boundaries."""

from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

PROHIBITED_RISK3_NAMES: frozenset[str] = frozenset(
    {
        "run_shell",
        "shell",
        "bash",
        "sh",
        "powershell",
        "cmd",
        "cmd_exec",
        "os_exec",
        "exec",
        "eval",
        "subprocess",
        "arbitrary_shell",
        "arbitrary_file_read",
        "arbitrary_file_write",
        "filesystem_read",
        "filesystem_write",
        "read_secrets",
        "get_credentials",
    }
)

PROHIBITED_RISK3_CATEGORIES: list[str] = [
    "Unrestricted OS shell, PowerShell, CMD, or arbitrary process execution (Risk 3 REJECTED)",
    "Unrestricted host filesystem traversal outside scoped domain adapters (Risk 3 REJECTED)",
    "Direct credential, secret store, or pairing-token inspection by models (Risk 3 REJECTED)",
    "Automated interactive browser form submission / Playwright automation (PC LATER)",
]

ALLOWED_PROVENANCES: frozenset[str] = frozenset(
    {
        "EXPLICIT_USER",
        "COMPANION_SUGGESTED",
        "APPROVED_ROUTINE",
        "SYSTEM_RECOVERY",
        "EXTERNAL_CONTENT",
    }
)


class _StrictToolArgs(BaseModel):
    """Base schema rejecting any unrecognized or injected tool parameters."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class WeatherLookupArgs(_StrictToolArgs):
    location: str = Field(..., min_length=1, max_length=120, description="City or region name.")


class WebSearchArgs(_StrictToolArgs):
    query: str = Field(..., min_length=1, max_length=300, description="Public search query.")
    max_results: int = Field(default=5, ge=1, le=8)


class WebFetchArgs(_StrictToolArgs):
    url: str = Field(..., min_length=8, max_length=1024, description="Public http/https URL.")


class ListTasksArgs(_StrictToolArgs):
    status: Optional[Literal["pending", "in_progress", "completed", "cancelled"]] = None
    limit: int = Field(default=20, ge=1, le=50)


class ListRemindersArgs(_StrictToolArgs):
    status: Optional[Literal["scheduled", "snoozed", "fired", "acknowledged", "dismissed", "cancelled"]] = None
    limit: int = Field(default=20, ge=1, le=50)


class ListAlarmsArgs(_StrictToolArgs):
    enabled_only: bool = False
    limit: int = Field(default=20, ge=1, le=50)


class SearchMemoriesArgs(_StrictToolArgs):
    query: str = Field(..., min_length=1, max_length=200)
    limit: int = Field(default=5, ge=1, le=10)


class CreateTaskArgs(_StrictToolArgs):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(default=None, max_length=1000)
    priority: Literal["low", "medium", "high", "urgent"] = "medium"
    category: Literal["work", "personal", "health", "study", "finance", "other"] = "personal"
    due_at: Optional[str] = Field(default=None, max_length=64)


class UpdateTaskArgs(_StrictToolArgs):
    task_id: str = Field(..., min_length=8, max_length=64)
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    status: Optional[Literal["pending", "in_progress", "completed", "cancelled"]] = None
    priority: Optional[Literal["low", "medium", "high", "urgent"]] = None


class CreateReminderArgs(_StrictToolArgs):
    title: str = Field(..., min_length=1, max_length=255)
    scheduled_at: str = Field(..., min_length=10, max_length=64, description="ISO-8601 UTC timestamp.")
    notes: Optional[str] = Field(default=None, max_length=1000)
    bypass_quiet_hours: bool = False
    center_popup: bool = True


class CreateAlarmArgs(_StrictToolArgs):
    label: str = Field(..., min_length=1, max_length=255)
    time_of_day: str = Field(..., pattern=r"^([01][0-9]|2[0-3]):([0-5][0-9])$")
    recurrence_days: Optional[list[int]] = None
    timezone: Optional[str] = Field(default=None, max_length=64)
    bypass_quiet_hours: bool = True


class DeleteTaskArgs(_StrictToolArgs):
    task_id: str = Field(..., min_length=8, max_length=64)


class DeleteReminderArgs(_StrictToolArgs):
    reminder_id: str = Field(..., min_length=8, max_length=64)


class DeleteAlarmArgs(_StrictToolArgs):
    alarm_id: str = Field(..., min_length=8, max_length=64)


@dataclass(frozen=True)
class ToolSpec:
    """Registered D9 tool metadata and strict request validator."""

    name: str
    description: str
    risk_tier: int
    domain: str
    reversible: bool
    args_model: type[_StrictToolArgs]


TOOL_REGISTRY: dict[str, ToolSpec] = {
    "weather_lookup": ToolSpec(
        name="weather_lookup",
        description="Check current public weather conditions and temperature for a location.",
        risk_tier=0,
        domain="web_info",
        reversible=True,
        args_model=WeatherLookupArgs,
    ),
    "web_search": ToolSpec(
        name="web_search",
        description="Search public web sources for current information.",
        risk_tier=0,
        domain="web_info",
        reversible=True,
        args_model=WebSearchArgs,
    ),
    "web_fetch": ToolSpec(
        name="web_fetch",
        description="Fetch and sanitize readable text from a public http/https URL.",
        risk_tier=0,
        domain="web_info",
        reversible=True,
        args_model=WebFetchArgs,
    ),
    "list_tasks": ToolSpec(
        name="list_tasks",
        description="List active tasks owned by the current profile.",
        risk_tier=0,
        domain="productivity",
        reversible=True,
        args_model=ListTasksArgs,
    ),
    "list_reminders": ToolSpec(
        name="list_reminders",
        description="List scheduled or recent reminders owned by the current profile.",
        risk_tier=0,
        domain="scheduling",
        reversible=True,
        args_model=ListRemindersArgs,
    ),
    "list_alarms": ToolSpec(
        name="list_alarms",
        description="List alarms owned by the current profile.",
        risk_tier=0,
        domain="scheduling",
        reversible=True,
        args_model=ListAlarmsArgs,
    ),
    "search_memories": ToolSpec(
        name="search_memories",
        description="Search verified profile/character memories using lexical FTS5.",
        risk_tier=0,
        domain="memory",
        reversible=True,
        args_model=SearchMemoriesArgs,
    ),
    "create_task": ToolSpec(
        name="create_task",
        description="Create a new personal task for the active profile.",
        risk_tier=1,
        domain="productivity",
        reversible=True,
        args_model=CreateTaskArgs,
    ),
    "update_task": ToolSpec(
        name="update_task",
        description="Update title, status, or priority of an existing profile task.",
        risk_tier=1,
        domain="productivity",
        reversible=True,
        args_model=UpdateTaskArgs,
    ),
    "create_reminder": ToolSpec(
        name="create_reminder",
        description="Schedule a profile reminder at an ISO-8601 UTC timestamp.",
        risk_tier=1,
        domain="scheduling",
        reversible=True,
        args_model=CreateReminderArgs,
    ),
    "create_alarm": ToolSpec(
        name="create_alarm",
        description="Create an alarm for a 24-hour HH:MM time and optional weekday recurrence.",
        risk_tier=1,
        domain="scheduling",
        reversible=True,
        args_model=CreateAlarmArgs,
    ),
    "delete_task": ToolSpec(
        name="delete_task",
        description="Move an active profile task to the 30-day recoverable trash.",
        risk_tier=2,
        domain="productivity",
        reversible=False,
        args_model=DeleteTaskArgs,
    ),
    "delete_reminder": ToolSpec(
        name="delete_reminder",
        description="Soft-delete an active profile reminder.",
        risk_tier=2,
        domain="scheduling",
        reversible=False,
        args_model=DeleteReminderArgs,
    ),
    "delete_alarm": ToolSpec(
        name="delete_alarm",
        description="Soft-delete an active profile alarm.",
        risk_tier=2,
        domain="scheduling",
        reversible=False,
        args_model=DeleteAlarmArgs,
    ),
}


def _compact_json_schema(node: Any) -> Any:
    """Strip Pydantic title metadata and flatten nullable anyOf unions for tight LLM contexts."""
    if isinstance(node, list):
        return [_compact_json_schema(item) for item in node]
    if not isinstance(node, dict):
        return node

    any_of = node.get("anyOf")
    if isinstance(any_of, list) and len(any_of) == 2 and {"type": "null"} in any_of:
        non_null = [item for item in any_of if item != {"type": "null"}]
        if len(non_null) == 1 and isinstance(non_null[0], dict):
            merged = dict(non_null[0])
            for key, value in node.items():
                if key in ("anyOf", "title"):
                    continue
                if key == "default" and value is None:
                    continue
                merged[key] = value
            return _compact_json_schema(merged)

    compacted: dict[str, Any] = {}
    for key, value in node.items():
        if key == "title":
            continue
        if key == "default" and value is None:
            continue
        if key == "properties" and isinstance(value, dict):
            # Property names like "title" belong to tool argument schemas and must be preserved.
            compacted["properties"] = {
                prop_name: _compact_json_schema(prop_schema)
                for prop_name, prop_schema in value.items()
            }
            continue
        compacted[key] = _compact_json_schema(value)
    return compacted


def get_openai_tool_definitions() -> list[dict[str, Any]]:
    """Return compacted OpenAI-compatible JSON Schema tool descriptors for LLM inference."""
    definitions: list[dict[str, Any]] = []
    for spec in TOOL_REGISTRY.values():
        definitions.append(
            {
                "type": "function",
                "function": {
                    "name": spec.name,
                    "description": spec.description,
                    "parameters": _compact_json_schema(spec.args_model.model_json_schema()),
                },
            }
        )
    return definitions


def estimate_openai_tools_tokens(tools: Optional[list[dict[str, Any]]] = None) -> int:
    """Estimate conservative prompt tokens consumed by OpenAI tool schemas in chat templates."""
    payload = tools if tools is not None else get_openai_tool_definitions()
    if not payload:
        return 0
    raw = json.dumps(payload, separators=(",", ":"))
    # Account for JSON punctuation tokenization density plus chat-template XML wrapper overhead.
    return max(1, len(raw) // 3) + 250
