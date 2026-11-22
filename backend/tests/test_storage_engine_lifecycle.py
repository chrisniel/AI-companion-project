"""Tests for canonical paths, engine lifecycle ordering, and SQLite PRAGMAs (8P.3B, 8P.3E, 8P.3F)."""

import json
from pathlib import Path
import pytest
from sqlalchemy import text

from app.core.config import settings
from app.core.storage import get_canonical_paths
from app.db import session as db_session


def test_canonical_paths_derived_from_one_root(tmp_path):
    """All persistent directories must be derived from one resolved COMPANION_DATA_ROOT."""
    data_root = tmp_path / "MyCompanionData"
    paths = get_canonical_paths(data_root)

    assert paths.COMPANION_DATA_ROOT == data_root.resolve()
    assert paths.DATABASE_DIR == data_root.resolve() / "database"
    assert paths.DATABASE_PATH == data_root.resolve() / "database" / "companion.db"
    assert paths.DATABASE_URL.startswith("sqlite+aiosqlite:///")
    assert paths.DATABASE_PATH.as_posix() in paths.DATABASE_URL

    assert paths.LIBRARY_DIR == data_root.resolve() / "library"
    assert paths.MODEL_LIBRARY_DIR == data_root.resolve() / "library" / "models" / "llm"
    assert paths.INSTALLED_REGISTRY_PATH == data_root.resolve() / "library" / "registry" / "models.json"
    assert paths.VOICE_LIBRARY_DIR == data_root.resolve() / "library" / "voices"
    assert paths.ATTACHMENT_DIR == data_root.resolve() / "attachments"
    assert paths.IMPORT_INBOX_DIR == data_root.resolve() / "library" / "imports" / "inbox"
    assert paths.IMPORT_STAGING_DIR == data_root.resolve() / "library" / "imports" / "staging"
    assert paths.CHARACTER_DIR == data_root.resolve() / "characters"
    assert paths.MEMORY_DIR == data_root.resolve() / "memory"
    assert paths.BACKUP_DIR == data_root.resolve() / "backups"
    assert paths.APP_INSTALL_ROOT.is_absolute()
    assert paths.CACHE_ROOT.is_absolute()
    assert paths.LOG_ROOT.is_absolute()


def test_canonical_paths_honors_relocated_library_root(tmp_path):
    """Explicit or resolved library_root relocates models, registry, voices, and D6 imports."""
    data_root = (tmp_path / "DataRoot").resolve()
    lib_root = (tmp_path / "RelocatedLibrary").resolve()
    paths = get_canonical_paths(data_root, library_root=lib_root)

    assert paths.DATABASE_DIR == data_root / "database"
    assert paths.LIBRARY_DIR == lib_root
    assert paths.MODEL_LIBRARY_DIR == lib_root / "models" / "llm"
    assert paths.INSTALLED_REGISTRY_PATH == lib_root / "registry" / "models.json"
    assert paths.VOICE_LIBRARY_DIR == lib_root / "voices"
    assert paths.IMPORT_INBOX_DIR == lib_root / "imports" / "inbox"
    assert paths.IMPORT_STAGING_DIR == lib_root / "imports" / "staging"


def test_factory_model_root_remains_in_repo_and_aliases_match():
    """Factory models must point to repo/models, and compatibility aliases point to factory root."""
    assert hasattr(settings, "FACTORY_MODEL_ROOT")
    assert settings.FACTORY_MODEL_ROOT.exists()
    assert (settings.FACTORY_MODEL_ROOT / "registry.template.json").exists()

    # MODELS_DIR and LLAMA_MODELS_DIR remain compatibility aliases to factory root
    assert settings.MODELS_DIR == settings.FACTORY_MODEL_ROOT
    assert settings.LLAMA_MODELS_DIR == settings.FACTORY_MODEL_ROOT / "vision"


def test_lazy_directory_creation_paths_do_not_eagerly_create(tmp_path):
    """Path generation must not create directory trees on disk."""
    data_root = tmp_path / "UncreatedRoot"
    paths = get_canonical_paths(data_root)

    assert not paths.COMPANION_DATA_ROOT.exists()
    assert not paths.LIBRARY_DIR.exists()
    assert not paths.MODEL_LIBRARY_DIR.exists()
    assert not paths.ATTACHMENT_DIR.exists()
    assert not paths.VOICE_LIBRARY_DIR.exists()


def test_uninitialized_database_runtime_raises_clean_error():
    """Calling get_db or get_engine before initialization must raise a clean error."""
    # Ensure runtime is disposed
    # get_session_factory should fail clearly
    with pytest.raises(RuntimeError) as exc_info:
        db_session.get_engine()
    assert "not been initialized" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_database_runtime_lifecycle_and_pragmas(tmp_path):
    """initialize_database_runtime creates engine with required SQLite PRAGMAs."""
    db_file = tmp_path / "test_lifecycle.db"
    db_url = f"sqlite+aiosqlite:///{db_file.resolve().as_posix()}"

    engine = db_session.initialize_database_runtime(database_url=db_url, debug=False)
    assert engine is not None

    async with engine.connect() as conn:
        journal_mode = (await conn.execute(text("PRAGMA journal_mode;"))).scalar()
        busy_timeout = (await conn.execute(text("PRAGMA busy_timeout;"))).scalar()
        foreign_keys = (await conn.execute(text("PRAGMA foreign_keys;"))).scalar()
        synchronous = (await conn.execute(text("PRAGMA synchronous;"))).scalar()

        assert str(journal_mode).lower() == "wal"
        assert busy_timeout == 5000
        assert foreign_keys == 1
        # synchronous = NORMAL is 1 in SQLite (0=OFF, 1=NORMAL, 2=FULL, 3=EXTRA)
        assert synchronous == 1

    await db_session.dispose_database_runtime()
    with pytest.raises(RuntimeError):
        db_session.get_engine()


