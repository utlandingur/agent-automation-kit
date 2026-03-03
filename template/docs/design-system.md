# Design System (Agent Guide)

Goal: keep UI consistent, accessible, and fast to implement.

## Principles
- Prefer existing components/patterns over new abstractions.
- Keep UI decisions deterministic and token-efficient.
- Optimize for clarity first, styling second.
- Default style authority for product UI:
  - [`docs/style-guide-spectrum.md`](/Users/lukehening/Sites/repos/moolang/docs/style-guide-spectrum.md)
- Legacy inspiration reference:
  - [`docs/style-guide-duolingo-inspired.md`](/Users/lukehening/Sites/repos/moolang/docs/style-guide-duolingo-inspired.md)
- Creative exception: if user says no finalized pattern exists, generate net-new concepts first; do not reuse old pattern layouts.
- Once a pattern is approved/finalized, reuse it consistently.
- Follow brand direction in:
  - [`docs/brand-brief.md`](/Users/lukehening/Sites/repos/moolang/docs/brand-brief.md)
- For AI-led UI work, follow:
  - [`docs/agent-design-iteration.md`](/Users/lukehening/Sites/repos/moolang/docs/agent-design-iteration.md)

## Styling Rules
- Use design tokens only (Tailwind theme classes / shared variables).
- No hard-coded colors, spacing systems, or one-off visual systems.
- Reuse existing component variants before adding new ones.
- For guide-create flow use shared tokenized classes in `app/globals.css`:
  - `.flow-panel`
  - `.flow-chip`
  - `.flow-title`
  - `.flow-subtitle`
  - `.flow-label`
  - `.flow-textarea`
  - `.flow-actions`
- Do not recreate ad-hoc panel classes when these cover the case.

## Component Rules
- Build from existing `components/ui/*` primitives first.
- Add new shared primitives only when reused by 2+ features.
- For new UI, prioritize Spectrum-aligned patterns/components over shadcn-specific patterns.
- Build new shared primitives when essential.
- Keep feature-specific UI inside feature folders.

## Interaction Rules
- Keyboard and focus-visible support are required.
- Preserve stable layouts during loading.
- Errors must be actionable and non-ambiguous.

## State & UX Patterns
- One clear primary action per step.
- Use explicit staged flows for multi-step tasks.
- Do not hide critical state transitions.
- Avoid nested decorative layers (`card-inside-card`) unless functionally required.
- Prefer one-focus-per-screen flows for core learning creation.

## Copy Rules
- Keep microcopy short and concrete.
- Avoid jargon in user-facing text.
- Error text should say what failed and what to do next.

## When Changing UX
- Major UX decisions require explicit user approval (per governance).
- Record major UX decisions in:
  - [`docs/decisions/`](/Users/lukehening/Sites/repos/moolang/docs/decisions/)

## Definition of UI Done
- Uses tokens + shared patterns
- Pattern maps to Spectrum guidance (or documented adaptation)
- Accessible keyboard/focus behavior verified
- Loading/error states implemented
- Relevant tests/docs updated
