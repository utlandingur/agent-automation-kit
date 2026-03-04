# Tool State Machine

Purpose: keep agent action scope explicit and phase-aligned with deterministic transitions.

## States
- `plan`
- `implement`
- `verify`
- `finalize`

Allowed order:
- `plan -> implement -> verify -> finalize`
- backward transitions are not allowed

## Commands
Initialize state for a run:
```bash
scripts/agents/tool-state-machine.sh init <run_name>
```

Read current state:
```bash
scripts/agents/tool-state-machine.sh get <run_name>
```

Check whether an action is allowed in current state:
```bash
scripts/agents/tool-state-machine.sh can <run_name> <action>
```

Advance to the next state:
```bash
scripts/agents/tool-state-machine.sh advance <run_name> <next_state>
```

## Actions
Current action set:
- `read_context`
- `ask_lead`
- `edit_code`
- `run_local_checks`
- `update_docs`
- `open_pr`
- `merge_pr`
- `cleanup_artifacts`

## Default policy
- Spawn initializes each run in `plan`.
- Agents should check and advance state explicitly as they progress.
- Eval smoke tracks whether per-run tool-state files are present.
