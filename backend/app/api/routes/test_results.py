from __future__ import annotations

from fastapi import APIRouter, HTTPException

from backend.app.api.deps import artifact_service
from backend.app.core.errors import ValidationError


router = APIRouter(prefix="/api/test-results", tags=["test-results"])


@router.get("")
def list_test_results() -> list[dict[str, object]]:
    return [item.__dict__ for item in artifact_service().list_test_runs()]


@router.get("/latest")
def latest_test_result() -> dict[str, object] | None:
    latest = artifact_service().get_latest_test_run()
    return latest.__dict__ if latest else None


@router.get("/{run_id}/summary")
def test_result_summary(run_id: str) -> dict[str, str]:
    return _section_response(run_id, "summary.txt")


@router.get("/{run_id}/rbac")
def test_result_rbac(run_id: str) -> dict[str, str]:
    return _section_response(run_id, "rbac-tests.txt")


@router.get("/{run_id}/resource")
def test_result_resource(run_id: str) -> dict[str, str]:
    return _section_response(run_id, "resource-tests.txt")


@router.get("/{run_id}/network")
def test_result_network(run_id: str) -> dict[str, str]:
    return _section_response(run_id, "network-tests.txt")


@router.get("/{run_id}/cluster-state")
def test_result_cluster_state(run_id: str) -> dict[str, str]:
    return _section_response(run_id, "cluster-state.txt")


def _section_response(run_id: str, section: str) -> dict[str, str]:
    try:
        content = artifact_service().read_test_result_section(run_id, section)
    except ValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"run_id": run_id, "section": section, "content": content}
