"""Native ACL enforcement uses synthetic paths, never the user's credential store."""

import os

import pytest


def test_private_secret_round_trip_and_reject_untrusted_acl(tmp_path, monkeypatch):
    from app.core.host_admin import initialize_host_admin_secret, read_host_admin_secret
    from app.core import host_admin
    monkeypatch.setattr(host_admin, "host_admin_secret_path", lambda: tmp_path / "private" / "desktop_admin.secret")
    token = initialize_host_admin_secret()
    assert len(token) >= 40
    assert read_host_admin_secret() == token
    assert initialize_host_admin_secret() == token
    path = host_admin.host_admin_secret_path()
    if os.name == "nt":
        from app.core.windows_security import _set_windows_dacl
        _set_windows_dacl(path, "D:P(A;;FA;;;WD)")
    else:
        path.chmod(0o644)
    with pytest.raises(RuntimeError):
        read_host_admin_secret()
    with pytest.raises(RuntimeError):
        initialize_host_admin_secret()


def test_secret_symlink_is_rejected(tmp_path, monkeypatch):
    from app.core import host_admin
    target = tmp_path / "other"
    target.write_text("not-private", encoding="utf-8")
    link = tmp_path / "link"
    try:
        link.symlink_to(target)
    except OSError:
        pytest.skip("Host does not permit test symlink creation")
    monkeypatch.setattr(host_admin, "host_admin_secret_path", lambda: link)
    with pytest.raises(RuntimeError):
        host_admin.read_host_admin_secret()
