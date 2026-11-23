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
    embedding_length: int | None = None,
    projector_type: str | None = None,
    vision_projection_dim: int | None = None,
    basename: str | None = None,
    tags: list[str] | None = None,
) -> bytes:
    def _str(s: str) -> bytes:
        b = s.encode("utf-8")
        return struct.pack("<Q", len(b)) + b

    kvs: list[tuple[str, int, object]] = [
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
    if basename is not None:
        kvs.append(("general.basename", 8, basename))
    if embedding_length is not None:
        kvs.append((f"{arch}.embedding_length", 4, embedding_length))
    if projector_type is not None:
        kvs.append(("clip.projector_type", 8, projector_type))
    if vision_projection_dim is not None:
        kvs.append(("clip.vision.projection_dim", 4, vision_projection_dim))
    if tags is not None:
        kvs.append(("general.tags", 9, tags))

    buf = bytearray(b"GGUF")
    buf.extend(struct.pack("<I", 3))
    buf.extend(struct.pack("<Q", 0))
    buf.extend(struct.pack("<Q", len(kvs)))
    for k, vt, v in kvs:
        buf.extend(_str(k))
        buf.extend(struct.pack("<I", vt))
        if vt == 4:
            buf.extend(struct.pack("<I", int(v)))  # type: ignore[arg-type]
        elif vt == 8:
            buf.extend(_str(str(v)))
        elif vt == 9:
            items = list(v)  # type: ignore[arg-type]
            buf.extend(struct.pack("<I", 8))
            buf.extend(struct.pack("<Q", len(items)))
            for item in items:
                buf.extend(_str(str(item)))
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
        user_id=r"CORP&CO\user<1>",
    )
    assert 'encoding="UTF-16"' in xml_str
    assert "&amp;" in xml_str and "&lt;" in xml_str
    root = ET.fromstring(xml_str.encode("utf-16"))
    ns = {"t": "http://schemas.microsoft.com/windows/2004/02/mit/task"}
    assert root.find(".//t:LogonTrigger/t:Enabled", ns).text == "true"
    assert root.find(".//t:LogonTrigger/t:UserId", ns).text == r"CORP&CO\user<1>"
    assert root.find(".//t:LogonTrigger/t:Delay", ns).text == "PT5S"
    trigger_tags = [child.tag.split("}")[-1] for child in root.find(".//t:LogonTrigger", ns)]
    assert trigger_tags.index("UserId") < trigger_tags.index("Delay")
    assert root.find(".//t:Principal/t:UserId", ns).text == r"CORP&CO\user<1>"
    assert root.find(".//t:Principal/t:RunLevel", ns).text == "LeastPrivilege"
    assert root.find(".//t:Settings/t:DisallowStartIfOnBatteries", ns).text == "false"
    assert root.find(".//t:Settings/t:StopIfGoingOnBatteries", ns).text == "false"
    assert root.find(".//t:Settings/t:ExecutionTimeLimit", ns).text == "PT0S"
    assert root.find(".//t:Settings/t:Priority", ns).text == "5"
    assert root.find(".//t:Settings/t:RestartOnFailure", ns) is None
    assert root.find(".//t:Exec/t:Command", ns).text == r"C:\AI & ML\Companion<1>\ai_companion_desktop.exe"
    assert root.find(".//t:Exec/t:Arguments", ns).text == "--minimized-to-tray"
    assert root.find(".//t:Exec/t:WorkingDirectory", ns).text == r"C:\AI & ML\Companion<1>"

    # Verify CREATE_NO_WINDOW gated cleanly, UTF-16LE BOM written to /XML file & get_status parses UTF-16 XML
    captured_xml_bytes = {}

    def _fake_schtasks(cmd, **kwargs):
        if "/Create" in cmd and "/XML" in cmd:
            xml_path = Path(cmd[cmd.index("/XML") + 1])
            captured_xml_bytes["bom"] = xml_path.read_bytes()[:2]
            return MagicMock(returncode=0, stdout="", stderr="")
        if "/Query" in cmd:
            return MagicMock(returncode=0, stdout=xml_str, stderr="")
        return MagicMock(returncode=0, stdout="", stderr="")

    with patch("app.services.autostart.subprocess.run", side_effect=_fake_schtasks) as mock_run, \
         patch.object(sys, "platform", "win32"):
        res = svc.set_enabled(True, minimized_to_tray=True, executable_path=str(exe_path), working_directory=str(exe_dir))
        assert res.enabled is True
        assert captured_xml_bytes.get("bom") == b"\xff\xfe"
        assert mock_run.called
        _, kwargs = mock_run.call_args
        assert "creationflags" in kwargs
        queried = svc.get_status()
        assert queried.task_registered is True
        assert queried.minimized_to_tray is True


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


