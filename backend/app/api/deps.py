from __future__ import annotations

from functools import lru_cache

from backend.app.config import Settings, get_settings
from backend.app.services.artifact_service import ArtifactService
from backend.app.services.audit_service import AuditService
from backend.app.services.command_runner import CommandRunner
from backend.app.services.environment_service import EnvironmentService
from backend.app.services.kubeconfig_service import KubeconfigService
from backend.app.services.kubectl_service import KubectlService
from backend.app.services.task_service import TaskService
from backend.app.services.validation_service import ValidationService


@lru_cache
def settings() -> Settings:
    return get_settings()


@lru_cache
def validation_service() -> ValidationService:
    return ValidationService()


@lru_cache
def command_runner() -> CommandRunner:
    return CommandRunner(settings())


@lru_cache
def audit_service() -> AuditService:
    return AuditService(settings())


@lru_cache
def task_service() -> TaskService:
    return TaskService(settings(), command_runner(), audit_service())


@lru_cache
def artifact_service() -> ArtifactService:
    return ArtifactService(settings())


@lru_cache
def kubeconfig_service() -> KubeconfigService:
    return KubeconfigService(settings(), validation_service())


@lru_cache
def kubectl_service() -> KubectlService:
    return KubectlService(settings())


@lru_cache
def environment_service() -> EnvironmentService:
    return EnvironmentService(settings())
