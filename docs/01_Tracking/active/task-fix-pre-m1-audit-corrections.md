# Branch Task: Pre-M1 Audit Corrections

- Branch: `fix/pre-m1-audit-corrections` (human-prepared).
- Audit baseline: `28c43320c54cd3333ad2f7b3f842a7a6c1db3f75`.
- Reviewed B1 publication / B2 starting checkpoint: `61766939e7eb529537519bae6f9a4dc04006ae98`.
- Reviewed B2 publication / consolidated authoring starting checkpoint: `8dfd9df9822e4f80fbd1e089bf63b465ec47f947`.
- Consolidated source-review / final qualification starting checkpoint: `4e934ab058b2ad6043f50c94cd06dd70bbd9c24e` (independent source review supplied by Chris).
- Plan: [supplied-scope record](../../02_Planning/01_Plans/plan-pre-m1-audit-corrections.md).
- Current authorization: final bounded setup correction and F04 qualification preparation. Separate target environments/resolution require the missing interpreter and consolidated human installation/network approval. No Git mutations, system-Python replacement, existing-environment writes, new audit/plan or M1.
- Governance publication: root `AGENTS.md` hardening was independently reviewed, the fresh-session Gemini canary passed, and Chris intentionally published it in the B1 checkpoint above. Codex must not modify it during product corrections.
- Current stage: previous source corrections independently reviewed per Chris; setup correction AUTHORED / independent documentation review pending. F04 OPEN: target interpreter, dependency reproducibility and Python 3.11/hosted qualification remain unresolved. No self-approval or delivery closure.

## Finding / Batch Evidence Record

| Batch | Findings | Execution / evidence state |
| --- | --- | --- |
| B1 | F09 | Independent safety checkpoint PASSED at B1 publication; consolidated rerun: 4 passed, 408 tests safely collected |
| B1 | F04 | OPEN / BLOCKED: reviewed declaration alignment preserved; refreshed inventory still lacks selected local Python 3.11; no target-qualified transitive/hash input or installation/network approval |
| B1 | F12 | Source-reviewed declaration alignment preserved; historical compatible Node 24.18.0 web checks passed; hosted Node 22.22.2 pending |
| B2 | F01, F02, F07 | Independent source-level review PASSED at B2 publication, per Chris; preserved by consolidated regressions; Python 3.11/hosted qualification pending |
| B3 | F05 | Independent source review supplied at consolidated checkpoint; approved semantics and historical HTTP/Pydantic/ORM/contract evidence preserved; target qualification pending |
| B4 | F03 | Independent source review supplied at consolidated checkpoint; cumulative integration policy and historical 21-test evidence preserved; hosted execution pending |
| B5 | F10, F11, F13 | AUTHORED: closest-owner reconciliation and verified setup/CI wording; independent documentation gate pending |
| B6 | F06, F08 | Independent source review supplied at consolidated checkpoint; prepared-schema CLI and locator behavior/regressions preserved; target qualification pending |

## Checkpoints & Boundaries

- [x] Branch / HEAD matched; no staged work or unexpected source changes at preflight.
- [x] F09 safely failed against actual module boundaries before implementation.
- [x] Focused F09 import/collection regressions passed mechanically.
- [x] Chris + independent reviewer approved the F09 isolation checkpoint.
- [ ] Exact environment/resolver/install operations approved where required.
- [ ] Windows Python 3.11 backend/OpenAPI qualification executed.
- [x] Compatible installed Node web tests/typecheck/build executed; no installation.
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

Historical B2 stop: independent implementation review after final mechanical verification. F04/F12,
qualified Python 3.11 integration, hosted CI and delivery closure remain open.
No installation, real-model execution, real authentication/user-data access,
master-tracker/debt expansion, Git mutation, B3 or M1 execution occurred.

## Consolidated Authoring Evidence — B3 / B4 / B6 / Remaining B1 / B5

Starting branch/HEAD matched `fix/pre-m1-audit-corrections` /
`8dfd9df9822e4f80fbd1e089bf63b465ec47f947`. Status, tracked diff and staged diff
were empty. Chris supplied B2 independent source-level approval; hosted/Python
3.11 acceptance remains pending. Published AGENTS.md and B1/B2 fixes were preserved.

