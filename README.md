# agent-automation-kit

Portable installer for agent orchestration scripts, docs, and policy baseline.

## What this is
This is a reusable automation layer you install in a repo so AI-assisted coding follows a consistent, script-based workflow.

It gives your project:
- checked-in scripts for task execution, monitoring, and PR shipping
- repo docs/templates that define how tasks are written and reviewed
- a safe update path so multiple repos can stay aligned over time

## Problem it solves (vs normal vibe coding)
Normal vibe coding is fast, but usually ad-hoc:
- task setup changes every time
- process lives in chat history instead of the repo
- hard to see what an agent ran and why
- parallel agent work can collide
- improvements are hard to roll out consistently across repos

This kit solves that by making the workflow reproducible:
- one task -> one branch/worktree -> one PR
- run artifacts in `.ops/agent-runs/*` for visibility and debugging
- health/lint/eval checks before shipping
- pinned, drift-aware updates for managed automation files

## What gets installed
- `agents.md`
- `scripts/agents/*`
- core docs for orchestration/rules/templates
- alignment docs:
  - `docs/agent-project-alignment.md`
  - `docs/agent-project-profile.md`

## Local usage
```bash
node /absolute/path/to/agent-automation-kit/bin/install.js /absolute/path/to/target-repo
```

After install, initialize project-specific context:
```bash
cd /absolute/path/to/target-repo
scripts/agents/init-project-context.sh
```

Use `--force` to overwrite existing files.
Use `--dry-run` to preview changes and `--check` for CI drift detection.

## How it works in practice
1. Write the task in `docs/tasks/...` (like a mini ticket + acceptance criteria).
2. Spawn an agent on an isolated branch/worktree.
3. Let the runtime enforce guardrails while it executes.
4. Inspect status/log artifacts as it runs.
5. Ship through PR flow, then cleanup run files.

Common run artifacts:
- `.ops/agent-runs/<ticket>-<slug>.log` - full execution log
- `.ops/agent-runs/<ticket>-<slug>.last.txt` - final/last assistant message
- `.ops/agent-runs/<ticket>-<slug>.context.txt` - deterministic run metadata
- `.ops/agent-runs/<ticket>-<slug>.context.pack.txt` - compacted prompt context
- `.ops/agent-runs/<ticket>-<slug>.todo.md` - run plan/checklist
- `.ops/agent-runs/<ticket>-<slug>.tool-state.env` - state-machine status

## Daily operator workflow
In a consumer repo that already has the kit installed:

1. Validate briefs before spawning:
```bash
scripts/agents/lint-task-briefs.sh
```

2. Spawn one agent:
```bash
bash scripts/agents/spawn-codex-agent.sh <TICKET_ID> <slug> docs/tasks/<file>.md
```

3. Monitor:
```bash
scripts/agents/orchestrator-status.sh --brief
scripts/agents/check-agent-health.sh <TICKET_ID>-<slug>
```

4. Evaluate reliability signals:
```bash
scripts/agents/run-eval-smoke.sh
```

5. Ship safely (sequential flow):
```bash
scripts/agents/ship-pr.sh --help
```

6. Cleanup stale run files after completion:
```bash
scripts/agents/cleanup-task-run-files.sh <TICKET_ID>-<slug>
```

## Worktree automation
The runtime includes a dedicated helper for repeatable branch/worktree management:

```bash
scripts/agents/worktree-task.sh create <TICKET_ID> <slug>
scripts/agents/worktree-task.sh list
scripts/agents/worktree-task.sh remove <TICKET_ID> <slug> --delete-branch
```

Defaults:
- branch format: `codex/<TICKET_ID>-<slug>`
- worktree location: `<repo-parent>/agent-worktrees`
- override location with `AGENT_WORKTREE_ROOT=/absolute/path`

`spawn-codex-agent.sh` uses this helper automatically, so task spawns stay aligned with the same worktree conventions.

## Humans + Agents in the same repo
Yes, this kit is designed for mixed teams where humans and agents both ship code.

Recommended collaboration model:
- humans own product direction, task quality, and final merge decisions
- agents own scoped execution per task brief
- one task = one branch = one PR (no shared feature branch editing)

How to stay in sync:
1. Keep task briefs current before and during execution.
2. Treat `scripts/agents/orchestrator-status.sh --brief` as source-of-truth for “is work actively running”.
3. Use PRs as handoff boundaries (human review and approval between major direction changes).
4. If a human changes the same area while an agent is running:
   - stop spawning dependent tasks
   - finish or stop the active task branch
   - rebase/sync from latest `main`
   - relaunch from updated task brief if needed
5. After each merge wave, run:
```bash
scripts/agents/orchestrator-context-compress.sh
scripts/agents/run-eval-smoke.sh
```

Practical handoff rhythm:
- start of day: lint task briefs + confirm queue
- during day: monitor active runs every 5-10 minutes
- before merge: human reviews PR, checks tests/risks, approves
- after merge: clean run artifacts and update next READY task

## Safe updates across repos
Run this in each consumer repo to pull managed automation while preserving local edits.
Use an immutable ref (commit SHA preferred, tags supported):
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha>
```

If you want to overwrite all managed files:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --force
```

CI drift check example:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --check
```

Pin to a tag:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git v0.1.0
```

You can also pass a local clone path, but updates still come from that clone's `origin` remote (never from local files):
```bash
scripts/agents/update-agent-automation.sh /absolute/path/to/local/agent-automation-kit <tag-or-commit-sha>
```

Branch refs are blocked by default. To allow branch-based updates explicitly:
```bash
AGENT_AUTOMATION_ALLOW_UNPINNED=1 scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git main
```

The installer stores managed-file hashes in `.agent-automation/state.json` and only auto-updates files that were previously installed and remain unchanged locally.
This means project-tailored files are preserved by default during safe updates.

## Context engineering in this kit
The runtime now includes provider-agnostic context controls:
- deterministic context packing with explicit section budgets
- run plan recitation requirements
- tool state-machine artifact for phased action scope
- retry diversity metrics + repeated-failure guardrail signals in eval output

Primary references installed in consumer repos:
- `docs/context-engineering.md`
- `docs/context-compaction.md`
- `docs/tool-state-machine.md`
- `docs/agent-evaluation.md`