def test_hardware_probe_and_dynamic_recommendations(monkeypatch):
    from app.services.hardware_probe import clear_hardware_probe_cache, probe_host_hardware
    from app.services.model_registry import compute_recommended_profiles_for_model

    clear_hardware_probe_cache()
    monkeypatch.setenv("HOST_DEDICATED_VRAM_GB", "8.0")
    hw8 = probe_host_hardware(force_refresh=True)
    assert hw8.dedicated_vram_gb == 8.0
    assert hw8.detection_source == "env_override"

    gb = 1024 ** 3
    # Qwen3-VL 2B (~1.4 GB + 0.85 GB mmproj) fits cleanly -> Balanced first
    rec_2b, _ = compute_recommended_profiles_for_model(
        file_size_bytes=int(1.4 * gb),
        companion_size_bytes=int(0.85 * gb),
        dedicated_vram_gb=8.0,
    )
    assert rec_2b[0] == "balanced"

    # Qwen3-VL 8B (~5.0 GB + 0.95 GB mmproj) exceeds usable 8 GB VRAM -> Eco recommended
    rec_8b_8gb, _ = compute_recommended_profiles_for_model(
        file_size_bytes=int(5.0 * gb),
        companion_size_bytes=int(0.95 * gb),
        dedicated_vram_gb=8.0,
    )
    assert rec_8b_8gb == ["eco"]

    # Same 8B on 16 GB GPU fits comfortably -> Balanced/Maximum
    rec_8b_16gb, _ = compute_recommended_profiles_for_model(
        file_size_bytes=int(5.0 * gb),
        companion_size_bytes=int(0.95 * gb),
        dedicated_vram_gb=16.0,
    )
    assert rec_8b_16gb[0] == "balanced"
    assert "maximum" in rec_8b_16gb
    clear_hardware_probe_cache()


@pytest.mark.asyncio
async def test_experimental_context_mode_and_profile_reset(monkeypatch, tmp_path):
    from app.services.host_config import get_saved_context_mode
    from app.services.llm.llama_cpp import LlamaCppProvider

    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "CtxData"))
    provider = LlamaCppProvider()
    assert provider._context_mode == "profile"
    assert provider._get_profile_params("maximum", model_max_context=32768)["n_ctx"] == 8192

    fake_proc = MagicMock()
    fake_proc.poll.return_value = None
    provider._managed_by_core = True
    provider._server_process = fake_proc
    provider._server_pid = 9999
    provider._server_is_active = True
    provider._active_model_name = "qwen3-vl-2b-instruct"
    provider._runtime_state = LLMRuntimeState.MODEL_READY

    with patch.object(provider, "_router_unload_model", new_callable=AsyncMock, return_value=True), \
         patch.object(provider, "_stop_managed_router_locked", return_value=True):
        ok_16k = await provider.set_profile("balanced", context_mode="16k")

    assert ok_16k is True
    assert get_saved_context_mode() == "16k"
    assert provider._runtime_state == LLMRuntimeState.SERVER_STOPPED
    assert provider._get_profile_params("balanced", model_max_context=32768)["n_ctx"] == 16384

    await provider.set_profile("balanced", context_mode="model_max")
    assert provider._get_profile_params("balanced", model_max_context=65536)["n_ctx"] == 65536
    assert await provider.set_profile("balanced", context_mode="invalid_ctx") is False


