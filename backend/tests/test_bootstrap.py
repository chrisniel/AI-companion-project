"""Tests for pure data root resolution and bootstrap handling (Batch 8P.3A)."""

import json
import os
from pathlib import Path
import pytest

from app.core.storage import (
    get_default_data_root,
    get_bootstrap_path,
    resolve_data_root,
    write_bootstrap,
    BootstrapCorruptError,
)


def test_default_data_root_windows_semantics(monkeypatch, tmp_path):
    """Ensure default data root follows %LOCALAPPDATA%\\AI Companion\\Data on Windows."""
    mock_localappdata = tmp_path / "LocalAppData"
    monkeypatch.setenv("LOCALAPPDATA", str(mock_localappdata))
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)

    default_root = get_default_data_root()
    expected = mock_localappdata / "AI Companion" / "Data"
    assert default_root == expected


def test_env_override_takes_highest_precedence(monkeypatch, tmp_path):
    """COMPANION_DATA_ROOT must take precedence over both bootstrap.json and default."""
    custom_root = tmp_path / "CustomDataRoot"
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1, "data_root": str(tmp_path / "BootstrapRoot")}))

    monkeypatch.setenv("COMPANION_DATA_ROOT", str(custom_root))

    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=tmp_path / "DefaultRoot",
    )
    assert resolved == custom_root.resolve()


def test_bootstrap_takes_precedence_over_default(monkeypatch, tmp_path):
    """bootstrap.json takes precedence over default when COMPANION_DATA_ROOT is unset."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_root = tmp_path / "BootstrapRoot"
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1, "data_root": str(bootstrap_root)}))

    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=tmp_path / "DefaultRoot",
    )
    assert resolved == bootstrap_root.resolve()


def test_corrupt_bootstrap_fails_closed(monkeypatch, tmp_path):
    """An existing malformed locator cannot select another persistent root."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text("{ this is corrupt json !!!")

    default_root = tmp_path / "DefaultRoot"
    with pytest.raises(BootstrapCorruptError):
        resolve_data_root(bootstrap_path=bootstrap_file, default_root=default_root)
    assert not default_root.exists()


def test_bootstrap_missing_data_root_fails_closed(monkeypatch, tmp_path):
    """Valid JSON without the required root is an invalid existing locator."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1}))

    default_root = tmp_path / "DefaultRoot"
    with pytest.raises(BootstrapCorruptError):
        resolve_data_root(bootstrap_path=bootstrap_file, default_root=default_root)
    assert not default_root.exists()


def test_pure_resolution_has_no_side_effects(monkeypatch, tmp_path):
    """resolve_data_root must not create directories, databases, or files."""
    target_root = tmp_path / "NonExistentDataRoot"
    bootstrap_file = tmp_path / "bootstrap_nonexistent.json"
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)

    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=target_root,
    )
    assert resolved == target_root.resolve()
    assert not target_root.exists(), "resolve_data_root must not eagerly create the directory!"
    assert not (target_root / "companion.db").exists()


def test_write_bootstrap_atomic_and_no_secrets(tmp_path):
    """write_bootstrap must write atomically and include only safe metadata."""
    bootstrap_file = tmp_path / "AI Companion" / "bootstrap.json"
    data_root = tmp_path / "MyData"

    write_bootstrap(data_root=data_root, bootstrap_path=bootstrap_file, schema_version=1)

    assert bootstrap_file.exists()
    content = json.loads(bootstrap_file.read_text(encoding="utf-8"))
    assert content["schema_version"] == 1
    assert content["data_root"] == str(data_root.resolve())
    assert set(content.keys()) == {"schema_version", "data_root"}


def test_authoritative_bootstrap_target_not_silently_switched(monkeypatch, tmp_path):
    """Target directory in bootstrap is authoritative even if not yet created on disk."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    uncreated_target = tmp_path / "FutureDisk" / "AICompanion"
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1, "data_root": str(uncreated_target)}))

    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=tmp_path / "DefaultRoot",
    )
    assert resolved == uncreated_target.resolve()
    assert not uncreated_target.exists()


def test_relative_companion_data_root_rejected(monkeypatch, tmp_path):
    """Relative COMPANION_DATA_ROOT must be rejected with a StorageError."""
    from app.core.storage import StorageError
    monkeypatch.setenv("COMPANION_DATA_ROOT", "./relative_custom_root")

    with pytest.raises(StorageError) as exc_info:
        resolve_data_root()
    assert "absolute" in str(exc_info.value).lower()


