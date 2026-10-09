#!/usr/bin/env python3
"""
Unit tests for check_dart_openapi_parity.py.

Verifies fail-closed behavior of contract parity verification,
strict MessageSend semantic enforcement, and route coverage analysis.
"""

import unittest
from pathlib import Path
import sys

SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import check_dart_openapi_parity as checker


class TestCheckDartOpenApiParity(unittest.TestCase):
    def test_all_parity_checks_pass(self):
        """Current repository schemas and Dart DTOs must pass all parity checks."""
        success, report = checker.run_checks()
        self.assertTrue(success, f"Parity check failed:\n{report}")
        self.assertIn("ALL CONTRACT PARITY AND ROUTE COVERAGE CHECKS PASSED", report)

    def test_snake_to_camel(self):
        self.assertEqual(checker.snake_to_camel("user_text"), "userText")
        self.assertEqual(checker.snake_to_camel("client_message_id"), "clientMessageId")
        self.assertEqual(checker.snake_to_camel("database_connected"), "databaseConnected")
        self.assertEqual(checker.snake_to_camel("single"), "single")

    def test_message_send_contract_guards_null_serialization(self):
        """MessageSend must fail if toJson does not guard attachmentIds."""
        fake_dart_info_bad = checker.DartClassInfo(
            name="MessageSend",
            fields={},
            json_keys_read=set(),
            json_keys_written=set(),
            raw_source="Map<String, dynamic> toJson() => {'attachment_ids': attachmentIds};",
        )
        fake_schema_ok = {
            "properties": {
                "attachment_ids": {"type": "array"},
            }
        }
        errors = checker.verify_message_send_contract(fake_dart_info_bad, fake_schema_ok)
        self.assertTrue(any("guard attachmentIds" in err for err in errors))

    def test_message_send_contract_fails_on_nullable_schema(self):
        """MessageSend must fail if OpenAPI schema marks attachment_ids nullable."""
        fake_dart_info = checker.DartClassInfo(
            name="MessageSend",
            fields={},
            json_keys_read=set(),
            json_keys_written=set(),
            raw_source="Map<String, dynamic> toJson() { if (attachmentIds != null) map['attachment_ids'] = attachmentIds; }",
        )
        fake_schema_nullable = {
            "properties": {
                "attachment_ids": {
                    "anyOf": [{"type": "array"}, {"type": "null"}]
                }
            }
        }
        errors = checker.verify_message_send_contract(fake_dart_info, fake_schema_nullable)
        self.assertTrue(any("must NOT be nullable" in err for err in errors))

    def test_verify_route_coverage_fails_closed_on_unknown_route(self):
        """Unexpected route in OpenAPI must fail closed."""
        fake_openapi = {
            "paths": {
                "/api/v1/health": {"get": {}},
                "/api/v1/unexpected_new_route": {"post": {}},
            }
        }
        errors, _, _ = checker.verify_route_coverage(fake_openapi)
        self.assertTrue(any("uncataloged route" in err for err in errors))

    def test_verify_companion_client_implementations_passes(self):
        """CompanionClient must implement all 12 M1 routes with correct path templates."""
        errors, verified = checker.verify_companion_client_implementations(checker.CLIENT_PATH)
        self.assertEqual(errors, [])
        self.assertEqual(len(verified), 12)

    def test_verify_companion_client_implementations_fails_on_missing_method(self):
        """Missing implementation method must fail closed."""
        import tempfile
        with tempfile.NamedTemporaryFile("w+", encoding="utf-8", delete=False) as tf:
            tf.write("// Empty client without required methods")
            temp_path = Path(tf.name)
        try:
            errors, verified = checker.verify_companion_client_implementations(temp_path)
            self.assertTrue(len(errors) > 0)
            self.assertTrue(any("lacks method" in err for err in errors))
        finally:
            if temp_path.exists():
                temp_path.unlink()


if __name__ == "__main__":
    unittest.main()
