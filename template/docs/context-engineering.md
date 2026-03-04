# Context Engineering Checklist

Reference: Manus context-engineering lessons for agent systems.

## 1) Stable Prefix + Deterministic Context
Status: implemented baseline

Checks:
- Spawn writes deterministic run context snapshot:
  - `.ops/agent-runs/<run>.context.txt`
- Spawn generates deterministic packed context artifact:
  - `.ops/agent-runs/<run>.context.pack.txt`
- Prompt prefix order is stable:
  1. hard requirements
  2. packed context sections (snapshot, plan, brief)

## 2) Externalized Working Memory
Status: implemented baseline

Checks:
- Spawn writes run plan file:
  - `.ops/agent-runs/<run>.todo.md`
- Agent must recite objective/scope/first verification command before coding.

## 3) Keep Failures in Context
Status: implemented baseline

Checks:
- Supervisor retries are logged with attempt metadata.
- Eval smoke reports include completion/failure and stream errors.
- Trace export bundles preserve run logs for incident review.

## 4) Avoid Repeating Failed Strategies
Status: implemented baseline

Checks:
- On retry attempts, launcher injects alternative-strategy instruction.
- Retry instructions rotate between at least 3 strategy variants.

## 5) Tool Exposure / State-Machine Discipline
Status: implemented baseline

Checks:
- Hard-stop domains and escalation remain enforced by runtime rules.
- Per-run tool-state file is initialized on spawn:
  - `.ops/agent-runs/<run>.tool-state.env`
- Deterministic state transitions are handled by:
  - `scripts/agents/tool-state-machine.sh`
- Tool contracts should stay schema-driven and compact.

## 6) Ongoing Evaluation
Status: implemented baseline

Checks:
- Run `scripts/agents/run-eval-smoke.sh` on orchestration changes.
- For incidents/deep review run `scripts/agents/export-agent-traces.sh`.
- Track trends over time (completion rate, retries, stream errors).
