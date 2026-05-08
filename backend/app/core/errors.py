class BackendError(Exception):
    """Base error raised by backend services."""


class ValidationError(BackendError):
    """Raised when request input or configuration is invalid."""


class CommandExecutionError(BackendError):
    """Raised when a local command fails to execute safely."""
