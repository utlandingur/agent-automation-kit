# Task Brief

## Task ID
`T000`

## Slug
`short-kebab-slug`

## Lifecycle
- Stage: `TODO` | `DOING` | `BLOCKED` | `DONE`
- Last Updated: `YYYY-MM-DD`
- Completion Evidence: `N/A` (required for `DONE`)
- Unit Estimate: `1` | `3` | `6` (must match Model Tier)

## Roles
- Lead Orchestrator: `@lead-orchestrator`
- Feature Orchestrator: `@feature-orchestrator` (or `None`)
- Task Lead Agent: `@lead-agent`
- Implementing Agent: `@impl-agent`
- Review Agent: `@review-agent`
- Design Review Agent: `@design-review-agent` (or `None`)
- Lead Coordination Thread: `.ops/coordination/<ticket-id>.md`

## Objective
Single clear outcome.

## Why
Business/product reason.

## User Story
As a `<user>`, I want `<capability>`, so that `<outcome>`.

## Goal Alignment
- List canonical goal IDs from `docs/product-spec.md` (for example: `G1`, `G3`).

## Dependencies
- Status: `READY` | `BLOCKED`
- Upstream tasks this depends on (`None` if none).
- If `BLOCKED`, implementation must not start.

## UI Impact
- `Yes` | `No`

## Model Tier
- `simple` | `standard` | `complex`
- Default target: cheapest acceptable model for this task.
- Escalate to higher tier only when acceptance criteria cannot be met.

## Required Context
- Exact docs/files the agent must read for this task only.
- Keep this list minimal.
- Include `docs/agent-runtime-rules.md` by default.
- If UI Impact is `Yes`, include:
  - `docs/design-system.md`
  - `docs/frontend-standards.md`
- If task is in a complex external domain, include:
  - `docs/library-selection.md`

## Recommended Skills (Optional)
- List up to `3` local vendored skills that improve delivery quality for this task.
- Use repo-local paths under `docs/skills/external/*` only.
- Example:
  - `docs/skills/external/vercel-labs/next-best-practices`

## In Scope
- Item

## Out of Scope
- Item

## Files/Areas
- `path/to/area`

## Acceptance Criteria
1. Testable outcome

## Required Tests (TDD)
- Unit: required coverage
- E2E: required flow(s)

## Constraints
- Small single-purpose PR only.
- No unrelated contract changes.
- No planning files in final commit.
- Only Task Lead can spawn/assign additional agents.
- Split into new tickets if scope grows.
- Record major technical/UX decisions in `docs/decisions/`.
- If unsure, implementer/reviewer must ask lead and pause until response.

## Deliverables
- Code
- Tests
- Required docs/decision note updates

## Completion Record
- Acceptance Criteria: `PASS` | `FAIL` | `N/A`
- Required Tests: `PASS` | `FAIL` | `N/A`
- Evidence: `N/A` (required for `DONE`)
