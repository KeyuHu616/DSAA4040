from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final


TENANT_NAME_PATTERN: Final[str] = r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"
SAFE_KUBECONFIG_SUFFIX: Final[str] = ".kubeconfig"
FORBIDDEN_KUBECONFIG_SUFFIXES: Final[tuple[str, ...]] = (".key", ".crt", ".csr")
FORBIDDEN_KUBECONFIG_NAMES: Final[tuple[str, ...]] = (".generated",)
SUPPORTED_BOOTSTRAP_RUNTIMES: Final[tuple[str, ...]] = ("k3d", "k3s", "minikube")


@dataclass(frozen=True)
class ActionSpec:
    argv_prefix: tuple[str, ...]
    serialized: bool


def allowed_action_map(repo_root: Path) -> dict[str, ActionSpec]:
    scripts_dir = repo_root / "scripts"
    return {
        "check-environment": ActionSpec(
            argv_prefix=("bash", str(scripts_dir / "check-environment.sh")),
            serialized=False,
        ),
        "bootstrap": ActionSpec(
            argv_prefix=("bash", str(scripts_dir / "bootstrap-cluster.sh")),
            serialized=True,
        ),
        "onboard-team": ActionSpec(
            argv_prefix=("bash", str(scripts_dir / "onboard-team.sh")),
            serialized=True,
        ),
        "offboard-team": ActionSpec(
            argv_prefix=("bash", str(scripts_dir / "offboard-team.sh")),
            serialized=True,
        ),
        "run-tests": ActionSpec(
            argv_prefix=("bash", str(scripts_dir / "run-tests.sh")),
            serialized=True,
        ),
    }