@pytest.mark.asyncio
async def test_d6_multiformat_warnings_and_transfer_modes(client, host_admin_headers, monkeypatch, tmp_path):
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "FmtData"))
    settings.IMPORT_INBOX_DIR.mkdir(parents=True, exist_ok=True)
    (settings.IMPORT_INBOX_DIR / "unsafe.pt").write_bytes(b"pickle-stub")
    (settings.IMPORT_INBOX_DIR / "weights.safetensors").write_bytes(b"st-stub")
    (settings.IMPORT_INBOX_DIR / "voice.onnx").write_bytes(b"onnx-stub")
    (settings.IMPORT_INBOX_DIR / "legacy.bin").write_bytes(b"bin-stub")

    valid_bytes = _build_gguf_bytes(arch="qwen3", name="Copy-Keep-Model", size_label="2B", context_length=32768)
    (settings.IMPORT_INBOX_DIR / "copy-keep.gguf").write_bytes(valid_bytes)

    scan = await client.post("/api/v1/models/import/scan", headers=host_admin_headers)
    assert scan.status_code == 200
    warnings = "\n".join(scan.json()["warnings"])
    assert "Blocked unsafe Python pickle file 'unsafe.pt'" in warnings
    assert "Ignored SafeTensors file 'weights.safetensors'" in warnings
    assert "Ignored ONNX file 'voice.onnx'" in warnings
    assert "Ignored legacy .bin file 'legacy.bin'" in warnings

    with patch.object(llm_manager, "refresh_auto_provider_if_idle", return_value=False):
        install_copy = await client.post(
            "/api/v1/models/import/install",
            json={
                "relative_path": "copy-keep.gguf",
                "model_id": "copy-keep-model",
                "transfer_mode": "copy",
            },
            headers=host_admin_headers,
        )
    assert install_copy.status_code == 200
    assert (settings.MODEL_LIBRARY_DIR / "copy-keep-model" / "copy-keep.gguf").is_file()
    assert (settings.IMPORT_INBOX_DIR / "copy-keep.gguf").is_file()


def test_assess_context_options_guardrails():
    from app.services.model_registry import assess_context_options

    gb = 1024 ** 3
    # 3.1 GB total weights on 8 GB VRAM GPU with 32K model limit in balanced mode
    opts = assess_context_options(
        int(2.3 * gb),
        companion_size_bytes=int(0.8 * gb),
        profile="balanced",
        model_max_context=32768,
        dedicated_vram_gb=8.0,
        total_ram_gb=16.0,
    )
    by_mode = {o.mode: o for o in opts}
    assert by_mode["profile"].selectable is True
    assert by_mode["2k"].status == "good_fit" and by_mode["2k"].selectable is True
    assert by_mode["4k"].status == "good_fit" and by_mode["4k"].selectable is True
    assert by_mode["8k"].status == "tight" and by_mode["8k"].selectable is True
    assert by_mode["16k"].status == "blocked" and by_mode["16k"].selectable is False
    assert by_mode["32k"].status == "blocked" and by_mode["32k"].selectable is False

    # Model with 8K max blocks 16k with exceeds_model_max=True
    opts_8k_cap = assess_context_options(
        int(1.0 * gb),
        profile="balanced",
        model_max_context=8192,
        dedicated_vram_gb=24.0,
        total_ram_gb=32.0,
    )
    cap_map = {o.mode: o for o in opts_8k_cap}
    assert cap_map["16k"].exceeds_model_max is True
    assert cap_map["16k"].selectable is False

    # Eco CPU mode checks RAM capacity rather than GPU VRAM
    opts_eco = assess_context_options(
        int(6.0 * gb),
        profile="eco",
        model_max_context=32768,
        dedicated_vram_gb=4.0,
        total_ram_gb=16.0,
    )
    eco_map = {o.mode: o for o in opts_eco}
    assert eco_map["2k"].status == "good_fit" and eco_map["2k"].selectable is True
    assert eco_map["32k"].status == "tight"


