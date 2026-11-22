"""Tests for Decision D6 controlled model import, multi-root LlamaCppProvider, and profile persistence."""

import hashlib
import json
import struct
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import settings
from app.services.llm.manager import llm_manager
from app.services.llm.runtime_state import LLMRuntimeState


def _build_gguf_bytes(
    *,
    arch: str = "qwen3vl",
    context_length: int = 8192,
    file_type: int = 15,
    general_type: str = "model",
    name: str = "CustomModel",
    size_label: str = "2B",
    license_name: str = "apache-2.0",
    chat_template: str = "{% for m in messages %}{{ m.content }}{% endfor %}",
) -> bytes:
    def _str(s: str) -> bytes:
        b = s.encode("utf-8")
        return struct.pack("<Q", len(b)) + b

    kvs = [
        ("general.architecture", 8, arch),
        ("general.type", 8, general_type),
        ("general.name", 8, name),
        ("general.size_label", 8, size_label),
        ("general.license", 8, license_name),
        (f"{arch}.context_length", 4, context_length),
        ("general.file_type", 4, file_type),
        ("general.quantization_version", 4, 2),
        ("tokenizer.chat_template", 8, chat_template),
    ]
    buf = bytearray(b"GGUF")
    buf.extend(struct.pack("<I", 3))
    buf.extend(struct.pack("<Q", 0))
    buf.extend(struct.pack("<Q", len(kvs)))
    for k, vt, v in kvs:
        buf.extend(_str(k))
        buf.extend(struct.pack("<I", vt))
        if vt == 4:
            buf.extend(struct.pack("<I", int(v)))
        elif vt == 8:
            buf.extend(_str(str(v)))
    return bytes(buf)


def test_hardware_suitability_advisory_thresholds():
    from app.services.model_registry import assess_hardware_suitability

    gb = 1024 ** 3
    rec = assess_hardware_suitability(int(2.0 * gb), dedicated_vram_gb=8.0)
    assert rec.status == "recommended"
    assert rec.recommended_profile in ("balanced", "maximum")

    warn = assess_hardware_suitability(int(4.5 * gb), dedicated_vram_gb=8.0)
    assert warn.status == "supported_with_warning"
    assert warn.recommended_profile in ("eco", "balanced")

    heavy = assess_hardware_suitability(int(7.0 * gb), dedicated_vram_gb=8.0)
    assert heavy.status == "not_recommended"
    assert heavy.recommended_profile == "eco"