@pytest.mark.asyncio
async def test_corrupt_locator_prevents_alternate_runtime_initialization(monkeypatch, tmp_path):
    from app.core.config import Settings
    from app.core.storage import BootstrapCorruptError

    monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
    locator = tmp_path / "AI Companion" / "bootstrap.json"
    locator.parent.mkdir()
    locator.write_text("{broken", encoding="utf-8")
    assert db_session._engine is None
    try:
        with pytest.raises(BootstrapCorruptError):
            configured = Settings()
            db_session.initialize_database_runtime(database_url=configured.DATABASE_URL)
        assert db_session._engine is None
        assert not (tmp_path / "AI Companion" / "Data").exists()
    finally:
        await db_session.dispose_database_runtime()


@pytest.mark.asyncio
async def test_system_storage_endpoints_and_library_relocation(client, host_admin_headers, monkeypatch, tmp_path):
    """PC-HOST-004: /system/storage reports 5 roots and relocates LIBRARY_ROOT safely."""
    from unittest.mock import AsyncMock, MagicMock
    from app.services.llm.manager import llm_manager

    unauth = await client.get("/api/v1/system/storage")
    assert unauth.status_code == 401

    resp = await client.get("/api/v1/system/storage", headers=host_admin_headers)
    assert resp.status_code == 200
    payload = resp.json()
    root_keys = {item["key"] for item in payload["roots"]}
    assert root_keys == {"app_install", "data", "library", "cache", "log"}
    assert "bootstrap_path" in payload

    # Test relocation blocked when COMPANION_LIBRARY_ROOT env override is active
    monkeypatch.setenv("COMPANION_LIBRARY_ROOT", str(tmp_path / "LockedEnvLib"))
    env_blocked = await client.put(
        "/api/v1/system/storage/library-root",
        json={"new_library_root": str(tmp_path / "TargetLib"), "migrate_existing_assets": True},
        headers=host_admin_headers,
    )
    assert env_blocked.status_code == 409
    monkeypatch.delenv("COMPANION_LIBRARY_ROOT", raising=False)

    # Test relocation blocked when model is loaded
    loaded_provider = MagicMock()
    loaded_provider.is_loaded.return_value = True
    loaded_provider.has_active_generation = False
    original_provider = llm_manager._provider
    try:
        llm_manager.set_provider(loaded_provider)
        loaded_blocked = await client.put(
            "/api/v1/system/storage/library-root",
            json={"new_library_root": str(tmp_path / "TargetLib"), "migrate_existing_assets": True},
            headers=host_admin_headers,
        )
        assert loaded_blocked.status_code == 409

        # Idle Core-managed router gets stopped before moving assets
        idle_provider = MagicMock()
        idle_provider.is_loaded.return_value = False
        idle_provider.has_active_generation = False
        idle_provider.unload = AsyncMock(return_value=True)
        llm_manager.set_provider(idle_provider)

        # Also verify relocation blocked with 409 when COMPANION_DATA_ROOT redirects away from bootstrap
        data_env_blocked = await client.put(
            "/api/v1/system/storage/library-root",
            json={"new_library_root": str(tmp_path / "TargetLib2"), "migrate_existing_assets": False},
            headers=host_admin_headers,
        )
        assert data_env_blocked.status_code == 409

        # Switch to isolated bootstrap-backed storage and validate path checks + migration
        fake_local = tmp_path / "RelocLocalApp"
        monkeypatch.setenv("LOCALAPPDATA", str(fake_local))
        monkeypatch.delenv("COMPANION_DATA_ROOT", raising=False)
        from app.core.storage import write_bootstrap
        write_bootstrap(data_root=(tmp_path / "RelocData").resolve(), bootstrap_path=fake_local / "AI Companion" / "bootstrap.json")

        # Reject relative and overlapping paths with 400
        rel_bad = await client.put(
            "/api/v1/system/storage/library-root",
            json={"new_library_root": "./rel", "migrate_existing_assets": False},
            headers=host_admin_headers,
        )
        assert rel_bad.status_code == 400

        db_overlap = await client.put(
            "/api/v1/system/storage/library-root",
            json={"new_library_root": str(settings.DATABASE_DIR), "migrate_existing_assets": False},
            headers=host_admin_headers,
        )
        assert db_overlap.status_code == 400

        settings.IMPORT_INBOX_DIR.mkdir(parents=True, exist_ok=True)
        (settings.IMPORT_INBOX_DIR / "migrated.gguf").write_bytes(b"GGUFmigrated")

        new_lib = (tmp_path / "RelocatedLib").resolve()
        ok = await client.put(
            "/api/v1/system/storage/library-root",
            json={"new_library_root": str(new_lib), "migrate_existing_assets": True},
            headers=host_admin_headers,
        )
        assert ok.status_code == 200
        idle_provider.unload.assert_awaited()
        data = ok.json()
        assert data["library_root"] == str(new_lib)
        assert (new_lib / "imports" / "inbox" / "migrated.gguf").read_bytes() == b"GGUFmigrated"
        boot = json.loads((fake_local / "AI Companion" / "bootstrap.json").read_text(encoding="utf-8"))
        assert boot["library_root"] == str(new_lib)
    finally:
        llm_manager.set_provider(original_provider)
