# Agent Evaluation & Trace Ops

## Goal
Provide a lightweight, repeatable evaluation loop for agent reliability and safety signals.

## Commands
Generate a run-quality snapshot from orchestration logs:
```bash
scripts/agents/run-eval-smoke.sh
```

Optional guardrails:
```bash
scripts/agents/run-eval-smoke.sh --require-runs --max-stream-errors 0
```

Export trace bundle for incident review / postmortems:
```bash
scripts/agents/export-agent-traces.sh
```

Include prompt files only when explicitly approved:
```bash
scripts/agents/export-agent-traces.sh --include-prompts
```

## Outputs
- Eval report JSON: `.ops/evals/latest.json`
- Eval report Markdown: `.ops/evals/latest.md`
- Trace bundles: `.ops/evals/traces/trace-export-*.tar.gz`
- Eval report includes context-engineering signals:
  - context snapshot/plan/tool-state presence
  - context-pack presence and truncation count

## Suggested CI Pattern
- Run `scripts/agents/run-eval-smoke.sh` after integration tests.
- Upload `.ops/evals/latest.json` as a CI artifact.
- On failures or incidents, run `scripts/agents/export-agent-traces.sh` and attach bundle to the incident ticket.

## Governance Notes
- Do not include prompt files in trace exports unless approved.
- Treat trace bundles as potentially sensitive operational data.
- Use eval reports as release gates for orchestration/script changes when applicable.
