# Implementation Plan: Pre-M1 Audit Corrections

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Previous source corrections independently reviewed per Chris at `4e934ab058b2ad6043f50c94cd06dd70bbd9c24e`; safe setup correction AUTHORED / documentation review pending. F04 OPEN; dependency reproducibility, Python 3.11 and hosted qualification unresolved.
- Scope Mode: Surgical Fix — supplied audit disposition B1–B6, not M1.
- Planning basis: Chris's supplied F01–F13 disposition and B1–B6 corrective plan.
- Approval: Chris authorized B1 and B2; F09 independent safety review passed at `61766939e7eb529537519bae6f9a4dc04006ae98`. B2 independent source-level review passed at `8dfd9df9822e4f80fbd1e089bf63b465ec47f947`. Chris subsequently authorized consolidated remaining authoring and the explicit policies below; no Git/installation/M1 authority.
- Execution/evidence owner: [branch tracker](../../01_Tracking/active/task-fix-pre-m1-audit-corrections.md).
- Final bounded authorization: correct existing setup/verification guides and prepare target qualification; no installation/network approval, Git mutations, system-Python changes, existing-environment writes or M1. Preserve the supplied plan and all source corrections.

## 1. Request Understanding & Goals

Persist the supplied delivery scope once, without a competing plan. Establish safe
verification bootstrap and reproducible toolchain inputs in B1. The F09 isolation
checkpoint passed independent review. Chris subsequently authorized B2 authoring
and safe Python 3.13 local regressions while F04/F12 qualification remains open.
Chris's consolidated instruction subsequently approved B3/B4/B6 policies and B5
corrections without approving independent delivery gates. It preserves the supplied
plan and finding IDs; this record does not introduce a replacement plan.

| Batch | Findings | Supplied scope | Authorization |
| --- | --- | --- | --- |
| B1 | F09, F04, F12 | Import/collection isolation; Python 3.11 dependency qualification; compatible Node inputs | Declaration alignment and installed-tool verification authorized; new installation/resolution not authorized |
| B2 | F01, F02, F07 | Error terminals; provider-owned active work; logging across startup migrations | Independent source-level review passed; qualified integration pending |
| B3 | F05 | Task omission/null semantics and generated contract | Independent source review supplied at consolidated checkpoint; target qualification pending |
| B4 | F03 | Cumulative integration coverage invariant | Approved policy preserved; independent source review supplied; hosted execution pending |
| B5 | F10, F11, F13 | Closest-owner documentation reconciliation and resulting setup guidance | Bounded owner edits authorized; independent documentation review pending |
| B6 | F06, F08 | Retention CLI lifecycle; existing-locator integrity | Approved policies preserved; independent source review supplied; target qualification pending |

## 2. Supplied Findings & Technical Root Cause

F09 at audit: configuration initialized/persisted a token during import, before fixture-level
isolation. F04: declared inputs are open-ended; existing local environments are not
an approved dependency set. F12: generic Node 22 documentation omits the committed
dependency engine minimum. Python 3.13 observations do not prove incompatibility.

## 3. B1 File Allowlist & Invariants

- `backend/app/core/config.py`, `backend/tests/conftest.py`.
- `backend/requirements.txt`, `backend/pyproject.toml`.
- `frontend/web/package.json`, `frontend/web/package-lock.json`.
- `.github/workflows/ci.yml`: interpreter/dependency inputs only, no F03 routing/cancellation.
- Potential additions: `backend/tests/test_import_isolation.py`, `backend/requirements.lock`.
- Governance records: this supplied-scope plan and the designated branch tracker,
  expressly authorized by Chris where required by the delivery workflow.

Preserve AGENTS.md and all existing environments, real authentication files and
user data. No Git mutations, system interpreter replacement, real-model runtime,
OpenAPI regeneration to conceal drift, unrelated upgrades, or M1 implementation.
Root governance hardening was independently reviewed and fresh-session Gemini
canary-tested; Chris intentionally published AGENTS.md in checkpoint
`61766939e7eb529537519bae6f9a4dc04006ae98`. The previous commit-exclusion constraint
is superseded by this publication truth. Codex must not modify AGENTS.md during
the consolidated corrections either.

## 4. Supplied Execution Sequence and Subsequent Authorization

The numbered sequence below records the historical B1 authorization. Chris later
approved B2 and then one consolidated authoring run in this order: B3 → B4 → B6 →
remaining B1 → B5 → final scoped verification. No automatic M1 or delivery closure.

1. Verify branch/baseline and user changes; safely reproduce F09 before source edits.
2. Make configuration import non-persisting; select disposable configuration and
   synthetic authentication/storage before test application imports.
3. Prove actual import and collection isolation; submit evidence for independent
   review and STOP before broad application-suite execution.
