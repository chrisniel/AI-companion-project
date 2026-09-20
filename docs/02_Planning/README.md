# Implementation Planning Index (`docs/02_Planning/`)

> **Directory Role:** Canonical catalog for all active feature implementation plans, technical templates, product roadmaps, and post-V1 planning sources.  
> **Status:** Active Canonical (Reconciled in Pass R5)  
> **Authority Precedence:**
> 1. **System Architecture:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md) and domain specifications.
> 2. **Product Delivery Roadmap:** [`docs/02_Planning/ROADMAP.md`](./ROADMAP.md).
> 3. **Active Sprint Execution State:** [`docs/01_Tracking/task.md`](../01_Tracking/task.md).
> 4. **Feature Implementation Plans:** Specific feature plans in this directory control execution steps during feature delivery.

---

## 1. Canonical Product Roadmap

- **[`ROADMAP.md`](./ROADMAP.md):** The single authoritative product and milestone delivery roadmap for the AI Companion ecosystem. Defines active delivery gates, V1 scope boundaries, post-V1 milestone tracks, and technical hardening recommendations.

---

## 2. Active & Upcoming Feature Plans

The plans below represent active engineering hubs and approved implementation plans for currently gated and upcoming work:

| Document Path | Title / Focus Area | Current Classification | Scope & Gate Status | Canonical Authority |
| :--- | :--- | :--- | :--- | :--- |
| [`phase-08/README.md`](./phase-08/README.md) | Phase 8 Planning Hub | **`ACTIVE / CURRENT`** | Active hub for Phase 8. 8A & 8P complete; R0–R8 reconciliation complete & verified; 8B unblocked / next; 8C planned. | Authoritative Phase 8 hub. |
| [`phase-08/plan-phase8-pc-frontend-architecture-ux.md`](./phase-08/plan-phase8-pc-frontend-architecture-ux.md) | Phase 8 Architecture & Multimodal Plan | **`ACTIVE / CURRENT`** | 8A and 8P verified; owns upcoming execution steps for 8B (Multimodal Vision) and 8C (Polish). | Authoritative feature plan for 8B and 8C. |

---

## 3. Planning Starter Templates

| Document Path | Title / Focus Area | Current Classification | Role |
| :--- | :--- | :--- | :--- |
| [`templates/implementation-plan-template.md`](./templates/implementation-plan-template.md) | Feature Implementation Plan Template | **`TEMPLATE`** | Standard 6-section template for drafting new feature-named plans. |

---

## 4. Post-V1 Planning Sources (`post-v1/`)

Exploratory architectural specifications and feature designs deferred beyond the V1 release boundary per Decision D1. See [`post-v1/README.md`](./post-v1/README.md) for authority rules and revalidation guidelines.

| Document Path | Title / Domain | Current Classification | Roadmap Track |
| :--- | :--- | :--- | :--- |
| [`post-v1/PROACTIVE_COMPANION_ROUTINES.md`](./post-v1/PROACTIVE_COMPANION_ROUTINES.md) | Proactive Companion Routines | **`POST-V1 PLANNING SOURCE`** | Post-V1 Routine Track |

---

## 5. Completed Historical Plans (Archived)

Historical planning files from completed engineering tracks (8 cross-cutting root plans, 5 backend plans, and 11 Android prototype plans) have been archived to keep this directory focused on active work:

- **Archive Catalog & Policy:** See [`docs/07_Archive/README.md`](../07_Archive/README.md) and [`docs/07_Archive/plans/`](../07_Archive/plans/).
- **Non-Authoritative Status:** Archived plans represent point-in-time implementation history and are superseded by active source code and canonical domain architecture in [`docs/04_Architecture/`](../04_Architecture/).
