import unittest
import json
import sys
import os

# Ensure scripts package is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from scripts import ci_policy

class DummyArgs:
    def __init__(self, **kwargs):
        for k, v in kwargs.items():
            setattr(self, k, v)

class TestCIPolicy(unittest.TestCase):
    def test_workflow_dispatch_forces_full_ci(self):
        args = DummyArgs(event="workflow_dispatch", target_branch="", files_json="[]")
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_backend"], "true")
        self.assertEqual(out["needs_frontend"], "true")
        self.assertEqual(out["needs_contract"], "true")
        self.assertEqual(out["needs_docs"], "true")
        
    def test_master_target_forces_full_ci(self):
        # PR to master
        args = DummyArgs(event="pull_request", target_branch="master", files_json=json.dumps(["docs/file.md"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_backend"], "true")
        
        # Push to master
        args2 = DummyArgs(event="push", target_branch="master", files_json=json.dumps(["docs/file.md"]))
        out2 = ci_policy.classify(args2)
        self.assertEqual(out2["needs_backend"], "true")
        
    def test_docs_only_develop(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["docs/file.md", "AGENTS.md"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_docs"], "true")
        self.assertEqual(out["needs_backend"], "false")
        self.assertEqual(out["needs_frontend"], "false")
        self.assertEqual(out["needs_contract"], "false")
        
    def test_backend_only_develop(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["backend/main.py"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_backend"], "true")
        self.assertEqual(out["needs_contract"], "true")
        self.assertEqual(out["needs_frontend"], "false")
        self.assertEqual(out["needs_docs"], "false")
        
    def test_unknown_forces_full_ci(self):
        # .github config file -> Full CI
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps([".github/workflows/ci.yml"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_backend"], "true")
        self.assertEqual(out["needs_frontend"], "true")
        self.assertEqual(out["needs_contract"], "true")
        self.assertEqual(out["needs_docs"], "true")

        # Unknown scripts -> Full CI
        args2 = DummyArgs(event="push", target_branch="develop", files_json=json.dumps(["scripts/deploy.sh"]))
        out2 = ci_policy.classify(args2)
        self.assertEqual(out2["needs_backend"], "true")
        
    def test_mixed_code_and_docs(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["frontend/src/App.tsx", "README.md"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_frontend"], "true")
        self.assertEqual(out["needs_docs"], "true")
        self.assertEqual(out["needs_backend"], "false")

    def test_contract_only(self):
        args = DummyArgs(event="push", target_branch="develop", files_json=json.dumps(["scripts/check_openapi_contract.py"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_contract"], "true")
        self.assertEqual(out["needs_backend"], "false")

    def test_invalid_json_fallback(self):
        args = DummyArgs(event="push", target_branch="develop", files_json="{invalid")
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_backend"], "true")

    def test_gate_pass(self):
        args = DummyArgs(
            classifier_status="success",
            requirements_json=json.dumps({"needs_backend": "true", "needs_frontend": "false", "needs_contract": "true", "needs_docs": "false"}),
            results_json=json.dumps({"backend": "success", "frontend": "skipped", "contract": "success", "docs_integrity": "skipped"})
        )
        self.assertTrue(ci_policy.gate(args))

    def test_gate_fail_required_skipped(self):
        args = DummyArgs(
            classifier_status="success",
            requirements_json=json.dumps({"needs_backend": "true", "needs_frontend": "false", "needs_contract": "false", "needs_docs": "false"}),
            results_json=json.dumps({"backend": "skipped", "frontend": "skipped", "contract": "skipped", "docs_integrity": "skipped"})
        )
        self.assertFalse(ci_policy.gate(args))
        
    def test_gate_fail_unrequired_success(self):
        args = DummyArgs(
            classifier_status="success",
            requirements_json=json.dumps({"needs_backend": "true", "needs_frontend": "false", "needs_contract": "false", "needs_docs": "false"}),
            results_json=json.dumps({"backend": "success", "frontend": "success", "contract": "skipped", "docs_integrity": "skipped"})
        )
        self.assertFalse(ci_policy.gate(args))
        
    def test_gate_fail_classifier_failed(self):
        args = DummyArgs(
            classifier_status="failure",
            requirements_json=json.dumps({"needs_backend": "true", "needs_frontend": "false", "needs_contract": "false", "needs_docs": "false"}),
            results_json=json.dumps({"backend": "success", "frontend": "skipped", "contract": "skipped", "docs_integrity": "skipped"})
        )
        self.assertFalse(ci_policy.gate(args))

    def test_gate_fail_missing_requirement(self):
        args = DummyArgs(
            classifier_status="success",
            requirements_json=json.dumps({"needs_backend": "true", "needs_frontend": "false", "needs_contract": "false"}), # missing needs_docs
            results_json=json.dumps({"backend": "success", "frontend": "skipped", "contract": "skipped", "docs_integrity": "skipped"})
        )
        self.assertFalse(ci_policy.gate(args))

    def test_gate_fail_invalid_requirement_value(self):
        args = DummyArgs(
            classifier_status="success",
            requirements_json=json.dumps({"needs_backend": "True", "needs_frontend": "false", "needs_contract": "false", "needs_docs": "false"}), # "True" instead of "true"
            results_json=json.dumps({"backend": "success", "frontend": "skipped", "contract": "skipped", "docs_integrity": "skipped"})
        )
        self.assertFalse(ci_policy.gate(args))

if __name__ == '__main__':
    unittest.main()
