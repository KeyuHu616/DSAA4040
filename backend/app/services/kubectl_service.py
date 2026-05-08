from __future__ import annotations

import json
import subprocess
from pathlib import Path

from backend.app.config import Settings
from backend.app.core.errors import CommandExecutionError


class KubectlService:
    """Runs a small whitelist of read-only kubectl get commands."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def list_nodes(self) -> dict[str, object]:
        return self._kubectl_get_json(["nodes"])

    def list_namespaces(self) -> dict[str, object]:
        return self._kubectl_get_json(["namespaces"])

    def list_resource(self, namespace: str, resource: str) -> dict[str, object]:
        allowed_resources = {
            "resourcequota",
            "limitrange",
            "networkpolicy",
            "rolebinding",
            "pods",
            "services",
        }
        if resource not in allowed_resources:
            raise CommandExecutionError(f"unsupported kubectl resource: {resource}")
        return self._kubectl_get_json([resource, "-n", namespace])

    def _kubectl_get_json(self, args: list[str]) -> dict[str, object]:
        command = ["kubectl", *self._kubeconfig_args(), "get", *args, "-o", "json"]
        try:
            completed = subprocess.run(
                command,
                cwd=self.settings.repo_root,
                text=True,
                capture_output=True,
                check=False,
            )
        except FileNotFoundError as exc:
            raise CommandExecutionError("kubectl is not available on PATH") from exc
        if completed.returncode != 0:
            raise CommandExecutionError(completed.stderr.strip() or completed.stdout.strip() or "kubectl get failed")
        return json.loads(completed.stdout)

    def _kubeconfig_args(self) -> list[str]:
        kubeconfig = self._default_bootstrap_kubeconfig()
        return ["--kubeconfig", str(kubeconfig)] if kubeconfig.exists() else []

    def _default_bootstrap_kubeconfig(self) -> Path:
        return Path.home() / ".kube" / "config"
