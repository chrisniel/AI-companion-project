# Active Branch Tracking

- `task.md` on `develop`/`master` is shared milestone/integration tracking only.
- Ordinary short-lived branches use `active/task-[branch-slug].md`.
- Branch slug replaces `/` with `-`.
- Branch active tasks own transient execution wording: planning, implementation, review, verification, blockers, pending checks.
- Shared `task.md` must not become a mirror of temporary PR state.
- Completed branch tasks are archived on the same branch before integration.
- Archive records are historical evidence and may truthfully record "PR integration pending at the time" without becoming stale later.
