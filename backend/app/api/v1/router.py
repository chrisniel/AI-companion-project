"""Aggregate V1 API routers with true fail-closed architecture."""

from fastapi import APIRouter, Depends

from app.api.deps import verify_token
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.health import public_health_router, system_router
from app.api.v1.endpoints.tasks import router as tasks_router

api_v1_router = APIRouter()

# 1. Explicit Whitelisted Public Router (No token required)
public_router = APIRouter()
public_router.include_router(public_health_router)

# 2. True Fail-Closed Protected Router (Token verified on all routes by construction)
protected_router = APIRouter(dependencies=[Depends(verify_token)])
protected_router.include_router(system_router)
protected_router.include_router(auth_router)
protected_router.include_router(tasks_router)

# Mount both routers under V1 prefix
api_v1_router.include_router(public_router)
api_v1_router.include_router(protected_router)
