import unittest
import json
import sys
import os
import subprocess

# Ensure scripts package is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from scripts import ci_policy

class DummyArgs:
    def __init__(self, **kwargs):
        for k, v in kwargs.items():
            setattr(self, k, v)

class TestCIPolicy(unittest.TestCase):
    FULL_REQUIREMENTS = {
        "needs_backend": "true", "needs_frontend": "true",
        "needs_contract": "true", "needs_docs": "true",
    }

    def test_develop_pushes_always_require_all_lanes(self):
        for files in (["backend/app/main.py"], ["docs/file.md"], ["frontend/web/src/App.tsx"]):
            with self.subTest(files=files):
                args = DummyArgs(event="push", target_branch="develop", files_json=json.dumps(files))
                self.assertEqual(ci_policy.classify(args), self.FULL_REQUIREMENTS)

    def test_later_docs_push_cannot_replace_backend_coverage_with_scoped_green(self):
        # A cancelled earlier run is covered by the complete later integrated tree.
        for files in (["backend/app/main.py"], ["docs/file.md"]):
            requirements = ci_policy.classify(DummyArgs(
                event="push", target_branch="develop", files_json=json.dumps(files),
            ))
            self.assertEqual(requirements, self.FULL_REQUIREMENTS)
            self.assertFalse(ci_policy.gate(DummyArgs(
                classifier_status="success", requirements_json=json.dumps(requirements),
                results_json=json.dumps({
                    "backend": "skipped", "frontend": "skipped",
                    "contract": "skipped", "docs_integrity": "success",
                }),
            )))

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
        args2 = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["scripts/deploy.sh"]))
        out2 = ci_policy.classify(args2)
        self.assertEqual(out2["needs_backend"], "true")
        
    def test_mixed_code_and_docs(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["frontend/src/App.tsx", "README.md"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_frontend"], "true")
        self.assertEqual(out["needs_docs"], "true")
        self.assertEqual(out["needs_backend"], "false")

    def test_contract_only(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json=json.dumps(["scripts/check_openapi_contract.py"]))
        out = ci_policy.classify(args)
        self.assertEqual(out["needs_contract"], "true")
        self.assertEqual(out["needs_backend"], "false")

    def test_invalid_json_fallback(self):
        args = DummyArgs(event="pull_request", target_branch="develop", files_json="{invalid")
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

    def test_non_success_classifier_cannot_pass_full_verification_gate(self):
        for status in ("failure", "cancelled", "skipped", ""):
            with self.subTest(status=status):
                args = DummyArgs(
                    classifier_status=status,
                    requirements_json=json.dumps(self.FULL_REQUIREMENTS),
                    results_json=json.dumps({
                        "backend": "success", "frontend": "success",
                        "contract": "success", "docs_integrity": "success",
                    }),
                )
                self.assertFalse(ci_policy.gate(args))

    def test_every_required_lane_must_finish_successfully(self):
        successes = {
            "backend": "success", "frontend": "success",
            "contract": "success", "docs_integrity": "success",
        }
        for lane in successes:
            for status in ("skipped", "failure", "cancelled", "", None):
                with self.subTest(lane=lane, status=status):
                    results = dict(successes)
                    if status is None:
                        results.pop(lane)
                    else:
                        results[lane] = status
                    self.assertFalse(ci_policy.gate(DummyArgs(
                        classifier_status="success",
                        requirements_json=json.dumps(self.FULL_REQUIREMENTS),
                        results_json=json.dumps(results),
                    )))

    def test_full_event_policy_through_actual_cli(self):
        for event, branch in (("push", "develop"), ("push", "master"), ("pull_request", "master"), ("workflow_dispatch", "")):
            with self.subTest(event=event, branch=branch):
                result = subprocess.run([
                    sys.executable, "-B", "scripts/ci_policy.py", "classify",
                    "--event", event, "--target-branch", branch,
                    "--files-json", '["docs/file.md"]',
                ], capture_output=True, text=True, check=True)
                outputs = dict(line.split("=", 1) for line in result.stdout.splitlines())
                self.assertEqual(outputs, self.FULL_REQUIREMENTS)

    def test_fail_closed_gate_through_actual_cli(self):
        results = {
            "backend": "success", "frontend": "success",
            "contract": "success", "docs_integrity": "success",
        }
        scenarios = [("success", results, 0), ("failure", results, 1)]
        for lane in results:
            scenarios.append(("success", dict(results, **{lane: "skipped"}), 1))
        for classifier_status, lane_results, expected_code in scenarios:
            with self.subTest(classifier=classifier_status, results=lane_results):
                result = subprocess.run([
                    sys.executable, "-B", "scripts/ci_policy.py", "gate",
                    "--classifier-status", classifier_status,
                    "--requirements-json", json.dumps(self.FULL_REQUIREMENTS),
                    "--results-json", json.dumps(lane_results),
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_code, result.stdout + result.stderr)

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

    def test_cli_smoke(self):
        cmd = [
            sys.executable, "-B", "scripts/ci_policy.py", "classify",
            "--event", "pull_request",
            "--target-branch", "develop",
            "--files-json", '["docs/test.md"]'
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        self.assertIn("needs_docs=true", result.stdout)
        self.assertIn("needs_backend=false", result.stdout)

if __name__ == '__main__':
    unittest.main()
