import os
import tempfile
import sqlite3
from pathlib import Path
import pytest
from alembic.config import Config
from alembic import command

BACKEND_DIR = Path(__file__).resolve().parent.parent


def test_fresh_database_upgrade_base_through_005():
    """Test A: Fresh SQLite database upgrades cleanly from base through revision 005."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "fresh_005.db"
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")

        command.upgrade(cfg, "head")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver is not None and ver[0] == "005_scope_message_constraints"

        # Verify messages table columns
        cols = [col[1] for col in cur.execute("PRAGMA table_info(messages);").fetchall()]
        for expected in ["id", "conversation_id", "sequence_no", "client_message_id", "is_deleted", "deleted_at"]:
            assert expected in cols

        # Verify foreign keys
        fks = cur.execute("PRAGMA foreign_key_list(messages);").fetchall()
        assert any(fk[2] == "conversations" and fk[3] == "conversation_id" and fk[6] == "CASCADE" for fk in fks)

        # Verify indexes
        idx_names = [idx[1] for idx in cur.execute("PRAGMA index_list(messages);").fetchall()]
        assert "ix_messages_is_deleted" in idx_names
        assert "ix_messages_deleted_at" in idx_names
        assert "ix_messages_conv_seq" in idx_names
        assert "ix_messages_owner_id" in idx_names
        assert "ix_messages_conversation_id" in idx_names

        conn.close()


def test_existing_004_database_upgrade_to_005_and_schema_parity():
    """Test B: Database at 004 with existing data upgrades to 005 with data preservation and schema parity."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path_a = Path(tmpdir) / "fresh_head.db"
        cfg_a = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg_a.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg_a.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path_a.as_posix()}")
        command.upgrade(cfg_a, "head")

        db_path_b = Path(tmpdir) / "upgraded_005.db"
        cfg_b = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg_b.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg_b.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path_b.as_posix()}")

        # Upgrade to 004
        command.upgrade(cfg_b, "004_add_soft_delete_columns")

        # Insert test data at 004
        conn_b = sqlite3.connect(db_path_b)
        cur_b = conn_b.cursor()
        cur_b.execute("INSERT INTO conversations (id, created_at, updated_at, owner_id, title, character_id, is_deleted) VALUES ('c1', '2026-09-14 00:00:00', '2026-09-14 00:00:00', 'u1', 'Conv 1', 'aura', 0);")
        cur_b.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, status, sequence_no, client_message_id, is_deleted) VALUES ('m1', '2026-09-14 00:00:00', '2026-09-14 00:00:00', 'u1', 'c1', 'user', 'Hello', 'completed', 1, 'client-uuid-1', 0);")
        cur_b.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, status, sequence_no, client_message_id, is_deleted) VALUES ('m2', '2026-09-14 00:00:00', '2026-09-14 00:00:00', 'u1', 'c1', 'assistant', 'Hi there', 'completed', 2, NULL, 0);")
        conn_b.commit()
        conn_b.close()

        # Upgrade to 005
        command.upgrade(cfg_b, "005_scope_message_constraints")

        # Verify data preservation
        conn_b = sqlite3.connect(db_path_b)
        cur_b = conn_b.cursor()
        rows = cur_b.execute("SELECT id, sequence_no, client_message_id, is_deleted FROM messages ORDER BY sequence_no;").fetchall()
        assert rows == [
            ("m1", 1, "client-uuid-1", 0),
            ("m2", 2, None, 0),
        ]

        # Verify schema parity between fresh A and upgraded B
        conn_a = sqlite3.connect(db_path_a)
        cur_a = conn_a.cursor()

        cols_a = [(c[1], c[2], c[3], c[4], c[5]) for c in cur_a.execute("PRAGMA table_info(messages);").fetchall()]
        cols_b = [(c[1], c[2], c[3], c[4], c[5]) for c in cur_b.execute("PRAGMA table_info(messages);").fetchall()]
        assert cols_a == cols_b

        fks_a = cur_a.execute("PRAGMA foreign_key_list(messages);").fetchall()
        fks_b = cur_b.execute("PRAGMA foreign_key_list(messages);").fetchall()
        assert fks_a == fks_b

        conn_a.close()
        conn_b.close()


