# Project Inputs Checklist for Future Tasks & Reviews

> **Document Role:** Operational checklist for contributors and users when preparing task requests, feature inputs, and reviews.
> **Status:** Active Canonical Guide
> **Normative Authority:** [`docs/04_Architecture/SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md), [`docs/02_Planning/ROADMAP.md`](../02_Planning/ROADMAP.md), and relevant domain architecture.

Provide only the items relevant to the specific task. Never include real passwords, API keys, access tokens, private certificates, signing keys, raw health records, or private user conversations.

---

## 1. For Every Request

- Exact objective and whether you want read-only inspection, an architecture review, a documentation edit, or a specific code edit.
- Authorized target paths or subsystem, plus anything that must remain untouched.
- Current milestone/phase and any divergence from [`SYSTEM_BASELINE.md`](../04_Architecture/SYSTEM_BASELINE.md), [`ROADMAP.md`](../02_Planning/ROADMAP.md), or domain architecture.
- Expected outcome, acceptance criteria, and any deadline or hardware constraint.
- Relevant files, diffs, error logs, screenshots, or reproduction steps.
- Commands already run and their actual output; do not summarize away important error traces.

---

## 2. Before Backend / Runtime Changes

- Specific API route or data model affected, and contract impact on `contracts/openapi/openapi.json`.
- Database schema changes requiring new Alembic revisions (must follow non-destructive migration rules).
- Storage root awareness: changes must respect canonical path derivation via `storage.py` (`COMPANION_DATA_ROOT`).
- Authentication boundary impact: protected routes require `verify_token` dependency.
- Test coverage requirements (unit tests in `backend/tests/` and contract verification via `check_openapi_contract.py`).

---

## 3. Before Local Model / Runtime Work

- Candidate model filenames, licenses, architectures, and quantizations.
- Exact local model paths without credentials or private host information.
- Installed `llama.cpp` build version or candidate binary to evaluate.
- Benchmark metrics: RAM, VRAM, context size, time to first token, tokens/second, gaming coexistence, and idle unload behavior.
- Confirmation that model artifacts may legally be downloaded, stored, and redistributed through configured repository and LFS topology.

---

## 4. Before Android Productionization or Offline Work

- Specific component, screen, or domain repository under modification.
- Physical test-device specifications relevant to display, refresh rate, notifications, alarms, and battery restrictions.
- Packaging alignment: acknowledgment of prototype package (`com.example`) vs target Decision D3 (`com.cnl.aicompanion`).
- Offline requirements and which alarms, tasks, or local summaries must remain functional when disconnected from the PC host.
- Health Connect record types and device-specific permission requirements.

---

## 5. Genuinely Open Future Design Inputs

The following topics represent genuinely open architectural and implementation designs that require dedicated future planning:

- **Windows Persistent Host Launch Mechanism:** Exact Windows service, background daemon, system tray runner, or scheduled task launch wrapper for the Local AI Runtime.
- **Device Pairing Protocol (Decision D4):** Specific cryptographic enrollment protocol, pairing exchange UX (e.g., QR code or temporary code), and credential rotation interval.
- **Android Synchronization Protocol:** Specific conflict-resolution algorithm, mutation queue replay mechanics, and state reconciliation schema.
- **Mobile Offline Inference Policy:** Final compact model selection (~0.5B–1.5B), quantization format, and minimum hardware requirements for on-device mobile LLM execution.
- **Voice Engine Selection:** Universal default TTS and STT engines following empirical Windows and Android benchmark evidence (evaluating Kokoro, Piper, KittenTTS, Whisper-family, etc.).
- **Controlled Local Model Importer (Decision D6):** Specific user interaction flow (e.g., folder drop + scan, import wizard, or CLI/API tool), duplicate resolution, and checksum validation details.
- **Tool Confirmation & Audit Schemas (Decision D9):** Concrete UI confirmation schemas, interactive confirmation timeout behavior, and permanent audit retention policies for Risk 1+ events.
- **Backup & Encryption Policies:** Automated backup schedules, encrypted export formats, and disaster recovery procedures for persistent user data.
- **Release, Licensing & Distribution:** Formal open-source or proprietary licensing model, distribution packaging, and contribution governance.
