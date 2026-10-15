"""Private Host Admin file permissions without third-party platform dependencies."""

import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import stat


def reject_reparse_path(path: Path) -> None:
    for part in (path, path.parent):
        if part.is_symlink() or (part.exists() and getattr(part.lstat(), "st_file_attributes", 0) & 0x400):
            raise RuntimeError("Host credential path cannot contain a reparse point")


def _windows_api():
    adv = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    adv.OpenProcessToken.argtypes = [wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(wintypes.HANDLE)]
    adv.GetTokenInformation.argtypes = [wintypes.HANDLE, ctypes.c_int, wintypes.LPVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    adv.ConvertSidToStringSidW.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.LPWSTR)]
    adv.ConvertStringSecurityDescriptorToSecurityDescriptorW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(wintypes.LPVOID), ctypes.POINTER(wintypes.DWORD)]
    adv.SetFileSecurityW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID]
    adv.GetFileSecurityW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    adv.GetSecurityDescriptorDacl.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.BOOL), ctypes.POINTER(wintypes.LPVOID), ctypes.POINTER(wintypes.BOOL)]
    adv.GetSecurityDescriptorControl.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.WORD), ctypes.POINTER(wintypes.DWORD)]
    adv.GetSecurityDescriptorOwner.argtypes = [wintypes.LPVOID, ctypes.POINTER(wintypes.LPVOID), ctypes.POINTER(wintypes.BOOL)]
    adv.GetAce.argtypes = [wintypes.LPVOID, wintypes.DWORD, ctypes.POINTER(wintypes.LPVOID)]
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel.LocalFree.argtypes = [wintypes.LPVOID]
    return adv, kernel


def _sid_string(sid, adv, kernel):
    result = wintypes.LPWSTR()
    if not adv.ConvertSidToStringSidW(sid, ctypes.byref(result)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return result.value
    finally:
        kernel.LocalFree(ctypes.cast(result, wintypes.LPVOID))


def current_user_sid() -> str:
    adv, kernel = _windows_api()
    handle = wintypes.HANDLE()
    if not adv.OpenProcessToken(kernel.GetCurrentProcess(), 8, ctypes.byref(handle)):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        needed = wintypes.DWORD()
        adv.GetTokenInformation(handle, 1, None, 0, ctypes.byref(needed))
        buffer = ctypes.create_string_buffer(needed.value)
        if not adv.GetTokenInformation(handle, 1, buffer, needed.value, ctypes.byref(needed)):
            raise ctypes.WinError(ctypes.get_last_error())
        return _sid_string(ctypes.cast(buffer, ctypes.POINTER(wintypes.LPVOID))[0], adv, kernel)
    finally:
        kernel.CloseHandle(handle)


def _set_windows_dacl(path: Path, sddl: str) -> None:
    adv, kernel = _windows_api()
    descriptor = wintypes.LPVOID()
    if not adv.ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, ctypes.byref(descriptor), None):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        information = 0x80000005 if sddl.startswith("O:") else 0x80000004
        if not adv.SetFileSecurityW(str(path), information, descriptor):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.LocalFree(descriptor)


def secure_private_path(path: Path) -> None:
    reject_reparse_path(path)
    if os.name == "nt":
        flags = "OICI" if path.is_dir() else ""
        sid = current_user_sid()
        _set_windows_dacl(path, f"O:{sid}D:P(A;{flags};FA;;;{sid})(A;{flags};FA;;;SY)")
    else:
        path.chmod(0o700 if path.is_dir() else 0o600)
    validate_private_path(path)


def validate_private_path(path: Path) -> None:
    reject_reparse_path(path)
    if not path.exists():
        raise RuntimeError("Host credential store is not initialized")
    if os.name != "nt":
        if path.stat().st_uid != os.getuid() or stat.S_IMODE(path.stat().st_mode) & 0o077:
            raise RuntimeError("Host credential permissions are not private")
        return
    adv, kernel = _windows_api()
    needed = wintypes.DWORD()
    adv.GetFileSecurityW(str(path), 5, None, 0, ctypes.byref(needed))
    buffer = ctypes.create_string_buffer(needed.value)
    if not adv.GetFileSecurityW(str(path), 5, buffer, needed.value, ctypes.byref(needed)):
        raise RuntimeError("Cannot inspect Host Admin security descriptor")
    control, revision = wintypes.WORD(), wintypes.DWORD()
    owner, owner_defaulted = wintypes.LPVOID(), wintypes.BOOL()
    present, dacl, defaulted = wintypes.BOOL(), wintypes.LPVOID(), wintypes.BOOL()
    if not adv.GetSecurityDescriptorControl(buffer, ctypes.byref(control), ctypes.byref(revision)) or not control.value & 0x1000:
        raise RuntimeError("Host credential DACL must disable inheritance")
    user_sid = current_user_sid()
    if not adv.GetSecurityDescriptorOwner(buffer, ctypes.byref(owner), ctypes.byref(owner_defaulted)) or _sid_string(owner, adv, kernel) != user_sid:
        raise RuntimeError("Host credential owner must be the current Windows user")
    if not adv.GetSecurityDescriptorDacl(buffer, ctypes.byref(present), ctypes.byref(dacl), ctypes.byref(defaulted)) or not present.value or not dacl.value:
        raise RuntimeError("Host credential DACL is missing")
    # ACL header: BYTE revision, BYTE reserved, WORD size, WORD ace_count, WORD reserved.
    count = ctypes.cast(dacl, ctypes.POINTER(ctypes.c_ushort))[2]
    allowed = set()
    for index in range(count):
        ace = wintypes.LPVOID()
        if not adv.GetAce(dacl, index, ctypes.byref(ace)):
            raise RuntimeError("Cannot inspect Host credential ACE")
        if ctypes.cast(ace, ctypes.POINTER(ctypes.c_ubyte))[0] != 0:
            raise RuntimeError("Unexpected Host credential ACE")
        sid = _sid_string(ace.value + 8, adv, kernel)
        if sid not in {user_sid, "S-1-5-18"}:
            raise RuntimeError("Host credential is accessible by another principal")
        allowed.add(sid)
    if user_sid not in allowed:
        raise RuntimeError("Host credential grants no access to the current user")
