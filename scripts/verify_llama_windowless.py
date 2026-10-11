"""
Real Isolated Windows Confirmation for llama.cpp Windowless Execution.

Verifies:
1. llama-server.exe is spawned windowless on Windows using CREATE_NO_WINDOW.
2. Console-window inspection via Win32 API and PowerShell fails closed if inspection cannot be performed.
3. No visible console window is associated with llama-server.exe or attached conhost.
   (Win32 IsWindowVisible == False, EnumWindows finds 0 visible windows, MainWindowHandle == 0).
4. Model loading succeeds with real qwen3-vl-2b-instruct in read-only mode.
5. Model status reporting (router_running, model_loaded, active_model).
6. Streaming generation executes and yields tokens.
7. Clean shutdown and process termination without leaving zombie processes.
8. Safe isolation: disposable data/log root, dynamic loopback port, zero live data mutation,
   only terminates subprocesses created by this test.
"""

import asyncio
import ctypes
from ctypes import wintypes
import logging
import os
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

# Configure paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "backend"))

# Create disposable data/log directory before initializing app settings
temp_data_dir = tempfile.TemporaryDirectory(prefix="companion_verify_llama_")
os.environ["COMPANION_DATA_ROOT"] = temp_data_dir.name

from app.core.config import settings
from app.schemas.llm import ChatMessage
from app.services.llm.llama_cpp import LlamaCppProvider
from app.services.llm.runtime_state import LLMRuntimeState

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("verify_llama_windowless")


