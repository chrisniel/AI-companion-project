# Branch Task: Pre-M1 Audit Corrections

- Branch: `fix/pre-m1-audit-corrections` (human-prepared).
- Audit baseline: `28c43320c54cd3333ad2f7b3f842a7a6c1db3f75`.
- Reviewed B1 publication / B2 starting checkpoint: `61766939e7eb529537519bae6f9a4dc04006ae98`.
- Plan: [supplied-scope record](../../02_Planning/01_Plans/plan-pre-m1-audit-corrections.md).
- Current authorization: B2 F01/F02/F07 source/test corrections; B1 remains PARTIAL for F04/F12 qualification. No Git mutations; no B3 or M1.
- Governance publication: root `AGENTS.md` hardening was independently reviewed, the fresh-session Gemini canary passed, and Chris intentionally published it in the B1 checkpoint above. Codex must not modify it during product corrections.
- Current stage: B2 AUTHORED / AWAITING INDEPENDENT IMPLEMENTATION REVIEW. Available-environment mechanical verification completed; no self-approval.

## Finding / Batch Evidence Record

| Batch | Findings | Execution / evidence state |
| --- | --- | --- |
| B1 | F09 | Independent safety checkpoint PASSED at the published B1 checkpoint; final B2 rerun: 4 passed, 364 tests safely collected |
| B1 | F04 | BLOCKED: approved Python 3.11 identity/path unavailable; no dependency input changed |
| B1 | F12 | Node 24.18.0 compatible with committed engines; input edits/web qualification pending |
| B2 | F01, F02, F07 | AUTHORED / AWAITING INDEPENDENT IMPLEMENTATION REVIEW; initial focused set 80 passed; final boundary file 26 passed; final broader suite 364 passed under Python 3.13; Python 3.11 qualification pending |
| B3 | F05 | Pending execution / Task-semantics approval |
| B4 | F03 | Pending execution / cumulative CI-policy approval |
| B5 | F10, F11, F13 | Pending execution; closest-owner reconciliation only |
| B6 | F06, F08 | Pending execution / retention and locator policies |

## Checkpoints & Boundaries

- [x] Branch / HEAD matched; no staged work or unexpected source changes at preflight.
- [x] F09 safely failed against actual module boundaries before implementation.
- [x] Focused F09 import/collection regressions passed mechanically.
- [x] Chris + independent reviewer approved the F09 isolation checkpoint.
- [ ] Exact environment/resolver/install operations approved where required.
- [ ] Windows Python 3.11 backend/OpenAPI qualification executed.
- [ ] Approved Node web tests/typecheck/build executed.
- [ ] B1 implementation independently approved; documentation/closure gates pending.

## Command Evidence — Historical B1 Authoring Checkpoint

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

## B2 Evidence — Python 3.13 Local Regression Only

B2 preflight: branch `fix/pre-m1-audit-corrections`, HEAD `61766939e7eb529537519bae6f9a4dc04006ae98`;
`git status --short`, `git diff --name-only`, and `git diff --cached --name-only`
were empty. Published AGENTS.md remained unchanged.

F01: actual adapter checks streaming HTTP status, decodes explicit SSE errors,
and rejects malformed/truncated protocol input with safe typed failures. Valid
empty completion remains successful. Both streaming callers close their provider
iterator and emit no successful terminal after failure. Actual assistant persistence
retains partial content with failed status. A real request-session commit failure
also preserves a failed terminal through the dedicated recovery session, with no
successful done. Direct completion errors use fixed text.

F02: provider-owned per-operation leases replace competing Boolean writes. Native
workers release their lease from actual worker completion on the event loop;
awaiting-task cancellation does not cancel that ownership. Lifecycle operations
reject active work. Shutdown closes admission, drains up to 120 seconds (matching
the existing HTTP generation timeout), and retains model/ownership on deadline.
No FIFO, scheduler, daemon, or forced native-worker termination was introduced.
An actual assistant iterator close persists cancelled partial content, releases
only its provider operation, and leaves a concurrent operation busy.

F07: programmatic schema upgrades set `application_owns_logging`; the real Alembic
environment skips `fileConfig` in that mode. Standalone CLI logging remains intact.
Repeated synthetic startup preserves application handlers, enabled logger and
sanitizing formatter. Actual disposable lifespan initializes/preserves the selected
credential and disposes its DB; the startup message exposes neither path nor value.

