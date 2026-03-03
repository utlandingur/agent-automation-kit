# AGENTS.md

Purpose: Ship this product reliably with strict contracts and clean collaboration.

Before first use, run:
- `scripts/agents/init-project-context.sh`

## Product Scope
- Input:
- Processing:
- Output:
- Priorities:

## Non-Negotiable Contracts
- Keep data contracts in sync across server/client/storage layers.
- Any contract change must update schema/types/parsing/tests together.
- Do not silently change external behavior without documenting and testing it.

## Hard-Stop (Ask First)
- DB schema/migrations/persisted formats
- External API contracts
- Auth/billing/payment/account behavior
- Core AI prompt semantics/output shape
- Security/privacy-sensitive handling
- Any paid action, purchase/subscription, or legal terms/conditions acceptance
- Implementing/Review agents must not proceed in these domains unless explicitly marked critical by Task Lead.
- For these domains, implementers/reviewers must escalate to lead and pause.
- Task Lead is responsible for decision quality and must use authoritative references:
  - Auth: official docs for the project's auth provider
  - Security/privacy: OWASP (ASVS + Cheat Sheets)
  - External APIs: official vendor docs

## Engineering Standards
- Keep solutions simple and explicit.
- Reuse existing patterns; avoid parallel abstractions.
- Avoid `as` casts unless unavoidable.
- Avoid memoization hooks unless measured need.
- TDD default: tests first, then code.

## UX Guardrails
- Tokenized styles only; no hard-coded colors.
- Preserve keyboard/focus/contrast accessibility.
- Keep loading layouts stable.
- Favor clear staged flows.
- Follow design implementation guide: [`docs/design-system.md`](docs/design-system.md)
- Follow frontend implementation standards: [`docs/frontend-standards.md`](docs/frontend-standards.md)

## Logging & Safety
- No secrets or full user content in logs.
- Debug logs behind env flags.
- Log concise metadata only.

## Validation Required
- `<LINT_COMMAND>`
- `<UNIT_TEST_COMMAND>`
- Plus required E2E for impacted flows

## Task/Branch Rules
- One task = one branch = one small PR.
- New task must start from latest `main`.
- Do not start dependent work if upstream unfinished task touches same feature/code area.
- Dependent tasks stay blocked until upstream merge to `main`.
- Use cheapest acceptable model for simple tasks; escalate model tier only when needed.
- Pause spawning new agents above 80% daily usage unless user explicitly approves override.
- Agents should read only task-required context; default runtime rules are in:
  - [`docs/agent-runtime-rules.md`](docs/agent-runtime-rules.md)

## Planning Files
- Use planning-with-files only for non-trivial tasks.
- For simple scoped tasks, skip planning files.
- Never merge planning artifacts to `main` (`task_plan.md`, `findings.md`, `progress.md`).

## Agent Authority
- Task Lead Agent owns decomposition, assignment, and sign-off recommendation.
- Lead Orchestrator owns periodic product/operational direction review (ticket quality, dependency health, UX direction).
- Only Task Lead Agent can spawn/assign additional agents.
- Implementer/Reviewer cannot self-assign sub-agents.
- If task grows beyond small PR scope, split into new tickets.
- If implementer/reviewer is unsure, they must escalate to lead and pause.
- Protocol:
  - [`docs/agent-communication.md`](docs/agent-communication.md)
- Allowed hierarchy depth is capped:
  - `Lead Orchestrator -> Feature Orchestrator -> Task Agent`
- No deeper nesting is allowed (no sub-task orchestrators under task agents).
- If a task becomes feature-sized, that agent may become Feature Orchestrator and must still report to Lead Orchestrator.

## Decision Authority
- Major technical decisions: Task Lead Agent decides and records.
- Major UX decisions: require explicit user approval before implementation continues.
- Record major decisions in:
  - [`docs/decisions/`](docs/decisions/)

## Library Selection
- For complex domains, evaluate modern maintained libraries using official docs first.
- For simple tasks, prefer direct implementation over extra dependencies.
- Follow: [`docs/library-selection.md`](docs/library-selection.md)

## Merge Safety

- Use sequential ship flow for task PRs via:
  - [`scripts/agents/ship-pr.sh`](scripts/agents/ship-pr.sh)
- Do not run `git commit` and `git push` in parallel.
- Never merge task branches directly into `main`.
- Default task path is:
  - `feature branch -> staging` (with required PR checks)
  - `staging -> main` promotion PR (with required PR checks)
- Use promotion helper for `staging -> main`:
  - [`scripts/agents/promote-staging-to-main.sh`](scripts/agents/promote-staging-to-main.sh)
- Staging branch availability is auto-healed by:
  - [`scripts/agents/ensure-staging-branch.sh`](scripts/agents/ensure-staging-branch.sh)
- For history hygiene, use `squash` or `rebase` merges only (no merge commits into `main`).

## Definition of Done
- Behavior implemented and scoped correctly.
- Contracts preserved.
- Lint/tests (and required E2E) pass or failure is documented.
- Required docs/decision notes updated.

## External Skills
- Vendored third-party skills live under:
  - [`docs/skills/external/`](docs/skills/external/)
- Skill index and source mapping:
  - [`docs/skills/README.md`](docs/skills/README.md)