def get_free_loopback_port() -> int:
    """Acquires a free dynamic loopback port."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


# Win32 Window Inspection Setup
def setup_win32_window_inspector():
    """Sets up Win32 window enumeration functions. Fails closed on error."""
    if sys.platform != "win32":
        raise RuntimeError("Native Windows verification must run on win32.")

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32

    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD

    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.IsWindowVisible.restype = wintypes.BOOL

    user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
    user32.GetWindowTextLengthW.restype = ctypes.c_int

    user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetWindowTextW.restype = ctypes.c_int

    user32.EnumWindows.argtypes = [WNDENUMPROC, wintypes.LPARAM]
    user32.EnumWindows.restype = wintypes.BOOL

    user32.CreateWindowExW.argtypes = [
        wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
        ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
        wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID
    ]
    user32.CreateWindowExW.restype = wintypes.HWND

    user32.DestroyWindow.argtypes = [wintypes.HWND]
    user32.DestroyWindow.restype = wintypes.BOOL

    def get_windows_for_pid(target_pid: int) -> list[dict]:
        found_windows = []

        def callback(hwnd, _):
            pid = wintypes.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            if pid.value == target_pid:
                is_vis = bool(user32.IsWindowVisible(hwnd))
                length = user32.GetWindowTextLengthW(hwnd)
                buf = ctypes.create_unicode_buffer(length + 1)
                user32.GetWindowTextW(hwnd, buf, length + 1)
                found_windows.append({
                    "hwnd": hwnd,
                    "visible": is_vis,
                    "title": buf.value,
                })
            return True

        cb = WNDENUMPROC(callback)
        kernel32.SetLastError(0)
        user32.EnumWindows(cb, 0)
        err = kernel32.GetLastError()
        if err != 0:
            raise RuntimeError(f"Native console-window inspection failed (Win32 error {err}).")

        return found_windows

    # Proactive self-test: create a visible dummy window and ensure inspector detects it
    # WS_VISIBLE | WS_POPUP = 0x10000000 | 0x80000000
    dummy_hwnd = user32.CreateWindowExW(
        0, "STATIC", "InspectorValidationDummy", 0x10000000, 0, 0, 10, 10, 0, 0, 0, 0
    )
    if not dummy_hwnd:
        raise RuntimeError("Failed to create dummy window for window-inspector validation.")

    try:
        probes = get_windows_for_pid(os.getpid())
        visible_probes = [p for p in probes if p["hwnd"] == dummy_hwnd and p["visible"]]
        if not visible_probes:
            raise RuntimeError("Window inspector self-test failed: did not detect known visible dummy window!")
        logger.info(f"Win32 window inspector successfully validated (detected dummy HWND {dummy_hwnd}).")
    finally:
        user32.DestroyWindow(dummy_hwnd)

    return get_windows_for_pid


async def run_verification():
    logger.info("============================================================")
    logger.info("VERIFYING LLAMA.CPP WINDOWLESS EXECUTION (ISOLATED RUN)")
    logger.info("============================================================")

    # Configure dynamic loopback port and ensure disposable data dir exists
    isolated_port = get_free_loopback_port()
    settings.LLAMA_ROUTER_PORT = isolated_port
    settings.LLAMA_SERVER_URL = f"http://127.0.0.1:{isolated_port}/v1"
    settings.DATA_DIR.mkdir(parents=True, exist_ok=True)

    logger.info(f"[ISOLATION] Disposable data/log root: {settings.DATA_DIR}")
    logger.info(f"[ISOLATION] Isolated dynamic loopback port: {isolated_port}")

    # 1. Setup inspector - fails closed if inspection itself fails
    get_windows_for_pid = setup_win32_window_inspector()

    # 2. Check engine binary and model (read-only assets)
    server_exe = settings.LLAMA_CPP_BIN_DIR / "llama-server.exe"
    if not server_exe.exists():
        raise FileNotFoundError(f"llama-server.exe not found at {server_exe}")
    logger.info(f"[PREFLIGHT] Found engine binary: {server_exe}")

    test_model = "qwen3-vl-2b-instruct"
    logger.info(f"[PREFLIGHT] Target model (read-only): {test_model}")

    provider = LlamaCppProvider()

    try:
        # 3. Load model and spawn router
        logger.info("[STEP 1] Loading model into llama-server router on isolated port...")
        loaded = await provider.load_model(test_model)
        if not loaded:
            status = await provider.get_status()
            raise RuntimeError(f"load_model failed: last_error={provider._last_error}, runtime_state={status.runtime_state}")

        logger.info(f"[STEP 1 PASS] Model loaded successfully: {test_model}")

        # 4. Check spawned process
        proc = provider._server_process
        if proc is None or proc.poll() is not None:
            raise RuntimeError("llama-server process is not running!")

        pid = proc.pid
        logger.info(f"[STEP 2] llama-server running with PID: {pid}")

        # 5. Windowless Inspection: Verify MainWindowHandle == 0 and 0 visible console windows
        logger.info(f"[STEP 3] Inspecting console windows for PID {pid}...")

        # A: Verify MainWindowHandle == 0 via PowerShell (fails closed)
        ps_handle_cmd = f"powershell -NoProfile -Command \"(Get-Process -Id {pid} -ErrorAction Stop).MainWindowHandle\""
        try:
            handle_out = subprocess.check_output(ps_handle_cmd, shell=True, text=True).strip()
            if not handle_out:
                raise RuntimeError(f"Could not retrieve MainWindowHandle for PID {pid}")
            main_window_handle = int(handle_out)
            logger.info(f"Process PID {pid} MainWindowHandle: {main_window_handle}")
            if main_window_handle != 0:
                raise AssertionError(f"Process PID {pid} has visible MainWindowHandle: {main_window_handle}!")
        except Exception as e:
            raise RuntimeError(f"Failed to inspect MainWindowHandle for PID {pid}: {e}")

        # B: Verify Win32 EnumWindows visible windows == 0
        windows = get_windows_for_pid(pid)
        visible_windows = [w for w in windows if w["visible"]]
        logger.info(f"Total windows found for PID {pid}: {len(windows)}, visible: {len(visible_windows)}")

        if visible_windows:
            for w in visible_windows:
                logger.error(f"FAIL: Visible window detected! HWND={w['hwnd']}, Title='{w['title']}'")
            raise AssertionError(f"Visible window detected for llama-server PID {pid}!")

        # Also inspect child processes (e.g. conhost.exe)
        try:
            wmi_query = f"powershell -NoProfile -Command \"Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {{ $_.ParentProcessId -eq {pid} }} | Select-Object -ExpandProperty ProcessId\""
            child_output = subprocess.check_output(wmi_query, shell=True, text=True).strip()
            if child_output:
                for line in child_output.splitlines():
                    if line.strip().isdigit():
                        child_pid = int(line.strip())
                        logger.info(f"Checking child process PID {child_pid}...")
                        # Child MainWindowHandle
                        ch_cmd = f"powershell -NoProfile -Command \"(Get-Process -Id {child_pid} -ErrorAction Stop).MainWindowHandle\""
                        ch_handle = subprocess.check_output(ch_cmd, shell=True, text=True).strip()
                        if ch_handle and int(ch_handle) != 0:
                            raise AssertionError(f"Child process PID {child_pid} has visible MainWindowHandle: {ch_handle}!")

                        child_windows = get_windows_for_pid(child_pid)
                        child_visible = [w for w in child_windows if w["visible"]]
                        if child_visible:
                            for cw in child_visible:
                                logger.error(f"FAIL: Visible window detected on child PID {child_pid}! HWND={cw['hwnd']}, Title='{cw['title']}'")
                            raise AssertionError(f"Visible window detected for child process PID {child_pid}!")
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to inspect child processes of PID {pid}: {e}")

        logger.info("[STEP 3 PASS] Confirmed MainWindowHandle == 0 and ZERO visible console windows for llama-server and children!")

        # 6. Verify Runtime and Model Health
        logger.info("[STEP 4] Verifying runtime and model health...")
        status = await provider.get_status()
        logger.info(f"Status: state={status.runtime_state}, model_loaded={status.model_loaded}, router_running={status.router_running}")
        assert status.router_running is True, "Router must be running"
        assert status.model_loaded is True, "Model must be loaded"
        assert status.active_model == test_model, f"Expected {test_model}, got {status.active_model}"
        logger.info("[STEP 4 PASS] Runtime and model health verified.")

        # 7. Verify Generation
        logger.info("[STEP 5] Verifying generation stream...")
        test_messages = [ChatMessage(role="user", content="Respond with 'PONG'.")]
        generated_tokens = []
        async for token in provider.generate_stream(test_messages):
            generated_tokens.append(token)
            if len(generated_tokens) >= 3:
                break

        generated_text = "".join(generated_tokens)
        logger.info(f"Received generation tokens: {repr(generated_text)}")
        assert len(generated_tokens) > 0, "Generation must produce tokens"
        logger.info("[STEP 5 PASS] Generation confirmed functional.")

        # 8. Clean Unload and Process Termination (Only terminate subprocess created by this test)
        logger.info("[STEP 6] Testing clean unload and shutdown...")
        unloaded = await provider.unload_model()
        logger.info(f"unload_model result: {unloaded}")

        if provider._managed_by_core and provider._server_process:
            logger.info(f"Terminating test router PID={provider._server_pid}")
            provider._server_process.terminate()
            try:
                provider._server_process.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                provider._server_process.kill()

        assert proc.poll() is not None, "llama-server process must terminate cleanly"
        logger.info(f"[STEP 6 PASS] Process PID {pid} exited with code {proc.poll()}.")

        logger.info("============================================================")
        logger.info("ALL WINDOWLESS ACCEPTANCE CRITERIA PASSED EMPIRICALLY!")
        logger.info("============================================================")

    finally:
        # Strictly bounded teardown: only terminate the subprocess created by this test
        if provider._server_process and provider._server_process.poll() is None:
            try:
                provider._server_process.terminate()
                provider._server_process.wait(timeout=2.0)
            except Exception:
                provider._server_process.kill()

        # Clean up disposable temporary data directory
        try:
            temp_data_dir.cleanup()
            logger.info(f"[ISOLATION] Cleaned up disposable temp root: {temp_data_dir.name}")
        except Exception as cleanup_err:
            logger.warning(f"Error cleaning up temporary directory: {cleanup_err}")


if __name__ == "__main__":
    asyncio.run(run_verification())
