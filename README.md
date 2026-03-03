# agent-automation-kit

Portable installer for agent orchestration scripts, docs, and policy baseline.

## Local usage
```bash
node agent-automation/bin/install.js /absolute/path/to/target-repo
```

## After publishing to npm
```bash
npx --yes --package agent-automation-kit agent-automation-install /absolute/path/to/target-repo
```

Use `--force` to overwrite existing files.
Use `--dry-run` to preview changes and `--check` for CI drift detection.

## Safe updates across repos
Run this in each consumer repo to pull latest managed automation while preserving local edits:
```bash
npx --yes --package agent-automation-kit@latest agent-automation-update .
```

If you want to overwrite all managed files:
```bash
npx --yes --package agent-automation-kit@latest agent-automation-update . --force
```

CI drift check example:
```bash
npx --yes --package agent-automation-kit@latest agent-automation-update . --check
```

The installer stores managed-file hashes in `.agent-automation/state.json` and only auto-updates files that were previously installed and remain unchanged locally.

## What gets installed
- `agents.md`
- `scripts/agents/*`
- core docs for orchestration/rules/templates
- `.ops/*` runtime skeleton
- alignment docs:
  - `docs/agent-project-alignment.md`
  - `docs/agent-project-profile.md`
