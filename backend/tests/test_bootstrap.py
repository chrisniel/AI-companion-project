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


def test_corrupt_bootstrap_falls_back_to_default(monkeypatch, tmp_path):
    """Corrupt or malformed bootstrap.json logs warning and falls back to default root."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text("{ this is corrupt json !!!")

    default_root = tmp_path / "DefaultRoot"
    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=default_root,
    )
    assert resolved == default_root.resolve()


def test_bootstrap_missing_data_root_falls_back(monkeypatch, tmp_path):
    """Valid JSON missing 'data_root' key falls back to default root."""
    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    bootstrap_file = tmp_path / "bootstrap.json"
    bootstrap_file.write_text(json.dumps({"schema_version": 1}))

    default_root = tmp_path / "DefaultRoot"
    resolved = resolve_data_root(
        bootstrap_path=bootstrap_file,
        default_root=default_root,
    )
    assert resolved == default_root.resolve()


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
