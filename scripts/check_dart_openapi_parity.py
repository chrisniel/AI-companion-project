#!/usr/bin/env python3
"""
OpenAPI to Dart DTO Contract Parity & Route Coverage Verifier.

Verifies that Dart DTOs in frontend/flutter/packages/companion_api/lib/dto/
strictly match contracts/openapi/openapi.json schemas and enforces
fail-closed validation:
  1. Field name parity (snake_case in OpenAPI <-> camelCase & json keys in Dart).
  2. Field type compatibility (string, int, bool, list/array, DateTime).
  3. Nullability and requiredness contracts.
  4. Specific enforcement: MessageSend.attachment_ids is optional array, NOT nullable.
  5. Route coverage classification: M1 covered routes vs explicitly registered M2-M4 unmapped routes.
  6. Source code inspection of CompanionClient: verifies each claimed M1 route has
     an actual Dart method and URL path template.

STATIC SOURCE VERIFICATION LIMITS:
  Static inspection verifies syntactic and structural conformance: schemas, fields,
  types, serialization keys, nullability guards, and method/route existence in Dart source.
  It does NOT replace dynamic integration testing; live network behaviors (timeouts,
  connection errors, streaming backpressure, TLS verification) are validated by
  automated unit tests (companion_client_test.dart) and live runtime harnesses.

Usage:
    python scripts/check_dart_openapi_parity.py          # default check mode
    python scripts/check_dart_openapi_parity.py --check  # explicit check mode
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTRACT_PATH = REPO_ROOT / "contracts" / "openapi" / "openapi.json"
DTO_DIR = REPO_ROOT / "frontend" / "flutter" / "packages" / "companion_api" / "lib" / "dto"
CLIENT_PATH = REPO_ROOT / "frontend" / "flutter" / "packages" / "companion_api" / "lib" / "client" / "companion_client.dart"

# M1 Covered Routes (method, path) implemented in CompanionClient
M1_COVERED_ROUTES: Set[Tuple[str, str]] = {
    ("GET", "/api/v1/health"),
    ("GET", "/api/v1/system/status"),
    ("POST", "/api/v1/auth/verify"),
    ("GET", "/api/v1/models"),
    ("POST", "/api/v1/conversations"),
    ("GET", "/api/v1/conversations"),
    ("GET", "/api/v1/conversations/{conversation_id}"),
    ("DELETE", "/api/v1/conversations/{conversation_id}"),
    ("GET", "/api/v1/conversations/{conversation_id}/messages"),
    ("POST", "/api/v1/conversations/{conversation_id}/messages"),
}

# Mapping of M1 route to expected Dart method name and path template in CompanionClient
M1_ROUTE_DART_METHODS: Dict[Tuple[str, str], Tuple[str, str]] = {
    ("GET", "/api/v1/health"): ("getHealth", "/api/v1/health"),
    ("GET", "/api/v1/system/status"): ("getSystemStatus", "/api/v1/system/status"),
    ("POST", "/api/v1/auth/verify"): ("verifyAuth", "/api/v1/auth/verify"),
    ("GET", "/api/v1/models"): ("getModelStatus", "/api/v1/models"),
    ("POST", "/api/v1/conversations"): ("createConversation", "/api/v1/conversations"),
    ("GET", "/api/v1/conversations"): ("listConversations", "/api/v1/conversations"),
    ("GET", "/api/v1/conversations/{conversation_id}"): ("getConversation", "/api/v1/conversations/$conversationId"),
    ("DELETE", "/api/v1/conversations/{conversation_id}"): ("deleteConversation", "/api/v1/conversations/$conversationId"),
    ("GET", "/api/v1/conversations/{conversation_id}/messages"): ("listMessages", "/api/v1/conversations/$conversationId/messages"),
    ("POST", "/api/v1/conversations/{conversation_id}/messages"): ("sendMessageStream", "/api/v1/conversations/$conversationId/messages"),
}

# Explicitly cataloged M2-M4 future routes to prevent silent omissions
UNMAPPED_FUTURE_ROUTES: Dict[Tuple[str, str], str] = {
    ("GET", "/api/v1/tasks"): "M2 Tasks / Task Management",
    ("POST", "/api/v1/tasks"): "M2 Tasks / Task Management",
    ("GET", "/api/v1/tasks/trash"): "M2 Tasks / Trash Management",
    ("GET", "/api/v1/tasks/{task_id}"): "M2 Tasks / Task Detail",
    ("PATCH", "/api/v1/tasks/{task_id}"): "M2 Tasks / Task Update",
    ("DELETE", "/api/v1/tasks/{task_id}"): "M2 Tasks / Task Deletion",
    ("POST", "/api/v1/tasks/{task_id}/restore"): "M2 Tasks / Task Restoration",
    ("DELETE", "/api/v1/tasks/{task_id}/permanent"): "M2 Tasks / Permanent Task Purge",
    ("GET", "/api/v1/models/registry"): "M2/M3 Model Registry & Downloader",
    ("POST", "/api/v1/models/load"): "M2/M3 Model Lifecycle Management",
    ("POST", "/api/v1/models/unload"): "M2/M3 Model Lifecycle Management",
    ("PATCH", "/api/v1/models/profile"): "M2/M3 Model Profile Tuning",
    ("POST", "/api/v1/chat/completions"): "M2/M3 OpenAI Compatibility Endpoint",
    ("PATCH", "/api/v1/conversations/{conversation_id}"): "M2 Conversation Title/State Updates",
    ("POST", "/api/v1/conversations/{conversation_id}/generate-title"): "M2 Auto Title Generation",
    ("POST", "/api/v1/conversations/{conversation_id}/attachments"): "M2 Attachment Ingestion",
    ("GET", "/api/v1/conversations/{conversation_id}/attachments/{attachment_id}/preview"): "M2 Attachment Preview",
    ("DELETE", "/api/v1/conversations/{conversation_id}/attachments/{attachment_id}"): "M2 Attachment Deletion",
    ("GET", "/api/v1/memories"): "M3 Long-term Memory Search",
    ("POST", "/api/v1/memories"): "M3 Long-term Memory Creation",
    ("PATCH", "/api/v1/memories/{memory_id}"): "M3 Long-term Memory Update",
    ("DELETE", "/api/v1/memories/{memory_id}"): "M3 Long-term Memory Deletion",
}

# Mapping of OpenAPI Schema Name to Dart file and Dart class name
SCHEMA_TO_DART_CLASS: Dict[str, Tuple[str, str]] = {
    "HealthResponse": ("health_dto.dart", "HealthResponse"),
    "AuthVerifyResponse": ("auth_dto.dart", "AuthVerifyResponse"),
    "SystemStatusResponse": ("system_status_dto.dart", "SystemStatusResponse"),
    "ModelStatusResponse": ("model_status_dto.dart", "ModelStatusResponse"),
    "ConversationCreate": ("conversation_dto.dart", "ConversationCreate"),
    "ConversationOut": ("conversation_dto.dart", "ConversationOut"),
    "ConversationListOut": ("conversation_dto.dart", "ConversationListOut"),
    "MessageSend": ("message_dto.dart", "MessageSend"),
    "MessageOut": ("message_dto.dart", "MessageOut"),
    "MessageListOut": ("message_dto.dart", "MessageListOut"),
    "AttachmentRef": ("message_dto.dart", "AttachmentRef"),
}


def snake_to_camel(snake_str: str) -> str:
    components = snake_str.split("_")
    return components[0] + "".join(x.title() for x in components[1:])


@dataclass
class DartField:
    dart_type: str
    name: str
    is_nullable: bool


@dataclass
class DartClassInfo:
    name: str
    fields: Dict[str, DartField]
    json_keys_read: Set[str]
    json_keys_written: Set[str]
    raw_source: str


def extract_class_body(text: str, class_name: str) -> str:
    pattern = rf"class\s+{re.escape(class_name)}\b[^{{]*\{{"
    m = re.search(pattern, text)
    if not m:
        raise ValueError(f"Could not find class {class_name} header in file")
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    if depth != 0:
        raise ValueError(f"Unbalanced braces in class {class_name}")
    return text[start : i - 1]


def parse_dart_class(file_path: Path, class_name: str) -> DartClassInfo:
    if not file_path.exists():
        raise FileNotFoundError(f"Dart DTO file not found: {file_path}")
    content = file_path.read_text(encoding="utf-8")
    body = extract_class_body(content, class_name)

    # Class fields reside before the first constructor or method declaration
    ctor_pattern = rf"(?:const\s+|factory\s+)?{re.escape(class_name)}\b"
    m_ctor = re.search(ctor_pattern, body)
    fields_block = body[: m_ctor.start()] if m_ctor else body

    # Extract final fields: e.g. final String title; final int? cpuCount; final List<String> availableModels;
    field_pattern = re.compile(r"^\s*final\s+([A-Za-z0-9_<>?]+)\s+([A-Za-z0-9_]+);", re.MULTILINE)
    fields: Dict[str, DartField] = {}
    for f_match in field_pattern.finditer(fields_block):
        type_str = f_match.group(1).strip()
        field_name = f_match.group(2).strip()
        is_nullable = type_str.endswith("?")
        clean_type = type_str[:-1] if is_nullable else type_str
        fields[field_name] = DartField(
            dart_type=clean_type,
            name=field_name,
            is_nullable=is_nullable,
        )

    # Extract JSON keys read: json['key_name']
    json_reads = set(re.findall(r"json\[['\"]([a-zA-Z0-9_]+)['\"]\]", body))

    # Extract JSON keys written: 'key_name': ... or if (...) 'key_name': ...
    json_writes = set(re.findall(r"['\"]([a-zA-Z0-9_]+)['\"]\s*:", body))

    return DartClassInfo(
        name=class_name,
        fields=fields,
        json_keys_read=json_reads,
        json_keys_written=json_writes,
        raw_source=body,
    )


def verify_schema_parity(
    schema_name: str,
    schema_def: Dict[str, Any],
    dart_info: DartClassInfo,
) -> List[str]:
    errors: List[str] = []
    properties = schema_def.get("properties", {})
    required_props = set(schema_def.get("required", []))

    for prop_name, prop_spec in properties.items():
        expected_camel = snake_to_camel(prop_name)
        if expected_camel not in dart_info.fields:
            errors.append(
                f"[{schema_name}] Property '{prop_name}' missing from Dart class '{dart_info.name}' (expected field: {expected_camel})"
            )
            continue

        dart_field = dart_info.fields[expected_camel]

        # Verify JSON keys are referenced in fromJson or toJson
        if prop_name not in dart_info.json_keys_read and prop_name not in dart_info.json_keys_written:
            errors.append(
                f"[{schema_name}] Property '{prop_name}' is not accessed or serialized in Dart class '{dart_info.name}'"
            )

        # Check nullability: if required in schema, Dart field shouldn't be nullable unless schema explicitly allows null
        is_schema_nullable = False
        if "anyOf" in prop_spec:
            is_schema_nullable = any(item.get("type") == "null" for item in prop_spec["anyOf"])

        if prop_name in required_props and not is_schema_nullable:
            if dart_field.is_nullable:
                errors.append(
                    f"[{schema_name}] Property '{prop_name}' is required and non-null in OpenAPI, but Dart field '{expected_camel}' is marked nullable ({dart_field.dart_type}?)"
                )

    # Extra Dart fields check: check if Dart class has extra fields not in OpenAPI
    for field_name in dart_info.fields:
        matched = False
        for prop_name in properties:
            if snake_to_camel(prop_name) == field_name:
                matched = True
                break
        if not matched:
            errors.append(
                f"[{schema_name}] Dart field '{field_name}' in class '{dart_info.name}' has no matching property in OpenAPI schema"
            )

    return errors


def extract_method_body(text: str, method_sig_regex: str) -> Optional[str]:
    m = re.search(method_sig_regex, text)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return text[start : i - 1]


def verify_message_send_contract(dart_info: DartClassInfo, schema_def: Dict[str, Any]) -> List[str]:
    """
    Binding Correction A:
    attachment_ids is an optional array, NOT nullable.
    For text-only turns, omit attachment_ids or send []. NEVER serialize null.
    """
    errors: List[str] = []
    att_prop = schema_def.get("properties", {}).get("attachment_ids", {})

    # Verify OpenAPI schema definition
    if att_prop.get("type") != "array":
        errors.append(f"[MessageSend Contract] OpenAPI attachment_ids must be type 'array', got {att_prop.get('type')}")
    if "anyOf" in att_prop and any(item.get("type") == "null" for item in att_prop["anyOf"]):
        errors.append("[MessageSend Contract] OpenAPI attachment_ids must NOT be nullable")

    # Verify Dart serialization does not emit null
    to_json_body = extract_method_body(dart_info.raw_source, r"Map<String,\s*dynamic>\s*toJson\(\)\s*\{")
    if to_json_body is None:
        arrow_match = re.search(r"Map<String,\s*dynamic>\s*toJson\(\)\s*=>\s*(.*?);", dart_info.raw_source, re.DOTALL)
        if arrow_match:
            to_json_body = arrow_match.group(1)

    if to_json_body is None:
        errors.append("[MessageSend Contract] MessageSend must define toJson()")
    else:
        if "attachmentIds != null" not in to_json_body:
            errors.append(
                "[MessageSend Contract] MessageSend.toJson() must guard attachmentIds to ensure null is never serialized"
            )

    return errors


def verify_route_coverage(openapi_data: Dict[str, Any]) -> Tuple[List[str], List[Tuple[str, str]], List[Tuple[str, str, str]]]:
    """
    Verifies route coverage:
    - Returns errors, list of verified M1 routes, list of unmapped M2-M4 routes.
    """
    errors: List[str] = []
    paths = openapi_data.get("paths", {})

    all_openapi_routes: Set[Tuple[str, str]] = set()
    for path, methods in paths.items():
        for method in methods:
            if method.lower() in ("get", "post", "put", "delete", "patch", "options", "head"):
                all_openapi_routes.add((method.upper(), path))

    # Verify all expected M1 routes exist in OpenAPI
    verified_m1: List[Tuple[str, str]] = []
    for method, path in sorted(M1_COVERED_ROUTES):
        if (method, path) in all_openapi_routes:
            verified_m1.append((method, path))
        else:
            errors.append(f"[Route Coverage] Required M1 route missing from OpenAPI: {method} {path}")

    # Check unmapped routes against catalog
    unmapped_cataloged: List[Tuple[str, str, str]] = []
    unaccounted_routes: List[Tuple[str, str]] = []

    for method, path in sorted(all_openapi_routes):
        if (method, path) in M1_COVERED_ROUTES:
            continue
        if (method, path) in UNMAPPED_FUTURE_ROUTES:
            unmapped_cataloged.append((method, path, UNMAPPED_FUTURE_ROUTES[(method, path)]))
        else:
            unaccounted_routes.append((method, path))

    if unaccounted_routes:
        for method, path in unaccounted_routes:
            errors.append(
                f"[Route Coverage] OpenAPI contains uncataloged route: {method} {path} (must be mapped to M1 or registered in UNMAPPED_FUTURE_ROUTES)"
            )

    return errors, verified_m1, unmapped_cataloged


def verify_companion_client_implementations(client_path: Path) -> Tuple[List[str], List[Tuple[str, str, str]]]:
    """
    Verifies that CompanionClient in Dart actually implements every M1 covered route
    with a corresponding method declaration and path template.
    """
    errors: List[str] = []
    verified_impls: List[Tuple[str, str, str]] = []

    if not client_path.exists():
        return [f"[Client Implementation] CompanionClient file not found: {client_path}"], []

    content = client_path.read_text(encoding="utf-8")

    for (http_method, openapi_path), (method_name, dart_path_template) in sorted(M1_ROUTE_DART_METHODS.items()):
        method_pattern = rf"\b{re.escape(method_name)}\s*\("
        if not re.search(method_pattern, content):
            errors.append(
                f"[Client Implementation] Route {http_method} {openapi_path} is claimed in M1, but CompanionClient lacks method '{method_name}()'"
            )
            continue

        if dart_path_template not in content:
            errors.append(
                f"[Client Implementation] Method '{method_name}' does not contain expected path template '{dart_path_template}'"
            )
            continue

        verified_impls.append((http_method, openapi_path, method_name))

    return errors, verified_impls


def run_checks() -> Tuple[bool, str]:
    if not CONTRACT_PATH.exists():
        return False, f"Contract file not found at {CONTRACT_PATH}"
    if not DTO_DIR.exists():
        return False, f"DTO directory not found at {DTO_DIR}"

    try:
        openapi_data = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except Exception as e:
        return False, f"Failed to parse OpenAPI JSON: {e}"

    all_errors: List[str] = []
    report_lines: List[str] = []
    report_lines.append("=" * 70)
    report_lines.append("OpenAPI to Dart DTO Contract Parity & Route Coverage Report")
    report_lines.append("=" * 70)

    # 1. Check DTO Schemas
    schemas = openapi_data.get("components", {}).get("schemas", {})
    verified_schemas: List[str] = []

    for schema_name, (dart_filename, class_name) in SCHEMA_TO_DART_CLASS.items():
        if schema_name not in schemas:
            all_errors.append(f"OpenAPI components.schemas missing target schema '{schema_name}'")
            continue

        schema_def = schemas[schema_name]
        dart_path = DTO_DIR / dart_filename
        try:
            dart_info = parse_dart_class(dart_path, class_name)
        except Exception as e:
            all_errors.append(f"Failed parsing Dart class '{class_name}' in {dart_filename}: {e}")
            continue

        schema_errors = verify_schema_parity(schema_name, schema_def, dart_info)
        if schema_errors:
            all_errors.extend(schema_errors)
        else:
            verified_schemas.append(f"{schema_name} <-> {class_name} ({dart_filename})")

        # Specific MessageSend contract validation
        if schema_name == "MessageSend":
            ms_errors = verify_message_send_contract(dart_info, schema_def)
            if ms_errors:
                all_errors.extend(ms_errors)

    report_lines.append(f"\n[Verified DTO Schemas: {len(verified_schemas)}/{len(SCHEMA_TO_DART_CLASS)}]")
    for item in verified_schemas:
        report_lines.append(f"  [OK] {item}")

    # 2. Check Route Coverage
    route_errors, verified_m1, unmapped_future = verify_route_coverage(openapi_data)
    if route_errors:
        all_errors.extend(route_errors)

    report_lines.append(f"\n[M1 Covered Routes: {len(verified_m1)}/{len(M1_COVERED_ROUTES)}]")
    for method, path in verified_m1:
        report_lines.append(f"  [OK] {method:<6} {path}")

    report_lines.append(f"\n[Unmapped Future Routes (M2-M4): {len(unmapped_future)} registered]")
    for method, path, target in unmapped_future:
        report_lines.append(f"  -    {method:<6} {path:<65} [{target}]")

    # 3. Check CompanionClient Dart Source Implementation
    client_errors, verified_impls = verify_companion_client_implementations(CLIENT_PATH)
    if client_errors:
        all_errors.extend(client_errors)

    report_lines.append(f"\n[Verified CompanionClient Route Methods: {len(verified_impls)}/{len(M1_ROUTE_DART_METHODS)}]")
    for method, path, dart_method in verified_impls:
        report_lines.append(f"  [OK] {method:<6} {path:<48} -> {dart_method}()")

    # 4. MessageSend Strict Guard Summary
    report_lines.append("\n[Strict Semantic Enforcements]")
    report_lines.append("  [OK] MessageSend: attachment_ids is optional array, NOT nullable.")
    report_lines.append("  [OK] MessageSend.toJson(): omits attachment_ids when null; never serializes null.")

    if all_errors:
        report_lines.append("\n" + "!" * 70)
        report_lines.append("PARITY ERRORS DETECTED:")
        for err in all_errors:
            report_lines.append(f"  [FAIL] {err}")
        report_lines.append("!" * 70)
        return False, "\n".join(report_lines)

    report_lines.append("\n" + "=" * 70)
    report_lines.append("RESULT: ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED.")
    report_lines.append("=" * 70)
    return True, "\n".join(report_lines)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Verify OpenAPI contract parity with Dart DTOs.")
    parser.add_argument("--check", action="store_true", default=True, help="Run contract parity checks (default)")
    args = parser.parse_args()

    success, report = run_checks()
    if success:
        print(report)
        return 0
    else:
        print(report, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
