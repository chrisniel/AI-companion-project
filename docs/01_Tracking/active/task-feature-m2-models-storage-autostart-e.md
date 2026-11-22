# Active Branch Task: M2 Batch E — Storage Roots, Relocatable Library, D6 Model Import, Model Management UI & Windows Autostart

- **Branch:** `feature/m2-models-storage-autostart-e`
- **Plan:** [`plan-m2-models-storage-autostart-e.md`](../../02_Planning/01_Plans/plan-m2-models-storage-autostart-e.md)
- **Delivery Level:** Level C — Sensitive Design
- **Current Phase:** Phase 1 — Plan Published & Under Independent Review (Awaiting Human Plan Approval)

## Checklist

- [x] Verify clean `develop` baseline (`99e34e5`) and create branch `feature/m2-models-storage-autostart-e`
- [x] Author Level C implementation plan (`plan-m2-models-storage-autostart-e.md`) and publish initial Phase 1 commit (`047d223`)
- [x] Fold Phase 1 Independent Plan Review findings (4 blocking fixes + minor notes) into `plan-m2-models-storage-autostart-e.md` for final Phase 1 Plan Gate re-verification
- [ ] Pass Phase 1 Independent Plan Review and obtain Human Owner Phase 1 Plan Gate approval
- [ ] Phase 2 Slice 1: Five Storage Roots & Relocatable `LIBRARY_ROOT` (`PC-HOST-004`, `storage.py`, `config.py`, `/system/storage*`)
- [ ] Phase 2 Slice 2: Decision D6 Controlled Model Import & Schema v3 Registry (`PC-MODEL-001`..`006`, `model_import.py`, `model_registry.py`, `/models/import/*`, `DELETE /models/registry/{id}`)
- [ ] Phase 2 Slice 3: Windows Task Scheduler Autostart (`PC-HOST-002`, `autostart.py`, `/system/autostart`, `--minimized-to-tray` in `main.dart`)
- [ ] Phase 2 Slice 4: OpenAPI 3.1 + `companion_api` parity + Desktop Settings UI (`PC-CLIENT-010`, Runtime/Storage/General sections) + full automated verification gate
- [ ] Phase 3: Canonical doc sync (`storage-and-assets.md`, `runtime-and-models.md`, `windows-host-and-notifications.md`, `WBS.md`, `MASTER_CHECKLIST.md`, `DELIVERY_INDEX.md`, `SPRINT_ROADMAP.md`, `task.md`), `CHANGELOG.md`, walkthrough, archive branch tracker, push & Draft PR
- [ ] Phase 4: Combined Independent Review, hosted CI green, & Human Owner squash merge into `develop`
