"""Lock validation must reject incomplete/extraneous/altered dependency inputs."""

import importlib.util
from pathlib import Path
import sys
import unittest

spec = importlib.util.spec_from_file_location("dependency_lock", Path(__file__).resolve().parents[1] / "python_dependency_lock.py")
lock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lock)


class LockValidationTests(unittest.TestCase):
    def test_missing_transitive_dependency_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing"):
            lock.closure({"root": {"version": "1", "requires": ["child>=2"]}}, [lock.Requirement("root")])

    def test_incompatible_transitive_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "incompatible"):
            lock.closure({"root": {"version": "1", "requires": ["child>=2"]},
                          "child": {"version": "1", "requires": []}}, [lock.Requirement("root")])

    def test_unrequested_distribution_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            lock.closure({"root": {"version": "1", "requires": []},
                          "surprise": {"version": "1", "requires": []}}, [lock.Requirement("root")])

    def test_required_extras_and_recursive_extras_are_checked(self):
        packages = {"root": {"version": "1", "requires": ['child[io]>=2; extra == "standard"']},
                    "child": {"version": "2", "requires": ['driver; extra == "io"']},
                    "driver": {"version": "1", "requires": []}}
        self.assertEqual(lock.closure(packages, [lock.Requirement("root[standard]")]),
                         {"root": {"standard"}, "child": {"io"}, "driver": set()})

    def test_unrequested_extra_is_not_installed(self):
        packages = {"root": {"version": "1", "requires": ['optional; extra == "unused"']}}
        self.assertEqual(lock.closure(packages, [lock.Requirement("root")]), {"root": set()})

    def test_fingerprint_and_hash_and_target_are_required(self):
        roots = [lock.Requirement("root")]
        header = "# declarations-sha256: " + lock.declaration_digest(roots) + "\n"
        valid = header + 'root==1 ; ' + lock.TARGET + ' --hash=sha256:' + 'a' * 64 + '\n'
        self.assertEqual(lock.read_lock(valid, roots)["root"]["version"], "1")
        for damaged in [valid.replace("sha256:", "sha256:z"), valid.replace('"3.11"', '"3.13"'),
                        valid.replace(header, ""), valid + valid.splitlines()[-1] + "\n"]:
            with self.subTest(damaged=damaged), self.assertRaises(ValueError):
                lock.read_lock(damaged, roots)


if __name__ == "__main__":
    unittest.main()