- **F05 / B3:** Actual PATCH validation rejects explicit null for required DB fields
  before ORM mutation; omission and nullable clears are distinct. Only supplied
  derivation inputs recompute/clear reminders; explicit reminder_at wins, including
  null. Twenty new HTTP/Pydantic/ORM cases use synthetic in-memory state.
- **F03 / B4:** Every develop push requires backend/frontend/contract/docs, including
  sequential backend then docs-only pushes. Master/dispatch stay full; develop PRs
  retain scopes. Failure of classification or any required lane fails the gate.
  Cancellation is retained; full replacement-tree coverage establishes the invariant.
- **F06 / B6:** Actual module/argparse CLI runs in guarded subprocesses against
  disposable schema/records. It reads schema metadata before initialization,
  requires current Alembic heads and Task columns, never migrates during purge,
  and disposes its owned runtime after success/failure. Existing runtimes and
  caller-owned sessions retain ownership. Expired Tasks across owners are purged;
  recent/active records and unrelated data remain, and owner-filtered calls stay scoped.
- **F08 / B6:** Missing locator alone permits the first-install default. Existing
  malformed/invalid/non-file locators fail closed; overrides retain precedence,
  relative roots remain rejected, and valid absolute nonexistent roots remain valid.
  Actual Settings/database-runtime regression proves corruption initializes no
  alternate database. Two old fallback assertions were replaced with the approved policy.
- **F04 / B1:** `pyproject.toml` now agrees with requirements: SQLAlchemy asyncio
  extra and existing httpx runtime dependency. No version upgrade, frozen local
  environment or manufactured lock. Selected Windows CPython 3.11 and a qualified
  transitive/hash input are still unavailable. Checked PATH/registered interpreters
  and standard locations did not locate 3.11; this is not an incompatibility claim.
- **F12 / B1:** Declared Node engines are `^22.22.2 || ^24.15.0`; npm lock changes
  only root engine metadata. Installed Node 24.18.0/npm 11.18.0 are compatible;
  all 21 direct installed dependencies match the lock, with no installed-lock
  version discrepancy. CI selects Node 22.22.2 and records versions.
- **F10/F11/F13 / B5:** Decision Debt retains the open Flutter native Toast adapter
  choice with Runtime durable scheduling/event ownership. Android owner/README
  reflect Conditional Mobile V1 read-only, consent-driven, hardware-qualified
  Health Connect and Kotlin prototype versus Flutter target. React README is a
  supported web harness; actual persistent attachment history is recorded in its
  conversation owner without claiming Flutter parity. Setup/CI guides reflect
  disposable config, locator/retention policies and evidenced toolchain boundaries.

### Commands and Results

Backend commands used cwd `backend`, existing Windows Python **3.13.14**; they
are local regression evidence, NOT Python 3.11 qualification. No package installed.

| Exact command / checkpoint | Exit | Result |
| --- | --- | --- |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_task_update_contract.py -q -p no:cacheprovider -o log_file=NUL --tb=line` — RED | 1 | 14 failed / 6 passed before source correction |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_tasks.py tests/test_task_update_contract.py -q -p no:cacheprovider -o log_file=NUL --tb=short` | 0 | 29 passed |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_bootstrap.py tests/test_storage_engine_lifecycle.py -q -p no:cacheprovider -o log_file=NUL --tb=line --show-capture=no` — RED | 1 | 15 failed / 17 passed before locator correction |
| Same bootstrap/lifecycle targets with `--tb=short` | 0 | 32 passed |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_retention_entrypoint.py -q -p no:cacheprovider -o log_file=NUL --tb=short` — RED / final GREEN | 1 / 0 | Meaningful RED 8 failed / 1 passed; final 10 passed. Harness corrections allowed only Windows stdlib socketpair and explicitly closed fixture SQLite connections; assertions retained |
| `& ./.venv/Scripts/python.exe -I -B tests/test_import_isolation.py -v` — final | 0 | 4 passed; guarded actual collection returned 0 with 408 items |
| `& ./.venv/Scripts/python.exe -B -m pytest tests/test_runtime_boundary_regressions.py tests/test_security_hardening.py tests/test_tasks.py tests/test_task_update_contract.py tests/test_bootstrap.py tests/test_storage_engine_lifecycle.py tests/test_retention_entrypoint.py -q -p no:cacheprovider -o log_file=NUL --tb=short` | 0 | 110 passed in 16.27 seconds; preserved F01/F02/F07 included |
| `& ./.venv/Scripts/python.exe -B -m pytest tests -q -p no:cacheprovider -o log_file=NUL --tb=short` | 0 | 408 passed in 51.34 seconds |

