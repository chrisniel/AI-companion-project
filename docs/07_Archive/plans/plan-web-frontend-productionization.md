# Implementation Plan: Web Frontend Productionization

Template Version: Docs_ProjectWorkflowStarterKit_v2.0

- Status: Awaiting Future Implementation Approval
- Scope Mode: Refactor and cleanup — preserve the existing UI/UX while preparing it for FastAPI integration
- Target Files: `frontend/web/` source, configuration, tests, and focused documentation to be determined during the authorized implementation task

## 1. Goal and Boundary

Prepare the repository-verified React prototype for real backend integration without redesigning it or changing application architecture outside the web frontend.

This plan is documentation only. It does not authorize code edits, dependency changes, installs, builds, or API implementation.

## 2. Verified Current Baseline

- React 19, TypeScript 5.8, Vite 6, and Tailwind CSS 4 are configured.
- `package-lock.json` exists and is tracked; the old draft claim that a lockfile is missing is resolved.
- `npm run lint` currently runs `tsc --noEmit` and passed on 2026-09-10.
- Navigation is local-state/switch based; React Router is not installed.
- UI components consume mock modules directly; there is no API client, WebSocket client, or repository/service boundary.
- Theme and settings persistence use `localStorage`.
- No tracked automated frontend test suite or CI workflow exists.

## 3. Confirmed Cleanup Backlog

### Priority 1 — Correctness and Safety

- Define or replace the missing `--color-border-strong` and `--color-surface` design tokens.
- Remove application-wide `select-none`; retain it only on controls and navigation where appropriate.
- Guard custom wallpaper uploads by file type/size and handle browser storage failures; evaluate IndexedDB instead of Base64 `localStorage` persistence.
- Remove frontend Gemini-key setup and prevent cloud credentials from entering client code.
- Replace the Unix-only `clean` script before relying on it on Windows.
- Normalize the performance-profile domain to Eco, Balanced, and Maximum; remove the legacy `turbo` compatibility state before shared contracts are fixed.

### Priority 2 — Integration Boundary

- Inventory every mock and hardcoded prototype value.
- Introduce typed repository/service interfaces between views and data sources.
- Keep mock implementations for UI development and add API implementations only after OpenAPI contracts stabilize.
- Centralize environment configuration and add sanitized examples only when actual frontend variables exist.
- Add a production error boundary and explicit loading, empty, offline, disconnected, and retry behavior.

### Priority 3 — Accessibility and Maintainability

- Add modal initial focus, focus trapping, and trigger-focus restoration.
- Complete keyboard navigation and active-option management for the custom Select, or adopt an approved accessible primitive.
- Separate responsive layout recommendations from explicit user overrides.
- Incrementally split very large components at meaningful feature boundaries without fragmenting the UI into trivial wrappers.
- Introduce strict TypeScript options gradually after the current cleanup baseline is stable.

### Priority 4 — Verification Foundation

- Rename the existing typecheck script accurately and add a real lint configuration only if approved.
- Add component, navigation, accessibility, repository-adapter, and responsive tests.
- Verify Light, Dark, and System themes plus background/glass controls at 1280, 1366, 1440, and 1920 widths.
- Run a production build and browser smoke test before backend integration.

## 4. Recommended Implementation Sequence

1. Capture a clean typecheck/build/browser baseline and record existing failures without changing behavior.
2. Fix correctness and credential-boundary issues.
3. Introduce repository/service contracts backed by the existing mocks.
4. Add focused tests around the new boundary and critical UI primitives.
5. Complete accessibility and responsive-state cleanup.
6. Re-run automated and manual checks, then freeze the productionized web baseline.
7. Begin FastAPI integration only through the approved API repository implementations.

## 5. Acceptance Criteria

- [ ] Existing primary views and visual design remain available.
- [ ] No frontend code requests or stores backend/cloud secrets.
- [ ] Mock data is accessed through typed boundaries rather than imported directly by feature views.
- [ ] Eco, Balanced, and Maximum are the only shared performance-profile values.
- [ ] Wallpaper persistence failures are handled without breaking settings.
- [ ] Text content can be selected while controls retain appropriate interaction behavior.
- [ ] Modal and Select keyboard behavior meets the approved accessibility baseline.
- [ ] Typecheck, production build, targeted tests, and desktop viewport checks have recorded results.

## 6. Risks and Rollback

- Risk: Cleanup may unintentionally redesign or destabilize the prototype.
- Mitigation: Work in small approved phases, preserve mock implementations, and compare each phase against the frozen UI baseline.
- Risk: Premature API wiring may couple views to unstable contracts.
- Mitigation: Establish provider/repository interfaces and OpenAPI ownership before adding real network calls.

