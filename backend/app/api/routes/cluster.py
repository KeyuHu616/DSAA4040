from __future__ import annotations

from fastapi import APIRouter, HTTPException

from backend.app.api.deps import environment_service, kubectl_service
from backend.app.core.errors import CommandExecutionError


router = APIRouter(prefix="/api/cluster", tags=["cluster"])


@router.get("/health")
def get_cluster_health() -> dict[str, object]:
    return environment_service().get_cluster_health()


@router.get("/nodes")
def get_nodes() -> dict[str, object]:
    try:
        return kubectl_service().list_nodes()
    except CommandExecutionError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/namespaces")
def get_namespaces() -> dict[str, object]:
    try:
        return kubectl_service().list_namespaces()
    except CommandExecutionError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
