"""Tests for canonical paths, engine lifecycle ordering, and SQLite PRAGMAs (8P.3B, 8P.3E, 8P.3F)."""

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
    assert paths.IMPORT_INBOX_DIR == data_root.resolve() / "imports" / "inbox"
    assert paths.IMPORT_STAGING_DIR == data_root.resolve() / "imports" / "staging"
    assert paths.CHARACTER_DIR == data_root.resolve() / "characters"
    assert paths.MEMORY_DIR == data_root.resolve() / "memory"
    assert paths.BACKUP_DIR == data_root.resolve() / "backups"


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
