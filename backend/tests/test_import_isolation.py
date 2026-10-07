"""Actual-import regressions runnable without importing pytest/conftest first.

Direct invocation intentionally uses unittest so the unsafe pre-fix conftest cannot
run in the parent process. Every application import happens in a guarded child.
"""

import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import textwrap
import unittest


BACKEND_DIR = Path(__file__).resolve().parents[1]
SYNTHETIC_TOKEN = "companion_sec_disposable_import_test_1234567890"


class ImportIsolationTests(unittest.TestCase):
    def run_isolated(self, body: str, env_contents: str = "DEBUG=false\n") -> None:
        with TemporaryDirectory(prefix="companion-import-regression-") as directory:
            sandbox = Path(directory)
            config_file = sandbox / "configuration.env"
            config_file.write_text(env_contents, encoding="utf-8")
            (sandbox / "tmp").mkdir()
            # Inherit OS execution necessities only, never application credentials.
            environment = {
                name: os.environ[name]
                for name in ("SystemRoot", "WINDIR", "PATH", "PATHEXT", "COMSPEC")
                if name in os.environ
            }
            environment.update({
                "COMPANION_ENV_FILE": str(config_file),
                "COMPANION_DATA_ROOT": str(sandbox / "data"),
                "LOCALAPPDATA": str(sandbox / "localappdata"),
                "APPDATA": str(sandbox / "appdata"),
                "USERPROFILE": str(sandbox / "home"),
                "HOME": str(sandbox / "home"),
                "TMP": str(sandbox / "tmp"),
                "TEMP": str(sandbox / "tmp"),
                "TMPDIR": str(sandbox / "tmp"),
                "PYTEST_DISABLE_PLUGIN_AUTOLOAD": "1",
            })
            guard = textwrap.dedent(f"""
                import os
                from pathlib import Path
                import sys

                sandbox = Path({str(sandbox)!r}).resolve()
                backend = Path({str(BACKEND_DIR)!r}).resolve()
                config_file = Path({str(config_file)!r})
                original_config = config_file.read_text(encoding="utf-8")
                synthetic_token = {SYNTHETIC_TOKEN!r}

                class ForbiddenLocalState(BaseException):
                    pass

                def is_disposable(path):
                    return path == sandbox or sandbox in path.parents

                def guard_local_state(event, arguments):
                    if event in ("socket.connect", "subprocess.Popen"):
                        raise ForbiddenLocalState("External activity during import/collection")
                    if event == "sqlite3.connect":
                        target = arguments[0]
                        if target != ":memory:" and not is_disposable(Path(target).resolve()):
                            raise ForbiddenLocalState("Non-disposable database access")
                    if event != "open" or not isinstance(arguments[0], (str, bytes, os.PathLike)):
                        return
                    target = Path(os.fsdecode(arguments[0])).resolve()
                    mode, flags = arguments[1:3]
                    writing = bool(flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND))
                    authentication = target.name == ".env" or target.name.startswith(".env.") or target == backend / ".env"
                    database = target.suffix.lower() in (".db", ".sqlite", ".sqlite3")
                    if not is_disposable(target) and (writing or authentication or database):
                        raise ForbiddenLocalState("Non-disposable authentication/data/file access")

                sys.addaudithook(guard_local_state)
                sys.path.insert(0, str(backend))
            """)
            result = subprocess.run(
                [sys.executable, "-I", "-B", "-c", guard + "\n" + textwrap.dedent(body)],
                cwd=BACKEND_DIR,
                env=environment,
                capture_output=True,
                text=True,
                timeout=90,
            )
            self.assertEqual(
                result.returncode,
                0,
                "Guarded child failed (no real local-state access allowed):\n"
                + result.stdout[-2500:] + result.stderr[-4500:],
            )
            for line in result.stdout.splitlines():
                if line.startswith("ISOLATED_COLLECTION_COUNT="):
                    print(line)

    def test_import_does_not_generate_or_persist_missing_credential(self):
        self.run_isolated("""
            from app.core.config import settings
            assert settings.COMPANION_API_KEY == "", "Import generated a credential"
            assert config_file.read_text(encoding="utf-8") == original_config, "Import persisted a credential"
            assert not list(sandbox.rglob("*.db")), "Import created a database"
        """)

    def test_explicit_initialization_preserves_valid_synthetic_credential(self):
        self.run_isolated("""
            from app.core.config import settings
            assert settings.COMPANION_API_KEY == synthetic_token, "Selected configuration was not loaded"
            assert settings.ensure_pairing_token() == synthetic_token, "Valid credential was replaced"
            assert config_file.read_text(encoding="utf-8") == original_config, "Valid configuration was rewritten"
        """, f"COMPANION_API_KEY={SYNTHETIC_TOKEN}\nDEBUG=false\n")

    def test_explicit_initialization_persists_only_disposable_configuration(self):
        self.run_isolated("""
            from app.core.config import Settings, settings
            assert settings.COMPANION_API_KEY == "", "Import initialized a missing credential"
            token = settings.ensure_pairing_token()
            assert token and len(token) >= 16, "Explicit initialization failed"
            persisted = config_file.read_text(encoding="utf-8")
            assert persisted.startswith(original_config), "Unrelated configuration was lost"
            assert persisted.count("COMPANION_API_KEY=") == 1, "Credential was not persisted once"
            assert Settings().COMPANION_API_KEY == token, "Credential cannot be reloaded"
            assert settings.ensure_pairing_token() == token, "Credential changed on repeated initialization"
            assert config_file.read_text(encoding="utf-8") == persisted, "Repeated initialization rewrote configuration"
        """)

    def test_collection_isolates_before_application_imports(self):
        self.run_isolated("""
            import importlib.abc
            observed = {}
            original_environment = {
                name: os.environ.get(name)
                for name in ("COMPANION_ENV_FILE", "COMPANION_API_KEY", "COMPANION_DATA_ROOT", "LOCALAPPDATA")
            }

            class ObserveConfigurationImport(importlib.abc.MetaPathFinder):
                def find_spec(self, fullname, path=None, target=None):
                    if fullname == "app.core.config":
                        selected = Path(os.environ["COMPANION_ENV_FILE"]).resolve()
                        root = Path(os.environ["COMPANION_DATA_ROOT"]).resolve()
                        assert selected != config_file and is_disposable(selected), "Collection inherited configuration"
                        assert root != Path(original_environment["COMPANION_DATA_ROOT"]) and is_disposable(root), "Storage isolated too late"
                        assert os.environ.get("COMPANION_API_KEY") == "companion_sec_test_token_abcdef1234567890", "Authentication isolated too late"
                        observed["before_import"] = True
                    return None

            sys.meta_path.insert(0, ObserveConfigurationImport())
            import pytest

            class CollectionEvidence:
                def pytest_collection_finish(self, session):
                    observed["count"] = len(session.items)

            result = pytest.main([
                "--collect-only", "-q", "-p", "no:cacheprovider",
                "-p", "pytest_asyncio.plugin", "-o", f"log_file={sandbox / 'collection.log'}",
                "tests",
            ], plugins=[CollectionEvidence()])
            assert result == 0, "Actual backend collection failed"
            assert observed.get("before_import"), "Configuration import boundary was not exercised"
            from app.db import session
            assert session._engine is None, "Collection initialized a database runtime"
            for name, original_value in original_environment.items():
                assert os.environ.get(name) == original_value, "Collection did not restore its environment"
            assert config_file.read_text(encoding="utf-8") == original_config, "Collection changed caller configuration"
            assert observed.get("count", 0) > 0, "No backend tests were collected"
            print(f"ISOLATED_COLLECTION_COUNT={observed['count']}")
        """)


if __name__ == "__main__":
    unittest.main()
