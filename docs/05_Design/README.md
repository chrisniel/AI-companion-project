# Design Documentation Hub & Architectural Boundaries

> **Document Role:** Design documentation navigation hub and design-vs-architecture boundary specification.  
> **Status:** Active Baseline (Pass R11.0)  
> **Authority Precedence:** Technical authority, domain models, and product invariants are owned by [`docs/04_Architecture/`](../04_Architecture/). Active sprint execution is tracked in [`docs/01_Tracking/task.md`](../01_Tracking/task.md).

---

## 1. Architecture vs. Design Boundary

This repository maintains a strict boundary between Architecture and Design:

| Dimension | Primary Focus | Boundary / Ownership |
| :--- | :--- | :--- |
| **Architecture (`docs/04_Architecture/`)** | **WHAT the concept means** & durable domain behavior | Owns business semantics, data models, persistence invariants, security boundaries, and runtime authority. |
| **Design (`docs/05_Design/`)** | **HOW the person experiences it** | Defines user interface presentation, visual language, interaction patterns, accessibility, and sensory presentation. |

### Concrete Boundary Examples

1. **Tasks & Reminders:**
   - **Architecture:** A standalone Reminder may exist without an associated Task (Decision D10). Tasks own stateful completion lifecycles and schedule associations.
   - **Design:** How standalone Reminders and Task reminders are grouped, color-coded, prioritized, and displayed in the Schedule / Calendar UI.
2. **Companion Emotion & Mood:**
   - **Architecture:** Emotion is lightweight, transient, conceptual companion state that influences conversational tone without blocking system execution (Decision D11).
   - **Design:** How companion emotional tone is visually expressed to the user (e.g., subtle avatar portrait expressions, ambient accent lighting, typography nuances, or status indicators).
3. **Tool Execution Confirmation:**
   - **Architecture:** Low-risk personal actions may resolve to `ALLOW`, `CONFIRM`, or `DENY` based on deterministic profile policy; destructive or external actions require confirmation (Decision D9).
   - **Design:** How the confirmation dialogue or inline prompt is presented, visually structured, and dismissed without disrupting conversation flow.

---

## 2. Invariants for Design Specifications

Design documents authored under `docs/05_Design/` must adhere to these invariants:

1. **Design Does Not Redefine Architecture:** Design specifications must **never** redefine:
   - Data ownership or entity models
   - Security policies or permission gates
   - Persistence authority or database schemas
   - Backend system authority or API contracts
   - Release allocation (e.g., PC V1 vs. Android V1)
   - Canonical product invariants
2. **Cross-Reference Architecture:** Design documents must explicitly cross-reference the relevant architectural domain specification in [`docs/04_Architecture/`](../04_Architecture/) for technical semantics and constraints.
3. **No Premature Specification:** Detailed UX screen designs, wireframes, and component specs are developed against approved architectural domains, not ahead of them.
