# Agent Orchestration Playbook

## Goal
Run parallel agents safely with small PRs and stable merges.

## Roles
- **Lead Orchestrator**: top-level coordinator across features
- **Feature Orchestrator**: coordinates one large feature stream and its task agents
- **Task Lead Agent**: scope, decomposition, assignment, final sign-off recommendation
- **Implementing Agent**: implements assigned ticket only
- **Review Agent**: validates acceptance criteria/tests
- **Design Review Agent**: validates end-user UX quality with screenshot-based review for UI-impacting work

Authority:
- Only Task Lead Agent can assign/spawn agents.
- Implementing/Review agents cannot self-assign.
- Major technical decisions: lead decides + records.
- Major UX decisions: require explicit user approval.
- Implementing/Review agents escalate uncertainty to lead and pause until resolved.
- Hard-stop domains are lead-gated: implementer/reviewer must escalate and pause.
- Lead must use authoritative references for hard-stop decisions:
  - official auth provider docs (auth)
  - OWASP ASVS/Cheat Sheets (security/privacy)
  - official vendor docs (external APIs)
- Max hierarchy depth is strict:
  - `Lead Orchestrator -> Feature Orchestrator -> Task Agent`
- No deeper orchestration chains are allowed.
- If a task agent detects feature-sized scope, it may be promoted to Feature Orchestrator for that feature only and must continue communication with Lead Orchestrator.

## Core Execution Rules
- One task = one branch = one PR.
- Task must be fully defined before execution.
- Single-agent first: default to one agent unless specialization/isolation is clearly required.
- Do not start dependent task if unfinished upstream touches same area.
- Block dependent task until upstream merged to `main`.
- Use planning-with-files only for complex tasks.
- Never merge planning artifacts to `main`.
- Route models by task complexity (`simple` -> cheapest acceptable model).
- Keep reasoning effort low by default; allow temporary step-up only when an agent is blocked or repeatedly failing.
- After solving the blocking issue, reduce reasoning effort back to baseline.
- Never perform paid actions or accept legal terms/conditions without explicit user approval.

When adding agents:
- Document why one agent is insufficient.
- Keep responsibilities non-overlapping.
- Keep context windows minimal and task-scoped.

## Task Definition Minimum
1. Objective
2. Scope + out-of-scope
3. Acceptance criteria
4. Required tests
5. Branch id/slug
6. Role assignment (Lead/Implementer/Reviewer)
7. Dependencies
8. UI Impact (`Yes`/`No`)
9. Model Tier (`simple`/`standard`/`complex`)
10. Required Context (minimal file list)
11. Recommended Skills (optional, up to 3 repo-local skill paths)

Template:
- [`docs/templates/task-brief.md`](docs/templates/task-brief.md)
- Default minimal rules file:
  - [`docs/agent-runtime-rules.md`](docs/agent-runtime-rules.md)
  - For UI tasks include:
    - [`docs/design-system.md`](docs/design-system.md)
    - [`docs/frontend-standards.md`](docs/frontend-standards.md)
  - For complex-domain tasks include:
    - [`docs/library-selection.md`](docs/library-selection.md)

## Branch/Isolation
- Branch format: `codex/<ticket-id>-<slug>`
- Use isolated worktrees: `${AGENT_WORKTREE_ROOT:-../agent-worktrees}/<ticket-id>-<slug>`

## Spawn Script
- [`scripts/agents/spawn-codex-agent.sh`](scripts/agents/spawn-codex-agent.sh)
- Lead (or user) only.
- Global concurrency cap is enforced at spawn time (default: 3 running agents).
- Override with `MAX_CONCURRENT_AGENTS=<n>` only when justified.
- Spawned agents should use minimal context:
  - `docs/agent-runtime-rules.md`
  - assigned task brief
  - task brief Required Context files only
- If present, task brief Recommended Skills may be used selectively:
  - load only relevant skills
  - default to 1-2 skills
  - avoid broad skill loading
- Spawn script applies model routing by `## Model Tier`:
  - `simple` -> `AGENT_MODEL_SIMPLE` (default `gpt-5`)
  - `standard` -> `AGENT_MODEL_STANDARD` (default `gpt-5`)
  - `complex` -> `AGENT_MODEL_COMPLEX` (default `gpt-5`)
- Execution mode defaults to `guarded` (no `--full-auto`).
  - Opt in to full-auto only when explicitly approved:
    - `AGENT_EXEC_MODE=full_auto bash scripts/agents/spawn-codex-agent.sh ...`
- Usage guardrails:
  - monitor: `scripts/agents/usage-guard.sh status`
  - default daily budget is derived as `monthly_budget / 30` unless `AGENT_DAILY_BUDGET_UNITS` is explicitly set
  - above 80% of daily budget: pause spawns unless explicit user override (`AGENT_ALLOW_OVER_80_PCT=1`)
  - at/above threshold, model tier may be auto-downgraded by policy.
- Script should refuse start when task is marked `BLOCKED`.
- Validate briefs before spawn:
  - `scripts/agents/lint-task-briefs.sh`
- Spawn preflight bootstraps dependencies for new worktrees when needed (node-modules linker).
  - Override only if explicitly needed: `SKIP_WORKTREE_BOOTSTRAP=1`

Example:
```bash
bash scripts/agents/spawn-codex-agent.sh T012 sample-task docs/tasks/todo/T012-sample-task.md
```

Override above-80% pause only after explicit user approval:
```bash
AGENT_ALLOW_OVER_80_PCT=1 bash scripts/agents/spawn-codex-agent.sh T012 sample-task docs/tasks/todo/T012-sample-task.md
```

