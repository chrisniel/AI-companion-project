# Archived Branch Task: M5 Batch A — Fast-Boot, ISO/TTS Polish & Low-Impact Resource Governance

- **Branch:** `feature/m5-resource-governance-a`
- **Plan:** [`plan-m5-resource-governance-a.md`](../../02_Planning/01_Plans/plan-m5-resource-governance-a.md)
- **Walkthrough:** [`walkthrough-m5-resource-governance-a.md`](../../03_Walkthroughs/walkthrough-m5-resource-governance-a.md)
- **Delivery Level:** Level C — Sensitive Design
- **Closure Checkpoint:** Phase 3 documentation sync & Draft PR closure prepared (pending Phase 4 Independent Review, manual Windows host QA, and Human Owner squash merge)

## Checklist

- [x] Verify clean `develop` baseline (`9e76f72`) and create branch `feature/m5-resource-governance-a`
- [x] Save approved 3-stage roadmap & M2 Batch E milestone note in Synapse
- [x] Author unified M5 implementation plan & Batch A spec (`plan-m5-resource-governance-a.md`)
- [x] Fold Phase 1 Independent Plan Review findings (4 Blocking + Major/Minor adjustments) into `plan-m5-resource-governance-a.md`
- [x] Complete Phase 1 Independent Plan Reviewer sign-off (`APPROVED`)
- [x] Publish Phase 1 plan & second-pass clarifications to `origin/feature/m5-resource-governance-a`
- [x] Obtain Human Plan Approval before starting Phase 2 implementation
- [x] Phase 2 Slice A1: Fast-Boot Startup Optimization (Win32 C++ `WindowsShellChannel` + `DesktopProcessInspector`, `350ms` loopback probe vs `2s` health, schema fast-path, post-yield cancellable sweeps)
- [x] Phase 2 Slice A2: ISO-8601 Timestamp Localization, Bold+Em-Dash Markdown & Kokoro TTS Polish
- [x] Phase 2 Slice A3: Host Resource Governance & Gaming Mode Engine (`PC-RESOURCE-001`..`004`, `DEBT-V1-07`, `GET`/`PUT /api/v1/system/resources`)
- [x] Phase 2 Slice A4: OpenAPI 3.1 (`87` paths / `119` routes), `companion_api` DTO parity (`102` schemas / `113` native routes) & parity unittest
- [x] Phase 2 Slice A5: Desktop `Settings -> Performance & Gaming` UI & synchronized System Tray quick controls
- [x] Phase 2 Automated Verification (`939` pytest in `295.53s`, `11/11` isolated `unittest` in `4.320s`, OpenAPI `87` routes, `102/102` schemas & `113/113` routes, `8/8` parity unittest in `0.271s`, `0` Dart analyzer issues, `24` `companion_core`, `117` `companion_api`, `455` Desktop tests in `02:37`, Windows MSVC `/W4 /WX` Debug build in `12.0s`, `git diff --check develop`)
- [x] Phase 3: Canonical doc sync, `CHANGELOG.md`, `walkthrough-m5-resource-governance-a.md`, branch tracker archival, commit, push & Draft PR
- [ ] Phase 4: Combined Independent Review, manual Windows host QA, hosted CI green, & Human Owner squash merge
