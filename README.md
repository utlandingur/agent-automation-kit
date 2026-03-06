# agent-automation-kit

Portable installer for file-first agent orchestration scripts, docs, and policy baseline.

## What this is
Install this kit into a repo to make AI-assisted coding reproducible through checked-in scripts, task briefs, and run artifacts.

Core model:
- one task -> one branch/worktree -> one PR
- file-first runtime state in `.ops/agent-runs/*`
- scripted guardrails for spawn, monitoring, evaluation, and shipping

## Quick start
Install from a local clone:

```bash
cd /absolute/path/to/agent-automation-kit
node bin/install.js /absolute/path/to/target-repo
```

Optional packed-tarball install flow:

```bash
cd /absolute/path/to/agent-automation-kit
pkg_tgz="$(npm pack --silent | tail -n1)"
npx --yes --package "./${pkg_tgz}" agent-automation-install /absolute/path/to/target-repo
```

Initialize project-specific context in the target repo (one-time):

```bash
cd /absolute/path/to/target-repo
scripts/agents/init-project-context.sh
```

`init-project-context.sh` is interactive and requires a TTY.
Successful initialization writes `.agent-automation/context-initialized`.

First run (minimal):

```bash
scripts/agents/lint-task-briefs.sh
bash scripts/agents/spawn-codex-agent.sh T001 example-task docs/tasks/todo/T001-example-task.md
scripts/agents/orchestrator-status.sh --brief
scripts/agents/check-agent-health.sh <TICKET_ID>-<slug>
```

## Why use this
Ad-hoc chat workflows often fail on reproducibility and coordination:
- process details live in chat, not the repo
- parallel runs can collide
- it is hard to debug what happened in a run
- it is hard to roll out improvements consistently across repos

This kit provides a repeatable, auditable repo workflow with safe update behavior.

## Use this if
- you are a solo developer or small team (typically up to ~10 engineers)
- your delivery model is git + PR based
- you want low-ops orchestration (scripts/files, no always-on control plane)
- you want transparent run artifacts for debugging and review

## Do not use this as-is if
- you need multi-host/distributed scheduling with strict global locks
- you need platform-grade RBAC/tenancy/SLA controls
- you need durable queue/worker semantics backed by DB/event bus
- you need centralized fleet-level orchestration across many repos/runners

In those cases, use this as the repo workflow layer and add a dedicated control plane.

## Pros and cons
### Pros
- simple adoption in existing repos
- explicit, inspectable file artifacts
- strong task isolation via branch/worktree conventions
- drift-aware managed updates that preserve local customizations
- minimal infrastructure overhead

### Cons
- not a distributed scheduler
- health/status are heuristic and log/file based
- still requires process discipline by humans and agents
- governance is workflow-level, not enterprise platform-level