4. Inspect tool metadata without application settings; consolidate exact installation
   approval only after an interpreter/resolver choice can be established.
5. After safety and environment approvals, resolve declared inputs in a new isolated
   environment and qualify actual imports/tests/OpenAPI and web tests/typecheck/build.
6. Stop at B1 review; never advance automatically to B2.

Chris's later B2 instruction explicitly permits authoring after the PASSED F09
checkpoint, without declaring B1 toolchain qualification complete. Its source/test
allowlist and invariants govern this batch. Evidence is recorded only in the
existing branch tracker. Chris approved extending the B2 test allowlist only to
`backend/tests/test_attachment_binding.py` and `backend/tests/test_llama_translator.py`
to migrate obsolete private-state assertions to public status/count checks. Initial
focused evidence was 80 passed; the final boundary regression file was 26 passed;
the broader checkpoint after the assertion migration was 362 passed. The final
broader suite passed all 364 tests under Python 3.13.14; F09 rerun passed all four
checks with guarded collection of 364 items. These are historical B2 results;
Chris subsequently supplied independent source-level approval and B3–B6 execution
authority. Do not infer Python 3.11/integration qualification or final closure.

### Approved Remaining Policies and File Boundaries

- **B3 / F05:** Omitted fields preserve values; explicit null is rejected for title,
  category, status and priority before mutation. Nullable fields may clear. Explicit
  reminder_at wins; otherwise changed derivation inputs recompute or clear, while
  unrelated updates preserve reminders. Only Task schema/endpoint, Task tests and
  the generated OpenAPI contract are authorized; no scheduler or provenance schema.
- **B4 / F03:** All existing lanes run on every develop push, master event and
  dispatch. Develop PRs retain path scopes; classifier failure or skipped required
  jobs fail the gate. Only ci.yml, ci_policy.py and its tests; no new Flutter lane.
- **B6 / F06:** Standalone retention owns initialization/disposal and requires an
  already prepared compatible schema without migrations. Caller sessions remain
  caller-owned. Only retention.py and its entrypoint/lifecycle tests.
- **B6 / F08:** Missing locator permits first-install default; invalid existing
  locator fails closed. Overrides and valid absolute targets remain supported.
  Only storage.py and bootstrap/lifecycle tests; no recovery UI or repair workflow.
- **B1 / F04/F12:** Align existing declarations and compatible Node engines without
  unrelated version changes or lock regeneration. No manufactured Python lock.
  Hosted Windows Python 3.11 and Node 22.22.2 qualification follows human publication.
- **B5 / F10/F11/F13:** Correct only Decision Debt, Android/conversation domain
  owners, subsystem READMEs, DEVELOPMENT_SETUP and TESTING_AND_CI. Preserve accepted
  Flutter/runtime ownership, Conditional Mobile V1 Health Connect and target tense.
- Evidence remains in this plan and the existing branch tracker. No new tracker,
  branch, PR, architecture, excluded-document sweep or master WBS expansion.

## 5. Acceptance & Verification

Actual-module subprocess regressions must reject real auth/data access, show import
does not create credentials, preserve valid synthetic credentials, and constrain
explicit credential persistence to supplied disposable configuration. Collection
must establish isolation before application imports. Narrow diagnostics under an
existing Python are not Python 3.11 qualification. Record commands/results in the
branch tracker; no self-approval or hosted-CI claims.

## 6. Risks & Recovery

Failing reproductions must deny real local-state access before importing the faulty
module. Existing environment/configuration changes are prohibited. Missing Python
3.11 or unresolved installation choices are blockers, not permission to substitute
an interpreter, freeze a local environment, or attempt speculative installation.

## 7. Final Qualification Authorization and Blocker

Chris's final instruction narrows remaining work to safe setup examples and F04.
The refreshed inventory did not locate Windows CPython 3.11. Documentation now
checks the interpreter before creating a unique temporary environment and uses
its explicit executable throughout; backend/.venv is never an output target.
Only the existing setup/testing guides and these evidence records changed.

F04 stays OPEN until a human-supplied interpreter identity and consolidated
installation/network permission allow two fresh target environments. Proposed
resolver: verified pip 26.1.2; resolve native Windows x64/CPython 3.11 wheel closure
from approved declarations, derive pins/SHA256 from downloaded metadata/bytes,
and prove a clean offline hash-checked install. Preserve extras and target conditions;
do not copy the Python 3.13 environment or change CI to an unverified input.
Detailed evidence and permission boundaries remain in the existing branch tracker.

Source review, new documentation review, Python 3.11 test qualification, verified
dependency input, candidate PR CI and post-merge develop CI remain separate gates.
No independent documentation/closure gate is self-approved; no tracker archiving,
PR creation, Git write, system install, unrelated correction or M1 follows this task.
