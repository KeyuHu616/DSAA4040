from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone

from backend.app.config import Settings


@dataclass(frozen=True)
class AuditEvent:
    timestamp: str
    action: str
    status: str
    run_id: str
    detail: dict[str, object]


class AuditService:
    """Appends a simple JSONL audit log under artifacts/gui-runs/audit."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.settings.gui_audit_root.mkdir(parents=True, exist_ok=True)
        self.audit_log_path = self.settings.gui_audit_root / "api-audit.jsonl"

    def append_event(self, action: str, status: str, run_id: str, detail: dict[str, object]) -> None:
        event = AuditEvent(
            timestamp=datetime.now(timezone.utc).isoformat(),
            action=action,
            status=status,
            run_id=run_id,
            detail=detail,
        )
        with self.audit_log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(asdict(event), ensure_ascii=True) + "\n")
