from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from backend.app.config import Settings


class EnvironmentService:
    """Collects lightweight local health data for the backend dashboard."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def get_cluster_health(self) -> dict[str, object]:
        kubeconfig = Path.home() / ".kube" / "config"
        kubectl_available = shutil.which("kubectl") is not None
        docker_available = shutil.which("docker") is not None
        k3d_available = shutil.which("k3d") is not None
        server = self._read_current_server(kubeconfig) if kubectl_available and kubeconfig.exists() else None

        return {
            "backend_host": self.settings.backend_host,
            "backend_port": self.settings.backend_port,
            "localhost_only": self.settings.backend_host in {"127.0.0.1", "localhost"},
            "kubectl_available": kubectl_available,
            "docker_available": docker_available,
            "k3d_available": k3d_available,
            "bootstrap_kubeconfig": str(kubeconfig),
            "bootstrap_kubeconfig_exists": kubeconfig.exists(),
            "current_server": server,
            "server_needs_loopback_fix": bool(server and "0.0.0.0:6550" in server),
        }

    def _read_current_server(self, kubeconfig: Path) -> str | None:
        completed = subprocess.run(
            [
                "kubectl",
                "--kubeconfig",
                str(kubeconfig),
                "config",
                "view",
                "--raw",
                "--minify",
                "-o",
                "jsonpath={.clusters[0].cluster.server}",
            ],
            cwd=self.settings.repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
        if completed.returncode != 0:
            return None
        server = completed.stdout.strip()
        return server or None
