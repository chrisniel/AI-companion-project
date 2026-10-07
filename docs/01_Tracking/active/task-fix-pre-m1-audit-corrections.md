# Branch Task: Pre-M1 Audit Corrections

- Branch: `fix/pre-m1-audit-corrections` (human-prepared).
- Audit/branch checkpoint: `28c43320c54cd3333ad2f7b3f842a7a6c1db3f75`.
- Plan: [supplied-scope record](../../02_Planning/01_Plans/plan-pre-m1-audit-corrections.md).
- Current authorization: B1 source/test corrections only; no Git mutations.
- Pre-existing change: root `AGENTS.md`; preserve unchanged and exclude from delivery commit.
- Current stage: STOPPED at F09 isolation review checkpoint; mechanical evidence available.

## Finding / Batch Evidence Record

| Batch | Findings | Execution / evidence state |
| --- | --- | --- |
| B1 | F09 | 4 focused regressions passed; 335 tests safely collected; independent review NOT PASSED |
| B1 | F04 | BLOCKED: approved Python 3.11 identity/path unavailable; no dependency input changed |
| B1 | F12 | Node 24.18.0 compatible with committed engines; input edits/web qualification pending |
| B2 | F01, F02, F07 | Pending execution authorization; no corrections performed |
| B3 | F05 | Pending execution / Task-semantics approval |
| B4 | F03 | Pending execution / cumulative CI-policy approval |
| B5 | F10, F11, F13 | Pending execution; closest-owner reconciliation only |
| B6 | F06, F08 | Pending execution / retention and locator policies |

## Checkpoints & Boundaries

- [x] Branch / HEAD matched; no staged work or unexpected source changes at preflight.
- [x] F09 safely failed against actual module boundaries before implementation.
- [x] Focused F09 import/collection regressions passed mechanically.
- [ ] Chris + independent reviewer approved the isolation checkpoint.
- [ ] Exact environment/resolver/install operations approved where required.
- [ ] Windows Python 3.11 backend/OpenAPI qualification executed.
- [ ] Approved Node web tests/typecheck/build executed.
- [ ] B1 implementation independently approved; documentation/closure gates pending.

## Command Evidence

Preflight: branch `fix/pre-m1-audit-corrections`; HEAD equals audit checkpoint;
`git status --short` showed only ` M AGENTS.md`; cached diff empty.

Focused command (cwd `backend`):
`& ./.venv/Scripts/python.exe -I -B tests/test_import_isolation.py -v`
- Interpreter: existing Windows backend environment, Python 3.13.14; NOT Python 3.11 qualification.
- Original RED: exit 1, 4 failures; guards denied real auth access and detected late collection isolation.
- Disposable-config-only RED: exit 1, 3 failures; actual import still generated credentials;
  valid synthetic credential case passed. No real authentication contents were read.
- Interim GREEN attempt: exit 1, 1 harness failure; pytest default log sink was denied.
  Logging output was explicitly routed inside the disposable sandbox; guards/assertions retained.
- Final GREEN: exit 0, 4 tests passed; actual backend collection returned 0, 335 items.
- Tests exercised actual configuration imports and explicit token initialization;
  actual application lifespan/startup was NOT executed. Existing lifespan call remains at main.py:163.
- Collection established synthetic configuration/auth/storage before config import,
  retained an uninitialized DB runtime and restored caller environment afterward.

Metadata: registered/PATH Python 3.13.14 only; root/backend environments preserved.
Available resolver: backend pip 26.1.2, Requires-Python >=3.10; no resolver installation performed.
Available Node: `D:\Applications\NodeJs\node.exe` 24.18.0, npm 11.18.0; committed
jsdom engine accepts it and sets the Node 22 floor at 22.22.2. Node 22 was not qualified.
Proposed dependency input: hashed transitive requirements for Windows x64 / CPython
3.11, runtime + test dependencies, derived from declarations in a separate approved
environment. No lock was fabricated from the local 3.13 environments.

No runtime, installation, network package resolution, migrations, broad suites,
OpenAPI regeneration or Git mutations executed. Installation request awaits the
exact approved Python 3.11 version/path/provenance; no speculative commands attempted.
Scoped `git diff --check` (config/conftest): exit 0; new-file whitespace check: exit 0.
Unscoped `git diff --check`: exit 1, solely pre-existing AGENTS.md:227 blank EOF line;
left unchanged. Owned tracked diff: 46 insertions / 5 deletions; three added files.

STOP at F09 safety review or B1 completion review. No automatic B2 progression,
no master-tracker/debt expansion, no M1 readiness or hosted-CI claims.
