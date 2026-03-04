# agent-automation-kit

Portable installer for agent orchestration scripts, docs, and policy baseline.

## What this is for
Use this kit when you want repeatable, policy-guarded multi-agent development in a normal Git repo.

It installs:
- runtime scripts for spawning/monitoring/shipping agent work
- baseline governance and orchestration docs
- templates for task briefs, PR descriptions, and review workflows

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

## How it works (human view)
1. Define a task brief in your consumer repo (`docs/tasks/...`).
2. Spawn a task agent on an isolated worktree/branch.
3. Agent runtime enforces policy rails (scope, hard-stop domains, cost/usage checks).
4. Monitor health/status from `.ops/agent-runs/*` and orchestration helpers.
5. Ship with sequential PR automation (`ship-pr.sh`), then cleanup run artifacts.

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

## What gets installed
- `agents.md`
- `scripts/agents/*`
- core docs for orchestration/rules/templates
- alignment docs:
  - `docs/agent-project-alignment.md`
  - `docs/agent-project-profile.md`
