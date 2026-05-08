from __future__ import annotations

import json
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence

from backend.app.config import Settings
from backend.app.core.constants import ActionSpec, allowed_action_map
from backend.app.core.errors import CommandExecutionError, ValidationError


@dataclass(frozen=True)
class CommandRunResult:
    action: str
    argv: tuple[str, ...]
    exit_code: int
    duration_seconds: float
    stdout: str
    stderr: str
    timed_out: bool
    log_path: Path

    @property
    def ok(self) -> bool:
        return self.exit_code == 0 and not self.timed_out


class CommandRunner:
    """Executes a small whitelist of repository-local commands without a shell."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.settings.gui_logs_root.mkdir(parents=True, exist_ok=True)
        self._allowed_actions = allowed_action_map(settings.repo_root)

    def get_action_spec(self, action: str) -> ActionSpec:
        try:
            return self._allowed_actions[action]
        except KeyError as exc:
            raise ValidationError(f"unsupported action: {action}") from exc

    def build_action_argv(self, action: str, args: Sequence[str] | None = None) -> list[str]:
        spec = self.get_action_spec(action)
        argv = list(spec.argv_prefix)
        if args:
            argv.extend(args)
        return argv

    def run_action(
        self,
        action: str,
        *,
        args: Sequence[str] | None = None,
        timeout_seconds: int | None = None,
        extra_env: Mapping[str, str] | None = None,
    ) -> CommandRunResult:
        argv = self.build_action_argv(action, args)
        started_at = time.monotonic()
        timeout = timeout_seconds or self.settings.command_timeout_seconds
        env = self._build_env(extra_env)
        timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        log_path = self.settings.gui_logs_root / f"{timestamp}-{action}.json"

        try:
            completed = subprocess.run(
                argv,
                cwd=self.settings.repo_root,
                env=env,
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
            duration_seconds = time.monotonic() - started_at
            result = CommandRunResult(
                action=action,
                argv=tuple(argv),
                exit_code=completed.returncode,
                duration_seconds=duration_seconds,
                stdout=completed.stdout,
                stderr=completed.stderr,
                timed_out=False,
                log_path=log_path,
            )
        except FileNotFoundError as exc:
            raise CommandExecutionError(f"failed to execute {action}: {exc}") from exc
        except subprocess.TimeoutExpired as exc:
            duration_seconds = time.monotonic() - started_at
            stdout = exc.stdout or ""
            stderr = exc.stderr or ""
            result = CommandRunResult(
                action=action,
                argv=tuple(argv),
                exit_code=124,
                duration_seconds=duration_seconds,
                stdout=stdout,
                stderr=stderr,
                timed_out=True,
                log_path=log_path,
            )

        self._write_log(result)
        return result

    def is_serialized_action(self, action: str) -> bool:
        return self.get_action_spec(action).serialized

    def _build_env(self, extra_env: Mapping[str, str] | None) -> dict[str, str]:
        base_keys = ("PATH", "HOME", "KUBECONFIG", "BOOTSTRAP_KUBECONFIG")
        env = {key: value for key, value in subprocess.os.environ.items() if key in base_keys}
        if extra_env:
            env.update(extra_env)
        return env

    def _write_log(self, result: CommandRunResult) -> None:
        payload = {
            "action": result.action,
            "argv": list(result.argv),
            "exit_code": result.exit_code,
            "duration_seconds": round(result.duration_seconds, 3),
            "timed_out": result.timed_out,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
        result.log_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
