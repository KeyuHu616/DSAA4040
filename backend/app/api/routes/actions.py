from __future__ import annotations

from fastapi import APIRouter, Body, HTTPException

from backend.app.api.deps import task_service, validation_service
from backend.app.core.constants import SUPPORTED_BOOTSTRAP_RUNTIMES
from backend.app.core.errors import ValidationError


router = APIRouter(prefix="/api/actions", tags=["actions"])


@router.post("/check-environment")
def run_check_environment() -> dict[str, object]:
    record = task_service().start_background_action("check-environment", timeout_seconds=120)
    return record.__dict__


@router.post("/bootstrap")
def run_bootstrap(payload: dict[str, str] = Body(default_factory=dict)) -> dict[str, object]:
    runtime = payload.get("runtime", "k3d")
    if runtime not in SUPPORTED_BOOTSTRAP_RUNTIMES:
        raise HTTPException(status_code=400, detail="unsupported bootstrap runtime")
    record = task_service().start_background_action("bootstrap", args=[runtime], timeout_seconds=900)
    return record.__dict__


@router.post("/run-tests")
def run_tests() -> dict[str, object]:
    record = task_service().start_background_action("run-tests", timeout_seconds=1800)
    return record.__dict__


@router.get("/runs")
def list_runs() -> list[dict[str, object]]:
    return [record.__dict__ for record in task_service().list_tasks()]


@router.get("/runs/{run_id}")
def get_run(run_id: str) -> dict[str, object]:
    try:
        record = task_service().get_task(run_id)
        payload = record.__dict__.copy()
        payload["log"] = task_service().read_task_log(run_id)
        return payload
    except ValidationError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
