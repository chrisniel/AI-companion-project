# AI Companion — React Web Desktop Client

> **Document Role:** Operational quickstart and subsystem orientation for the React Web desktop control center.
> **Status:** Active Operational Quickstart
> **Normative Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../../docs/04_Architecture/SYSTEM_BASELINE.md) and [`docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md`](../../docs/02_Planning/phase-08/plan-phase8-pc-frontend-architecture-ux.md).
> **Canonical Setup Guide:** [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../../docs/06_Guides/DEVELOPMENT_SETUP.md).
> **Canonical Verification Guide:** [`docs/06_Guides/TESTING_AND_CI.md`](../../docs/06_Guides/TESTING_AND_CI.md).

The primary desktop client for the **AI Companion Project**, built with **React 19, TypeScript 5.8, Vite 6, Tailwind CSS 4, and Motion**. It provides the local PC control center, model lifecycle controls, streaming conversation workspace, memory inspection, and personal task management.

---

## Role & System Boundary

- **Primary Desktop Interface:** Serves as the primary user interface in V1, communicating with the local FastAPI backend (**Local AI Runtime**) at `http://127.0.0.1:8000` via REST and live Server-Sent Events (SSE).
- **Process Independence (Decision D2):** The Local AI Runtime runs as an independent Windows host process. Closing the browser tab does not terminate backend processes, inference jobs, or data transactions.
- **Direct Local Communication:** All assistant interactions, model discovery, memory queries, and task updates stream directly from the local backend host. Cloud API keys are not required for local operation.

---

## Quickstart (Windows PowerShell)

For complete development setup instructions and prerequisites, consult [`docs/06_Guides/DEVELOPMENT_SETUP.md`](../../docs/06_Guides/DEVELOPMENT_SETUP.md).

### 1. Install Dependencies
```powershell
cd frontend/web
npm install
```

### 2. Start Development Server
```powershell
npm run dev
```
- Local Web Application: `http://localhost:3000` (or `http://127.0.0.1:3000`)
- Connects automatically to Local AI Runtime on `http://127.0.0.1:8000`.

### 3. Verification & Build Commands

```powershell
# Run Vitest component & unit test suite
npm test

# Run TypeScript static compilation & typecheck
npm run lint

# Build production bundle
npm run build

# Preview production build locally
npm run preview
```

For test standards and CI gate details, consult [`docs/06_Guides/TESTING_AND_CI.md`](../../docs/06_Guides/TESTING_AND_CI.md).
