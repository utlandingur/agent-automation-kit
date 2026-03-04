# Agent Runtime Rules (Minimal)

Use this file as the default rule source during task execution.

## Mandatory
- Scope strictly to the assigned task brief.
- Use TDD (tests first, then implementation).
- Keep changes small and PR-ready.
- Do not start if task is blocked by unfinished dependency touching same area.
- Do not create/commit planning files unless task explicitly requires planning.
- Never commit planning artifacts to `main`.
- Run required checks for the task (`yarn lint`, `yarn test`, required E2E).
- Run tests in non-watch mode and stop any leftover runners/processes after checks.
- Follow existing design system and established code patterns for any UI work.
- Follow modern frontend reliability/performance standards for UI work.
- For UI design tasks, run `docs/agent-design-iteration.md` protocol before presenting screenshots.
- Respect global agent concurrency cap (default max 3 running agents).
- Before any "work is running" progress update, verify:
  - `scripts/agents/orchestrator-status.sh --brief`
  - only report active work when status is `ACTIVE`.
- If orchestrator is `IDLE` and no hard-stop/user-decision block exists, start next eligible task immediately.
- For orchestration/script changes, generate an eval smoke report:
  - `scripts/agents/run-eval-smoke.sh`

## Architecture Selection
- Default to single-agent execution for tasks that do not require explicit specialization or isolation.
- Add more agents only when one agent cannot meet acceptance criteria with reasonable tool/prompt changes.
- Extra agents must have clear, non-overlapping responsibilities.

## Authority
- Only Task Lead Agent can spawn/assign additional agents.
- Major technical decisions: lead decides and records.
- Major UX decisions: require explicit user approval before continuing.
- If unsure, ask Task Lead via communication protocol and pause until reply.
- Hierarchy cap: `Lead Orchestrator -> Feature Orchestrator -> Task Agent` only.
- If scope expands to feature-level, escalate for Feature Orchestrator assignment; do not create deeper chains.

## Protected Domains (Hard-Stop)
- DB schema/migrations/persisted formats
- External API contracts
- Auth/billing/payment/account behavior
- Core AI prompt semantics/output shape
- Security/privacy-sensitive handling
- Any paid action, subscription, purchase, or acceptance of legal terms/conditions
- Implementing/Review agents: escalate + pause by default.
- Task Lead may proceed only when critical and with authoritative references.

## Cost + Consent
- Default to cheapest acceptable model tier for assigned task.
- Default to lower reasoning effort; increase only when blocked/struggling to solve correctly.
- Escalate reasoning one step at a time, only for the minimum time needed, then drop back down.
- Monitor usage with `scripts/agents/usage-guard.sh status`.
- Pause new agent spawns when daily usage is above 80% unless user explicitly approves override.
- Never run paid actions, purchases, billing upgrades, or accept terms/conditions.
- Require explicit user approval before any spend or legal acceptance step.

## Decision Logging
- Record major technical/UX decisions in:
  - [`docs/decisions/`](docs/decisions/)

## Library Policy
- For complex domains, review current maintained libraries using official docs before implementing.
- For simple tasks, do not add dependencies when direct code is sufficient.
- Record major library choices in `docs/decisions/`.
- Auth-specific requirement: use the project's chosen auth provider and its official docs for decisions.
- Security-specific requirement: use OWASP guidance (ASVS + relevant Cheat Sheets).

## Tool Contract Quality
- Tool interfaces must use strict schemas and unambiguous parameter names.
- Tool outputs should be compact and task-relevant to reduce token usage.
- Avoid passing untrusted raw text between agents/tools when structured fields are sufficient.

## MCP Safety
- MCP tools should declare risk metadata (read-only/destructive/open-world) when supported.
- Destructive/open-world operations require explicit user approval before execution.

## Context Policy
- Read only:
  1. this file
  2. assigned task brief
  3. files listed in task brief “Required Context”
- You may read task-scoped implementation files listed in the brief (`Files/Areas`, `In Scope`) and their direct dependencies/imports needed to complete the task.
- Do not read broader docs unless task brief explicitly requires them.
- For UI-impacting tasks, task brief must include:
  - [`docs/design-system.md`](docs/design-system.md)
  - [`docs/frontend-standards.md`](docs/frontend-standards.md)
  - [`docs/agent-design-iteration.md`](docs/agent-design-iteration.md)
  in “Required Context”.


## Skill Usage Policy
- Prefer repo-local vendored skills from:
  - [`docs/skills/README.md`](docs/skills/README.md)
- Load skills only when they are relevant to the task scope.
- Keep skill context minimal:
  - read `SKILL.md` first
  - read only directly referenced files needed to execute
  - avoid loading entire skill folders
- Default to `1-2` skills per task; avoid broad multi-skill loading unless explicitly justified.

## Escalation Channel
- Use:
  - [`docs/agent-communication.md`](docs/agent-communication.md)
- Ask lead script:
  - `scripts/agents/ask-lead.sh <ticket_id> \"<question>\" \"<recommended_option>\"`

## UI Consistency Rules (when UI is in scope)
- Use existing `components/ui/*` primitives before creating new ones.
- Prefer project-aligned patterns/components for new UI work.
- Do not introduce new shadcn-specific layout patterns for net-new screens.
- Use design tokens only; no hard-coded one-off styles.
- Keep interaction patterns consistent with existing flows.
- Do not present a UI iteration that fails the design-iteration hard-fail rules.
- If task is explicitly creative and user says no finalized pattern exists, avoid reusing prior layout patterns; propose net-new concepts first.
- Preserve accessibility: keyboard, focus, contrast.
- Keep loading/error states explicit and stable.