Repository-root commands:

| Exact command / mechanism | Exit | Result |
| --- | --- | --- |
| `& ./backend/.venv/Scripts/python.exe -B -m unittest scripts/tests/test_ci_policy.py` — RED / GREEN and final recheck | 1 / 0 / 0 | RED five expected develop-policy subtest failures; both GREEN runs 21 passed; negative gate FAIL messages are expected assertions |
| `& ./backend/.venv/Scripts/python.exe --version` | 0 | Python 3.13.14 |
| `& ./backend/.venv/Scripts/python.exe -B -m pip --version` | 0 | pip 26.1.2 |
| `& ./backend/.venv/Scripts/python.exe -B -m pip check` | 0 | No broken requirements found in the existing 3.13 environment |
| `npm --logs-max=0 --update-notifier=false --prefix frontend/web test` | 0 | 229 tests / 12 files passed |
| `npm --logs-max=0 --update-notifier=false --prefix frontend/web run lint` | 0 | TypeScript check passed |
| `npm --logs-max=0 --update-notifier=false --prefix frontend/web run build` | 0 | Vite 6.4.3 build passed; 1,736 modules |
| `& ./backend/.venv/Scripts/python.exe -I -B -c $taskContractCode` — guarded in-memory wrapper invoking `scripts/check_openapi_contract.py --write`, then `--check` through runpy | 0 | Actual approved generator: 23 routes, required model routes present. Pre-write comparison rejected any non-TaskUpdate change; only four required-field null alternatives/defaults changed |
| `& ./backend/.venv/Scripts/python.exe -I -B -c $contractCheckCode` — final wrapper using existing ImportIsolationTests guard and actual generator `--check` | 0 | Contract synchronized; database runtime remained uninitialized; selected disposable config unchanged |
| `& ./backend/.venv/Scripts/python.exe -I -B -c $staticCheckCode` | 0 | 10 Python ASTs, declaration parity, YAML parse, TaskUpdate-only contract/root-engine-only lock comparisons, 7 added local links, allowlist and new-file whitespace checks passed |
| `git diff --check` | 0 | Authored tracked whitespace clean; root AGENTS.md diff empty |

Wrappers ran from PowerShell here-strings and created no helper files. The first
whole-file whitespace harness exited 1 on pre-existing retention.py whitespace;
it was narrowed to new files plus `git diff --check`, leaving unrelated lines intact.
Git reported existing CRLF normalization for generated OpenAPI; no Git config changed.
Vitest emitted a jsdom performance hint, with no failures. Hosted CI was not executed.

### Remaining Qualification and Gates

After human publication, review hosted **Windows Python 3.11** backend and OpenAPI
lanes and **Node 22.22.2** frontend on the actual candidate (PR or full manual dispatch),
then review full develop integration CI separately after merge. Workflow records
interpreter/package versions and pip health, uses disposable auth/storage, and runs
F09 before the application suite. These changes do not supply a transitive/hash lock.
F04 requires an explicitly selected target interpreter/resolver and approved isolated
resolution/install operations before a verified reproducible input can be produced.

Independent implementation review of B3/B4/B6/B1 changes and independent B5
documentation review remain pending. No gate is self-approved, tracker archived,
delivery closed or M1 started. Tests used synthetic credentials, temporary storage,
in-memory databases and isolated inference doubles; CLI/import/collection guards
denied real authentication/databases and external side effects. No real model,
user database/configuration, package install, network resolution or Git mutation.

