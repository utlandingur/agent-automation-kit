# Task Briefs

Use Kanban lane folders in this directory:
- `docs/tasks/todo`
- `docs/tasks/doing`
- `docs/tasks/blocked`
- `docs/tasks/done`

Naming convention:
- `T001-short-slug.md`
- `T002-short-slug.md`

Create each file from:
- [`docs/templates/task-brief.md`](docs/templates/task-brief.md)

Required in every brief:
- `Lifecycle` with deterministic stage and unit estimate
- `User Story` (one line, user-facing impact)
- `Goal Alignment` with canonical goal IDs from your project goals/spec file
- `Dependencies` with `Status: READY | BLOCKED`
- `UI Impact: Yes | No`
- `Required Context` (minimal file list)
- `Recommended Skills (Optional)` (up to 3 repo-local skills)
- Prefer compact context docs (for example `docs/task-context-v0.md`) over broad docs.

Lifecycle contract:
- Stage must match folder lane exactly:
  - `todo` => `TODO`
  - `doing` => `DOING`
  - `blocked` => `BLOCKED`
  - `done` => `DONE`
- Unit estimate is deterministic from model tier:
  - `simple` => `1`
  - `standard` => `3`
  - `complex` => `6`
- `DONE` tasks must include completion proof:
  - `## Completion Record`
  - `Acceptance Criteria: PASS`
  - `Required Tests: PASS`
  - non-`N/A` evidence

Move rules:
- Use `scripts/agents/move-task-lane.sh` to move tasks between lanes.
- Moving to `done` requires explicit AC+tests pass and evidence.
- Dependency status is lane-driven:
  - `blocked` lane => `Dependencies: Status: BLOCKED`
  - `todo`/`doing`/`done` lanes => `Dependencies: Status: READY`


Skill recommendation rules:
- Add `Recommended Skills (Optional)` only when it materially improves quality/speed.
- Recommend at most 3 skills, using repo-local paths under `docs/skills/external/`.
- Prefer narrow skills over broad catalogs to keep context windows small.
- Canonical index: [`docs/skills/README.md`](docs/skills/README.md)

Execution rules:
- Do not start tasks marked `BLOCKED`.
- If `UI Impact` is `Yes`, include:
  - `docs/design-system.md`
  - `docs/frontend-standards.md`
- If task is a complex external domain, include `docs/library-selection.md`.
- If agent is unsure, use lead coordination protocol:
  - `docs/agent-communication.md`

These briefs are inputs to:
- [`scripts/agents/spawn-codex-agent.sh`](scripts/agents/spawn-codex-agent.sh)

Lint task briefs:
- `scripts/agents/lint-task-briefs.sh`

Task board:
- `scripts/agents/task-board.sh`
- `scripts/agents/update-project-update.sh`
- `scripts/agents/check-project-update-clean.sh`

Usage monitoring:
- `scripts/agents/usage-guard.sh status`
- Above 80% daily usage, spawns pause unless explicit user override.
- Before pausing at >80%, record a compact handoff:
  - current progress
  - next step to execute on resume

Final review assets:
- `docs/templates/final-review-task.md`
- `docs/templates/final-review-checklist.md`
