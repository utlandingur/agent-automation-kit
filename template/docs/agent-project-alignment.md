# Agent Project Alignment Guide

Use this checklist right after installing automation into a new project.

## 1) Initialize Project Context
- Run:
  - `scripts/agents/init-project-context.sh`
- This captures project-specific purpose, validation commands, design baseline, and architecture guardrails.

## 2) Project Identity
- Update `docs/agent-project-profile.md` with:
  - product scope
  - design pattern baseline
  - architecture guardrails
  - non-negotiable contracts
  - hard-stop domains
  - required validation commands

## 3) Policy Alignment
- Update `agents.md`:
  - product-specific constraints
  - decision authority model
  - branch/PR process
  - model usage rules and budget constraints

## 4) Runtime Alignment
- Confirm task lanes exist under `docs/tasks/{todo,doing,blocked,done}`.
- Confirm `.ops/` runtime paths are writable.
- Confirm required CLIs exist (`codex`, `gh`, `git`, `python3`, `rg`).

## 5) Merge and Quality Gates
- Set the project checks command in your operating routine (for example: `yarn lint && yarn test`).
- Confirm branch protection and required checks are configured for your default base branch.

## 6) Dry Run
- Validate scripts:
  - `bash -n scripts/agents/*.sh`
  - `python3 -m py_compile scripts/agents/launch-agent-daemon.py`
- Execute a low-risk smoke run:
  - `scripts/agents/task-board.sh`
  - `scripts/agents/orchestrator-status.sh --brief`

## 7) Update Safety
- Safe update mode preserves local edits:
  - only unchanged managed files are auto-updated
  - project-tailored files (for example `agents.md` and `docs/agent-project-profile.md`) are preserved unless you force overwrite
