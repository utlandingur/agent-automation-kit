# External Skills (Vendored)

These skills were selected from [skills.sh](https://skills.sh) for this project and vendored locally so any agent working in this repository can use them without global installation.

## Location
- `docs/skills/external/`

## Useful Skills Shortlist (for this repo)

| Area | Skill | skills.sh | Status |
|---|---|---|---|
| Next.js app-router quality | `next-best-practices` | <https://skills.sh/vercel-labs/next-skills/next-best-practices> | Installed |
| Next.js caching model | `next-cache-components` | <https://skills.sh/vercel-labs/next-skills/next-cache-components> | Installed |
| Next.js upgrades | `next-upgrade` | <https://skills.sh/vercel-labs/next-skills/next-upgrade> | Installed |
| React implementation quality | `vercel-react-best-practices` | <https://skills.sh/vercel-labs/agent-skills/vercel-react-best-practices> | Installed |
| Web UI/design direction | `web-design-guidelines` | <https://skills.sh/vercel-labs/agent-skills/web-design-guidelines> | Installed |
| Accessibility checks | `accessibility` | <https://skills.sh/addyosmani/web-quality-skills/accessibility> | Installed |
| Web quality audit flow | `web-quality-audit` | <https://skills.sh/addyosmani/web-quality-skills/web-quality-audit> | Installed |
| Browser/manual app testing | `webapp-testing` | <https://skills.sh/anthropics/skills/webapp-testing> | Installed |
| Debugging discipline | `systematic-debugging` | <https://skills.sh/obra/superpowers/systematic-debugging> | Installed |
| TDD discipline | `test-driven-development` | <https://skills.sh/obra/superpowers/test-driven-development> | Installed |
| Completion verification | `verification-before-completion` | <https://skills.sh/obra/superpowers/verification-before-completion> | Installed |
| Branch finish/merge hygiene | `finishing-a-development-branch` | <https://skills.sh/obra/superpowers/finishing-a-development-branch> | Installed |
| Auth integration guardrails | `better-auth-best-practices` | <https://skills.sh/better-auth/skills/better-auth-best-practices> | Installed |
| Postgres operational practices | `supabase-postgres-best-practices` | <https://skills.sh/supabase/agent-skills/supabase-postgres-best-practices> | Installed |

## Installed Skills (local paths)
- `docs/skills/external/vercel-labs/next-best-practices`
- `docs/skills/external/vercel-labs/next-cache-components`
- `docs/skills/external/vercel-labs/next-upgrade`
- `docs/skills/external/vercel-labs/vercel-react-best-practices`
- `docs/skills/external/vercel-labs/web-design-guidelines`
- `docs/skills/external/addyosmani/accessibility`
- `docs/skills/external/addyosmani/web-quality-audit`
- `docs/skills/external/anthropics/webapp-testing`
- `docs/skills/external/obra/systematic-debugging`
- `docs/skills/external/obra/test-driven-development`
- `docs/skills/external/obra/verification-before-completion`
- `docs/skills/external/obra/finishing-a-development-branch`
- `docs/skills/external/better-auth/better-auth-best-practices`
- `docs/skills/external/supabase/supabase-postgres-best-practices`

## Usage Guidance (context minimization)
- Pick at most `1-2` skills per task.
- Read only `SKILL.md` plus directly needed referenced files.
- Use scripts in a skill as black-box tools where available.
- Do not load entire skill folders unless necessary.

## Refresh Procedure
- Re-run sparse checkouts from the source repositories and overwrite these directories.
- Re-check that skill names/paths still match the skills.sh page.

## Notes
- These are third-party artifacts; keep upstream attribution.
- Review upstream changes before refreshing.
