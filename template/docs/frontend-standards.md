# Frontend Standards (2026)

Goal: modern, stable, high-performance frontend behavior with predictable error handling.

## Error Handling Model
- Treat expected errors as data/state (not thrown exceptions).
- Use route-level error boundaries for unexpected failures.
- Keep user-facing errors concise, actionable, and non-leaky.
- For framework-controlled throws (for example redirects/not-found behavior), preserve framework behavior; do not swallow internal control-flow exceptions.

## UX Reliability Rules
- Loading states must keep layout stable (avoid content jumps).
- Reserve space for async content to prevent CLS regressions.
- Never block primary flow on non-critical UI.

## Performance Rules
- Track and protect Core Web Vitals:
  - LCP, INP, CLS
- Prefer server-first data loading patterns and avoid client waterfalls.
- Use progressive loading/Suspense boundaries for long-running segments.
- Minimize JS shipped to client and defer non-critical work.

## Accessibility Rules
- Keyboard interaction coverage for all actionable controls.
- Visible focus states.
- Semantic markup and clear labels.

## Test Expectations
- Unit tests for view state/error mapping logic.
- E2E tests for critical user journeys and failure paths.
