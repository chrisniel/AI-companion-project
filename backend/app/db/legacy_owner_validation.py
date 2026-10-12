"""Strict legacy owner validation shared by Migration 007 and its tests (PC-IDENTITY-001).

Only an explicit allowlist of single-user aliases may be folded into the Default Profile.
Anything else - unexpected ids, empty or whitespace strings, case/whitespace variants and
NULLs - must make the migration refuse so that no data is silently merged or dropped.
"""

from typing import Any, Dict, Iterable, List

APPROVED_LEGACY_OWNER_ALIASES = frozenset({"local_user", "default_user"})


def _fetchall(conn: Any, sql: str) -> List[Any]:
    # SQLAlchemy Connection (Alembic) or raw sqlite3.Connection (tests).
    if hasattr(conn, "exec_driver_sql"):
        return conn.exec_driver_sql(sql).fetchall()
    return conn.execute(sql).fetchall()


def find_unapproved_owners(conn: Any, tables: Iterable[str]) -> Dict[str, List[Any]]:
    """Return {table: [offending owner values]} for owners outside the approved alias set.

    Read-only. Tables that do not exist are skipped. NULL owners are reported as ``None``.
    """
    offenders: Dict[str, List[Any]] = {}
    for table in tables:
        exists = _fetchall(conn, f"SELECT 1 FROM sqlite_master WHERE type='table' AND name='{table}'")
        if not exists:
            continue
        owners = [row[0] for row in _fetchall(conn, f'SELECT DISTINCT owner_id FROM "{table}"')]
        bad = [o for o in owners if o is None or o not in APPROVED_LEGACY_OWNER_ALIASES]
        if bad:
            offenders[table] = sorted(bad, key=lambda v: (v is None, "" if v is None else str(v)))
    return offenders