def test_migration_005_downgrade_and_reupgrade_cycle():
    """Test C: Migration 005 downgrades to 004 and re-upgrades to 005 cleanly."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "cycle_005.db"
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")

        command.upgrade(cfg, "005_scope_message_constraints")

        # Downgrade to 004
        command.downgrade(cfg, "004_add_soft_delete_columns")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "004_add_soft_delete_columns"

        # On 004, global unique constraint is restored
        table_sql = cur.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='messages';").fetchone()[0]
        assert "client_message_id" in table_sql
        conn.close()

        # Re-upgrade to 005
        command.upgrade(cfg, "005_scope_message_constraints")

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        ver = cur.execute("SELECT version_num FROM alembic_version;").fetchone()
        assert ver[0] == "005_scope_message_constraints"

        table_sql = cur.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='messages';").fetchone()[0]
        assert "uq_messages_conversation_sequence" in table_sql
        assert "uq_messages_conversation_client_message_id" in table_sql
        conn.close()


def test_scoped_message_constraints_enforcement():
    """Test D: Explicit verification of scoped unique constraints and NULL handling."""
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = Path(tmpdir) / "enforcement.db"
        cfg = Config(str(BACKEND_DIR / "alembic.ini"))
        cfg.set_main_option("script_location", str(BACKEND_DIR / "migrations"))
        cfg.set_main_option("sqlalchemy.url", f"sqlite+aiosqlite:///{db_path.as_posix()}")
        command.upgrade(cfg, "head")

        conn = sqlite3.connect(db_path)
        conn.execute("PRAGMA foreign_keys = ON;")
        cur = conn.cursor()

        # Create two conversations
        cur.execute("INSERT INTO conversations (id, created_at, updated_at, owner_id, title, is_deleted) VALUES ('conv-a', '2026-09-14', '2026-09-14', 'u1', 'Conv A', 0);")
        cur.execute("INSERT INTO conversations (id, created_at, updated_at, owner_id, title, is_deleted) VALUES ('conv-b', '2026-09-14', '2026-09-14', 'u1', 'Conv B', 0);")
        conn.commit()

        # 1. same client_message_id in conversation A and B -> ALLOWED
        cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-a-1', '2026-09-14', '2026-09-14', 'u1', 'conv-a', 'user', 'Msg A1', 1, 'shared-client-id', 0);")
        cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-b-1', '2026-09-14', '2026-09-14', 'u1', 'conv-b', 'user', 'Msg B1', 1, 'shared-client-id', 0);")
        conn.commit()

        # 2. same client_message_id twice in conversation A -> REJECTED
        with pytest.raises(sqlite3.IntegrityError):
            cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-a-dup', '2026-09-14', '2026-09-14', 'u1', 'conv-a', 'user', 'Msg A Dup', 2, 'shared-client-id', 0);")
            conn.commit()
        conn.rollback()

        # 3. same sequence_no in conversation A and B -> ALLOWED
        # Both conv-a and conv-b already have sequence_no=1 from above!
        seq_a = cur.execute("SELECT sequence_no FROM messages WHERE conversation_id = 'conv-a';").fetchall()
        seq_b = cur.execute("SELECT sequence_no FROM messages WHERE conversation_id = 'conv-b';").fetchall()
        assert seq_a == [(1,)]
        assert seq_b == [(1,)]

        # 4. same sequence_no twice in conversation A -> REJECTED
        with pytest.raises(sqlite3.IntegrityError):
            cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-a-seq-dup', '2026-09-14', '2026-09-14', 'u1', 'conv-a', 'user', 'Msg Seq Dup', 1, 'different-client-id', 0);")
            conn.commit()
        conn.rollback()

        # 5. multiple NULL client_message_id values in conversation A -> ALLOWED
        cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-a-null-1', '2026-09-14', '2026-09-14', 'u1', 'conv-a', 'assistant', 'Response 1', 2, NULL, 0);")
        cur.execute("INSERT INTO messages (id, created_at, updated_at, owner_id, conversation_id, sender, content, sequence_no, client_message_id, is_deleted) VALUES ('m-a-null-2', '2026-09-14', '2026-09-14', 'u1', 'conv-a', 'assistant', 'Response 2', 3, NULL, 0);")
        conn.commit()

        null_msgs = cur.execute("SELECT count(*) FROM messages WHERE conversation_id = 'conv-a' AND client_message_id IS NULL;").fetchone()[0]
        assert null_msgs == 2

        conn.close()