@pytest.mark.asyncio
async def test_multimmproj_header_matching_and_incompatible_rejection(
    client, host_admin_headers, monkeypatch, tmp_path
):
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "MmprojData"))
    inbox = settings.IMPORT_INBOX_DIR
    inbox.mkdir(parents=True, exist_ok=True)

    # Gemma 3 4B (emb=2560, tags=['image-text-to-text']) + Qwen3-VL 4B Instruct + Thinking (emb=2560)
    # Note both Gemma 3 and Qwen3-VL 4B have dim=2560; projector_type prevents cross-pairing!
    (inbox / "gemma-3-4b-it-Q4_K_M.gguf").write_bytes(
        _build_gguf_bytes(
            arch="gemma3",
            name="Gemma 3 4b It",
            basename="gemma-3",
            embedding_length=2560,
            tags=["image-text-to-text"],
        )
    )
    (inbox / "mmproj-model-f16.gguf").write_bytes(
        _build_gguf_bytes(
            arch="clip",
            general_type="",
            name="",
            projector_type="gemma3",
            vision_projection_dim=2560,
        )
    )
    (inbox / "Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf").write_bytes(
        _build_gguf_bytes(
            arch="qwen3vl",
            name="Qwen3 VL 4B Instruct",
            basename="Qwen3-VL",
            embedding_length=2560,
            tags=["image-text-to-text"],
        )
    )
    (inbox / "mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf").write_bytes(
        _build_gguf_bytes(
            arch="clip",
            general_type="mmproj",
            name="Qwen3 VL 4B Instruct",
            basename="Qwen3-VL",
            projector_type="qwen3vl_merger",
            vision_projection_dim=2560,
        )
    )
    (inbox / "mmproj-Qwen_Qwen3-VL-4B-Thinking-f16.gguf").write_bytes(
        _build_gguf_bytes(
            arch="clip",
            general_type="mmproj",
            name="Qwen3 VL 4B Thinking",
            basename="Qwen3-VL",
            projector_type="qwen3vl_merger",
            vision_projection_dim=2560,
        )
    )
    # Single VL file with no matching projector in its folder or wrong dim
    sub = inbox / "lonely-gemma4"
    sub.mkdir()
    (sub / "gemma-4-E2B-it-Q4_K_M.gguf").write_bytes(
        _build_gguf_bytes(
            arch="gemma4",
            name="Gemma-4-E2B-It",
            basename="Gemma-4-E2B-It",
            embedding_length=1536,
            tags=["unsloth", "any-to-any"],
        )
    )

    scan = await client.post("/api/v1/models/import/scan", headers=host_admin_headers)
    assert scan.status_code == 200
    body = scan.json()
    assert len(body["available_mmprojs"]) == 3
    by_file = {c["primary_filename"]: c for c in body["candidates"]}

    g3 = by_file["gemma-3-4b-it-Q4_K_M.gguf"]
    assert g3["expects_vision_projector"] is True
    assert g3["has_vision_projector"] is True
    assert g3["companion_mmproj_relative_path"] == "mmproj-model-f16.gguf"
    assert g3["compatible_mmproj_paths"] == ["mmproj-model-f16.gguf"]
    assert g3["reasoning_mode"] == "unsupported"
    assert len(g3["context_options"]) >= 6

    q4 = by_file["Qwen_Qwen3-VL-4B-Instruct-Q4_K_M.gguf"]
    assert q4["companion_mmproj_relative_path"] == "mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf"
    assert "mmproj-model-f16.gguf" not in q4["compatible_mmproj_paths"]
    assert "mmproj-Qwen_Qwen3-VL-4B-Thinking-f16.gguf" in q4["compatible_mmproj_paths"]

    g4 = by_file["gemma-4-E2B-it-Q4_K_M.gguf"]
    assert g4["expects_vision_projector"] is True
    assert g4["has_vision_projector"] is False
    assert g4["companion_mmproj_relative_path"] is None
    assert g4["compatible_mmproj_paths"] == []

    # Installing Gemma 3 with Qwen3-VL mmproj fails closed with HTTP 400
    bad = await client.post(
        "/api/v1/models/import/install",
        json={
            "relative_path": "gemma-3-4b-it-Q4_K_M.gguf",
            "companion_relative_path": "mmproj-Qwen_Qwen3-VL-4B-Instruct-f16.gguf",
            "model_id": "gemma3-mismatched",
        },
        headers=host_admin_headers,
    )
    assert bad.status_code == 400
    assert "incompatible" in bad.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_reasoning_mode_detection_and_persistence(
    client, host_admin_headers, monkeypatch, tmp_path
):
    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "ReasonData"))
    inbox = settings.IMPORT_INBOX_DIR
    inbox.mkdir(parents=True, exist_ok=True)

    (inbox / "gemma4-toggle.gguf").write_bytes(
        _build_gguf_bytes(
            arch="gemma4",
            name="Gemma 4 Toggle",
            chat_template="{% if enable_thinking %}<|thought|>{% endif %}",
        )
    )
    (inbox / "qwen-think.gguf").write_bytes(
        _build_gguf_bytes(
            arch="qwen3vl",
            name="Qwen3 VL 2B Thinking",
            chat_template="{% for m in messages %}<think>{{ m.content }}</think>{% endfor %}",
        )
    )
    (inbox / "plain-instruct.gguf").write_bytes(
        _build_gguf_bytes(
            arch="llama",
            name="Plain Instruct",
            chat_template="{% for m in messages %}{{ m.content }}{% endfor %}",
        )
    )

    scan = await client.post("/api/v1/models/import/scan", headers=host_admin_headers)
    assert scan.status_code == 200
    by_file = {c["primary_filename"]: c for c in scan.json()["candidates"]}
    assert by_file["gemma4-toggle.gguf"]["reasoning_mode"] == "toggleable"
    assert "reasoning" in by_file["gemma4-toggle.gguf"]["detected_capabilities"]
    assert by_file["qwen-think.gguf"]["reasoning_mode"] == "always_on"
    assert "reasoning" in by_file["qwen-think.gguf"]["detected_capabilities"]
    assert by_file["plain-instruct.gguf"]["reasoning_mode"] == "unsupported"
    assert "reasoning" not in by_file["plain-instruct.gguf"]["detected_capabilities"]

    with patch.object(llm_manager, "refresh_auto_provider_if_idle", return_value=False):
        install_t = await client.post(
            "/api/v1/models/import/install",
            json={"relative_path": "gemma4-toggle.gguf", "model_id": "gemma4-toggle-installed"},
            headers=host_admin_headers,
        )
    assert install_t.status_code == 200
    reg_json = json.loads(settings.INSTALLED_REGISTRY_PATH.read_text(encoding="utf-8"))
    installed_raw = next(m for m in reg_json["models"] if m["id"] == "gemma4-toggle-installed")
    assert installed_raw["reasoning_mode"] == "toggleable"
    assert "reasoning" in installed_raw["capabilities"]

    from app.services.model_registry import build_model_list
    installed_entry = next(m for m in build_model_list() if m.manifest.id == "gemma4-toggle-installed")
    assert installed_entry.manifest.reasoning_mode.value == "toggleable"
    assert any(c.value == "reasoning" for c in installed_entry.manifest.capabilities)


