"""Authenticated API shared by the Admin and Student Flutter applications."""
from fastapi import APIRouter, Depends, HTTPException

from ..auth import AuthenticatedUser, get_current_user
from .models import CapabilityPlanRequest
from .registry import CapabilityRegistryError, get_capability_registry

router = APIRouter(prefix="/v1/capabilities", tags=["capabilities"])


@router.get("")
async def list_capabilities(
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    del user
    registry = get_capability_registry()
    return {
        "schema_version": registry.catalog.schema_version,
        "reviewed_at": registry.catalog.reviewed_at,
        "zero_cost_policy": registry.catalog.policy.model_dump(),
        "capabilities": registry.list_capabilities(),
    }


@router.post("/plan")
async def plan_capability(
    request: CapabilityPlanRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    del user
    try:
        return get_capability_registry().plan(request).model_dump()
    except CapabilityRegistryError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/{capability_id}")
async def get_capability(
    capability_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    del user
    result = get_capability_registry().get_capability(capability_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Capability inconnue : {capability_id}")
    return result

