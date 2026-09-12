"""Endpoints for LLM model inspection and chat completions."""

import json
import time
import uuid
from typing import AsyncGenerator, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse

from app.api.deps import verify_token
from app.schemas.llm import (
    ChatCompletionChoice,
    ChatCompletionDelta,
    ChatCompletionRequest,
    ChatCompletionResponse,
    ChatCompletionStreamChoice,
    ChatCompletionStreamChunk,
    ChatCompletionUsage,
    ChatMessage,
    ModelLoadRequest,
    ModelProfileUpdateRequest,
    ModelStatusResponse,
)
from app.services.llm.base import BaseLLMProvider
from app.services.llm.manager import get_llm_provider

router = APIRouter()


@router.get(
    "/models",
    response_model=ModelStatusResponse,
    summary="Get LLM model status and hardware profiles",
    dependencies=[Depends(verify_token)],
)
async def get_model_status(
    provider: BaseLLMProvider = Depends(get_llm_provider),
) -> ModelStatusResponse:
    """Return active model, loaded state, VRAM profile, and available GGUF files."""
    return await provider.get_status()


@router.post(
    "/models/load",
    response_model=ModelStatusResponse,
    summary="Load LLM model into VRAM",
    dependencies=[Depends(verify_token)],
)
async def load_model(
    request: Optional[ModelLoadRequest] = None,
    provider: BaseLLMProvider = Depends(get_llm_provider),
) -> ModelStatusResponse:
    """Load model weights into GPU VRAM or memory."""
    model_name = request.model_name if request else None
    profile = request.profile if request else None
    success = await provider.load_model(model_name=model_name, profile=profile)
    if not success:
        error_msg = getattr(provider, "_last_error", None) or "Failed to load model into memory."
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_msg,
        )
    return await provider.get_status()


@router.post(
    "/models/unload",
    response_model=ModelStatusResponse,
    summary="Unload LLM model and release VRAM",
    dependencies=[Depends(verify_token)],
)
async def unload_model(
    provider: BaseLLMProvider = Depends(get_llm_provider),
) -> ModelStatusResponse:
    """Unload model from GPU memory to free VRAM immediately."""
    await provider.unload_model()
    return await provider.get_status()


@router.patch(
    "/models/profile",
    response_model=ModelStatusResponse,
    summary="Update hardware performance profile",
    dependencies=[Depends(verify_token)],
)
async def update_profile(
    request: ModelProfileUpdateRequest,
    provider: BaseLLMProvider = Depends(get_llm_provider),
) -> ModelStatusResponse:
    """Switch hardware profile (eco, balanced, maximum)."""
    success = await provider.set_profile(request.profile)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid hardware profile '{request.profile}'.",
        )
    return await provider.get_status()


@router.post(
    "/chat/completions",
    response_model=ChatCompletionResponse,
    summary="Generate chat completions (streaming or synchronous)",
    dependencies=[Depends(verify_token)],
)
async def create_chat_completion(
    request: ChatCompletionRequest,
    provider: BaseLLMProvider = Depends(get_llm_provider),
):
    """Generate conversational completions matching OpenAI API format.
    
    Supports Server-Sent Events (SSE) streaming with `stream: true`.
    """
    if not request.messages:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Messages list cannot be empty.",
        )

    completion_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
    created_ts = int(time.time())
    model_name = request.model or (await provider.get_status()).active_model or "default"

    # Streaming mode (SSE)
    if request.stream:
        async def event_stream() -> AsyncGenerator[str, None]:
            # Initial delta with role
            first_chunk = ChatCompletionStreamChunk(
                id=completion_id,
                created=created_ts,
                model=model_name,
                choices=[
                    ChatCompletionStreamChoice(
                        index=0,
                        delta=ChatCompletionDelta(role="assistant"),
                    )
                ],
            )
            yield f"data: {first_chunk.model_dump_json()}\n\n"

            # Content token deltas
            try:
                async for token in provider.generate_stream(
                    messages=request.messages,
                    temperature=request.temperature,
                    max_tokens=request.max_tokens or 1024,
                ):
                    chunk = ChatCompletionStreamChunk(
                        id=completion_id,
                        created=created_ts,
                        model=model_name,
                        choices=[
                            ChatCompletionStreamChoice(
                                index=0,
                                delta=ChatCompletionDelta(content=token),
                            )
                        ],
                    )
                    yield f"data: {chunk.model_dump_json()}\n\n"
            except Exception as e:
                error_payload = {"error": {"message": str(e), "type": "runtime_error"}}
                yield f"data: {json.dumps(error_payload)}\n\n"

            # Final stop chunk
            stop_chunk = ChatCompletionStreamChunk(
                id=completion_id,
                created=created_ts,
                model=model_name,
                choices=[
                    ChatCompletionStreamChoice(
                        index=0,
                        delta=ChatCompletionDelta(),
                        finish_reason="stop",
                    )
                ],
            )
            yield f"data: {stop_chunk.model_dump_json()}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(
            event_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    # Synchronous mode (JSON)
    try:
        content = await provider.generate(
            messages=request.messages,
            temperature=request.temperature,
            max_tokens=request.max_tokens or 1024,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference error: {str(e)}",
        )

    # Approximate token counts
    prompt_chars = sum(len(m.content) for m in request.messages)
    prompt_tokens = max(1, prompt_chars // 4)
    completion_tokens = max(1, len(content) // 4)

    return ChatCompletionResponse(
        id=completion_id,
        created=created_ts,
        model=model_name,
        choices=[
            ChatCompletionChoice(
                index=0,
                message=ChatMessage(role="assistant", content=content),
                finish_reason="stop",
            )
        ],
        usage=ChatCompletionUsage(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=prompt_tokens + completion_tokens,
        ),
    )