Commands below used cwd `backend`, existing `.venv` Python 3.13.14, `-B`,
disabled pytest cache and `log_file=NUL`. They are NOT Python 3.11 qualification.

| Command / checkpoint | Exit | Result |
| --- | --- | --- |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_runtime_boundary_regressions.py -q -p no:cacheprovider -o log_file=NUL --tb=short` — initial harness | 1 | 22 failed / 2 passed; assistant assertions included an ORM expiration harness error |
| Same test target with `--tb=line` — corrected harness, before source correction | 1 | 20 failed / 4 passed, reproducing terminal and ownership defects |
| Same test target with `--tb=short` — corrected source | 0 | 24 passed |
| Same test target with `--tb=short` — final regression file | 0 | 26 passed, including commit failure and actual assistant close during overlap |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_security_hardening.py -k 'programmatic_schema or standalone_alembic or disposable_lifespan' -q -p no:cacheprovider -o log_file=NUL --tb=short` — RED then GREEN | 1 / 0 | After allowing only Windows stdlib loopback wake-up socketpair: 2 failed / 1 passed before correction; 3 passed / 10 deselected after correction. Initial guard refinement was a harness issue |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_security_hardening.py -q -p no:cacheprovider -o log_file=NUL --tb=short` | 0 | 13 passed |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_runtime_boundary_regressions.py tests/test_assistant_orchestrator.py tests/test_llm_router.py tests/test_llm_router_lifecycle.py tests/test_security_hardening.py -q -p no:cacheprovider -o log_file=NUL --tb=short` | 0 | 80 passed |
| `& ./.venv/Scripts/python.exe -I -B tests/test_import_isolation.py -v` — three B2 reruns | 0 each | 4 passed each; guarded actual collections returned 0, 362 / 362 / 364 items respectively |
| `& ./.venv/Scripts/python.exe -B -m pytest tests -q -p no:cacheprovider -o log_file=NUL --tb=short` — first broader run | 1 | 359 passed / 3 failed; newly failing private `_generation_active` assertions in two files outside initial B2 allowlist |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_attachment_binding.py tests/test_llama_translator.py -q -p no:cacheprovider -o log_file=NUL --tb=short` — approved assertion migration | 1 / 0 | Interim 40 passed / 1 failed (remaining obsolete assertion); final 41 passed |
| Same broader-suite command — after approved assertion migration | 0 | 362 passed |
| Same broader-suite command — final authored B2 scope | 0 | 364 passed in 51.03 seconds |

Additional static checks (repo cwd): `backend/.venv/Scripts/python.exe --version`
returned Python 3.13.14, exit 0. `backend/.venv/Scripts/python.exe -I -B -c`
using stdlib `ast.parse` on the authored Python source/test files: exit 0,
initial `AST_PARSE_OK 11`, final `AST_PARSE_OK 13 NEW_FILE_WHITESPACE_OK`.
The final check also rejected trailing whitespace in the new boundary regression
file. No application import or bytecode creation. `git diff --check` returned 0;
`git diff -- AGENTS.md` was empty.

Chris approved a bounded test-only extension after the first broader run:
replace obsolete private-state assertions
in `backend/tests/test_attachment_binding.py` and `backend/tests/test_llama_translator.py`
with public active-generation status/count checks. The three failing tests
contained five assertions (the initial request counted failures, not every assertion).
Only those assertions and their directly associated comments/docstrings changed.
No failed assertion was weakened or skipped. Focused read-only local peer checking
found no concrete B2 source defect; this is not the independent human gate.

Final authored scope: six source files, six existing test files, one new boundary
regression file, and the two existing governance evidence records. Core logging
implementation and published AGENTS.md remained unchanged. Proposed Conventional
Commit for Chris: `fix(runtime): harden streaming lifecycle and startup logging`.

STOP at independent implementation review after final mechanical verification. F04/F12,
qualified Python 3.11 integration, hosted CI and delivery closure remain open.
No installation, real-model execution, real authentication/user-data access,
master-tracker/debt expansion, Git mutation, B3 or M1 execution occurred.
