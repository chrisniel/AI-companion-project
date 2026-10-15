"""Aggregate V1 API routers with true fail-closed architecture."""

from fastapi import APIRouter, Depends

from app.api.deps import get_current_profile_session, require_host_admin
from app.api.v1.endpoints.profiles import router as profiles_router
from app.api.v1.endpoints.attachments import router as attachments_router
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.conversations import router as conversations_router
from app.api.v1.endpoints.health import public_health_router, system_router
from app.api.v1.endpoints.llm import router as llm_router
from app.api.v1.endpoints.memories import router as memories_router
from app.api.v1.endpoints.tasks import router as tasks_router

api_v1_router = APIRouter()

# 1. Explicit Whitelisted Public Router (No token required)
public_router = APIRouter()
public_router.include_router(public_health_router)

# 2. True Fail-Closed Protected Router (Token verified on all routes by construction)
protected_router = APIRouter(dependencies=[Depends(get_current_profile_session)])
protected_router.include_router(tasks_router)
protected_router.include_router(conversations_router, prefix="/conversations", tags=["Conversations"])
protected_router.include_router(attachments_router, prefix="/conversations", tags=["Attachments"])
protected_router.include_router(memories_router, prefix="/memories", tags=["Memories"])

# Mount both routers under V1 prefix
api_v1_router.include_router(public_router)
api_v1_router.include_router(protected_router)
api_v1_router.include_router(system_router, dependencies=[Depends(require_host_admin)])
# Mixed authority routers assign explicit dependencies per operation.
api_v1_router.include_router(auth_router)
api_v1_router.include_router(profiles_router)
api_v1_router.include_router(llm_router)
