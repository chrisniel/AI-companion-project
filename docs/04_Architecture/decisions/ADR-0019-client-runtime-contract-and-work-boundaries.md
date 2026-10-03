# Client ↔ Runtime Contract & Work Boundaries

**Status:** Accepted  
**Decision ID:** ADR-0019  
**Codification Date:** 2026-10-03  
**Primary Canonical Owner:** [`assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md)  
**Related Specifications:** [`windows-host-and-notifications.md`](../04_Infrastructure/windows-host-and-notifications.md), [`voice-and-audio.md`](../01_Domains/voice-and-audio.md)

## Decision History
- Approved during PC V1 Architecture Decision Pass (2026-10-03).
- Recorded in Master Decision Register (`DECISION_REGISTER.md`, Row 24).

## Context
With multiple clients planned or supported (Flutter Desktop primary, React Web harness, Android satellite reference), a clean, unambiguous architectural contract is required between client applications and the Local AI Runtime. Without strict boundaries, race conditions, fragmented state management, and lost in-flight responses occur when clients disconnect, reload, or crash during local inference.

## Decision
- **Protocol Taxonomy:**
  - **REST/JSON:** Used for all discrete commands, mutations, configuration updates, and query endpoints.
  - **Server-Sent Events (SSE):** Used for uni-directional streaming of LLM token responses and asynchronous companion events to clients.
  - **WebSocket:** Dedicated duplex channel for conversational voice mode (audio chunk streaming, real-time VAD events, barge-in signaling).
- **Single Contract Authority:** The FastAPI auto-generated OpenAPI JSON contract (`/openapi.json`) serves as the single source of truth for all API definitions, request/response models, and status codes.
- **Durable Turn Queue:**
  - The runtime hosts a server-side durable FIFO turn queue.
  - Conversational turns submitted by clients are assigned a `turn_id` and queued.
  - If a client disconnects or closes during inference, the runtime completes the turn and commits the assistant response and tool side effects to the database.
  - The client retrieves the completed state upon reconnecting via REST or SSE replay.
- **Work Boundary Separation:**
  - **Client Responsibilities:** UI rendering, user input collection, local audio capture/playback hardware control, and native toast presentation.
  - **Runtime Responsibilities:** Model management, local LLM/VLM inference, tool policy execution, memory extraction/retrieval, speech recognition, speech synthesis, and background scheduling.

## Consequences
- Clean separation allows clients in Dart/Flutter, TypeScript/React, or Kotlin/Android to interact with the runtime interchangeably.
- In-flight inference responses are never lost due to UI restarts or browser window closures.
- Hardware audio drivers remain on the native client side, preventing audio server dependencies in the Python backend.

## Canonical Relationships
Normative authority for client-runtime orchestration resides in [`docs/04_Architecture/01_Domains/assistant-and-conversations.md`](../01_Domains/assistant-and-conversations.md).

## Change Control
Modifying communication protocols or work boundaries requires an approved contract revision and regression testing across supported clients.
