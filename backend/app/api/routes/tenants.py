from __future__ import annotations

from fastapi import APIRouter, Body, HTTPException

from backend.app.api.deps import kubectl_service, task_service, validation_service
from backend.app.core.errors import CommandExecutionError, ValidationError


router = APIRouter(prefix="/api/tenants", tags=["tenants"])


@router.get("")
def list_tenants() -> list[dict[str, object]]:
    try:
        namespace_items = kubectl_service().list_namespaces().get("items", [])
    except CommandExecutionError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    results: list[dict[str, object]] = []
    for item in namespace_items:
        metadata = item.get("metadata", {})
        labels = metadata.get("labels", {})
        tenant_name = labels.get("tenant")
        if not tenant_name:
            continue
        results.append(
            {
                "name": metadata.get("name"),
                "tenant": tenant_name,
                "status": item.get("status", {}).get("phase"),
                "labels": labels,
            }
        )
    return results


@router.get("/{tenant}")
def get_tenant(tenant: str) -> dict[str, object]:
    tenant = _validated_tenant(tenant)
    return {
        "tenant": tenant,
        "resourcequota": _resource(tenant, "resourcequota"),
        "limitrange": _resource(tenant, "limitrange"),
        "networkpolicies": _resource(tenant, "networkpolicy"),
        "rolebindings": _resource(tenant, "rolebinding"),
        "pods": _resource(tenant, "pods"),
        "services": _resource(tenant, "services"),
    }


@router.post("/{tenant}/onboard")
def onboard_tenant(tenant: str) -> dict[str, object]:
    tenant = _validated_tenant(tenant)
    record = task_service().start_background_action("onboard-team", args=[tenant], timeout_seconds=300)
    return record.__dict__


@router.post("/{tenant}/offboard")
def offboard_tenant(tenant: str, payload: dict[str, str] = Body(default_factory=dict)) -> dict[str, object]:
    try:
        tenant = validation_service().validate_confirmed_tenant(tenant, payload.get("confirm_tenant", ""))
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    record = task_service().start_background_action("offboard-team", args=[tenant], timeout_seconds=300)
    return record.__dict__


@router.get("/{tenant}/resourcequota")
def tenant_resourcequota(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "resourcequota")


@router.get("/{tenant}/limitrange")
def tenant_limitrange(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "limitrange")


@router.get("/{tenant}/networkpolicies")
def tenant_networkpolicies(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "networkpolicy")


@router.get("/{tenant}/rolebindings")
def tenant_rolebindings(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "rolebinding")


@router.get("/{tenant}/pods")
def tenant_pods(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "pods")


@router.get("/{tenant}/services")
def tenant_services(tenant: str) -> dict[str, object]:
    return _resource(_validated_tenant(tenant), "services")


def _validated_tenant(tenant: str) -> str:
    try:
        return validation_service().validate_tenant_name(tenant)
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _resource(tenant: str, resource: str) -> dict[str, object]:
    try:
        return kubectl_service().list_resource(tenant, resource)
    except CommandExecutionError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
