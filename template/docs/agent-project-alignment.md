# Agent Project Alignment Guide

Use this checklist right after installing automation into a new project.

## 1) Project Identity
- Update `docs/agent-project-profile.md` with:
  - product scope
  - non-negotiable contracts
  - hard-stop domains
  - required validation commands

## 2) Policy Alignment
- Update `agents.md`:
  - product-specific constraints
  - decision authority model
  - branch/PR process
  - model usage rules and budget constraints

## 3) Runtime Alignment
- Confirm task lanes exist under `docs/tasks/{todo,doing,blocked,done}`.
- Confirm `.ops/` runtime paths are writable.
- Confirm required CLIs exist (`codex`, `gh`, `git`, `python3`, `rg`).

## 4) Merge and Quality Gates
- Set the project checks command in your operating routine (for example: `yarn lint && yarn test`).
- Confirm branch protection and required checks are configured for your default base branch.

## 5) Dry Run
- Validate scripts:
  - `bash -n scripts/agents/*.sh`
  - `python3 -m py_compile scripts/agents/launch-agent-daemon.py`
- Execute a low-risk smoke run:
  - `scripts/agents/task-board.sh`
  - `scripts/agents/orchestrator-status.sh --brief`