## Alternatives (and when to use them)
- [mini-SWE-agent](https://github.com/SWE-agent/mini-swe-agent)
  - Choose for a very lightweight coding-agent CLI.
  - Choose this kit when you want stronger repo policy/docs/run-artifact conventions.
- [SWE-agent](https://swe-agent.com/latest/usage/hello_world/)
  - Choose for benchmark-oriented SWE workflows and richer built-in runtime patterns.
  - Choose this kit for simpler file-first repo orchestration you can customize directly.
- [CrewAI](https://docs.crewai.com/en/quickstart)
  - Choose for framework-style multi-agent app flows (Python/YAML).
  - Choose this kit for script + git + repo-file orchestration instead of app framework orchestration.
- [OpenHands](https://docs.all-hands.dev/openhands/usage/architecture/runtime)
  - Choose for platform-style runtime/service architecture.
  - Choose this kit for low-ops, repo-local control and explicit file artifacts.

Decision shorthand:
- choose this kit for file-first, repo-local orchestration
- choose framework/platform alternatives for centralized runtime services and larger-scale control planes

## Prerequisites
Install and update workflows:
- Node.js `>=18`
- `git`

Runtime workflows:
- `python3`
- `codex` CLI in `PATH`
- `gh` CLI for PR shipping helpers
- `rg` (recommended; many scripts have fallbacks)

OS support:
- macOS
- Linux
- Windows via WSL (shell scripts are bash-based)

## Installer modes and exit codes
With `node bin/install.js`:
- `--dry-run` preview changes
- `--update` update previously managed unchanged files
- `--force` overwrite all managed files
- `--check` exits `2` when updates/conflicts are detected

With `agent-automation-update`:
- exits `3` when update conflicts are present and `--force` is not used

## Daily operator workflow
1. Validate briefs:
```bash
scripts/agents/lint-task-briefs.sh
```
2. Spawn one task agent:
```bash
bash scripts/agents/spawn-codex-agent.sh <TICKET_ID> <slug> docs/tasks/<file>.md
```
3. Monitor health:
```bash
scripts/agents/orchestrator-status.sh --brief
scripts/agents/check-agent-health.sh <TICKET_ID>-<slug>
```
4. Evaluate reliability signals:
```bash
scripts/agents/run-eval-smoke.sh
```
5. Ship through sequential PR flow:
```bash
scripts/agents/ship-pr.sh --help
```
`ship-pr.sh` defaults to `--base staging`. Use `--base main --allow-main` only when you intentionally bypass the staging flow.
6. Clean up run artifacts:
```bash
scripts/agents/cleanup-task-run-files.sh <TICKET_ID>-<slug>
```

## What gets installed
- `agents.md`
- `scripts/agents/*`
- core orchestration docs/templates
- alignment docs:
  - `docs/agent-project-alignment.md`
  - `docs/agent-project-profile.md`

## How it works in practice
1. Write task brief in `docs/tasks/...`.
2. Spawn an isolated agent branch/worktree.
3. Runtime applies policy and records artifacts.
4. Review status/log/context outputs.
5. Ship via PR and clean run files.

Common run files:
- `.ops/agent-runs/<ticket>-<slug>.log` (full execution log)
- `.ops/agent-runs/<ticket>-<slug>.last.txt` (final assistant message)
- `.ops/agent-runs/<ticket>-<slug>.context.txt` (deterministic run metadata)
- `.ops/agent-runs/<ticket>-<slug>.context.pack.txt` (compacted prompt context)
- `.ops/agent-runs/<ticket>-<slug>.todo.md` (run plan/checklist)
- `.ops/agent-runs/<ticket>-<slug>.tool-state.env` (state-machine status)

## Worktree automation
```bash
scripts/agents/worktree-task.sh create <TICKET_ID> <slug>
scripts/agents/worktree-task.sh list
scripts/agents/worktree-task.sh remove <TICKET_ID> <slug> --delete-branch
```

Defaults:
- branch format: `codex/<TICKET_ID>-<slug>`
- worktree root: `<repo-parent>/agent-worktrees`
- override: `AGENT_WORKTREE_ROOT=/absolute/path`

`spawn-codex-agent.sh` uses this helper automatically.
It delegates branch/worktree creation to `worktree-task.sh create ...`.

## Humans + agents in the same repo
Recommended model:
- humans own direction/task quality/final merge decisions
- agents execute scoped task briefs
- one task = one branch = one PR

Sync rules:
1. Keep task briefs current.
2. Treat `scripts/agents/orchestrator-status.sh --brief` as run truth source.
3. Use PR boundaries for handoffs.
4. If humans edit same area during an active run:
   - stop dependent spawns
   - finish/stop active task branch
   - sync from latest `main`
   - relaunch from updated brief if needed
5. After merge waves:
```bash
scripts/agents/orchestrator-context-compress.sh
scripts/agents/run-eval-smoke.sh
```

## Safe updates across repos
Use immutable refs (commit SHA preferred, tags supported):

```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha>
```

Overwrite all managed files:

```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --force
```

CI drift check:

```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --check
```

Tag pin:

```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git v0.1.0
```

Local clone input (still resolves from clone `origin`, never from local files):

```bash
scripts/agents/update-agent-automation.sh /absolute/path/to/local/agent-automation-kit <tag-or-commit-sha>
```

Allow branch refs only when explicitly intended:

```bash
AGENT_AUTOMATION_ALLOW_UNPINNED=1 scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git main
```

Managed file hashes are stored in `.agent-automation/state.json`; unchanged managed files update automatically, while project-tailored edits are preserved by default.

## Troubleshooting
- `Task brief is missing '## Required Context'`: update the task brief before spawn.
- `Task stage is BLOCKED/DONE`: move the task to a runnable state before spawn.
- `codex CLI not found in PATH`: install/configure Codex CLI for runtime execution.
- `init-project-context.sh requires interactive confirmation`: run it from an interactive terminal.

## Uninstall / revert
To remove kit-managed files in a consumer repo:
1. Read `.agent-automation/state.json`.
2. Remove managed files listed under `files`.
3. Remove `.agent-automation/`.

Review before deletion so project-specific customizations are preserved where needed.

## Context engineering support
Installed runtime includes provider-agnostic context controls:
- deterministic context packing with explicit section budgets
- run-plan recitation requirements
- tool state-machine artifact for phased action scope
- retry-diversity and repeated-failure guardrail signals in eval output

Primary references:
- `docs/context-engineering.md`
- `docs/context-compaction.md`
- `docs/tool-state-machine.md`
- `docs/agent-evaluation.md`

## Non-goals
- replace enterprise orchestration platforms
- provide centralized auth/tenancy/governance
- act as a distributed control plane across many independent workers
