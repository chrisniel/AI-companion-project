# Documentation Map

This map identifies the authoritative role of each documentation area.

## Canonical Sources

- `docs/04_Architecture/AI_COMPANION_MASTER_IMPLEMENTATION_PLAN.md` — canonical product architecture, system boundaries, current status, V1 goals, and implementation sequence.
- `docs/04_Architecture/decisions/` — accepted architectural decisions and their consequences.
- `docs/01_Tracking/task.md` — current execution state, immediate blocker, and next authorized action.
- `docs/02_Planning/plan-*.md` — task-specific implementation proposals and acceptance criteria. A plan does not authorize code changes until the user approves it.
- `README.md` — concise repository overview and entry-point guidance; it must link to deeper canonical documents rather than duplicate them.

## Lifecycle Directories

| Directory | Purpose |
| --- | --- |
| `docs/00_Drafts/` | Non-canonical ideas, old reviews, and source material retained for reference |
| `docs/01_Tracking/` | Active task plus one archive file per completed sprint |
| `docs/02_Planning/` | Focused plans, technical designs, and acceptance criteria |
| `docs/03_Walkthroughs/` | Verified delivery explanations and handoffs |
| `docs/04_Architecture/` | Canonical architecture, contracts, schemas, and ADRs |
| `docs/05_Design/` | Product, web/mobile UX, character, voice, and visual specifications |
| `docs/06_Guides/` | Setup, contributor, AI Studio, testing, and maintenance guidance |
| `docs/07_Archive/` | Superseded canonical material retained for history |

## Permanent Exception

`docs/ProjectWorkflowStarterKit/` is a user-owned starter reference. It remains in its current location and is not part of normal AI context or active project documentation.

## Draft Handling

Files under `docs/00_Drafts/` never override the canonical master plan. Before moving a draft to `docs/07_Archive/`, confirm that all still-valid unique information has either been incorporated into a canonical document or intentionally rejected.