def test_autostart_windowed_token_readback_and_timeout_handling(monkeypatch, tmp_path):
    """Blocking 1 regression: '--autostart-windowed' must read back minimized_to_tray=False; timeouts handled cleanly."""
    import subprocess
    import sys
    from app.services.autostart import AutostartConfigurationError, WindowsAutostartService

    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "AutostartWindowedData"))
    exe = tmp_path / "ai_companion_desktop.exe"
    exe.write_bytes(b"MZ")

    svc = WindowsAutostartService()
    saved_xml: dict[str, str] = {}

    def _fake_schtasks(cmd, **kwargs):
        if "/Create" in cmd and "/XML" in cmd:
            xml_path = Path(cmd[cmd.index("/XML") + 1])
            saved_xml["content"] = xml_path.read_text(encoding="utf-16")
            return MagicMock(returncode=0, stdout="", stderr="")
        if "/Query" in cmd:
            return MagicMock(returncode=0, stdout=saved_xml["content"], stderr="")
        return MagicMock(returncode=0, stdout="", stderr="")

    with patch("app.services.autostart.subprocess.run", side_effect=_fake_schtasks), \
         patch.object(sys, "platform", "win32"):
        enabled = svc.set_enabled(
            True,
            minimized_to_tray=False,
            executable_path=str(exe),
            working_directory=str(tmp_path),
        )
        assert enabled.minimized_to_tray is False
        assert "--autostart-windowed" in saved_xml["content"]
        queried = svc.get_status()
        assert queried.task_registered is True
        assert queried.minimized_to_tray is False

    # subprocess.TimeoutExpired must fail gracefully (status detail on get, AutostartConfigurationError on set)
    with patch("app.services.autostart.subprocess.run", side_effect=subprocess.TimeoutExpired("schtasks", 15)), \
         patch.object(sys, "platform", "win32"):
        q_timeout = svc.get_status()
        assert q_timeout.task_registered is False
        assert "timed out" in q_timeout.status_detail.lower()
        with pytest.raises(AutostartConfigurationError):
            svc.set_enabled(True, executable_path=str(exe), working_directory=str(tmp_path))