Proposed Conventional Commit: `fix: complete bounded pre-m1 audit corrections`.

## Final F04 Qualification Preparation — 2026-10-08

Preflight matched branch `fix/pre-m1-audit-corrections` and HEAD
`4e934ab058b2ad6043f50c94cd06dd70bbd9c24e`; working/staged diffs were empty.
Chris reported independent source review of the previously authored corrections.
This does not establish independent documentation closure, dependency reproducibility,
Python 3.11 qualification, candidate PR CI or post-merge develop CI.

Only DEVELOPMENT_SETUP, TESTING_AND_CI and the two existing evidence records changed.
The setup example now verifies Windows x64 CPython 3.11 before allocating a uniquely
named temporary environment outside the repository. It never targets backend/.venv,
does not activate an environment, and uses explicit executable paths for installation,
verification and optional normal development startup. Missing Python stops before
environment creation. Testing guidance retains synthetic config/storage and F09-first
execution. The previous unsafe example could reuse .venv despite its preservation text.

Read-only metadata refresh: PATH, `py -0p`, registered Python and checked standard
locations exposed Windows x64 Python 3.13.14 at `D:\Applications\Python\python.exe`,
with no located 3.11. Existing backend/root environments remain 3.13.14/pip 26.1.2;
global pip is 26.2.1. pip-tools/uv were absent in inspected metadata/PATH. No environment
was changed. The available pip 26.1.2 distribution declares Requires-Python >=3.10.

F04 remains **OPEN**. Smallest proposed solution, pending consolidated approval:
human supplies an existing full CPython 3.11 x64 executable/version/provenance;
use pip 26.1.2 in a separate native-target resolver environment, download only wheels
from approved declarations, and derive pins/hashes from actual wheel METADATA/bytes
while preserving direct extras. Verify offline hash-required installation in a second
clean target environment. Scope covers runtime + test dependency closure for Windows
x64/CPython 3.11; no universal-platform/source-build/model-binary claim. Stop on missing
compatible wheels, declaration mismatch or unrelated OpenAPI drift. No input was
generated, system interpreter installed, existing environment frozen or CI switched.

Planned temporary paths: `%TEMP%\ai-companion-f04-<fresh UUID>\resolver`, `verify`,
`wheelhouse`, and `requirements-win-amd64-cp311.lock`; package access limited to
`https://pypi.org/simple` and HTTPS wheel downloads on `files.pythonhosted.org`.
Resolver installation/download and offline install commands are proposed in the
human handoff, not executed. A repository lock/CI consumption change awaits verified
resolution and installation evidence. Hosted Python 3.11 pass alone is not a lock.

Mechanical checks executed with installed PowerShell only:
- `System.Management.Automation.Language.Parser::ParseInput` on all nine PowerShell
  fences in the two guides: exit 0; no syntax errors. Static guard/order checks rejected
  .venv targeting, activation dependence and bare-Python verification commands.
- Actual setup discovery/probe prefix (stopped before `# 3. Create`): exit 0 for the
  harness, with the expected missing-Python-3.11 throw; no directory/environment created.
- Scoped documentation link/scope checks: exit 0, exactly four allowed files and
  12 local links. `git diff --check`: exit 0; staged and AGENTS.md diffs empty.
- `py -0p`: exit 0, only registered Python 3.13 at the path above. Existing backend
  `python.exe -I -B -c` using only sys/struct/importlib.metadata: exit 0, confirmed
  Python 3.13.14 x64, pip 26.1.2 and its Requires-Python >=3.10. No application import.

No application suite, application import, OpenAPI generator, package/network operation
or hosted CI ran in this documentation-only correction. Historical Python 3.13 results
remain historical evidence. Previous source implementations/manifests/workflow/AGENTS.md
are unchanged. No secrets/user database/model access, Git mutation, M1 or closure.
The branch can receive candidate CI evidence after human publication, but is not
F04-resolved or ready for final integration acceptance. New documentation review pending.
