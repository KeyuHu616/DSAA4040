from __future__ import annotations

import re
from pathlib import Path

from backend.app.core.constants import (
    FORBIDDEN_KUBECONFIG_NAMES,
    FORBIDDEN_KUBECONFIG_SUFFIXES,
    SAFE_KUBECONFIG_SUFFIX,
    TENANT_NAME_PATTERN,
)
from backend.app.core.errors import ValidationError


class ValidationService:
    """Input and file-surface validation helpers shared across API routes."""

    tenant_pattern = re.compile(TENANT_NAME_PATTERN)

    def validate_tenant_name(self, tenant: str) -> str:
        if not self.tenant_pattern.fullmatch(tenant):
            raise ValidationError("tenant name must be a valid DNS-1123 label")
        return tenant

    def validate_confirmed_tenant(self, tenant: str, confirmed_tenant: str) -> str:
        self.validate_tenant_name(tenant)
        if confirmed_tenant != tenant:
            raise ValidationError("tenant confirmation does not match target tenant")
        return tenant

    def is_safe_kubeconfig_path(self, path: Path) -> bool:
        if path.name in FORBIDDEN_KUBECONFIG_NAMES:
            return False
        if path.suffix != SAFE_KUBECONFIG_SUFFIX:
            return False
        if any(path.name.endswith(suffix) for suffix in FORBIDDEN_KUBECONFIG_SUFFIXES):
            return False
        if any(part.startswith(".") and part != path.name for part in path.parts):
            return False
        return True
