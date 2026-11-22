# Archived Branch Task: M2 Batch E — Storage Roots, Relocatable Library, D6 Model Import, Model Management UI & Windows Autostart

- **Branch:** `feature/m2-models-storage-autostart-e`
- **Plan:** [`plan-m2-models-storage-autostart-e.md`](../../02_Planning/01_Plans/plan-m2-models-storage-autostart-e.md)
- **Walkthrough:** [`walkthrough-m2-models-storage-autostart-e.md`](../../03_Walkthroughs/walkthrough-m2-models-storage-autostart-e.md)
- **Delivery Level:** Level C — Sensitive Design
- **Closure Status:** Phase 2 & Phase 3 Complete Locally — Archived on Same Branch Before Draft PR & Phase 4 Independent Review

## Checklist

- [x] Verify clean `develop` baseline (`99e34e5`) and create branch `feature/m2-models-storage-autostart-e`
- [x] Author Level C implementation plan (`plan-m2-models-storage-autostart-e.md`) and publish initial Phase 1 commit (`047d223`)
- [x] Fold Phase 1 Independent Plan Review findings (4 blocking fixes + minor notes) and deep related-file audit refinements (`ce08a41`, `3a03320`) into `plan-m2-models-storage-autostart-e.md`
- [x] Pass Phase 1 Independent Plan Review and obtain Human Owner Phase 1 Plan Gate approval
- [x] Phase 2 Slice 1: Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`, `storage.py`, `config.py`, `/system/storage*`)
- [x] Phase 2 Slice 2: Decision D6 Controlled Model Import & Schema v3 Registry (`PC-MODEL-001`..`006`, `model_import.py`, `model_registry.py`, `_skip_gguf_array` + `_GGUF_METADATA_CACHE`, `/models/import/*`, `DELETE /models/registry/{id}`)
- [x] Phase 2 Slice 3: Windows Task Scheduler Autostart (`PC-HOST-002`, `autostart.py`, `/system/autostart`, `--minimized-to-tray` in Win32 + `main.dart`)
- [x] Phase 2 Slice 4: OpenAPI 3.1 (`86` routes) + `companion_api` parity (`98/98` schemas, `111/111` routes) + Desktop Settings UI (`PC-CLIENT-010`, Runtime/Storage/General sections)
- [x] Phase 2 Slice 5 (Live Windows QA Remediation & Consumer UX Polish): `autostart.py` `<UserId>` + `CompanionClient` nested error unwrapping, Win32 `hardware_probe.py` real GPU VRAM/RAM + dynamic profile recommendations, experimental `>8K` `context_mode` (`"profile"`/`"16k"`/`"model_max"`), multi-format inbox safety/engine warnings + `transfer_mode`, zero-plugin `WindowsShellChannel` (`pickFolder`/`pickFiles`) + `DesktopShellAdapter` (auto-creating `Open Inbox Folder` & async `stageFilesToInbox`), consumer-first Settings Storage/Runtime redesign with `storageRevision` sync & responsive overflow fix
- [x] Phase 2 Slice 6 (Startup Maximize, UTF-16 XML, Smart CTX Dropdown Guardrails, Multi-`mmproj` Header Matching & Reasoning Detection): Win32 `flutter_window.cpp` first-frame `SW_SHOWMAXIMIZED` preservation + `DesktopLifecycleCoordinator` deferred maximize on tray restore; `autostart.py` UTF-16LE BOM `<?xml version="1.0" encoding="UTF-16"?>` + `get_status()` XML encoding normalization; unified `context_mode` dropdown (`"profile"`/`"2k"`/`"4k"`/`"8k"`/`"16k"`/`"32k"`/`"model_max"`) backed by `assess_context_options()` VRAM/RAM guardrails, opt-in **Allow unsafe experimental CTX** switch (`exceeds_model_max` strictly blocked), & **Reset to Auto (Profile Default)** warning banner; header-verified multi-`mmproj` scoring (`score_mmproj_compatibility()`, `is_vision_capable_primary()`, override dropdown, `Attach mmproj...`, HTTP 400 mismatch guard); automatic `tokenizer.chat_template`/name reasoning detection (`toggleable` / `always_on` / `unsupported`) & OpenAPI/Dart parity (`928` backend pytest + `4` subtests, `100/100` schemas / `111/111` native routes, `24` `companion_core`, `115` `companion_api`, `437` Flutter Desktop, `13.4s` MSVC debug build)
- [x] Phase 3: Canonical doc sync (`storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `DECISION_DEBT.md`, `task.md`), `CHANGELOG.md`, `walkthrough-m2-models-storage-autostart-e.md`, & archive branch tracker on same branch
- [ ] Phase 4: Combined Independent Review, manual Windows host QA (`Settings` native folder picker & storage relocation / real `.gguf`+multi-`mmproj` D6 install & reasoning badges / smart CTX dropdown & unsafe toggle / `schtasks` UTF-16LE XML + flash-free tray & maximized startup), hosted CI green, & Human Owner squash merge into `develop`
