# Context Compaction

Purpose: keep runtime context deterministic, bounded, and less prone to lost-in-the-middle failure.

## Packer Script
Use:
```bash
scripts/agents/context-pack.sh \
  --run-name <run_name> \
  --output .ops/agent-runs/<run_name>.context.pack.txt \
  --context-file .ops/agent-runs/<run_name>.context.txt \
  --todo-file .ops/agent-runs/<run_name>.todo.md \
  --task-file <task_brief_path>
```

Deterministic section order:
1. context snapshot
2. run plan
3. task brief

## Budgeting Defaults
- total max chars: `18000`
- context section: `2000`
- run plan section: `4000`
- task brief section: `12000`

If budgets exceed total max, deterministic shrink order is:
1. task brief
2. run plan
3. context snapshot

## Truncation Rules
- context snapshot: head truncation
- run plan: head truncation
- task brief: head+tail with explicit middle-truncation marker

## Output Metadata
Packed file includes:
- per-section source/output chars
- per-section truncated flag
- per-section SHA-256 source hash

Eval smoke tracks:
- context pack file presence
- number of runs with truncated packed context
