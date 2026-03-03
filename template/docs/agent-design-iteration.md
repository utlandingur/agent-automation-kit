# Agent Design Iteration Protocol (v2)

Goal: make AI-designed UI feel product-grade, not template-grade.

## Inputs (required)
- 2-3 live product references (screenshots/flows) relevant to the task.
- 1 explicit user goal statement for the screen.
- 1 measurable success signal for the screen (clarity/time-to-complete/error rate).

## Multi-Role Critique (required)
Run critique in 3 roles before presenting:
- `UX`: hierarchy, clarity, cognitive load, forward/backward certainty.
- `Visual`: typography rhythm, spacing consistency, contrast, perceived quality.
- `Engineer`: implementation simplicity, token reuse, maintainability.

If any role fails, iterate again. Do not present to user.

## Hard Fail Rules
- No nested decorative surfaces (`card inside card inside card`) unless functionally required.
- One primary CTA per screen state.
- Mobile-first spacing and tap targets must remain clear.
- Input labels/help text must be concise and specific.
- Avoid repeated generic patterns (same selector block reused across iterations).
- Do not add new visual tokens until user approves the direction.
- If user flags a pattern as bad, that pattern is banned for the next iteration set.
- For explicitly creative tasks with no finalized pattern, do not reuse existing in-repo patterns as concept seeds.
- If patterns are finalized and approved, reuse them by default.

## Iteration Loop (required)
1. Produce at least 2 materially different concepts.
2. Screenshot desktop + mobile for each.
3. Critique with the 3-role pass.
4. Keep only the best concept and iterate one more time.
5. Re-check against user feedback bans.
6. Present only post-critique outputs.

## Acceptance Checklist
- Distinct from previous rejected pattern.
- Visual hierarchy is obvious in first 2 seconds.
- No unnecessary layers or borders.
- Back/next flow is explicit.
- Lint/types pass after changes.
- Copy is globally understandable (Duolingo “global user” bar).
- Design can be tested quickly (prototype/screenshot/usability loop ready).

## References used for this protocol
- Figma critique practice: https://www.figma.com/blog/design-critiques-at-figma/
- Duolingo collaboration method: https://www.figma.com/blog/the-method-duolingo/
- Duolingo product principles: https://blog.duolingo.com/product-principles/
- Anthropic agent workflow guidance: https://www.anthropic.com/engineering/building-effective-agents
- Anthropic prompt/eval practice for reliable outcomes: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview
