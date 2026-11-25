# Active Branch Task: M5 Batch B — Coordinated Backup, Quiesced Staged Restore & Factory Reset

- **Branch:** `feature/m5-backup-restore-reset-b`
- **Plan:** [`plan-m5-backup-restore-reset-b.md`](../../02_Planning/01_Plans/plan-m5-backup-restore-reset-b.md)
- **Delivery Level:** Level C — Sensitive Design
- **Phase Status:** Phase 1 — Plan Authored (Pending Phase 1 Independent Plan Review & Human Plan Approval)

## Checklist

- [x] Verify clean `develop` baseline (`a5bf4a9`) and create `feature/m5-backup-restore-reset-b`
- [x] Author Level C Batch B implementation plan (`plan-m5-backup-restore-reset-b.md`)
- [ ] Complete Phase 1 Independent Plan Review and fold any feedback into plan
- [ ] Obtain Human Plan Approval before starting Phase 2 code edits
- [ ] Phase 2 Slice B1: Host-level Maintenance Quiescence Barrier (`DEBT-V1-10`)
- [ ] Phase 2 Slice B2: Coordinated `.zip` DB + Profile-Asset Backup Engine (`PC-RESILIENCE-001`)
- [ ] Phase 2 Slice B3: Staged Restore Verification & Quiesced Live Restore w/ Guards & Rollback (`PC-RESILIENCE-003`)
- [ ] Phase 2 Slice B4: Local Admin Factory Reset Engine (`PC-RESILIENCE-004`)
- [ ] Phase 2 Slice B5: Host-Admin REST Endpoints, OpenAPI/Dart Parity (`PC-API-001`), Win32 `.zip` Picker & Desktop UI (`PC-CLIENT-011`)
- [ ] Phase 2 Full Automated Verification (Backend, Isolation, Parity, Dart Analyze, SDK Tests, Desktop Suite, Windows Build, Diff Check)
- [ ] Phase 3 Canonical Documentation Sync, Walkthrough, Changelog, Branch Closure & Draft PR
- [ ] Phase 4 Combined Independent Review, Manual Windows Host QA, CI Green & Human Owner Squash Merge
