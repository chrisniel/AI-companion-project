# Tool Permissions and Actions Architecture

> **Document Role:** Canonical domain architecture specification.
> **Status:** Active Canonical — authority transferred during R11.4.
> **Authority Precedence:** Source code, generated API schemas, and automated test suites remain authoritative for implemented reality. [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) owns cross-cutting product architecture, ecosystem boundaries, and Decisions D1–D11. This focused specification owns normative architecture for its domain. Legacy monolithic architecture documents are subordinate compatibility and technical-reference material.

---

## 1. Purpose & Scope

This specification defines the execution governance, deterministic policy gates, and safety boundaries for assistant tool invocation:
- Five-stage execution pipeline decoupling generative models from raw execution authority.
- `DEFAULT DENY` capability architecture.
- Three-valued deterministic policy evaluation: `ALLOW`, `CONFIRM`, `DENY`.
- Strict rejection of unrestricted generic shell, PowerShell, and OS administration tools.
- Boundaries for narrow, typed privileged actions and deferred interactive browser automation.

---

## 2. Durable Architecture & Invariants

### 2.1 Five-Stage Execution Pipeline (Decision D9, Principle P1)

In accordance with Decision D9 and Principle P1:
- **Zero Model Self-Elevation:** Generative language models have **zero inherent system authority**. An LLM cannot execute tools, read files, or dispatch network requests directly. It can only emit structured text representing an intent.
- **Durable Pipeline:** Every tool action follows a strict deterministic pipeline:
  $$\text{Model} \longrightarrow \text{Typed Request} \longrightarrow \text{Deterministic Policy} \longrightarrow \text{Narrow Adapter} \longrightarrow \text{Capability}$$
  1. **Model:** Emits an intent payload.
  2. **Typed Request:** Schema validation converts raw text into a strictly typed, bounded request object.
  3. **Deterministic Policy:** External security logic outside the LLM evaluates the request against current permissions, profile policy, risk tiers, and (when the action/delivery domain is scheduling- or notification-related) quiet hours.
  4. **Narrow Adapter:** A purpose-built, least-privilege software adapter executes the specific action.
  5. **Capability:** The underlying resource (database, file, or network endpoint) is accessed.

### 2.2 DEFAULT DENY & Policy Outcomes

- **`DEFAULT DENY` Architecture:** Any unrecognized tool call, invalid schema payload, or action lacking an explicit permission rule is unconditionally rejected (`DENY`).
- **Deterministic Outcomes:** Policy evaluation produces one of three distinct outcomes:
  - **`ALLOW`**: The tool may execute automatically without interactive user prompts.
  - **`CONFIRM`**: The tool requires explicit user approval before execution commences.
  - **`DENY`**: The tool execution is blocked and rejected back to the orchestrator.
- **Low-Risk Actions (`ALLOW` Semantics):** Low-risk personal reads, creates, and updates (e.g., retrieving tasks, creating reminders, recording a user memory) **MAY** auto-execute (`ALLOW`) only when the capability is explicitly enabled and deterministic policy permits it. Domain specifications must **not** state that all low-risk operations unconditionally auto-execute.
- **Destructive & External Actions (`CONFIRM` Semantics):** Irreversible actions, state mutations affecting external services, record deletions, or high-risk integrations require explicit user confirmation (`CONFIRM`).

### 2.3 Conceptual Risk Tiers (Decision D9)

Risk tiers represent a conceptual architecture for categorizing operations, **not** a promise that runtime tool implementations currently exist for every listed example:
- **Risk 0 (Read-Only / Information):** Safe, bounded information retrieval (e.g., read-only weather context, public search snippets, listing companion tasks). Risk 0 actions MAY resolve to `ALLOW` when enabled and permitted by deterministic policy. Policy architecture retains `ALLOW` / `CONFIRM` / `DENY`.
- **Risk 1 (Reversible Low-Impact Personal Operations):** Internal personal mutations (e.g., create task, create non-alarm reminder, harmless preference update). Policy may resolve to `ALLOW`, `CONFIRM`, or `DENY`.
- **Risk 2 (Significant State Change):** Significant personal or external state mutations (e.g., delete task/conversation, external message transmission, web form submission, model uninstall, sensitive configuration change). Explicit confirmation required by default. Ordinary destructive deletes are classified as Risk 2, not Risk 3.
- **Risk 3 (Privileged / Prohibited Generic Capabilities):** Privileged or unrestricted generic system capabilities (e.g., arbitrary shell / PowerShell, unrestricted filesystem authority, credential access, raw OS/device administration, network/security reconfiguration). Generic Risk 3 capabilities remain strictly **`REJECTED`**.

### 2.4 Unrestricted OS Shell Prohibited

In accordance with the Feature Promotion Map (**Generic Shell / OS Administration**):
- **Classification:** `REJECTED / NOT STARTED / N/A`.
- **Policy Invariant:** Unrestricted command-line shell execution (e.g., arbitrary `cmd.exe`, PowerShell, Bash, raw OS process spawning, unrestricted filesystem traversal, credential access, or security reconfiguration) is **strictly prohibited** as a generic assistant tool.
- **No PC Later Promotion:** Generic shell tools must **NOT** be classified as `PC LATER` or scheduled for future delivery.
- **Narrow Privileged Actions:** Any future system administration capabilities must be designed as separate, narrow, typed adapters with bounded inputs, explicit confirmation gates, and auditable execution appropriate to the action and security policy.