@pytest.mark.asyncio
async def test_d6_install_atomicity_extension_and_delete_transitional_guards(
    client, host_admin_headers, monkeypatch, tmp_path
):
    """Verify .gguf suffix enforcement, post-registry inbox unlink atomicity, family regex & delete 409 guards."""
    from app.services.model_import import _extract_family_signature

    assert _extract_family_signature("mmproj_gemma4_f16.gguf") == "gemma4"

    monkeypatch.setenv("COMPANION_DATA_ROOT", str(tmp_path / "AtomicityData"))
    inbox = settings.IMPORT_INBOX_DIR
    inbox.mkdir(parents=True, exist_ok=True)

    valid_bytes = _build_gguf_bytes(arch="llama", name="SafeModel", context_length=4096)
    (inbox / "fake.safetensors").write_bytes(valid_bytes)
    bad_ext = await client.post(
        "/api/v1/models/import/install",
        json={"relative_path": "fake.safetensors", "model_id": "bad-ext-model"},
        headers=host_admin_headers,
    )
    assert bad_ext.status_code == 400

    src_gguf = inbox / "atomic-model.gguf"
    src_gguf.write_bytes(valid_bytes)
    with patch("app.services.model_import._write_installed_registry_atomic", side_effect=OSError("disk full")):
        with pytest.raises(OSError):
            await client.post(
                "/api/v1/models/import/install",
                json={
                    "relative_path": "atomic-model.gguf",
                    "model_id": "atomic-model",
                    "transfer_mode": "move",
                },
                headers=host_admin_headers,
            )
    # Inbox source must still exist and orphaned target dir must have been rolled back
    assert src_gguf.is_file()
    assert not (settings.MODEL_LIBRARY_DIR / "atomic-model").exists()

    # Complete clean install then test transitional MODEL_LOADING & locked-file OSError -> 409 on delete
    with patch.object(llm_manager, "refresh_auto_provider_if_idle", return_value=False):
        ok_inst = await client.post(
            "/api/v1/models/import/install",
            json={
                "relative_path": "atomic-model.gguf",
                "model_id": "atomic-model",
                "transfer_mode": "move",
            },
            headers=host_admin_headers,
        )
    assert ok_inst.status_code == 200
    assert not src_gguf.exists()

    orig = llm_manager._provider
    try:
        loading_mock = MagicMock()
        loading_mock.has_active_generation = False
        loading_mock.is_loaded.return_value = False
        loading_mock._runtime_state = LLMRuntimeState.MODEL_LOADING
        llm_manager.set_provider(loading_mock)
        busy_del = await client.delete("/api/v1/models/registry/atomic-model", headers=host_admin_headers)
        assert busy_del.status_code == 409

        idle_mock = MagicMock()
        idle_mock.has_active_generation = False
        idle_mock.is_loaded.return_value = False
        idle_mock._runtime_state = LLMRuntimeState.MODEL_UNLOADED
        llm_manager.set_provider(idle_mock)
        with patch("app.services.model_import.shutil.rmtree", side_effect=PermissionError("locked by handle")):
            lock_del = await client.delete("/api/v1/models/registry/atomic-model", headers=host_admin_headers)
        assert lock_del.status_code == 409
    finally:
        llm_manager.set_provider(orig)


def test_context_resolution_and_assessment_consistent_on_small_models():
    """Major 2 regression: resolve_context_size_for_mode() & assess_context_options() agree on <= 4K models."""
    from app.services.model_registry import assess_context_options, resolve_context_size_for_mode

    gb = 1024 ** 3
    # 4096-max model in maximum (default 8192) clamps profile context down to 4096
    assert resolve_context_size_for_mode(8192, "profile", 4096) == 4096
    opts_4k = {
        o.mode: o
        for o in assess_context_options(
            int(1.0 * gb),
            profile="maximum",
            model_max_context=4096,
            dedicated_vram_gb=16.0,
            total_ram_gb=32.0,
        )
    }
    assert opts_4k["profile"].context_tokens == 4096
    assert opts_4k["model_max"].context_tokens == 4096
    assert resolve_context_size_for_mode(8192, "model_max", 4096) == 4096

    # 2048-max model keeps model_max at 2048 (not forced up to 4096 with exceeds_model_max=True)
    assert resolve_context_size_for_mode(4096, "model_max", 2048) == 2048
    assert resolve_context_size_for_mode(4096, "8k", 2048) == 2048
    opts_2k = {
        o.mode: o
        for o in assess_context_options(
            int(1.0 * gb),
            profile="balanced",
            model_max_context=2048,
            dedicated_vram_gb=16.0,
            total_ram_gb=32.0,
        )
    }
    assert opts_2k["model_max"].context_tokens == 2048
    assert opts_2k["model_max"].exceeds_model_max is False
    assert opts_2k["model_max"].selectable is True
