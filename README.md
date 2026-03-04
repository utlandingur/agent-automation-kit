# agent-automation-kit

Portable installer for agent orchestration scripts, docs, and policy baseline.

## Local usage
```bash
node /absolute/path/to/agent-automation-kit/bin/install.js /absolute/path/to/target-repo
```

After install, initialize project-specific context:
```bash
cd /absolute/path/to/target-repo
scripts/agents/init-project-context.sh
```

Use `--force` to overwrite existing files.
Use `--dry-run` to preview changes and `--check` for CI drift detection.

## Safe updates across repos
Run this in each consumer repo to pull managed automation while preserving local edits.
Use an immutable ref (commit SHA preferred, tags supported):
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha>
```

If you want to overwrite all managed files:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --force
```

CI drift check example:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git <commit-sha> --check
```

Pin to a tag:
```bash
scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git v0.1.0
```

You can also pass a local clone path, but updates still come from that clone's `origin` remote (never from local files):
```bash
scripts/agents/update-agent-automation.sh /absolute/path/to/local/agent-automation-kit <tag-or-commit-sha>
```

Branch refs are blocked by default. To allow branch-based updates explicitly:
```bash
AGENT_AUTOMATION_ALLOW_UNPINNED=1 scripts/agents/update-agent-automation.sh https://github.com/<org>/agent-automation-kit.git main
```

The installer stores managed-file hashes in `.agent-automation/state.json` and only auto-updates files that were previously installed and remain unchanged locally.
This means project-tailored files are preserved by default during safe updates.

## What gets installed
- `agents.md`
- `scripts/agents/*`
- core docs for orchestration/rules/templates
- alignment docs:
  - `docs/agent-project-alignment.md`
  - `docs/agent-project-profile.md`