### 2.5 Interactive Browser Automation Phasing

In accordance with the Feature Promotion Map (**Interactive Browser Automation**):
- **Classification:** `APPROVED / NOT STARTED / PC LATER`.
- **Scope Distinction:** Programmatic browser interaction (e.g., automated form submission, checkout flows, authenticated sessions via Playwright) is classified as a post-PC-V1 capability. It is architecturally separate from read-only search and fetch (PC V1).

---

## 3. Current Verified Implementation

Repository source code establishes the following baseline reality:

- **Conversational Tool Engine Status:** **NOT IMPLEMENTED**. The current backend runtime contains no conversational tool calling engine, no tool dispatcher, and no JSON-schema tool registry.
- **REST Endpoints vs. Tool Engine:** The existing REST API exposes endpoints for tasks (`/api/v1/tasks`), memories (`/api/v1/memories`), and attachments (`/api/v1/conversations/{id}/attachments`). These are standard HTTP CRUD routes invoked directly by client interfaces. They must **not** be mistaken for an automated conversational tool execution policy engine.
- **Model Registry Flags:** `app/schemas/model_registry.py` defines `ModelCapability.tool_calling = "tool_calling"`, but this is a metadata capability flag declaring whether a model architecture supports tool call tokens, not an active execution engine.

---

## 4. Approved Target Architecture / Not Yet Implemented (PC V1)

When implemented for PC V1, the tool permission system establishes durable governance:

1. **Typed Tool Requests:** Strictly typed, validated request objects decoupling model text generation from tool execution.
2. **Deterministic Policy Evaluation:** Authorization logic evaluating tool requests against profile permissions, risk tiers, and domain-specific rules (such as quiet hours for notification/scheduling tools) prior to invocation.
3. **Narrow Adapters:** Purpose-built, least-privilege adapters executing permitted capabilities without generic system authority.
4. **Appropriate Explicit Confirmation:** High-impact or destructive actions (Risk 2) require explicit user confirmation before execution.
5. **Auditable Security & State-Changing Actions:** State-changing or sensitive actions are auditable where required.

---

## 5. OPEN DESIGN

The following technical mechanisms remain open design for future technical specification:

- **Tool Registry Mechanism:** Specific architecture of the tool schema catalog (e.g., centralized registry vs. distributed decorator/adapter registration).
- **Confirmation Channel & Token Design:** Concrete user interaction mechanism for confirmations (e.g., frontend interactive modal, out-of-band token issuance, temporary cryptographic grant).
- **Audit Coverage, Schema & Storage:** Specific audit ledger design, including whether audit logs are persisted in a dedicated SQLite table, file append log, or structured event stream, schema fields, and persistence duration.
- **Resource Bounds & Limiting:** Exact timeout, memory, payload, and concurrency limits are adapter-specific open design.
- **Policy Persistence Schema:** Database schema for storing user permission grants, tool enable/disable toggles, and auto-execute allowances.
- **Permission UX:** User interface presentation for confirmation modals (e.g., diff previews, parameter inspection, and "Always allow for this session" toggles).
- **Tool Cancellation API:** Mechanism allowing users or the orchestrator to cancel an in-flight tool execution cleanly.
- **Narrow Privileged Adapter Designs:** Specification of any narrow, typed administrative tools permitted in future releases.

---

## 6. Security & Ownership Boundaries

- **Prompt Injection Defense (Decision D9):** The deterministic policy engine executes entirely outside the LLM context. Malicious prompts or prompt injections embedded in external data cannot bypass policy evaluation or grant auto-execute status to tools.
- **BOLA Enforcement in Tool Adapters:** Every tool adapter modifying personal records must bind operations strictly to the authenticated `owner_id`.
- **Resource Limits:** Tool adapters must apply appropriate bounded resource controls for their capability and threat model. Exact timeout, memory, payload, and concurrency limits are adapter-specific open design.

---

## 7. Canonical Relationships & Cross-Links

### Upstream Baseline & Legacy Architecture
- [`docs/04_Architecture/SYSTEM_BASELINE.md`](../SYSTEM_BASELINE.md) — Decision D9 (Deterministic tool permissions), Principle P1 (Safe personal actions).
- [`docs/04_Architecture/SECURITY_AND_TRUST_ARCHITECTURE.md`](../SECURITY_AND_TRUST_ARCHITECTURE.md) — Tool risk tiers, execution guardrails, shell prohibition.

### Related Domain & Security Specifications
- [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md) — Orchestration loop and tool response injection.
- [`docs/04_Architecture/02_Data_and_Security/privacy-retention-and-audit.md`](privacy-retention-and-audit.md) — Auditing of tool execution and state-changing actions.
- [`docs/04_Architecture/03_Integrations/web-current-information.md`](../03_Integrations/web-current-information.md) — Read-only web query tool boundaries.