@pytest.mark.asyncio
async def test_d6_import_scan_install_and_delete_lifecycle(client, host_admin_headers, monkeypatch, tmp_path):
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "DataRoot"))

    # 1. Auth required
    unauth = await client.post("/api/v1/models/import/scan")
    assert unauth.status_code == 401

    # 2. Empty scan lazily creates IMPORT_INBOX_DIR
    assert not settings.IMPORT_INBOX_DIR.exists()
    empty_scan = await client.post("/api/v1/models/import/scan", headers=host_admin_headers)
    assert empty_scan.status_code == 200
    assert settings.IMPORT_INBOX_DIR.is_dir()
    assert empty_scan.json()["candidates"] == []

    # 3. Drop bundle (primary + companion mmproj) + corrupt file into inbox
    bundle_dir = settings.IMPORT_INBOX_DIR / "gemma-bundle"
    bundle_dir.mkdir(parents=True)
    primary_bytes = _build_gguf_bytes(arch="gemma3", name="Gemma-3-4B-IT", size_label="4B", context_length=8192)
    mmproj_bytes = _build_gguf_bytes(arch="clip", general_type="mmproj", name="mmproj-gemma3", size_label="")
    (bundle_dir / "gemma-3-4b-it-Q4_K_M.gguf").write_bytes(primary_bytes)
    (bundle_dir / "mmproj-gemma-3-4b-f16.gguf").write_bytes(mmproj_bytes)
    (settings.IMPORT_INBOX_DIR / "broken.gguf").write_bytes(b"NOT_GGUF_CORRUPT")

    scan_resp = await client.post("/api/v1/models/import/scan", headers=host_admin_headers)
    assert scan_resp.status_code == 200
    candidates = scan_resp.json()["candidates"]
    valid_cand = next(c for c in candidates if c["primary_filename"] == "gemma-3-4b-it-Q4_K_M.gguf")
    broken_cand = next(c for c in candidates if c["primary_filename"] == "broken.gguf")

    assert valid_cand["artifact_valid"] is True
    assert valid_cand["architecture"] == "gemma3"
    assert valid_cand["quantization"] == "Q4_K_M"
    assert valid_cand["has_vision_projector"] is True
    assert valid_cand["companion_mmproj_filename"] == "mmproj-gemma-3-4b-f16.gguf"
    assert "vision" in valid_cand["detected_capabilities"]
    assert broken_cand["artifact_valid"] is False

    # 4. Reject installing invalid/corrupt candidate with 400
    bad_install = await client.post(
        "/api/v1/models/import/install",
        json={"relative_path": broken_cand["relative_path"], "model_id": "broken-model"},
        headers=host_admin_headers,
    )
    assert bad_install.status_code == 400

    # 5. Valid D6 atomic install
    with patch.object(llm_manager, "refresh_auto_provider_if_idle", return_value=True) as mock_refresh:
        install_resp = await client.post(
            "/api/v1/models/import/install",
            json={
                "relative_path": valid_cand["relative_path"],
                "companion_relative_path": valid_cand["companion_mmproj_relative_path"],
                "model_id": "gemma-3-4b-custom",
                "display_name": "My Gemma 3 4B",
                "variant": "instruct",
                "family": "Gemma3",
            },
            headers=host_admin_headers,
        )
    assert install_resp.status_code == 200
    mock_refresh.assert_called_once()
    install_data = install_resp.json()
    assert install_data["installed_id"] == "gemma-3-4b-custom"
    assert install_data["sha256_primary"] == hashlib.sha256(primary_bytes).hexdigest()

    installed_primary = settings.MODEL_LIBRARY_DIR / "gemma-3-4b-custom" / "gemma-3-4b-it-Q4_K_M.gguf"
    installed_mmproj = settings.MODEL_LIBRARY_DIR / "gemma-3-4b-custom" / "mmproj-gemma-3-4b-f16.gguf"
    assert installed_primary.is_file()
    assert installed_mmproj.is_file()
    # Original inbox assets removed atomically on install
    assert not (bundle_dir / "gemma-3-4b-it-Q4_K_M.gguf").exists()
    assert not (bundle_dir / "mmproj-gemma-3-4b-f16.gguf").exists()

    reg_json = json.loads(settings.INSTALLED_REGISTRY_PATH.read_text(encoding="utf-8"))
    assert reg_json["_schema_version"] == "3"
    assert reg_json["models"][0]["id"] == "gemma-3-4b-custom"
    assert reg_json["models"][0]["architecture"] == "gemma3"
    assert reg_json["models"][0]["quantization"] == "Q4_K_M"
    assert reg_json["models"][0]["display_name"] == "My Gemma 3 4B"

    # 6. Cannot delete a model while loaded
    loaded_mock = MagicMock()
    loaded_mock.is_loaded.return_value = True
    loaded_mock.has_active_generation = False
    loaded_mock.get_status = AsyncMock(return_value=MagicMock(active_model="gemma-3-4b-custom", model_loaded=True))
    orig = llm_manager._provider
    try:
        llm_manager.set_provider(loaded_mock)
        del_busy = await client.delete("/api/v1/models/registry/gemma-3-4b-custom", headers=host_admin_headers)
        assert del_busy.status_code == 409

        # Unload and delete succeeds, clearing stale host_config selected_model
        from app.services.host_config import get_saved_model_selection, save_model_selection
        save_model_selection("gemma-3-4b-custom")
        loaded_mock.is_loaded.return_value = False
        loaded_mock.get_status = AsyncMock(return_value=MagicMock(active_model=None, model_loaded=False))

        del_ok = await client.delete("/api/v1/models/registry/gemma-3-4b-custom", headers=host_admin_headers)
        assert del_ok.status_code == 200
        assert del_ok.json()["deleted_id"] == "gemma-3-4b-custom"
        assert not (settings.MODEL_LIBRARY_DIR / "gemma-3-4b-custom").exists()
        assert get_saved_model_selection() is None
    finally:
        llm_manager.set_provider(orig)


@pytest.mark.asyncio
async def test_llama_cpp_profile_persistence_router_reset_and_multiroot(monkeypatch, tmp_path):
    """Profile persists across provider restart, set_profile resets stale active state, and installed root uses MODEL_LIBRARY_DIR."""
    from app.services.host_config import get_saved_hardware_profile
    from app.services.llm.llama_cpp import LlamaCppProvider
    from app.schemas.model_registry import (
        ModelDiscoveryState,
        ModelLibraryState,
        ModelManifest,
        ModelRegistryEntry,
        ModelRuntimeHints,
        ValidationStatus,
    )

    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "ProfData"))
    provider = LlamaCppProvider()
    assert provider._active_profile == "balanced"

    # Simulate an active Core-managed router before set_profile()
    fake_proc = MagicMock()
    fake_proc.poll.return_value = None
    provider._managed_by_core = True
    provider._server_process = fake_proc
    provider._server_pid = 4321
    provider._server_is_active = True
    provider._active_model_name = "qwen3-vl-2b-instruct"
    provider._runtime_state = LLMRuntimeState.MODEL_READY

    with patch.object(provider, "_router_unload_model", new_callable=AsyncMock, return_value=True), \
         patch.object(provider, "_stop_managed_router_locked", return_value=True):
        ok = await provider.set_profile("maximum")

    assert ok is True
    assert get_saved_hardware_profile() == "maximum"
    assert provider._server_is_active is False
    assert provider._active_model_name is None
    assert provider._runtime_state == LLMRuntimeState.SERVER_STOPPED

    # New instance loads persisted hardware_profile
    restarted = LlamaCppProvider()
    assert restarted._active_profile == "maximum"

    # Multi-root check: installed model resolves to MODEL_LIBRARY_DIR when launching llama-server
    installed_dir = settings.MODEL_LIBRARY_DIR / "user-model"
    installed_dir.mkdir(parents=True)
    (installed_dir / "model.gguf").write_bytes(b"GGUFtest")

    entry = ModelRegistryEntry(
        manifest=ModelManifest(id="user-model", display_name="User Model", primary_file="user-model/model.gguf"),
        library_state=ModelLibraryState(
            discovery_state=ModelDiscoveryState.verified,
            validation_status=ValidationStatus.verified,
            primary_file_exists=True,
        ),
        hints=ModelRuntimeHints(),
        runtime_model_id="user-model",
        registry_source="installed",
    )
    assert restarted._models_dir_for_entry(entry) == settings.MODEL_LIBRARY_DIR
    # MagicMock entry must default safely to LLAMA_MODELS_DIR (regression guard)
    assert restarted._models_dir_for_entry(MagicMock()) == settings.LLAMA_MODELS_DIR