def test_relative_bootstrap_data_root_rejected(monkeypatch, tmp_path):
    """Relative data_root in bootstrap.json must be rejected with a StorageError."""
    from app.core.storage import StorageError
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1, "data_root": "./relative_bootstrap_root"}))

    with pytest.raises(StorageError) as exc_info:
        resolve_data_root(bootstrap_path=bootstrap_file)
    assert "absolute" in str(exc_info.value).lower()


def test_absolute_companion_data_root_accepted(monkeypatch, tmp_path):
    """Absolute COMPANION_DATA_ROOT is accepted without error."""
    abs_path = (tmp_path / "AbsoluteRoot").resolve()
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(abs_path))

    resolved = resolve_data_root()
    assert resolved == abs_path


def test_absolute_bootstrap_data_root_accepted(monkeypatch, tmp_path):
    """Absolute data_root in bootstrap.json is accepted without error."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    abs_path = (tmp_path / "AbsoluteBootstrapRoot").resolve()
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1, "data_root": str(abs_path)}))

    resolved = resolve_data_root(bootstrap_path=bootstrap_file)
    assert resolved == abs_path


def test_write_bootstrap_rejects_relative_data_root(tmp_path):
    """write_bootstrap must reject relative data_root with StorageError and not create the file."""
    from app.core.storage import StorageError
    bootstrap_target = tmp_path / "bootstrap.json"

    with pytest.raises(StorageError) as exc_info:
        write_bootstrap(
            data_root=Path("./relative-root"),
            bootstrap_path=bootstrap_target,
        )
    assert "absolute" in str(exc_info.value).lower()
    assert not bootstrap_target.exists()


@pytest.mark.parametrize("payload", [
    [], None, {}, {"data_root": "ROOT"}, {"schema_version": 2, "data_root": "ROOT"},
    {"schema_version": True, "data_root": "ROOT"}, {"schema_version": 1.0, "data_root": "ROOT"},
    {"schema_version": 1, "data_root": None}, {"schema_version": 1, "data_root": 123},
    {"schema_version": 1, "data_root": ""}, {"schema_version": 1, "data_root": "   "},
])
def test_invalid_existing_locator_schema_fails_closed(payload, monkeypatch, tmp_path):
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    if isinstance(payload, dict) and payload.get("data_root") == "ROOT":
        payload = {**payload, "data_root": str(tmp_path / "configured")}
    locator = tmp_path / "bootstrap.json"
    locator.write_text(json.dumps(payload), encoding="utf-8")
    default = tmp_path / "alternate"
    with pytest.raises(BootstrapCorruptError):
        resolve_data_root(bootstrap_path=locator, default_root=default)
    assert not default.exists()


def test_locator_directory_fails_closed(monkeypatch, tmp_path):
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    locator = tmp_path / "bootstrap.json"
    locator.mkdir()
    with pytest.raises(BootstrapCorruptError):
        resolve_data_root(bootstrap_path=locator, default_root=tmp_path / "alternate")


def test_explicit_override_preserves_precedence_over_corrupt_locator(monkeypatch, tmp_path):
    locator = tmp_path / "bootstrap.json"
    locator.write_text("broken", encoding="utf-8")
    explicit = tmp_path / "explicit"
    environment = tmp_path / "environment"
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(environment))
    assert resolve_data_root(bootstrap_path=locator) == environment.resolve()
    assert resolve_data_root(env_override=str(explicit), bootstrap_path=locator) == explicit.resolve()
    assert not explicit.exists() and not environment.exists()


def test_default_cache_and_log_roots_windows_semantics(monkeypatch, tmp_path):
    from app.core.storage import get_default_app_install_root, get_default_cache_root, get_default_log_root

    mock_localappdata = tmp_path / "LocalAppData"
    monkeypatch.setenv("LOCALAPPDATA", str(mock_localappdata))

    assert get_default_cache_root() == mock_localappdata / "AI Companion" / "Cache"
    assert get_default_log_root() == mock_localappdata / "AI Companion" / "Logs"
    assert get_default_app_install_root().is_absolute()


def test_cache_log_app_install_root_resolvers_and_relative_rejection(monkeypatch, tmp_path):
    from app.core.storage import (
        StorageError,
        resolve_app_install_root,
        resolve_cache_root,
        resolve_log_root,
    )

    custom_cache = tmp_path / "CustomCache"
    custom_log = tmp_path / "CustomLogs"
    custom_install = tmp_path / "CustomInstall"
    monkeypatch.setenv("COMPANION_CACHE_ROOT", str(custom_cache))
    monkeypatch.setenv("COMPANION_LOG_ROOT", str(custom_log))
    monkeypatch.setenv("COMPANION_APP_INSTALL_ROOT", str(custom_install))

    assert resolve_cache_root() == custom_cache.resolve()
    assert resolve_log_root() == custom_log.resolve()
    assert resolve_app_install_root() == custom_install.resolve()
    assert not custom_cache.exists() and not custom_log.exists() and not custom_install.exists()

    with pytest.raises(StorageError):
        resolve_cache_root(env_override="./rel-cache")
    with pytest.raises(StorageError):
        resolve_log_root(env_override="./rel-logs")
    with pytest.raises(StorageError):
        resolve_app_install_root(env_override="./rel-install")


def test_resolve_library_root_precedence_and_env_isolation(monkeypatch, tmp_path):
    from app.core.storage import StorageError, resolve_library_root

    data_root = (tmp_path / "Data").resolve()
    lib_from_bootstrap = (tmp_path / "BootstrapLibrary").resolve()
    lib_from_env = (tmp_path / "EnvLibrary").resolve()
    locator = tmp_path / "bootstrap.json"
    locator.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "data_root": str(data_root),
                "library_root": str(lib_from_bootstrap),
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.delenv("COMPANION_LIBRARY_ROOT", raising=False)
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)

    # 1. Explicit bootstrap_path uses library_root
    assert resolve_library_root(data_root, bootstrap_path=locator) == lib_from_bootstrap

    # 2. If global bootstrap has library_root while COMPANION_DATA_ROOT env redirects away,
    #    do NOT mix unrelated global library_root into isolated test/env data_root.
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "FakeLocal"))
    global_locator = tmp_path / "FakeLocal" / "AI Companion" / "bootstrap.json"
    global_locator.parent.mkdir(parents=True)
    global_locator.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "data_root": str(tmp_path / "RealData"),
                "library_root": str(lib_from_bootstrap),
            }
        ),
        encoding="utf-8",
    )
    isolated_data = (tmp_path / "IsolatedData").resolve()
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(isolated_data))
    assert resolve_library_root(isolated_data) == (isolated_data / "library").resolve()

    # 3. COMPANION_LIBRARY_ROOT env override beats bootstrap.json
    monkeypatch.setenv("COMPANION_LIBRARY_ROOT", str(lib_from_env))
    assert resolve_library_root(data_root, bootstrap_path=locator) == lib_from_env

    # 4. Relative COMPANION_LIBRARY_ROOT fails closed
    with pytest.raises(StorageError):
        resolve_library_root(data_root, env_override="./rel-lib", bootstrap_path=locator)

    assert not lib_from_bootstrap.exists() and not lib_from_env.exists()


@pytest.mark.parametrize("bad_lib_root", [123, "", "   ", "./relative-lib", None])
def test_resolve_library_root_malformed_bootstrap_fails_closed(bad_lib_root, monkeypatch, tmp_path):
    from app.core.storage import resolve_library_root

    monkeypatch.delenv("COMPANION_LIBRARY_ROOT", raising=False)
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    data_root = (tmp_path / "Data").resolve()
    locator = tmp_path / "bootstrap.json"
    locator.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "data_root": str(data_root),
                "library_root": bad_lib_root,
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(BootstrapCorruptError):
        resolve_library_root(data_root, bootstrap_path=locator)


def test_write_bootstrap_optional_library_root(tmp_path):
    from app.core.storage import StorageError

    locator = tmp_path / "AI Companion" / "bootstrap.json"
    data_root = tmp_path / "Data"
    lib_root = tmp_path / "ExternalLibrary"

    with pytest.raises(StorageError):
        write_bootstrap(data_root=data_root, bootstrap_path=locator, library_root=Path("./rel"))
    assert not locator.exists()

    write_bootstrap(data_root=data_root, bootstrap_path=locator, library_root=lib_root)
    payload = json.loads(locator.read_text(encoding="utf-8"))
    assert payload["schema_version"] == 1
    assert payload["data_root"] == str(data_root.resolve())
    assert payload["library_root"] == str(lib_root.resolve())
