from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    """Static local-backend settings derived from the repository layout."""

    repo_root: Path
    backend_host: str = "127.0.0.1"
    backend_port: int = 8000
    command_timeout_seconds: int = 120

    @property
    def artifacts_root(self) -> Path:
        return self.repo_root / "artifacts"

    @property
    def gui_runs_root(self) -> Path:
        return self.artifacts_root / "gui-runs"

    @property
    def gui_logs_root(self) -> Path:
        return self.gui_runs_root / "logs"

    @property
    def gui_tasks_root(self) -> Path:
        return self.gui_runs_root / "tasks"

    @property
    def gui_audit_root(self) -> Path:
        return self.gui_runs_root / "audit"


def get_settings() -> Settings:
    return Settings(repo_root=Path(__file__).resolve().parents[2])