def test_autostart_service_xml_and_escaping(monkeypatch, tmp_path):
    """PC-HOST-002: Standard-user Task Scheduler v1.2 XML escapes paths, uses LeastPrivilege & PT0S."""
    import sys
    import xml.etree.ElementTree as ET
    from app.services.autostart import WindowsAutostartService

    exe_dir = tmp_path / "AI & ML"
    exe_dir.mkdir(parents=True)
    exe_path = exe_dir / "ai_companion_desktop.exe"
    exe_path.write_bytes(b"MZ")

    svc = WindowsAutostartService()
    xml_str = svc.build_task_xml(
        command=r"C:\AI & ML\Companion<1>\ai_companion_desktop.exe",
        arguments="--minimized-to-tray",
        working_directory=r"C:\AI & ML\Companion<1>",
    )
    assert "&amp;" in xml_str and "&lt;" in xml_str
    root = ET.fromstring(xml_str)
    ns = {"t": "http://schemas.microsoft.com/windows/2004/02/mit/task"}
    assert root.find(".//t:LogonTrigger/t:Enabled", ns).text == "true"
    assert root.find(".//t:Principal/t:RunLevel", ns).text == "LeastPrivilege"
    assert root.find(".//t:Settings/t:DisallowStartIfOnBatteries", ns).text == "false"
    assert root.find(".//t:Settings/t:StopIfGoingOnBatteries", ns).text == "false"
    assert root.find(".//t:Settings/t:ExecutionTimeLimit", ns).text == "PT0S"
    assert root.find(".//t:Settings/t:RestartOnFailure", ns) is None
    assert root.find(".//t:Exec/t:Command", ns).text == r"C:\AI & ML\Companion<1>\ai_companion_desktop.exe"
    assert root.find(".//t:Exec/t:Arguments", ns).text == "--minimized-to-tray"
    assert root.find(".//t:Exec/t:WorkingDirectory", ns).text == r"C:\AI & ML\Companion<1>"

    # Verify CREATE_NO_WINDOW gated cleanly & schtasks called on set_enabled
    with patch("app.services.autostart.subprocess.run") as mock_run, \
         patch.object(sys, "platform", "win32"):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        res = svc.set_enabled(True, minimized_to_tray=True, executable_path=str(exe_path), working_directory=str(exe_dir))
        assert res.enabled is True
        assert mock_run.called
        _, kwargs = mock_run.call_args
        assert "creationflags" in kwargs


@pytest.mark.asyncio
async def test_autostart_endpoints_auth_and_persistence(client, host_admin_headers, monkeypatch, tmp_path):
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "AutostartData"))

    unauth = await client.get("/api/v1/system/autostart")
    assert unauth.status_code == 401

    from app.schemas.health import AutostartStatusOut
    fake_status = AutostartStatusOut(
        supported=True,
        enabled=True,
        task_registered=True,
        task_name="AICompanionAutostart",
        minimized_to_tray=True,
        command=r"C:\Program Files\AICompanion\ai_companion_desktop.exe --minimized-to-tray",
        working_directory=r"C:\Program Files\AICompanion",
        status_detail="Registered in Windows Task Scheduler (LeastPrivilege)",
    )
    with patch("app.api.v1.endpoints.health.WindowsAutostartService.set_enabled", return_value=fake_status), \
         patch("app.api.v1.endpoints.health.WindowsAutostartService.get_status", return_value=fake_status):
        put_resp = await client.put(
            "/api/v1/system/autostart",
            json={"enabled": True, "minimized_to_tray": True},
            headers=host_admin_headers,
        )
        assert put_resp.status_code == 200
        assert put_resp.json()["enabled"] is True
        assert put_resp.json()["minimized_to_tray"] is True

        get_resp = await client.get("/api/v1/system/autostart", headers=host_admin_headers)
        assert get_resp.status_code == 200
        assert get_resp.json()["task_name"] == "AICompanionAutostart"
