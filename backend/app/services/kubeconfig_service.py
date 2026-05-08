from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from backend.app.config import Settings
from backend.app.services.validation_service import ValidationService


@dataclass(frozen=True)
class KubeconfigInfo:
    filename: str
    username: str
    namespace: str | None
    size_bytes: int
    modified_time: float


class KubeconfigService:
    """Lists safe kubeconfig files without exposing key material."""

    def __init__(self, settings: Settings, validation_service: ValidationService) -> None:
        self.settings = settings
        self.validation_service = validation_service

    def list_safe_kubeconfigs(self) -> list[KubeconfigInfo]:
        kubeconfig_dir = self.settings.artifacts_root / "kubeconfigs"
        if not kubeconfig_dir.exists():
            return []

        results: list[KubeconfigInfo] = []
        for path in sorted(kubeconfig_dir.iterdir()):
            if not path.is_file() or not self.validation_service.is_safe_kubeconfig_path(path):
                continue

            stat = path.stat()
            username, namespace = self._read_kubeconfig_metadata(path)
            results.append(
                KubeconfigInfo(
                    filename=path.name,
                    username=username,
                    namespace=namespace,
                    size_bytes=stat.st_size,
                    modified_time=stat.st_mtime,
                )
            )
        return results

    def _read_kubeconfig_metadata(self, path: Path) -> tuple[str, str | None]:
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}

        user_name = path.stem
        users = data.get("users", [])
        if users and isinstance(users[0], dict):
            user_name = users[0].get("name", user_name)

        namespace = None
        contexts = data.get("contexts", [])
        current_context = data.get("current-context")
        if current_context:
            for context in contexts:
                if context.get("name") == current_context:
                    namespace = context.get("context", {}).get("namespace")
                    break

        return user_name, namespace
