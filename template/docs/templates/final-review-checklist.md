# Final Review Checklist

Use this for feature sign-off before merge.

## Scope Lock
- [ ] Scope frozen (no new features)
- [ ] Branch synced with latest target branch (`main` or `staging`)

## Quality Gates
- [ ] `yarn lint` pass
- [ ] `yarn test` pass
- [ ] required E2E pass

## Acceptance Criteria
- [ ] All ticket acceptance criteria verified
- [ ] No unresolved blockers in coordination thread

## UI Verification (if UI impact)
- [ ] Desktop screenshots captured
- [ ] Mobile screenshots captured
- [ ] Loading/error/empty states captured
- [ ] Matches `docs/design-system.md`
- [ ] Matches `docs/frontend-standards.md`
- [ ] Design Review Agent sign-off recorded

## Accessibility Spot Check
- [ ] Keyboard flow verified
- [ ] Focus visibility verified
- [ ] Basic semantics/labels verified

## Decisions & Docs
- [ ] Major decisions recorded in `docs/decisions/`
- [ ] Any major UX decision has explicit user approval

## Merge Readiness
- [ ] Reviewer recommendation: approve / changes required
- [ ] Lead orchestrator final go/no-go recorded
