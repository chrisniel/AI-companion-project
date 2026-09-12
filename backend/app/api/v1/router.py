"""Aggregate V1 API routers with default-deny authentication architecture."""

from fastapi import APIRouter, Depends
from app.api.deps import verify_token
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.tasks import router as tasks_router

api_v1_router = APIRouter()

# 1. Explicitly Public Routes (Health check liveness probe)
api_v1_router.include_router(health_router)

# 2. Authenticated-by-Default Sub-Routers (Enforced at router inclusion boundary)
api_v1_router.include_router(auth_router, dependencies=[Depends(verify_token)])
api_v1_router.include_router(tasks_router, dependencies=[Depends(verify_token)])

