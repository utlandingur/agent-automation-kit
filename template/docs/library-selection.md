# Library Selection Policy

Goal: use libraries only where they provide clear leverage.

## Rule
- For complex domains (auth, payments, advanced editors, realtime, feature flags, observability), evaluate current maintained libraries before implementing custom code.
- For simple/local tasks, implement directly without adding dependencies.

## Required Process (Complex Domains)
1. Check current options using official docs (and release/maintenance signals) at task start.
2. Prefer well-maintained libraries with:
   - active releases
   - clear migration docs
   - security posture
   - framework compatibility
3. Record choice and rationale in `docs/decisions/`.

## Default Bias
- Use a library when complexity/risk is high.
- Write code directly when the task is straightforward and low-risk.

## Anti-Patterns
- Adding a dependency for trivial helpers.
- Building custom auth/payment frameworks when mature options fit.
- Choosing unmaintained libraries without an explicit exception record.
