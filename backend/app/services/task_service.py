from __future__ import annotations

import json
import threading
import uuid
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

from backend.app.config import Settings
from backend.app.core.errors import ValidationError
from backend.app.core.locks import cluster_mutation_lock
from backend.app.services.audit_service import AuditService
from backend.app.services.command_runner import CommandRunner, CommandRunResult


@dataclass(frozen=True)
class TaskRecord:
    run_id: str
    action: str
    argv: list[str]
    status: str
    started_at: str
    finished_at: str | None
    duration_seconds: float | None
    exit_code: int | None
    timed_out: bool
    log_path: str | None
    error: str | None


class TaskService:
    """Stores task metadata on disk and executes actions in background threads."""

    def __init__(self, settings: Settings, command_runner: CommandRunner, audit_service: AuditService) -> None:
        self.settings = settings
        self.command_runner = command_runner
        self.audit_service = audit_service
        self.settings.gui_tasks_root.mkdir(parents=True, exist_ok=True)

    def start_background_action(
        self,
        action: str,
        *,
        args: Sequence[str] | None = None,
        timeout_seconds: int | None = None,
    ) -> TaskRecord:
        argv = self.command_runner.build_action_argv(action, args)
        run_id = uuid.uuid4().hex
        record = TaskRecord(
            run_id=run_id,
            action=action,
            argv=argv,
            status="running",
            started_at=datetime.now(timezone.utc).isoformat(),
            finished_at=None,
            duration_seconds=None,
            exit_code=None,
            timed_out=False,
            log_path=None,
            error=None,
        )
        self._write_record(record)
        self.audit_service.append_event(action, "started", run_id, {"argv": argv})

        worker = threading.Thread(
            target=self._execute_action,
            kwargs={
                "run_id": run_id,
                "action": action,
                "args": list(args or []),
                "timeout_seconds": timeout_seconds,
            },
            daemon=True,
        )
        worker.start()
        return record

    def list_tasks(self) -> list[TaskRecord]:
        results: list[TaskRecord] = []
        for path in sorted(self.settings.gui_tasks_root.glob("*.json"), reverse=True):
            results.append(self._read_record(path))
        return results

    def get_task(self, run_id: str) -> TaskRecord:
        path = self._task_path(run_id)
        if not path.exists():
            raise ValidationError(f"unknown task run_id: {run_id}")
        return self._read_record(path)

    def read_task_log(self, run_id: str) -> dict[str, object] | None:
        record = self.get_task(run_id)
        if not record.log_path:
            return None

        log_path = Path(record.log_path)
        if not log_path.exists():
            return None
        return json.loads(log_path.read_text(encoding="utf-8"))

    def _execute_action(
        self,
        *,
        run_id: str,
        action: str,
        args: list[str],
        timeout_seconds: int | None,
    ) -> None:
        if self.command_runner.is_serialized_action(action):
            with cluster_mutation_lock:
                self._run_and_store(run_id, action, args, timeout_seconds)
            return
        self._run_and_store(run_id, action, args, timeout_seconds)

    def _run_and_store(
        self,
        run_id: str,
        action: str,
        args: list[str],
        timeout_seconds: int | None,
    ) -> None:
        try:
            result = self.command_runner.run_action(action, args=args, timeout_seconds=timeout_seconds)
            record = TaskRecord(
                run_id=run_id,
                action=action,
                argv=list(result.argv),
                status="succeeded" if result.ok else "failed",
                started_at=self.get_task(run_id).started_at,
                finished_at=datetime.now(timezone.utc).isoformat(),
                duration_seconds=result.duration_seconds,
                exit_code=result.exit_code,
                timed_out=result.timed_out,
                log_path=str(result.log_path),
                error=None,
            )
            self._write_record(record)
            self.audit_service.append_event(
                action,
                record.status,
                run_id,
                {
                    "exit_code": result.exit_code,
                    "timed_out": result.timed_out,
                    "log_path": str(result.log_path),
                },
            )
        except Exception as exc:
            started_at = self.get_task(run_id).started_at
            record = TaskRecord(
                run_id=run_id,
                action=action,
                argv=self.command_runner.build_action_argv(action, args),
                status="failed",
                started_at=started_at,
                finished_at=datetime.now(timezone.utc).isoformat(),
                duration_seconds=None,
                exit_code=None,
                timed_out=False,
                log_path=None,
                error=str(exc),
            )
            self._write_record(record)
            self.audit_service.append_event(action, "failed", run_id, {"error": str(exc)})

    def _task_path(self, run_id: str) -> Path:
        return self.settings.gui_tasks_root / f"{run_id}.json"

    def _write_record(self, record: TaskRecord) -> None:
        self._task_path(record.run_id).write_text(
            json.dumps(asdict(record), indent=2),
            encoding="utf-8",
        )

    def _read_record(self, path: Path) -> TaskRecord:
        payload = json.loads(path.read_text(encoding="utf-8"))
        return TaskRecord(**payload)
