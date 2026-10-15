# Python 3.11 Stream Cancellation Correction

> **Branch:** `codex/fix-stream-cancellation`
> **Scope:** Surgical correction of the backend failure in develop CI run `38767676191` at `5cb2fe6`.
> **Authorization:** Chris authorized investigation, a new branch, correction and non-destructive Git operations, including commit/push. No merge is included.

## Evidence and Plan

- The merged tree matched green PR #27 head `1c38530` exactly. Post-merge Flutter passed; backend had 599 passes and one cancellation failure. The preceding develop run failed Flutter, not backend.
- Python 3.11.9 `asyncio.wait_for` can return an already-ready token instead of propagating simultaneous consumer cancellation. Batch B introduced the affected authority-polling wrapper; the older timing-based test exposed this intermittently. See [CPython issue 86296](https://github.com/python/cpython/issues/86296).
- Replace only the token polling primitive with `asyncio.wait`; retain the 250 ms authority poll, pre-yield validation, pending-task cleanup, provider closure, cancelled-message persistence and conversation-lock release.
- Make cancellation regressions deterministic at consumer suspension, blocked provider and simultaneous token completion. No API, schema, architecture, dependency or CI-gate change.

## Verification

- Focused orchestrator and Profile authorization suites: **80 passed** on both Python 3.13.14 and Python 3.11.9.
- Chris approved an isolated Python 3.11.9 environment under ignored `runtime/ci-cancellation/`. Hash-locked installation and verification confirmed **39 distributions**; `pip check` passed. System installations, existing environments and dependency lockfiles were unchanged.
- Exact Python 3.11.9 regression proof: the original polling function from `5cb2fe6` produced **1 failed / 2 passed**; token-ready cancellation failed with the hosted error. The corrected implementation passed all three cancellation cases. Disposable reproduction harnesses did not alter tracked source or real configuration/data.
- Full backend suite on both Python 3.13.14 and Python 3.11.9: **602 passed, 1 existing deprecation warning** each. Command: `<python> -B -m pytest backend/tests -q -p no:cacheprovider -o log_file=NUL`; interpreters were `backend/.venv/Scripts/python.exe` and `runtime/ci-cancellation/qualification311/Scripts/python.exe` respectively.
- Independent AI static review reported no actionable findings; it is advisory, not human gate approval.
- `git diff --check` passed. Hosted verification remains pending at this publication checkpoint.

## Delivery Boundary

Commit/push only this correction after verification. Independent human review and merge remain pending; do not modify or close the wider M2 delivery.
