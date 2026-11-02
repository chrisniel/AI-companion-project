"""Character REST endpoints adhering to PC-CHAR-001 and PC-CHAR-005."""

from typing import List
from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_profile_session, get_db
from app.models.profile_session import ProfileSession
from app.schemas.character import (
    ActiveCharacterSelectRequest,
    ActiveCharacterStateOut,
    CharacterInstanceCreate,
    CharacterInstanceOut,
    CharacterInstanceUpdate,
    CharacterPresetOut,
    CharacterTemplateOut,
    NeutralAssistantOut,
)
from app.services.character_service import (
    create_character_instance,
    delete_character_instance,
    get_active_character_state,
    get_neutral_assistant_template,
    get_profile_character_instance,
    list_character_presets,
    list_character_templates,
    list_profile_character_instances,
    reset_to_neutral_assistant,
    select_active_character,
    update_character_instance,
)

router = APIRouter(prefix="/characters", tags=["Characters"])


@router.get(
    "/templates",
    response_model=List[CharacterTemplateOut],
    summary="List Character Templates",
)
async def get_templates(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> List[CharacterTemplateOut]:
    """List application-owned character templates."""
    return await list_character_templates(db)


@router.get(
    "/presets",
    response_model=List[CharacterPresetOut],
    summary="List Character Presets",
)
async def get_presets(
    session: ProfileSession = Depends(get_current_profile_session),
) -> List[CharacterPresetOut]:
    """List frozen eight personality presets."""
    return list_character_presets()


@router.get(
    "/neutral",
    response_model=NeutralAssistantOut,
    summary="Get Neutral Assistant Fallback",
)
async def get_neutral_fallback(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> NeutralAssistantOut:
    """Get immutable Neutral Assistant fallback definition."""
    return await get_neutral_assistant_template(db)


@router.get(
    "/active",
    response_model=ActiveCharacterStateOut,
    summary="Get Active Character State",
)
async def get_active_character(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ActiveCharacterStateOut:
    """Get the active character state for the authenticated Profile."""
    return await get_active_character_state(db, session)


@router.put(
    "/active",
    response_model=ActiveCharacterStateOut,
    summary="Select Active Character",
)
async def set_active_character(
    payload: ActiveCharacterSelectRequest,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ActiveCharacterStateOut:
    """Set active character for the authenticated Profile."""
    return await select_active_character(db, session, payload.character_id)


@router.post(
    "/active/reset-neutral",
    response_model=ActiveCharacterStateOut,
    summary="Reset Active Character to Neutral Assistant",
)
async def reset_active_character(
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> ActiveCharacterStateOut:
    """Reset active character selection to Neutral Assistant fallback."""
    return await reset_to_neutral_assistant(db, session)


@router.get(
    "/instances",
    response_model=List[CharacterInstanceOut],
    summary="List Profile Character Instances",
)
async def get_instances(
    include_archived: bool = Query(True, description="Whether to include archived character instances"),
    include_legacy: bool = Query(False, description="Whether to include preserved legacy placeholders"),
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> List[CharacterInstanceOut]:
    """List character instances owned by the authenticated Profile."""
    return await list_profile_character_instances(
        db, session, include_archived=include_archived, include_legacy=include_legacy
    )


@router.post(
    "/instances",
    response_model=CharacterInstanceOut,
    status_code=status.HTTP_201_CREATED,
    summary="Create Character Instance",
)
async def post_instance(
    payload: CharacterInstanceCreate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> CharacterInstanceOut:
    """Create a new Profile-owned CharacterInstance snapshot from a template."""
    return await create_character_instance(db, session, payload)


@router.get(
    "/instances/{instance_id}",
    response_model=CharacterInstanceOut,
    summary="Get Profile Character Instance",
)
async def get_instance(
    instance_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> CharacterInstanceOut:
    """Get a specific CharacterInstance owned by the authenticated Profile."""
    return await get_profile_character_instance(db, session, instance_id)


@router.patch(
    "/instances/{instance_id}",
    response_model=CharacterInstanceOut,
    summary="Update Profile Character Instance",
)
async def patch_instance(
    instance_id: str,
    payload: CharacterInstanceUpdate,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> CharacterInstanceOut:
    """Update a specific CharacterInstance owned by the authenticated Profile."""
    return await update_character_instance(db, session, instance_id, payload)


@router.delete(
    "/instances/{instance_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Profile Character Instance",
)
async def delete_instance(
    instance_id: str,
    session: ProfileSession = Depends(get_current_profile_session),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Soft-delete/archive a CharacterInstance owned by the authenticated Profile."""
    await delete_character_instance(db, session, instance_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
