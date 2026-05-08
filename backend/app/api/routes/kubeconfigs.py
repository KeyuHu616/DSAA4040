from __future__ import annotations

from fastapi import APIRouter

from backend.app.api.deps import kubeconfig_service


router = APIRouter(prefix="/api/kubeconfigs", tags=["kubeconfigs"])


@router.get("")
def list_kubeconfigs() -> list[dict[str, object]]:
    return [item.__dict__ for item in kubeconfig_service().list_safe_kubeconfigs()]
