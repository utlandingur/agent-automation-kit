# Agent Communication Protocol

Goal: if an agent is unsure, it can ask the Task Lead Agent quickly and safely.

## When to Ask Lead
- ambiguous requirements
- conflicting constraints
- potential contract/schema impact
- uncertain dependency status
- major technical decision point
- any major UX decision (user approval required)

## Rule
- Implementing/Review agents must pause on blocked/uncertain decisions.
- Ask Lead, wait for reply, then continue.
- Feature Orchestrator must keep Lead Orchestrator informed on major blockers/decisions.
- No communication chain deeper than `Lead Orchestrator -> Feature Orchestrator -> Task Agent`.

## Channel
- Task thread file:
  - `.ops/coordination/<ticket-id>.md`
- This is runtime coordination, not product documentation.
- Do not commit `.ops/**` to `main`.

## Message Format
- `Question` entry:
  - timestamp
  - agent
  - task id
  - concise question
  - options considered
  - recommended option
- `Reply` entry:
  - timestamp
  - lead
  - decision
  - next action

## Helper Scripts
- Ask lead:
  - `scripts/agents/ask-lead.sh <ticket_id> \"<question>\" \"<recommended_option>\"`
- Reply as lead:
  - `scripts/agents/reply-lead.sh <ticket_id> \"<decision>\"`
