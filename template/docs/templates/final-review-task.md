# Final Review Task Template

## Task ID
`Txxx`

## Slug
`feature-final-review`

## Roles
- Lead Orchestrator: `@lead-orchestrator`
- Feature Orchestrator: `@feature-orchestrator`
- Task Lead Agent: `@review-lead`
- Implementing Agent: `None` (review-only ticket unless fixes are required)
- Review Agent: `@review-agent`
- Design Review Agent: `@design-review-agent` (required if UI Impact is `Yes`)
- Lead Coordination Thread: `.ops/coordination/<ticket-id>.md`

## Objective
Run final feature review gate and produce a merge recommendation.

## Dependencies
- Status: `BLOCKED`
- Upstream tasks: `<all feature implementation tickets>`
- Unblock only when all upstream tickets are merged and green.

## UI Impact
- `Yes` | `No`

## Required Context
- `docs/agent-runtime-rules.md`
- `docs/task-context-v0.md`
- `docs/templates/final-review-checklist.md`
- If UI Impact is `Yes`:
  - `docs/design-system.md`
  - `docs/frontend-standards.md`

## In Scope
- Validate all feature acceptance criteria.
- Execute final quality gates.
- Capture screenshots for UI validation when applicable.
- Produce clear approve/changes-required recommendation.

## Out of Scope
- New feature work.

## Deliverables
- Completed checklist in PR comment or linked review note.
- Screenshot set for UI-impacting features.
- Explicit go/no-go recommendation to Lead Orchestrator.
