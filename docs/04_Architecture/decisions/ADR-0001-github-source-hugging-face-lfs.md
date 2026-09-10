# ADR-0001: GitHub Source with Hugging Face LFS Object Storage

- Status: Accepted
- Decision Date: 2026-09-10
- Scope: Repository and large-model artifact storage

## Context

The project needs normal Git history for source and documentation while potentially sharing model artifacts that are unsuitable for ordinary Git object storage. The repository already contains active Git LFS patterns and a `.lfsconfig` endpoint for a private Hugging Face dataset.

## Decision

GitHub is the canonical Git source repository. It stores:

- source code and documentation;
- Git history and configuration;
- ordinary small assets; and
- Git LFS pointer files.

The configured private Hugging Face dataset stores the corresponding large LFS objects.

Local model files that do not need repository sharing may remain outside the working tree, such as under `D:\AI\Models\`.

## Consequences

- A normal GitHub clone obtains Git history and pointer files.
- Retrieving private LFS objects requires appropriate Hugging Face authorization.
- Contributors without access may see pointer files or LFS download failures.
- Model artifacts must be added deliberately; the presence of an LFS pattern is not permission to commit every downloaded model.
- Model licensing, redistribution permission, privacy, repository need, and storage cost must be checked before adding an artifact.
- Credentials and access tokens must remain outside Git and documentation.

## Current Implementation Evidence

- `.gitattributes` routes `*.gguf`, `*.ggml`, `*.safetensors`, `*.onnx`, `*.pt`, `*.pth`, and `*.ckpt` through Git LFS.
- `.lfsconfig` points LFS transfers to the private Hugging Face dataset endpoint.
- `models/lfs-test.gguf` is a test pointer and not a production model.

## Change Control

Changing the storage topology, LFS endpoint, tracked formats, access model, or repository split requires explicit user approval and a new or superseding ADR.

