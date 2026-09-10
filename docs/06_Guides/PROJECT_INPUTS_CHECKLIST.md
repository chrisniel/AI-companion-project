# Project Inputs Checklist for Future Reviews

Provide only the items relevant to the task. Never include real passwords, API keys, access tokens, private certificates, signing keys, raw health records, or private conversations.

## For Every Request

- Exact objective and whether you want read-only review, a documentation edit, or a specific code edit.
- Authorized paths or subsystem, plus anything that must remain untouched.
- Current phase or batch and what changed since the master plan was last updated.
- Expected outcome, acceptance criteria, and any deadline or hardware constraint.
- Relevant files, diff, error text, screenshots, or reproduction steps.
- Commands already run and their actual output; do not summarize away important errors.

## When Providing Google AI Studio Work

- Exported project/source files for the completed batch.
- AI Studio prompt used for that batch.
- Batch number, intended scope, and whether it is UI/UX-only or includes real behavior.
- Short list of features added, changed, or intentionally deferred.
- Screenshots or screen recordings for important visual states when available.
- Known mock values, generated dependencies, environment instructions, and AI Studio-specific metadata.
- Any build/run results from AI Studio, clearly separated from local repository verification.

## Before Backend Foundation Work

- Desired Python version and package/dependency manager, if you have a preference.
- Whether the first delivery should be scaffolding only or include `/api/v1/health`, settings, logging, database setup, and tests.
- Preferred configuration format and local data directory.
- Expected local host/port and approved web origins for CORS.
- Single-user assumptions for V1 and which entities should still include future `user_id` ownership.
- Authentication timing: local-only development first or authentication from the first remote-capable milestone.
- Backup, retention, and privacy expectations for conversations, memories, tasks, logs, and health data.

## Before Local Model Work

- Candidate model names, licenses, quantizations, and approximate sizes.
- Exact local model/runtime paths without credentials.
- Installed llama.cpp build or the desired source/version to evaluate.
- Benchmark priorities: RAM, VRAM, context size, time to first token, tokens/second, gaming coexistence, and idle unload behavior.
- Confirmation that each artifact may legally be downloaded, stored, and redistributed through the configured LFS topology.

## Before Android Import or Integration

- Exported Android project from Google AI Studio.
- Application/package ID, minimum SDK, target SDK, and intended Android versions.
- Current completed batch and unresolved UI states.
- Physical test-device details relevant to layout, notifications, alarms, Bluetooth, microphone, and battery restrictions.
- Health Connect record types actually exposed through the user's device/FitCloudPro setup.
- Required offline behavior and which alarms/tasks must remain available when the PC is off.

## Decisions Still Needed Later

- Backend dependency manager and supported Python version.
- Authentication/session approach before remote exposure.
- Tailscale-only V1 versus another remote gateway.
- Database backup/encryption and retention policy.
- Android application ID and SDK support range.
- Health-data retention, permissions, and deletion behavior.
- License and contribution model.
- Exact LLM, STT, TTS, VAD, and audio providers after real hardware benchmarks.