## Monitoring
- `.ops/agent-runs/<ticket>-<slug>.pid`
- `.ops/agent-runs/<ticket>-<slug>.log`
- `.ops/agent-runs/<ticket>-<slug>.last.txt`
- `.ops/agent-runs/<ticket>-<slug>.prompt.txt`
- `.ops/coordination/<ticket-id>.md` (lead-agent thread)

Reliability behavior:
- Spawn uses detached supervisor launch to prevent silent process reaping.
- If agent exits early/no completion message, supervisor retries automatically (bounded attempts) and writes failure note to `.last.txt` if unrecoverable.
- Spawn writes deterministic run context + plan artifacts:
  - `.ops/agent-runs/<ticket>-<slug>.context.txt`
  - `.ops/agent-runs/<ticket>-<slug>.todo.md`
  - `.ops/agent-runs/<ticket>-<slug>.tool-state.env`
- When lead deems task complete (merged to `main`), remove run artifacts immediately:
  - `scripts/agents/cleanup-task-run-files.sh <ticket-slug-prefix>`

Communication protocol:
- [`docs/agent-communication.md`](docs/agent-communication.md)
- Ask lead: `scripts/agents/ask-lead.sh`
- Lead reply: `scripts/agents/reply-lead.sh`

Lead check-in cadence:
- Lead orchestrator should check each active agent at least every 5-10 minutes.
- Use health check:
  - `scripts/agents/check-agent-health.sh <ticket-slug-prefix>`
- Use global orchestrator status (truth source for user updates):
  - `scripts/agents/orchestrator-status.sh --brief`
- Throughput rule:
  - If `IDLE` and no hard-stop/user-decision block, immediately start next eligible task.
  - Maintain at least one active implementation stream; add a second parallel task agent when dependencies and usage budget allow.
  - Auto-dispatch helper:
    - `scripts/agents/spawn-next-ready-agent.sh`
- Clean stale long-running/no-longer-needed processes:
  - `scripts/agents/cleanup-stale-processes.sh`
- If status is `struggling` or `stalled`, lead must intervene:
  - inspect log + last message
  - decide unblock guidance, temporary reasoning step-up, or task split

Truthful heartbeat protocol:
- Any progress update that says work is currently running must be backed by:
  - `scripts/agents/orchestrator-status.sh --brief` reporting `ACTIVE`
- If status is `IDLE`, update must say idle + next action.

Operational PM cadence:
- Lead orchestrator performs periodic product/ops review at least every 60-90 minutes or after each major merge wave.
- Review checklist:
  - ticket quality/scope clarity
  - dependency correctness and merge order
  - UX direction and end-user quality risks
  - whether direction should change before more implementation
- Default is one orchestrator handling PM review; spawn separate PM-review agent only if complexity justifies added overhead.
- Compress orchestration context to file after each PM review:
  - `scripts/agents/orchestrator-context-compress.sh`

UI design quality gate:
- UI-impacting tickets should include Design Review Agent or equivalent review responsibility.
- Design review must include screenshot capture (desktop + mobile + loading/error/empty where applicable).

## Evaluation Loop
- Major orchestration policy/script changes must include a small evaluation pass before/after change.
- Evaluation should check:
  - task completion rate
  - silent-stop rate
  - retry frequency
  - token/cost trend
- Generate baseline metrics with:
  - `scripts/agents/run-eval-smoke.sh`
- Export trace bundle for incidents/deep review with:
  - `scripts/agents/export-agent-traces.sh`
- Apply context-engineering checklist:
  - [`docs/context-engineering.md`](docs/context-engineering.md)
- Apply tool-state machine checklist:
  - [`docs/tool-state-machine.md`](docs/tool-state-machine.md)
- Record results in decision note or linked PR summary.

## PR Rules
- Small, task-scoped PRs only.
- Title: `<type>(<area>): <outcome>`
- Must include: scope, changes, tests run, risks/follow-ups.

Template:
- [`docs/templates/pr-description.md`](docs/templates/pr-description.md)
- Final review templates:
  - [`docs/templates/final-review-checklist.md`](docs/templates/final-review-checklist.md)
  - [`docs/templates/final-review-task.md`](docs/templates/final-review-task.md)


Sequential ship helper:
- Use [`scripts/agents/ship-pr.sh`](scripts/agents/ship-pr.sh) to enforce serial `check -> commit -> push -> PR -> merge` execution and avoid commit/push race conditions.

## Merge Strategy
- Task branches must target `staging` first (never direct to `main`).
- Require CI checks to pass before every merge.
- Use squash/rebase merges for clean history (no merge commits into `main`).
- Promotion path is mandatory:
  - `feature branch -> staging`
  - `staging -> main` via promotion PR
- Use:
  - [`scripts/agents/ship-pr.sh`](scripts/agents/ship-pr.sh) for feature branch shipping (defaults to `staging` and waits for required checks)
  - [`scripts/agents/promote-staging-to-main.sh`](scripts/agents/promote-staging-to-main.sh) for promotion
  - [`scripts/agents/ensure-staging-branch.sh`](scripts/agents/ensure-staging-branch.sh) auto-recreates `origin/staging` from `origin/main` when missing
- For feature streams, run an agent-managed final review task before final promote.
- Final review must include screenshot verification for UI-impacting features.

## Decision Records
- Major technical/UX decisions must be recorded in:
  - [`docs/decisions/`](docs/decisions/)
- Decision note must merge with task PR or immediately linked PR.
- Library-selection decisions for complex domains must also be recorded.

## Main Hygiene
Never on `main`:
- planning files (`task_plan.md`, `findings.md`, `progress.md`)
- temporary task notes outside approved docs
- mixed-purpose commits
